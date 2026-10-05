begin;
create function pg_temp.try_as(p_role text, p_uid text, p_sql text) returns text
language plpgsql as $$
declare r text;
begin
  perform set_config(
    'request.jwt.claims',
    case when p_uid is null then json_build_object('role', p_role)::text
         else json_build_object('role', p_role, 'sub', p_uid, 'email',
           (select email from auth.users where id = p_uid::uuid))::text end,
    true
  );
  execute format('set local role %I', p_role);
  begin
    if p_sql ~* '^\s*(insert|update|delete)' then execute p_sql; r := 'ok'; else execute p_sql into r; end if;
  exception when others then
    r := 'ERROR: ' || sqlerrm;
  end;
  reset role;
  perform set_config('request.jwt.claims', '', true);
  return coalesce(r, '(null)');
end $$;

create function pg_temp.try_raw(p_sql text) returns text
language plpgsql as $$
begin
  execute p_sql;
  return 'ok';
exception when others then
  return 'ERROR: ' || sqlerrm;
end $$;

create temp table t(n int, test text, expected text, actual text);
create temp table exp as
select
  (select year_graduated from public.users where id = '6f6c569a-9ded-4c90-acab-19d78ab2a3f3') as a_year,
  (select program from public.users where id = '6f6c569a-9ded-4c90-acab-19d78ab2a3f3') as a_program,
  (select count(*) from public.user_notifications where user_id = '6f6c569a-9ded-4c90-acab-19d78ab2a3f3') as a_notifs;

-- ===== Phase 7 tests =====
-- A = 6f6c569a-9ded-4c90-acab-19d78ab2a3f3, B = dfdf41bb-e201-4446-abee-e6b6ac67d82b, admin = 8a845be5-5870-437f-95e6-7ea3b0ad7a06
insert into t select 1, 'legacy tables dropped', 'gone',
  case when to_regclass('public.notifications') is null and to_regclass('public.reminders') is null
        and to_regclass('public.archived_employment_records') is null then 'gone' else 'still there' end;
insert into t select 2, 'batch_year / roster employment columns dropped', '0',
  (select count(*)::text || coalesce(': ' || string_agg(table_name || '.' || column_name, ', '), '')
   from information_schema.columns where table_schema = 'public'
     and ((table_name in ('users', 'alumni_members') and column_name = 'batch_year')
       or (table_name = 'alumni_members' and column_name in ('current_position', 'current_company'))));
insert into t select 3, 'old helper signatures dropped', 'gone',
  case when to_regprocedure('public.profile_batch_year_digits(text,text)') is null
        and to_regprocedure('public.survey_audience_matches(text[],text[],text,text,text)') is null
    then 'gone' else 'still there' end;
insert into t select 4, 'only dss functions still mention batch_year', 'dss_recheck_open_flags, dss_run_flag_action',
  (select string_agg(proname, ', ' order by proname) from pg_proc
   where pronamespace = 'public'::regnamespace and prosrc ~ '\mbatch_year\M');
insert into t select 5, 'audience match by graduation year', 'true/false/true',
  public.survey_audience_matches('{}', '{2024}', 'BSIT', '2024')::text || '/'
  || public.survey_audience_matches('{}', '{2023}', 'BSIT', '2024')::text || '/'
  || public.survey_audience_matches('{}', '{}', 'BSIT', '')::text;
insert into t select 6, 'get_public_profiles works, no batch_year column', '2 rows, no batch_year',
  pg_temp.try_as('authenticated', '6f6c569a-9ded-4c90-acab-19d78ab2a3f3',
    $q$select count(*)::text || ' rows' from public.get_public_profiles(array['6f6c569a-9ded-4c90-acab-19d78ab2a3f3','dfdf41bb-e201-4446-abee-e6b6ac67d82b']::uuid[])$q$)
  || case when pg_get_function_result('public.get_public_profiles(uuid[])'::regprocedure) ~ 'batch_year' then ', has batch_year' else ', no batch_year' end;
insert into t select 7, 'alumnus profile save keeps roster year', 'ok, year kept',
  pg_temp.try_as('authenticated', '6f6c569a-9ded-4c90-acab-19d78ab2a3f3',
    $q$update public.users set year_graduated = '1999', updated_at = now() where id = '6f6c569a-9ded-4c90-acab-19d78ab2a3f3'$q$);
update t set actual = actual || case when (select year_graduated from public.users where id = '6f6c569a-9ded-4c90-acab-19d78ab2a3f3') = (select a_year from exp)
       then ', year kept' else ', year CHANGED' end where n = 7;
insert into t select 8, 'alumnus cannot change roster year', 'blocked',
  pg_temp.try_as('authenticated', '6f6c569a-9ded-4c90-acab-19d78ab2a3f3',
    $q$update public.alumni_members set year_graduated = '1999' where auth_uid = '6f6c569a-9ded-4c90-acab-19d78ab2a3f3'$q$);
update t set actual = 'blocked' where n = 8 and actual like 'ERROR: Only the alumni office%';
insert into t select 9, 'admin roster insert normalizes year', 'ok/2031',
  pg_temp.try_as('authenticated', '8a845be5-5870-437f-95e6-7ea3b0ad7a06',
    $q$insert into public.alumni_members (id, full_name, course, student_id, year_graduated) values ('00000000-0000-4000-8000-000000000701', 'Phase Seven Test', 'BSIT', 'P7-TEST-0001', ' 2031 ')$q$)
;
update t set actual = actual || '/' || coalesce((select year_graduated from public.alumni_members where id = '00000000-0000-4000-8000-000000000701'), 'missing') where n = 9;
insert into t select 10, 'auto-assign still runs', 'ok',
  case when public.auto_assign_open_surveys('6f6c569a-9ded-4c90-acab-19d78ab2a3f3') >= 0 then 'ok' else 'failed' end;
insert into t select 11, 'announcement targeted by year reaches A (in-app)', '+1',
  pg_temp.try_as('authenticated', '8a845be5-5870-437f-95e6-7ea3b0ad7a06',
    format($q$insert into public.announcements (id, title, body, status, data) values ('00000000-0000-4000-8000-000000000702', 'Phase 7', 'targeted', 'published', %L::jsonb)$q$,
      jsonb_build_object('targetBatchYears', jsonb_build_array((select a_year from exp)), 'notifyPush', 'false')::text));
update t set actual = actual || ' +' || ((select count(*) from public.user_notifications where user_id = '6f6c569a-9ded-4c90-acab-19d78ab2a3f3') - (select a_notifs from exp)) where n = 11;
update t set actual = '+1' where n = 11 and actual = 'ok +1';
insert into t select 12, 'announcement for another year skips A', '+0',
  pg_temp.try_as('authenticated', '8a845be5-5870-437f-95e6-7ea3b0ad7a06',
    $q$insert into public.announcements (id, title, body, status, data) values ('00000000-0000-4000-8000-000000000703', 'Phase 7 other', 'targeted', 'published', '{"targetBatchYears":["1901"],"notifyPush":"false"}'::jsonb)$q$);
update t set actual = actual || ' +' || ((select count(*) from public.user_notifications where user_id = '6f6c569a-9ded-4c90-acab-19d78ab2a3f3') - (select a_notifs from exp) - 1) where n = 12;
update t set actual = '+0' where n = 12 and actual = 'ok +0';
insert into t select 13, 'registration link still works for A', 'true',
  pg_temp.try_as('authenticated', '6f6c569a-9ded-4c90-acab-19d78ab2a3f3',
    (select format('select public.link_alumni_registration(%L,%L,%L,%L,%L)->>''ok''', id::text, full_name, student_id, course, coalesce(registered_email, ''))
     from public.alumni_members where auth_uid = '6f6c569a-9ded-4c90-acab-19d78ab2a3f3'));

-- typed event times
insert into t select 14, 'clock parser', '07:00/00:00/12:30/19:05/19:00/null/null',
  concat_ws('/',
    coalesce(to_char(public.event_clock_time('7:00 AM'), 'HH24:MI'), 'null'),
    coalesce(to_char(public.event_clock_time('12:00 AM'), 'HH24:MI'), 'null'),
    coalesce(to_char(public.event_clock_time('12:30 PM'), 'HH24:MI'), 'null'),
    coalesce(to_char(public.event_clock_time('19:05'), 'HH24:MI'), 'null'),
    coalesce(to_char(public.event_clock_time('7:00PM'), 'HH24:MI'), 'null'),
    coalesce(to_char(public.event_clock_time('abc'), 'HH24:MI'), 'null'),
    coalesce(to_char(public.event_clock_time('13:00 PM'), 'HH24:MI'), 'null'));
insert into t select 15, 'every event has typed times, end >= start', '0 bad',
  (select count(*) filter (where starts_at is null or ends_at is null or ends_at < starts_at)::text || ' bad' from public.events);
insert into t select 16, 'backfill matches the text times (Manila)', '0 mismatched',
  (select count(*)::text || ' mismatched' from public.events
   where public.event_clock_time(start_time) is not null
     and (starts_at at time zone 'Asia/Manila')::time <> public.event_clock_time(start_time));
insert into t select 17, 'admin creates event -> typed times derived', 'ok, 2026-12-02 01:00 -> 09:00 UTC',
  pg_temp.try_as('authenticated', '8a845be5-5870-437f-95e6-7ea3b0ad7a06',
    $q$insert into public.events (id, theme, date, start_time, end_time, status) values ('00000000-0000-4000-8000-000000000704', 'Phase 7 event', '2026-12-01 16:00:00+00', '9:00 AM', '5:00 PM', 'Active')$q$);
update t set actual = actual || ', ' || coalesce((select to_char(starts_at at time zone 'UTC', 'YYYY-MM-DD HH24:MI') || ' -> ' || to_char(ends_at at time zone 'UTC', 'HH24:MI') || ' UTC'
                       from public.events where id = '00000000-0000-4000-8000-000000000704'), 'missing') where n = 17;
insert into t select 18, 'client cannot override typed times', 'ok, unchanged',
  pg_temp.try_as('authenticated', '8a845be5-5870-437f-95e6-7ea3b0ad7a06',
    $q$update public.events set starts_at = '2000-01-01', ends_at = '2000-01-01' where id = '00000000-0000-4000-8000-000000000704'$q$);
update t set actual = actual || case when (select starts_at from public.events where id = '00000000-0000-4000-8000-000000000704') = '2026-12-02 01:00:00+00'
       then ', unchanged' else ', CHANGED' end where n = 18;
insert into t select 19, 'overnight event ends next day', 'ok, 2026-12-02 14:00 -> 2026-12-02 17:00 UTC',
  pg_temp.try_as('authenticated', '8a845be5-5870-437f-95e6-7ea3b0ad7a06',
    $q$update public.events set start_time = '10:00 PM', end_time = '1:00 AM' where id = '00000000-0000-4000-8000-000000000704'$q$);
update t set actual = actual || ', ' || (select to_char(starts_at at time zone 'UTC', 'YYYY-MM-DD HH24:MI') || ' -> ' || to_char(ends_at at time zone 'UTC', 'YYYY-MM-DD HH24:MI') || ' UTC'
              from public.events where id = '00000000-0000-4000-8000-000000000704') where n = 19;
set local role service_role;
create temp table rem as select public.run_event_reminders() as n;
reset role;
insert into t select 20, 'event reminder job runs on typed times', 'ok',
  case when (select n from rem) >= 0 then 'ok' else 'failed' end;

-- account removal still works (rolled back)
insert into t select 21, 'admin_remove_alumni_account still works', 'true',
  pg_temp.try_as('authenticated', '8a845be5-5870-437f-95e6-7ea3b0ad7a06',
    $q$select public.admin_remove_alumni_account((select id from public.alumni_members where auth_uid = 'dfdf41bb-e201-4446-abee-e6b6ac67d82b'))->>'ok'$q$);

select n, test, expected, actual from t order by n;

rollback;
