-- Notifications Phase 5: push delivery (Web Push + FCM).
--
-- Flow:
--   user_notifications INSERT
--     -> queue_notification_push (per row): one delivery per active device,
--        honouring push preferences, data.push = false and quiet hours
--     -> kick_notification_push (per statement): pg_net POST to the
--        send-push Edge Function
--   send-push claims due deliveries (claim_push_deliveries), sends them,
--   and reports back (complete_push_deliveries).
--   pg_cron retries / releases quiet-hours deliveries every minute.
--
-- Provider secrets (VAPID private key, FCM service account) live only in
-- Edge Function secrets. The function URL + shared dispatch secret live in
-- Vault ('push_dispatch_url', 'push_dispatch_secret'); without them pushes
-- stay queued and nothing is sent.

create extension if not exists pg_net;

begin;

-- ---------------------------------------------------------------------------
-- Devices
-- ---------------------------------------------------------------------------
create table if not exists public.push_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  provider text not null check (provider in ('webpush', 'fcm')),
  platform text not null check (platform in ('web', 'android', 'ios')),
  -- FCM registration token, or the Web Push endpoint URL.
  token text not null unique check (length(token) between 10 and 4096),
  -- Web Push only: { endpoint, keys: { p256dh, auth } }.
  subscription jsonb,
  device_label text check (device_label is null or length(device_label) <= 120),
  failure_count integer not null default 0,
  disabled_at timestamptz,
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists push_tokens_user_active_idx
  on public.push_tokens (user_id)
  where disabled_at is null;

alter table public.push_tokens enable row level security;

drop policy if exists push_tokens_select_own on public.push_tokens;
create policy push_tokens_select_own
on public.push_tokens for select
using (user_id = auth.uid());

drop policy if exists push_tokens_delete_own on public.push_tokens;
create policy push_tokens_delete_own
on public.push_tokens for delete
using (user_id = auth.uid());

revoke insert, update on public.push_tokens from anon, authenticated;

-- A device belongs to whoever registered it last (shared phones / browsers).
create or replace function public.register_push_token(
  p_provider text,
  p_platform text,
  p_token text,
  p_subscription jsonb default null,
  p_device_label text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
  token_id uuid;
  clean_token text := trim(coalesce(p_token, ''));
begin
  if me is null then
    raise exception 'not authenticated';
  end if;
  if p_provider not in ('webpush', 'fcm') or p_platform not in ('web', 'android', 'ios') then
    raise exception 'invalid provider or platform';
  end if;
  if length(clean_token) < 10 or length(clean_token) > 4096 then
    raise exception 'invalid token';
  end if;
  if p_provider = 'webpush' then
    if clean_token !~ '^https://'
       or p_subscription is null
       or p_subscription->>'endpoint' is distinct from clean_token
       or coalesce(p_subscription #>> '{keys,p256dh}', '') = ''
       or coalesce(p_subscription #>> '{keys,auth}', '') = '' then
      raise exception 'invalid web push subscription';
    end if;
  end if;

  insert into public.push_tokens as t (
    user_id, provider, platform, token, subscription, device_label
  ) values (
    me, p_provider, p_platform, clean_token,
    case when p_provider = 'webpush' then p_subscription else null end,
    left(nullif(trim(coalesce(p_device_label, '')), ''), 120)
  )
  on conflict (token) do update set
    user_id = excluded.user_id,
    provider = excluded.provider,
    platform = excluded.platform,
    subscription = excluded.subscription,
    device_label = coalesce(excluded.device_label, t.device_label),
    failure_count = 0,
    disabled_at = null,
    last_seen_at = now(),
    updated_at = now()
  returning id into token_id;

  -- Keep the 10 most recently seen devices per user.
  delete from public.push_tokens
  where user_id = me
    and id in (
      select id from public.push_tokens
      where user_id = me
      order by last_seen_at desc
      offset 10
    );

  return token_id;
end;
$$;

create or replace function public.unregister_push_token(p_token text)
returns void
language sql
security definer
set search_path = public
as $$
  delete from public.push_tokens
  where token = trim(coalesce(p_token, ''))
    and user_id = auth.uid();
$$;

revoke all on function public.register_push_token(text, text, text, jsonb, text) from public, anon;
grant execute on function public.register_push_token(text, text, text, jsonb, text) to authenticated;
revoke all on function public.unregister_push_token(text) from public, anon;
grant execute on function public.unregister_push_token(text) to authenticated;

-- ---------------------------------------------------------------------------
-- Delivery queue / log
-- ---------------------------------------------------------------------------
create table if not exists public.notification_push_deliveries (
  id uuid primary key default gen_random_uuid(),
  notification_id uuid not null references public.user_notifications (id) on delete cascade,
  user_id uuid not null,
  token_id uuid not null references public.push_tokens (id) on delete cascade,
  status text not null default 'queued'
    check (status in ('queued', 'sending', 'sent', 'failed', 'skipped')),
  scheduled_at timestamptz not null default now(),
  attempts integer not null default 0,
  last_error text,
  created_at timestamptz not null default now(),
  claimed_at timestamptz,
  sent_at timestamptz,
  unique (notification_id, token_id)
);

create index if not exists notification_push_deliveries_due_idx
  on public.notification_push_deliveries (scheduled_at)
  where status in ('queued', 'sending');

create index if not exists notification_push_deliveries_created_idx
  on public.notification_push_deliveries (created_at desc);

alter table public.notification_push_deliveries enable row level security;

-- Admins can read the delivery log; nobody writes it from the client.
drop policy if exists notification_push_deliveries_admin_select on public.notification_push_deliveries;
create policy notification_push_deliveries_admin_select
on public.notification_push_deliveries for select
using (public.is_admin());

revoke insert, update, delete on public.notification_push_deliveries from anon, authenticated;

-- Lock-screen text. Private content (messages, feedback, account notices)
-- never leaves the app; the alert only says something is waiting.
create or replace function public.notification_push_text(
  p_type text,
  p_title text,
  p_body text
)
returns table (title text, body text)
language sql
immutable
as $$
  select
    case p_type
      when 'message' then 'New message'
      when 'feedback' then 'Feedback update'
      when 'system' then 'Account update'
      else left(coalesce(nullif(trim(p_title), ''), 'Alumni Portal'), 80)
    end,
    case p_type
      when 'message' then 'You have a new message. Open the app to read it.'
      when 'feedback' then 'There is an update on your feedback. Open the app to see it.'
      when 'system' then 'Open the app to see the details.'
      else case when length(coalesce(p_body, '')) > 140
        then left(p_body, 139) || '…' else coalesce(p_body, '') end
    end;
$$;

create or replace function public.queue_notification_push()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  at timestamptz;
begin
  begin
    if lower(coalesce(new.data->>'push', 'true')) = 'false' then
      return new;
    end if;
    if new.expires_at is not null and new.expires_at <= now() then
      return new;
    end if;
    if not exists (
      select 1 from public.push_tokens t
      where t.user_id = new.user_id and t.disabled_at is null
    ) then
      return new;
    end if;
    if not public.notification_channel_allowed(
      new.user_id, new.type, 'push', coalesce(new.priority, 'normal')
    ) then
      return new;
    end if;

    at := coalesce(
      public.notification_quiet_until(new.user_id, coalesce(new.priority, 'normal')),
      now()
    );

    insert into public.notification_push_deliveries (
      notification_id, user_id, token_id, scheduled_at
    )
    select new.id, new.user_id, t.id, at
    from public.push_tokens t
    where t.user_id = new.user_id and t.disabled_at is null
    on conflict (notification_id, token_id) do nothing;
  exception when others then
    raise warning 'queue_notification_push(%): %', new.id, sqlerrm;
  end;
  return new;
end;
$$;

drop trigger if exists trg_queue_notification_push on public.user_notifications;
create trigger trg_queue_notification_push
after insert on public.user_notifications
for each row execute function public.queue_notification_push();

-- POST to send-push when something is due. Silent no-op until Vault has
-- the dispatch URL + secret.
create or replace function public.notification_push_dispatch()
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  url text;
  secret text;
begin
  if not exists (
    select 1 from public.notification_push_deliveries
    where (status = 'queued' and scheduled_at <= now())
       or (status = 'sending' and claimed_at < now() - interval '5 minutes')
  ) then
    return false;
  end if;

  select decrypted_secret into url from vault.decrypted_secrets where name = 'push_dispatch_url';
  select decrypted_secret into secret from vault.decrypted_secrets where name = 'push_dispatch_secret';
  if coalesce(url, '') = '' or coalesce(secret, '') = '' then
    return false;
  end if;

  perform net.http_post(
    url := url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-dispatch-secret', secret
    ),
    body := '{}'::jsonb,
    timeout_milliseconds := 10000
  );
  return true;
exception when others then
  raise warning 'notification_push_dispatch: %', sqlerrm;
  return false;
end;
$$;

create or replace function public.kick_notification_push()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.notification_push_dispatch();
  return null;
end;
$$;

drop trigger if exists trg_kick_notification_push on public.user_notifications;
create trigger trg_kick_notification_push
after insert on public.user_notifications
for each statement execute function public.kick_notification_push();

-- Called by send-push (service role only).
create or replace function public.claim_push_deliveries(p_limit integer default 100)
returns table (
  delivery_id uuid,
  notification_id uuid,
  provider text,
  platform text,
  token text,
  subscription jsonb,
  type text,
  priority text,
  title text,
  body text,
  route text,
  attempts integer
)
language plpgsql
security definer
set search_path = public
as $$
#variable_conflict use_column
begin
  update public.notification_push_deliveries d
  set status = 'skipped', last_error = 'device disabled'
  from public.push_tokens t
  where t.id = d.token_id
    and t.disabled_at is not null
    and d.status in ('queued', 'sending');

  update public.notification_push_deliveries d
  set status = 'failed', last_error = coalesce(d.last_error, 'send timed out')
  where d.status = 'sending'
    and d.claimed_at < now() - interval '5 minutes'
    and d.attempts >= 4;

  return query
  with due as (
    select d.id
    from public.notification_push_deliveries d
    where (d.status = 'queued' and d.scheduled_at <= now())
       or (d.status = 'sending' and d.claimed_at < now() - interval '5 minutes')
    order by d.scheduled_at
    limit greatest(1, least(coalesce(p_limit, 100), 500))
    for update skip locked
  ),
  claimed as (
    update public.notification_push_deliveries d
    set status = 'sending', attempts = d.attempts + 1, claimed_at = now()
    from due
    where d.id = due.id
    returning d.*
  )
  select c.id, c.notification_id, t.provider, t.platform, t.token, t.subscription,
         n.type, coalesce(n.priority, 'normal'), txt.title, txt.body, n.route, c.attempts
  from claimed c
  join public.push_tokens t on t.id = c.token_id
  join public.user_notifications n on n.id = c.notification_id
  cross join lateral public.notification_push_text(n.type, n.title, n.body) txt;
end;
$$;

-- p_results: [{ "id": uuid, "ok": bool, "error": text, "retry": bool, "disable_token": bool }]
create or replace function public.complete_push_deliveries(p_results jsonb)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  r jsonb;
  d public.notification_push_deliveries%rowtype;
  handled integer := 0;
begin
  for r in select * from jsonb_array_elements(coalesce(p_results, '[]'::jsonb)) loop
    select * into d from public.notification_push_deliveries
    where id = (r->>'id')::uuid
    for update;
    if not found then
      continue;
    end if;
    handled := handled + 1;

    if coalesce((r->>'ok')::boolean, false) then
      update public.notification_push_deliveries
      set status = 'sent', sent_at = now(), last_error = null
      where id = d.id;
      update public.push_tokens
      set failure_count = 0
      where id = d.token_id and failure_count <> 0;
      continue;
    end if;

    if coalesce((r->>'disable_token')::boolean, false) then
      update public.push_tokens
      set disabled_at = now(), updated_at = now()
      where id = d.token_id;
      update public.notification_push_deliveries
      set status = 'failed', last_error = left(r->>'error', 500)
      where id = d.id;
      continue;
    end if;

    update public.push_tokens
    set failure_count = failure_count + 1, updated_at = now()
    where id = d.token_id;

    if coalesce((r->>'retry')::boolean, true) and d.attempts < 4 then
      update public.notification_push_deliveries
      set status = 'queued',
          scheduled_at = now() + (interval '1 minute' * power(4, d.attempts - 1)),
          last_error = left(r->>'error', 500)
      where id = d.id;
    else
      update public.notification_push_deliveries
      set status = case when coalesce((r->>'skipped')::boolean, false) then 'skipped' else 'failed' end,
          last_error = left(r->>'error', 500)
      where id = d.id;
    end if;
  end loop;

  -- Devices that keep failing stop receiving pushes until they re-register.
  update public.push_tokens
  set disabled_at = now(), updated_at = now()
  where disabled_at is null and failure_count >= 10;

  return handled;
end;
$$;

revoke all on function public.notification_push_text(text, text, text) from public, anon, authenticated;
revoke all on function public.queue_notification_push() from public, anon, authenticated;
revoke all on function public.notification_push_dispatch() from public, anon, authenticated;
revoke all on function public.kick_notification_push() from public, anon, authenticated;
revoke all on function public.claim_push_deliveries(integer) from public, anon, authenticated;
revoke all on function public.complete_push_deliveries(jsonb) from public, anon, authenticated;
grant execute on function public.claim_push_deliveries(integer) to service_role;
grant execute on function public.complete_push_deliveries(jsonb) to service_role;

-- Housekeeping for the delivery log (runs with the existing cleanup job).
create or replace function public.run_notification_cleanup()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  removed integer;
begin
  delete from public.user_notifications n
  where (n.expires_at is not null and n.expires_at < now() - interval '1 day')
     or (n.is_read and n.created_at < now() - interval '90 days')
     or n.created_at < now() - interval '180 days';
  get diagnostics removed = row_count;

  delete from public.notification_push_deliveries
  where status in ('sent', 'failed', 'skipped')
    and created_at < now() - interval '30 days';

  delete from public.push_tokens
  where disabled_at is not null and disabled_at < now() - interval '30 days';

  return removed;
end;
$$;

revoke all on function public.run_notification_cleanup() from public, anon, authenticated;

commit;

select cron.schedule(
  'aess-push-dispatch',
  '* * * * *',
  $$select public.notification_push_dispatch()$$
);
