-- Add publish/assignment SMS ('assigned') alongside week-1 + closing-in-3-days.
-- Mirrors scheduled survey email's 'assigned' kind. Max 3 SMS per alumnus per
-- survey. Cron moves from daily to hourly so assigned texts arrive soon after
-- publish (same cadence idea as aess-email-scheduled).

begin;

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
#variable_conflict use_column
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
      a.id as cand_assignment_id,
      a.user_id as cand_uid,
      s.id as cand_sid,
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
          when not exists (
            select 1 from public.notification_deliveries d
            where d.channel = 'sms'
              and d.user_id = a.user_id
              and d.data->>'survey_id' = s.id::text
              and d.data->>'kind' = 'assigned'
              and (d.status = 'sent'
                   or (d.status = 'sending'
                       and d.created_at > now() - interval '15 minutes'))
          ) then 'assigned'
          when a.assigned_at <= now() - interval '7 days'
            then 'week1'
        end as kind,
        case
          when s.close_at is not null
               and (s.close_at at time zone 'Asia/Manila')::date - today = 3
            then 0
          when not exists (
            select 1 from public.notification_deliveries d
            where d.channel = 'sms'
              and d.user_id = a.user_id
              and d.data->>'survey_id' = s.id::text
              and d.data->>'kind' = 'assigned'
              and (d.status = 'sent'
                   or (d.status = 'sending'
                       and d.created_at > now() - interval '15 minutes'))
          ) then 1
          else 2
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
      c.cand_uid,
      u.mobile_number,
      'sending',
      1,
      now(),
      jsonb_build_object(
        'kind', c.ckind,
        'survey_id', c.cand_sid::text,
        'assignment_id', c.cand_assignment_id::text,
        'automated', true
      )
    from candidates c
    join public.users u on u.id = c.cand_uid
    returning id as claimed_id, user_id as claimed_uid, recipient as claimed_recipient, data as claimed_data
  )
  select
    cl.claimed_id,
    a.id,
    cl.claimed_uid,
    cl.claimed_recipient,
    coalesce(nullif(trim(u.display_name), ''), 'Alumni'),
    s.id,
    coalesce(s.title, ''),
    coalesce(s.data->>'kind', '') = 'ched_gts_builtin'
      or coalesce(s.data->>'template_key', '') = 'ched_gts_builtin',
    s.close_at,
    cl.claimed_data->>'kind'
  from claimed cl
  join public.survey_assignments a
    on a.id = (cl.claimed_data->>'assignment_id')::uuid
  join public.surveys s on s.id = a.survey_id
  join public.users u on u.id = cl.claimed_uid;
end;
$$;

comment on function public.claim_scheduled_survey_sms(integer) is
  'Claim due automated survey SMS: assigned (on/near publish), week1, '
  'closing_3d. Verified PH mobiles only; preference sms.survey; daily cap.';

revoke all on function public.claim_scheduled_survey_sms(integer)
  from public, anon, authenticated;
grant execute on function public.claim_scheduled_survey_sms(integer)
  to service_role;

-- Hourly at :15 (was daily 01:15 UTC). cron.schedule replaces same job name.
select cron.schedule(
  'aess-sms-scheduled',
  '15 * * * *',
  $$select public.scheduled_sms_dispatch()$$
);

commit;
