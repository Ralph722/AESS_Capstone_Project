-- Phase 23: scheduled survey SMS 'assigned' is near-publish only (24h),
-- hourly cron, publish kick via notify_survey_published, and does not
-- backfill stale assignments. Seeds throwaway rows, claims as
-- service_role, asserts, then rolls back.
begin;

create temp table t (n int, test text, expected text, actual text);

insert into t
select 1,
  'claim_scheduled_survey_sms defines assigned kind',
  'true',
  (pg_get_functiondef('public.claim_scheduled_survey_sms(integer)'::regprocedure)
     like '%''assigned''%')::text;

insert into t
select 2,
  'aess-sms-scheduled runs hourly at :15',
  '15 * * * *',
  coalesce(
    (select schedule from cron.job where jobname = 'aess-sms-scheduled'),
    'missing'
  );

insert into t
select 3,
  'assigned requires 24h assigned_at window',
  'true',
  (pg_get_functiondef('public.claim_scheduled_survey_sms(integer)'::regprocedure)
     like '%interval ''24 hours''%')::text;

insert into t
select 7,
  'notify_survey_published kicks scheduled_sms_dispatch',
  'true',
  (pg_get_functiondef('public.notify_survey_published()'::regprocedure)
     like '%scheduled_sms_dispatch%')::text;

insert into t
select 8,
  'notify_survey_published kicks scheduled_email_dispatch',
  'true',
  (pg_get_functiondef('public.notify_survey_published()'::regprocedure)
     like '%scheduled_email_dispatch%')::text;

set local role service_role;

update public.users
set mobile_number = '09171234567',
    mobile_verified_at = coalesce(mobile_verified_at, now())
where id = '6f6c569a-9ded-4c90-acab-19d78ab2a3f3';

insert into public.surveys (
  id, title, status, open_at, close_at, created_by
) values (
  '00000000-0000-4000-8000-000000000b23',
  'P23 assigned SMS',
  'published',
  now() - interval '1 hour',
  now() + interval '30 days',
  '6f6c569a-9ded-4c90-acab-19d78ab2a3f3'
) on conflict (id) do update
  set status = 'published',
      open_at = excluded.open_at,
      close_at = excluded.close_at,
      title = excluded.title;

-- Fresh assignment → assigned
insert into public.survey_assignments (
  id, survey_id, user_id, survey_title, status, assigned_at
) values (
  '00000000-0000-4000-8000-000000000b24',
  '00000000-0000-4000-8000-000000000b23',
  '6f6c569a-9ded-4c90-acab-19d78ab2a3f3',
  'P23 assigned SMS',
  'notStarted',
  now()
) on conflict (id) do update
  set status = 'notStarted',
      assigned_at = now(),
      survey_title = excluded.survey_title;

delete from public.notification_deliveries
where channel = 'sms'
  and (
    user_id = '6f6c569a-9ded-4c90-acab-19d78ab2a3f3'
    or recipient = '09171234567'
  )
  and data->>'survey_id' = '00000000-0000-4000-8000-000000000b23';

insert into t
select 4,
  'claim returns assigned for fresh incomplete assignment',
  'assigned',
  coalesce(
    (
      select kind
      from public.claim_scheduled_survey_sms(5)
      where survey_id = '00000000-0000-4000-8000-000000000b23'
        and user_id = '6f6c569a-9ded-4c90-acab-19d78ab2a3f3'
      limit 1
    ),
    'none'
  );

insert into t
select 5,
  'second claim does not re-queue assigned while sending',
  'none',
  coalesce(
    (
      select kind
      from public.claim_scheduled_survey_sms(5)
      where survey_id = '00000000-0000-4000-8000-000000000b23'
        and user_id = '6f6c569a-9ded-4c90-acab-19d78ab2a3f3'
        and kind = 'assigned'
      limit 1
    ),
    'none'
  );

-- Stale assignment (>24h, <7d) must not claim assigned or week1.
insert into public.surveys (
  id, title, status, open_at, close_at, created_by
) values (
  '00000000-0000-4000-8000-000000000b25',
  'P23 stale SMS',
  'published',
  now() - interval '3 days',
  now() + interval '30 days',
  '6f6c569a-9ded-4c90-acab-19d78ab2a3f3'
) on conflict (id) do update
  set status = 'published',
      open_at = excluded.open_at,
      close_at = excluded.close_at,
      title = excluded.title;

insert into public.survey_assignments (
  id, survey_id, user_id, survey_title, status, assigned_at
) values (
  '00000000-0000-4000-8000-000000000b26',
  '00000000-0000-4000-8000-000000000b25',
  '6f6c569a-9ded-4c90-acab-19d78ab2a3f3',
  'P23 stale SMS',
  'notStarted',
  now() - interval '3 days'
) on conflict (id) do update
  set status = 'notStarted',
      assigned_at = now() - interval '3 days',
      survey_title = excluded.survey_title;

delete from public.notification_deliveries
where channel = 'sms'
  and (
    user_id = '6f6c569a-9ded-4c90-acab-19d78ab2a3f3'
    or recipient = '09171234567'
  )
  and data->>'survey_id' = '00000000-0000-4000-8000-000000000b25';

insert into t
select 6,
  'stale assignment (<7d) is not claimed as assigned or week1',
  'none',
  coalesce(
    (
      select kind
      from public.claim_scheduled_survey_sms(5)
      where survey_id = '00000000-0000-4000-8000-000000000b25'
        and user_id = '6f6c569a-9ded-4c90-acab-19d78ab2a3f3'
      limit 1
    ),
    'none'
  );

reset role;

do $$
declare
  r record;
  failed int := 0;
begin
  for r in select * from t order by n loop
    if r.expected is distinct from r.actual then
      raise warning 'FAIL %: % expected=% actual=%', r.n, r.test, r.expected, r.actual;
      failed := failed + 1;
    else
      raise notice 'PASS %: %', r.n, r.test;
    end if;
  end loop;
  if failed > 0 then
    raise exception 'phase23_scheduled_survey_sms_assigned: % failure(s)', failed;
  end if;
end $$;

rollback;
