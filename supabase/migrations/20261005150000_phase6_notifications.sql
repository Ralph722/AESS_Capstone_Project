-- Phase 6: notifications.
--   * user_notifications are created by the server only (triggers, cron jobs
--     and admin RPCs, all SECURITY DEFINER); clients can read, mark read and
--     delete their own
--   * notify_new_message dropped (trg notify_message_recipient does the job)
--   * notification_push_deliveries becomes notification_deliveries with a
--     channel column ('push', 'email', 'sms'); send-email logs each email.
--     SMS is reserved for later; nothing writes it yet.

-- ---------------------------------------------------------------------------
-- Server-only notification creation
-- ---------------------------------------------------------------------------
drop policy if exists user_notifications_insert_admin_or_owner on public.user_notifications;
revoke insert on public.user_notifications from authenticated;
revoke all on public.user_notifications from anon;

drop function if exists public.notify_new_message(uuid, uuid, text, uuid, text, text);

-- ---------------------------------------------------------------------------
-- One delivery log for every channel
-- ---------------------------------------------------------------------------
alter table public.notification_push_deliveries rename to notification_deliveries;

alter index public.notification_push_deliveries_pkey rename to notification_deliveries_pkey;
alter index public.notification_push_deliveries_notification_id_token_id_key
  rename to notification_deliveries_notification_id_token_id_key;
alter index public.notification_push_deliveries_created_idx rename to notification_deliveries_created_idx;
alter index public.idx_notification_push_deliveries_token_id rename to idx_notification_deliveries_token_id;
alter index public.idx_notification_push_deliveries_user_id rename to idx_notification_deliveries_user_id;

alter table public.notification_deliveries
  rename constraint notification_push_deliveries_status_check to notification_deliveries_status_check;
alter table public.notification_deliveries
  rename constraint notification_push_deliveries_notification_id_fkey to notification_deliveries_notification_id_fkey;
alter table public.notification_deliveries
  rename constraint notification_push_deliveries_token_id_fkey to notification_deliveries_token_id_fkey;
alter table public.notification_deliveries
  rename constraint notification_push_deliveries_user_id_fkey to notification_deliveries_user_id_fkey;

alter table public.notification_deliveries
  add column if not exists channel text not null default 'push',
  add column if not exists recipient text,
  add column if not exists data jsonb not null default '{}'::jsonb,
  alter column notification_id drop not null,
  alter column token_id drop not null,
  alter column user_id drop not null;

alter table public.notification_deliveries
  add constraint notification_deliveries_channel_check
    check (channel in ('push', 'email', 'sms')),
  add constraint notification_deliveries_target_check
    check (
      case channel
        when 'push' then token_id is not null and notification_id is not null and user_id is not null
        else recipient is not null and token_id is null
      end
    );

drop index if exists public.notification_push_deliveries_due_idx;
create index if not exists notification_deliveries_due_idx
  on public.notification_deliveries (scheduled_at)
  where channel = 'push' and status in ('queued', 'sending');

drop policy if exists notification_push_deliveries_admin_select on public.notification_deliveries;
drop policy if exists notification_deliveries_admin_select on public.notification_deliveries;
create policy notification_deliveries_admin_select on public.notification_deliveries
  for select to authenticated
  using ((select public.is_admin()));

revoke all on public.notification_deliveries from public, anon, authenticated;
grant select on public.notification_deliveries to authenticated;
grant all on public.notification_deliveries to service_role;

comment on table public.notification_deliveries is
  'Delivery attempts per channel. push: one row per notification and device (queued by trg_queue_notification_push, sent by send-push). email: one row per email sent by send-email. sms: reserved.';

-- ---------------------------------------------------------------------------
-- Push pipeline on the renamed table (push rows only)
-- ---------------------------------------------------------------------------
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
    insert into public.notification_deliveries (
      channel, notification_id, user_id, token_id, scheduled_at
    )
    select 'push', new.id, new.user_id, t.id, at
    from public.push_tokens t
    where t.user_id = new.user_id and t.disabled_at is null
    on conflict (notification_id, token_id) do nothing;
  exception when others then
    raise warning 'queue_notification_push(%): %', new.id, sqlerrm;
  end;
  return new;
end;
$$;

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
    select 1 from public.notification_deliveries
    where channel = 'push'
      and ((status = 'queued' and scheduled_at <= now())
        or (status = 'sending' and claimed_at < now() - interval '5 minutes'))
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
  update public.notification_deliveries d
  set status = 'skipped', last_error = 'device disabled'
  from public.push_tokens t
  where t.id = d.token_id
    and d.channel = 'push'
    and t.disabled_at is not null
    and d.status in ('queued', 'sending');
  update public.notification_deliveries d
  set status = 'failed', last_error = coalesce(d.last_error, 'send timed out')
  where d.channel = 'push'
    and d.status = 'sending'
    and d.claimed_at < now() - interval '5 minutes'
    and d.attempts >= 4;
  return query
  with due as (
    select d.id
    from public.notification_deliveries d
    where d.channel = 'push'
      and ((d.status = 'queued' and d.scheduled_at <= now())
        or (d.status = 'sending' and d.claimed_at < now() - interval '5 minutes'))
    order by d.scheduled_at
    limit greatest(1, least(coalesce(p_limit, 100), 500))
    for update skip locked
  ),
  claimed as (
    update public.notification_deliveries d
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

create or replace function public.complete_push_deliveries(p_results jsonb)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  r jsonb;
  d public.notification_deliveries%rowtype;
  handled integer := 0;
begin
  for r in select * from jsonb_array_elements(coalesce(p_results, '[]'::jsonb)) loop
    select * into d from public.notification_deliveries
    where id = (r->>'id')::uuid and channel = 'push'
    for update;
    if not found then
      continue;
    end if;
    handled := handled + 1;
    if coalesce((r->>'ok')::boolean, false) then
      update public.notification_deliveries
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
      update public.notification_deliveries
      set status = 'failed', last_error = left(r->>'error', 500)
      where id = d.id;
      continue;
    end if;
    update public.push_tokens
    set failure_count = failure_count + 1, updated_at = now()
    where id = d.token_id;
    if coalesce((r->>'retry')::boolean, true) and d.attempts < 4 then
      update public.notification_deliveries
      set status = 'queued',
          scheduled_at = now() + (interval '1 minute' * power(4, d.attempts - 1)),
          last_error = left(r->>'error', 500)
      where id = d.id;
    else
      update public.notification_deliveries
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
  delete from public.notification_deliveries
  where status in ('sent', 'failed', 'skipped')
    and created_at < now() - interval '30 days';
  delete from public.push_tokens
  where disabled_at is not null and disabled_at < now() - interval '30 days';
  return removed;
end;
$$;

notify pgrst, 'reload schema';
