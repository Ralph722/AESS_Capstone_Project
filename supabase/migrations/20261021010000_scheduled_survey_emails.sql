-- Automated survey emails: assignment notice, weekly reminder, closing
-- warning — the email counterparts of the scheduled in-app/push notices in
-- 20261001050000_notifications_scheduled.sql.
--
-- Cadence per survey assignment (all Asia/Manila aware, survey must still
-- be accepting responses, alumnus must not have completed it):
--   * 'assigned'   — once, the first run after the assignment exists.
--   * 'weekly'     — every 7 days after the previous automated email,
--                    at most 3 times (survey_assignments.auto_email_count).
--                    Manual admin reminders use reminder_count and never
--                    consume this cap.
--   * 'closing_3d' / 'closing_1d' — once each, when the survey closes in
--                    3 days / 1 day. These bypass the weekly cap.
--
-- Flow mirrors push: pg_cron (hourly) -> scheduled_email_dispatch()
-- (pg_net, reuses the Vault push_dispatch_url/push_dispatch_secret pair,
-- swapping the function name) -> Edge Function 'send-scheduled-emails'
-- (x-dispatch-secret = PUSH_DISPATCH_SECRET) -> claim/complete RPCs below.
-- Claiming inserts a 'sending' row in notification_deliveries (channel
-- 'email'), which doubles as the dedupe log and the audit trail.
--
-- Silent no-op until the Vault push dispatch pair exists (same behaviour
-- as notification_push_dispatch).

begin;

alter table public.survey_assignments
  add column if not exists auto_email_count integer not null default 0,
  add column if not exists last_auto_email_at timestamptz;

-- ---------------------------------------------------------------------------
-- Claim: pick due automated emails, highest urgency first, and reserve
-- them as 'sending' delivery rows so overlapping runs cannot double-send.
-- ---------------------------------------------------------------------------
create or replace function public.claim_scheduled_survey_emails(
  p_limit integer default 40
)
returns table (
  delivery_id uuid,
  assignment_id uuid,
  user_id uuid,
  email text,
  display_name text,
  survey_id uuid,
  survey_title text,
  is_ched boolean,
  close_at timestamptz,
  kind text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  today date := public.notification_manila_today();
begin
  return query
  with candidates as (
    select
      a.id as assignment_id,
      a.user_id as uid,
      s.id as sid,
      c.kind as ckind,
      c.urgency as urgency
    from public.survey_assignments a
    join public.surveys s on s.id = a.survey_id
    cross join lateral (
      select
        case
          when s.close_at is not null
               and (s.close_at at time zone 'Asia/Manila')::date - today = 1
            then 'closing_1d'
          when s.close_at is not null
               and (s.close_at at time zone 'Asia/Manila')::date - today = 3
            then 'closing_3d'
          when not exists (
            select 1 from public.notification_deliveries d
            where d.channel = 'email'
              and d.user_id = a.user_id
              and d.data->>'survey_id' = s.id::text
              and d.data->>'kind' = 'assigned'
              and (d.status = 'sent'
                   or (d.status = 'sending'
                       and d.created_at > now() - interval '15 minutes'))
          ) then 'assigned'
          when coalesce(a.auto_email_count, 0) < 3
               and a.last_auto_email_at is not null
               and a.last_auto_email_at <= now() - interval '7 days'
            then 'weekly'
        end as kind,
        case
          when s.close_at is not null
               and (s.close_at at time zone 'Asia/Manila')::date - today in (1, 3)
            then 0
          when a.last_auto_email_at is null then 1
          else 2
        end as urgency
    ) c
    where c.kind is not null
      and a.status <> 'completed'
      and public.notification_survey_accepting(s)
      and public.notification_is_active_alumni(a.user_id)
      -- Closing kinds dedupe on the delivery log; weekly is gated by the
      -- counter/last-sent columns instead, 'assigned' by its lateral check.
      and (
        c.kind = 'weekly'
        or not exists (
          select 1 from public.notification_deliveries d
          where d.channel = 'email'
            and d.user_id = a.user_id
            and d.data->>'survey_id' = s.id::text
            and d.data->>'kind' = c.kind
            and (d.status = 'sent'
                 or (d.status = 'sending'
                     and d.created_at > now() - interval '15 minutes'))
        )
      )
    order by c.urgency, a.assigned_at
    limit greatest(1, least(coalesce(p_limit, 40), 100))
  ),
  claimed as (
    insert into public.notification_deliveries (
      channel, user_id, recipient, status, attempts, scheduled_at, data
    )
    select
      'email',
      c.uid,
      lower(trim(u.email)),
      'sending',
      1,
      now(),
      jsonb_build_object(
        'kind', c.ckind,
        'survey_id', c.sid::text,
        'assignment_id', c.assignment_id::text,
        'automated', true
      )
    from candidates c
    join public.users u on u.id = c.uid
    where u.email is not null and trim(u.email) like '%@%'
    returning id, user_id, recipient, data
  )
  select
    cl.id,
    a.id,
    cl.user_id,
    cl.recipient,
    coalesce(nullif(trim(u.display_name), ''), 'Alumni'),
    s.id,
    coalesce(s.title, ''),
    coalesce(s.data->>'kind', '') = 'ched_gts_builtin'
      or coalesce(s.data->>'template_key', '') = 'ched_gts_builtin',
    s.close_at,
    cl.data->>'kind'
  from claimed cl
  join public.survey_assignments a
    on a.id = (cl.data->>'assignment_id')::uuid
  join public.surveys s on s.id = a.survey_id
  join public.users u on u.id = cl.user_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Complete: record the outcome; only successful sends advance the cadence.
-- 'assigned' starts the 7-day clock, 'weekly' consumes one of the 3 slots,
-- closing warnings never touch the counters.
-- ---------------------------------------------------------------------------
create or replace function public.complete_scheduled_survey_emails(
  p_results jsonb
)
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
    where id = (r->>'id')::uuid and channel = 'email'
    for update;
    if not found then
      continue;
    end if;
    handled := handled + 1;

    if coalesce((r->>'ok')::boolean, false) then
      update public.notification_deliveries
      set status = 'sent', sent_at = now(), last_error = null
      where id = d.id;

      if d.data->>'kind' = 'weekly' then
        update public.survey_assignments
        set auto_email_count = coalesce(auto_email_count, 0) + 1,
            last_auto_email_at = now()
        where id = (d.data->>'assignment_id')::uuid;
      elsif d.data->>'kind' = 'assigned' then
        update public.survey_assignments
        set last_auto_email_at = now()
        where id = (d.data->>'assignment_id')::uuid;
      end if;
    else
      update public.notification_deliveries
      set status = 'failed', last_error = left(r->>'error', 500)
      where id = d.id;
    end if;
  end loop;
  return handled;
end;
$$;

-- ---------------------------------------------------------------------------
-- Dispatcher called by pg_cron. Derives the function URL from the push
-- dispatch pair so no extra Vault secrets are needed.
-- ---------------------------------------------------------------------------
create or replace function public.scheduled_email_dispatch()
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  push_url text;
  url text;
  secret text;
begin
  select decrypted_secret into push_url from vault.decrypted_secrets where name = 'push_dispatch_url';
  select decrypted_secret into secret from vault.decrypted_secrets where name = 'push_dispatch_secret';
  if coalesce(push_url, '') = '' or coalesce(secret, '') = '' then
    return false;
  end if;

  url := replace(push_url, '/send-push', '/send-scheduled-emails');
  if url = push_url then
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
  raise warning 'scheduled_email_dispatch: %', sqlerrm;
  return false;
end;
$$;

revoke all on function public.claim_scheduled_survey_emails(integer) from public, anon, authenticated;
revoke all on function public.complete_scheduled_survey_emails(jsonb) from public, anon, authenticated;
revoke all on function public.scheduled_email_dispatch() from public, anon, authenticated;
grant execute on function public.claim_scheduled_survey_emails(integer) to service_role;
grant execute on function public.complete_scheduled_survey_emails(jsonb) to service_role;

commit;

-- Hourly at :05. The function itself decides whether anything is due.
select cron.schedule(
  'aess-email-scheduled',
  '5 * * * *',
  $$select public.scheduled_email_dispatch()$$
);
