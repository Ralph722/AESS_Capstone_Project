-- Automated survey SMS reminders via Semaphore (week-1 + closing-in-3-days).
-- Mirrors scheduled survey email (claim / complete / vault URL swap / cron).
--
-- Cadence per incomplete assignment (Asia/Manila):
--   * 'week1'      — once, when assigned_at is at least 7 days ago
--   * 'closing_3d' — once, when the survey closes in 3 Manila days
-- Max 2 SMS per alumnus per survey. Verified PH mobiles only.
-- Preference: notification_preferences.sms->>'survey' (missing = on).
--
-- Flow: pg_cron daily 01:15 UTC (09:15 Manila) -> scheduled_sms_dispatch()
-- -> Edge Function send-scheduled-sms -> claim/complete RPCs below.

begin;

alter table public.notification_preferences
  add column if not exists sms jsonb not null default '{}'::jsonb;

comment on column public.notification_preferences.sms is
  'Per-type SMS switches (jsonb map). Missing key means on. Only survey '
  'reminders are sent today; verification OTPs ignore this map.';

-- Channel switch understands 'sms' (same missing-key-means-on rule as email).
create or replace function public.notification_channel_allowed(
  p_user uuid,
  p_type text,
  p_channel text,
  p_priority text default 'normal'
)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  prefs public.notification_preferences%rowtype;
  raw text;
begin
  if p_type = 'system' or p_priority = 'urgent' then
    return true;
  end if;
  if p_channel = 'in_app' and p_type = 'survey' then
    return true;
  end if;

  select * into prefs from public.notification_preferences where user_id = p_user;
  if not found then
    return true;
  end if;

  raw := case p_channel
    when 'push' then prefs.push->>p_type
    when 'email' then prefs.email->>p_type
    when 'sms' then prefs.sms->>p_type
    else prefs.in_app->>p_type
  end;
  return coalesce(lower(raw), 'true') <> 'false';
end;
$$;

-- ---------------------------------------------------------------------------
-- Claim due survey SMS (verified PH mobile, preference on, daily cap).
-- ---------------------------------------------------------------------------
create or replace function public.claim_scheduled_survey_sms(
  p_limit integer default 40
)
returns table (
  delivery_id uuid,
  assignment_id uuid,
  user_id uuid,
  mobile text,
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
  v_daily_cap integer := 100;
  v_used integer;
  v_limit integer;
begin
  select count(*) into v_used
  from public.notification_deliveries d
  where d.channel = 'sms'
    and coalesce(d.data->>'automated', '') = 'true'
    and d.status in ('sent', 'sending')
    and (d.created_at at time zone 'Asia/Manila')::date = today;

  v_limit := least(
    greatest(1, least(coalesce(p_limit, 40), 100)),
    v_daily_cap - coalesce(v_used, 0)
  );
  if v_limit <= 0 then
    return;
  end if;

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
    join public.users u on u.id = a.user_id
    cross join lateral (
      select
        case
          when s.close_at is not null
               and (s.close_at at time zone 'Asia/Manila')::date - today = 3
            then 'closing_3d'
          when a.assigned_at <= now() - interval '7 days'
            then 'week1'
        end as kind,
        case
          when s.close_at is not null
               and (s.close_at at time zone 'Asia/Manila')::date - today = 3
            then 0
          else 1
        end as urgency
    ) c
    where c.kind is not null
      and a.status <> 'completed'
      and public.notification_survey_accepting(s)
      and public.notification_is_active_alumni(a.user_id)
      and public.notification_channel_allowed(a.user_id, 'survey', 'sms', 'normal')
      and u.mobile_verified_at is not null
      and u.mobile_number ~ '^09[0-9]{9}$'
      and not exists (
        select 1 from public.notification_deliveries d
        where d.channel = 'sms'
          and d.user_id = a.user_id
          and d.data->>'survey_id' = s.id::text
          and d.data->>'kind' = c.kind
          and (d.status = 'sent'
               or (d.status = 'sending'
                   and d.created_at > now() - interval '15 minutes'))
      )
    order by c.urgency, a.assigned_at
    limit v_limit
  ),
  claimed as (
    insert into public.notification_deliveries (
      channel, user_id, recipient, status, attempts, scheduled_at, data
    )
    select
      'sms',
      c.uid,
      u.mobile_number,
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

create or replace function public.complete_scheduled_survey_sms(
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
    where id = (r->>'id')::uuid and channel = 'sms'
    for update;
    if not found then
      continue;
    end if;
    handled := handled + 1;

    if coalesce((r->>'ok')::boolean, false) then
      update public.notification_deliveries
      set status = 'sent', sent_at = now(), last_error = null
      where id = d.id;
    else
      update public.notification_deliveries
      set status = 'failed', last_error = left(r->>'error', 500)
      where id = d.id;
    end if;
  end loop;
  return handled;
end;
$$;

create or replace function public.scheduled_sms_dispatch()
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

  url := replace(push_url, '/send-push', '/send-scheduled-sms');
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
    timeout_milliseconds := 15000
  );
  return true;
exception when others then
  raise warning 'scheduled_sms_dispatch: %', sqlerrm;
  return false;
end;
$$;

revoke all on function public.claim_scheduled_survey_sms(integer) from public, anon, authenticated;
revoke all on function public.complete_scheduled_survey_sms(jsonb) from public, anon, authenticated;
revoke all on function public.scheduled_sms_dispatch() from public, anon, authenticated;
grant execute on function public.claim_scheduled_survey_sms(integer) to service_role;
grant execute on function public.complete_scheduled_survey_sms(jsonb) to service_role;

comment on table public.notification_deliveries is
  'Delivery attempts per channel. push: send-push. email: send-email / '
  'send-scheduled-emails. sms: contact-verify OTP and send-scheduled-sms.';

commit;

-- Once daily at 01:15 UTC = 09:15 Asia/Manila.
select cron.schedule(
  'aess-sms-scheduled',
  '15 1 * * *',
  $$select public.scheduled_sms_dispatch()$$
);
