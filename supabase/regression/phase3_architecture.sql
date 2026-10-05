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
    if p_sql ~* '^\s*insert' then execute p_sql; r := 'ok'; else execute p_sql into r; end if;
  exception when others then
    r := 'ERROR: ' || sqlerrm;
  end;
  reset role;
  perform set_config('request.jwt.claims', '', true);
  return coalesce(r, '(null)');
end $$;

create function pg_temp.try_raw(p_sql text) returns text
language plpgsql as $$
declare r text;
begin
  begin
    execute p_sql into r;
  exception when others then
    r := 'ERROR: ' || sqlerrm;
  end;
  return coalesce(r, '(null)');
end $$;

create temp table t(n int, test text, expected text, actual text);

-- Year helper and backfill
insert into t select 1, 'normalize_grad_year samples', '2019||2024|1998',
  public.normalize_grad_year('Class of 2019-2020') || '|' || public.normalize_grad_year('abc') || '|'
  || public.normalize_grad_year(' 2024 ') || '|' || public.normalize_grad_year('Batch 1998');
insert into t select 2, 'linked roster rows got the alumni year', '2027/2027 2027/2027',
  (select string_agg(coalesce(year_graduated, '-') || '/' || coalesce(year_graduated, ''), ' ' order by id)
   from public.alumni_members where id in ('305517b7-72b9-4746-9156-cf362e7ded6b', 'a9bb659a-a452-40e1-8bdc-8b65085a507f'));
insert into t select 3, 'unlinked roster rows keep a blank year', '0',
  (select count(*)::text from public.alumni_members where auth_uid is null and (year_graduated is not null or coalesce(year_graduated, '') <> ''));

-- Programs
insert into t select 4, 'programs readable by anon', '5',
  pg_temp.try_as('anon', null, 'select count(*)::text from public.programs');
insert into t select 5, 'alumnus cannot add a program', 'blocked',
  pg_temp.try_as('authenticated', '6f6c569a-9ded-4c90-acab-19d78ab2a3f3',
    $q$insert into public.programs (code, name) values ('XX', 'X')$q$);
insert into t select 6, 'roster row with unknown course rejected', 'fk violation',
  pg_temp.try_raw($q$with i as (insert into public.alumni_members (full_name, course, student_id) values ('Z', 'BSCS', 'Z-1') returning 1) select count(*)::text from i$q$);

-- Alumni cannot override the roster year
insert into t select 7, 'alumnus A sets year 2020 (roster says 2027)', '1',
  pg_temp.try_as('authenticated', '6f6c569a-9ded-4c90-acab-19d78ab2a3f3',
    $q$with u as (update public.users set year_graduated = '2020' where id = '6f6c569a-9ded-4c90-acab-19d78ab2a3f3' returning 1) select count(*)::text from u$q$);
insert into t select 7, '...stored year', '2027/2027',
  (select year_graduated || '/' || coalesce(year_graduated, '') from public.users where id = '6f6c569a-9ded-4c90-acab-19d78ab2a3f3');
insert into t select 8, 'alumnus A changes batch only', '2027/2027',
  pg_temp.try_as('authenticated', '6f6c569a-9ded-4c90-acab-19d78ab2a3f3',
    $q$with u as (update public.users set updated_at = now() where id = '6f6c569a-9ded-4c90-acab-19d78ab2a3f3' returning year_graduated || '/' || coalesce(year_graduated, '')) select * from u$q$);
insert into t select 9, 'alumnus A edits own roster year', 'blocked',
  pg_temp.try_as('authenticated', '6f6c569a-9ded-4c90-acab-19d78ab2a3f3',
    $q$with u as (update public.alumni_members set year_graduated = '2010' where auth_uid = '6f6c569a-9ded-4c90-acab-19d78ab2a3f3' returning 1) select count(*)::text from u$q$);
insert into t select 10, 'alumnus A mirrors contact details to roster', '1',
  pg_temp.try_as('authenticated', '6f6c569a-9ded-4c90-acab-19d78ab2a3f3',
    $q$with u as (update public.alumni_members set contact_number = contact_number, email_address = email_address, address = address, gender = gender, civil_status = civil_status, birth_date = birth_date, tracer_profile_complete = tracer_profile_complete, updated_at = now() where auth_uid = '6f6c569a-9ded-4c90-acab-19d78ab2a3f3' returning 1) select count(*)::text from u$q$);

-- Roster changes flow to users
insert into t select 11, 'admin sets roster A year to "Batch 2025" and course BTLED-ICT', '2025/2025',
  pg_temp.try_as('authenticated', '8a845be5-5870-437f-95e6-7ea3b0ad7a06',
    $q$with u as (update public.alumni_members set year_graduated = 'Batch 2025', course = 'BTLED-ICT' where id = '305517b7-72b9-4746-9156-cf362e7ded6b' returning year_graduated || '/' || coalesce(year_graduated, '')) select * from u$q$);
insert into t select 11, '...users A follows', 'BTLED-ICT 2025/2025',
  (select program || ' ' || year_graduated || '/' || coalesce(year_graduated, '') from public.users where id = '6f6c569a-9ded-4c90-acab-19d78ab2a3f3');

-- Blank roster year is filled from the alumnus once
insert into t select 12, 'admin clears roster B year', '-/',
  pg_temp.try_as('authenticated', '8a845be5-5870-437f-95e6-7ea3b0ad7a06',
    $q$with u as (update public.alumni_members set year_graduated = '' where id = 'a9bb659a-a452-40e1-8bdc-8b65085a507f' returning coalesce(year_graduated, '-') || '/' || coalesce(year_graduated, '')) select * from u$q$);
insert into t select 12, '...users B keeps its year', '2027',
  (select year_graduated from public.users where id = 'dfdf41bb-e201-4446-abee-e6b6ac67d82b');
insert into t select 13, 'alumnus B sets year 2023', '1',
  pg_temp.try_as('authenticated', 'dfdf41bb-e201-4446-abee-e6b6ac67d82b',
    $q$with u as (update public.users set year_graduated = '2023' where id = 'dfdf41bb-e201-4446-abee-e6b6ac67d82b' returning 1) select count(*)::text from u$q$);
insert into t select 13, '...users and roster B', '2023/2023 roster 2023/2023',
  (select year_graduated || '/' || coalesce(year_graduated, '') from public.users where id = 'dfdf41bb-e201-4446-abee-e6b6ac67d82b')
  || ' roster ' ||
  (select coalesce(year_graduated, '-') || '/' || coalesce(year_graduated, '') from public.alumni_members where id = 'a9bb659a-a452-40e1-8bdc-8b65085a507f');
insert into t select 14, 'alumnus B now locked by roster year', '2023',
  pg_temp.try_as('authenticated', 'dfdf41bb-e201-4446-abee-e6b6ac67d82b',
    $q$with u as (update public.users set year_graduated = '2001' where id = 'dfdf41bb-e201-4446-abee-e6b6ac67d82b' returning year_graduated) select * from u$q$);
insert into t select 15, 'privileged batch-only write moves both', '1999/1999',
  pg_temp.try_raw($q$with u as (update public.users set year_graduated = '1999' where id = 'dfdf41bb-e201-4446-abee-e6b6ac67d82b' returning year_graduated || '/' || coalesce(year_graduated, '')) select * from u$q$);
update public.users set year_graduated = '2023' where id = 'dfdf41bb-e201-4446-abee-e6b6ac67d82b';

-- Survey counters
insert into t select 16, 'admin writes response_count = 99', 'kept 1',
  pg_temp.try_as('authenticated', '8a845be5-5870-437f-95e6-7ea3b0ad7a06',
    $q$with u as (update public.surveys set response_count = 99, assignment_count = 99 where id = '2057ffdc-27f3-4f95-b372-554e4369b28d' returning 1) select count(*)::text from u$q$);
insert into t select 16, '...stored counts', 'a=2 r=1',
  (select 'a=' || assignment_count || ' r=' || response_count from public.surveys where id = '2057ffdc-27f3-4f95-b372-554e4369b28d');
insert into t select 17, 'new survey with fake counts', '0/0',
  pg_temp.try_raw($q$with i as (insert into public.surveys (id, title, created_by, assignment_count, response_count) values ('00000000-0000-4000-8000-0000000f3001', 'P3 test', '8a845be5-5870-437f-95e6-7ea3b0ad7a06', 50, 50) returning 1) select count(*)::text from i$q$);
update t set actual = (select assignment_count || '/' || response_count from public.surveys where id = '00000000-0000-4000-8000-0000000f3001') where n = 17;
insert into t select 18, 'assign two alumni', '2',
  pg_temp.try_raw($q$with i as (insert into public.survey_assignments (survey_id, user_id) values
    ('00000000-0000-4000-8000-0000000f3001', '6f6c569a-9ded-4c90-acab-19d78ab2a3f3'),
    ('00000000-0000-4000-8000-0000000f3001', 'dfdf41bb-e201-4446-abee-e6b6ac67d82b') returning 1) select count(*)::text from i$q$);
update t set actual = (select assignment_count::text from public.surveys where id = '00000000-0000-4000-8000-0000000f3001') where n = 18;
insert into t select 19, 'remove one assignment', '1',
  pg_temp.try_raw($q$with d as (delete from public.survey_assignments where survey_id = '00000000-0000-4000-8000-0000000f3001' and user_id = 'dfdf41bb-e201-4446-abee-e6b6ac67d82b' returning 1) select count(*)::text from d$q$);
update t set actual = (select assignment_count::text from public.surveys where id = '00000000-0000-4000-8000-0000000f3001') where n = 19;
insert into t select 20, 'delete survey that has assignments (cascade + recount)', '1',
  pg_temp.try_raw($q$with d as (delete from public.surveys where id = '00000000-0000-4000-8000-0000000f3001' returning 1) select count(*)::text from d$q$);
insert into t select 21, 'submitted response moved back to draft (raw)', 'r=0',
  pg_temp.try_raw($q$with u as (update public.survey_responses set status = 'draft' where survey_id = '2057ffdc-27f3-4f95-b372-554e4369b28d' and status = 'submitted' returning 1) select count(*)::text from u$q$);
update t set actual = (select 'r=' || response_count from public.surveys where id = '2057ffdc-27f3-4f95-b372-554e4369b28d') where n = 21;
insert into t select 22, 'all survey counters accurate', '0',
  (select count(*)::text from public.surveys s
   where s.assignment_count <> (select count(*) from public.survey_assignments a where a.survey_id = s.id)
      or s.response_count <> (select count(*) from public.survey_responses r where r.survey_id = s.id and r.status = 'submitted'));

-- Jobs
-- View counts grow with real traffic, so compare against the count at the start.
create temp table jv as select views as v0 from public.jobs where id = '8cde79a0-3963-4a96-93f9-3f4ada111b90';
insert into t select 23, 'views column mirrored in data.views', 'all match',
  (select case when count(*) = 0 then 'all match' else count(*) || ' differ' end
   from public.jobs where views::text is distinct from coalesce(data->>'views', views::text));
insert into t select 24, 'admin edit with stale views + new title', 'kept|kept|P3 title|P3 title',
  pg_temp.try_as('authenticated', '8a845be5-5870-437f-95e6-7ea3b0ad7a06',
    $q$with u as (update public.jobs set title = 'P3 title', views = 0, data = data || '{"views": 0, "jobTitle": "old"}' where id = '8cde79a0-3963-4a96-93f9-3f4ada111b90' returning views || '|' || (data->>'views') || '|' || title || '|' || (data->>'jobTitle')) select * from u$q$);
update t set actual =
  case when split_part(actual, '|', 1) = (select v0::text from jv) then 'kept' else 'CHANGED' end || '|' ||
  case when split_part(actual, '|', 2) = (select v0::text from jv) then 'kept' else 'CHANGED' end || '|' ||
  split_part(actual, '|', 3) || '|' || split_part(actual, '|', 4)
where n = 24;
insert into t select 25, 'alumnus opens job (increment_job_views)', '+1|+1',
  pg_temp.try_as('authenticated', '6f6c569a-9ded-4c90-acab-19d78ab2a3f3',
    $q$select public.increment_job_views('8cde79a0-3963-4a96-93f9-3f4ada111b90')::text$q$);
update t set actual = (
  select case when j.views = jv.v0 + 1 then '+1' else j.views::text end || '|' ||
         case when j.data->>'views' = (jv.v0 + 1)::text then '+1' else coalesce(j.data->>'views', 'null') end
  from public.jobs j, jv where j.id = '8cde79a0-3963-4a96-93f9-3f4ada111b90')
where n = 25;
insert into t select 26, 'alumnus sets views directly', '0',
  pg_temp.try_as('authenticated', '6f6c569a-9ded-4c90-acab-19d78ab2a3f3',
    $q$with u as (update public.jobs set views = 9999 where id = '8cde79a0-3963-4a96-93f9-3f4ada111b90' returning 1) select count(*)::text from u$q$);
insert into t select 27, 'legacy insert with only data fields', 'Legacy|ACME|active|7',
  pg_temp.try_raw($q$with i as (insert into public.jobs (data) values ('{"jobTitle": "Legacy", "companyName": "ACME", "views": 7}') returning title || '|' || company || '|' || status || '|' || views) select * from i$q$);

-- Peer profiles
insert into t select 28, 'alumnus A looks up B and admin', '2 rows, emails hidden',
  pg_temp.try_as('authenticated', '6f6c569a-9ded-4c90-acab-19d78ab2a3f3',
    $q$select count(*) || ' rows, ' || case when bool_and(email = '') then 'emails hidden' else 'EMAIL LEAK' end
       from public.get_public_profiles(array['dfdf41bb-e201-4446-abee-e6b6ac67d82b', '8a845be5-5870-437f-95e6-7ea3b0ad7a06']::uuid[])$q$);
insert into t select 29, 'B profile fields for alumni', 'name set, BSIT, 2023',
  pg_temp.try_as('authenticated', '6f6c569a-9ded-4c90-acab-19d78ab2a3f3',
    $q$select case when display_name <> '' then 'name set' else 'NO NAME' end || ', ' || program || ', ' || year_graduated
       from public.get_public_profiles(array['dfdf41bb-e201-4446-abee-e6b6ac67d82b']::uuid[])$q$);
insert into t select 30, 'admin sees emails', 'emails shown',
  pg_temp.try_as('authenticated', '8a845be5-5870-437f-95e6-7ea3b0ad7a06',
    $q$select case when bool_and(email <> '') then 'emails shown' else 'MISSING' end
       from public.get_public_profiles(array['dfdf41bb-e201-4446-abee-e6b6ac67d82b', '6f6c569a-9ded-4c90-acab-19d78ab2a3f3']::uuid[])$q$);
insert into t select 31, 'anon cannot call get_public_profiles', 'permission denied',
  pg_temp.try_as('anon', null,
    $q$select count(*)::text from public.get_public_profiles(array['dfdf41bb-e201-4446-abee-e6b6ac67d82b']::uuid[])$q$);
insert into t select 32, 'alumnus still cannot read B''s users row directly', '0',
  pg_temp.try_as('authenticated', '6f6c569a-9ded-4c90-acab-19d78ab2a3f3',
    $q$select count(*)::text from public.users where id = 'dfdf41bb-e201-4446-abee-e6b6ac67d82b'$q$);

-- GTS catalog
insert into t select 33, 'catalog rows visible to alumni', '47',
  pg_temp.try_as('authenticated', '6f6c569a-9ded-4c90-acab-19d78ab2a3f3',
    $q$select count(*)::text from public.gts_question_catalog where schema_version = '3.0.0'$q$);
insert into t select 34, 'catalog hidden from anon', 'permission denied',
  pg_temp.try_as('anon', null, $q$select count(*)::text from public.gts_question_catalog$q$);
insert into t select 35, 'catalog spot check ched_16', 'single / d / required',
  (select field_type || ' / ' || section || ' / ' || case when required then 'required' else 'optional' end
   from public.gts_question_catalog where item_id = 'ched_16');

-- Hygiene
insert into t select 36, 'surveys.created_by nullable', 'YES',
  (select is_nullable from information_schema.columns where table_schema = 'public' and table_name = 'surveys' and column_name = 'created_by');
insert into t select 37, 'functions anon can execute', '3',
  (select count(*)::text || ': ' || string_agg(proname, ', ' order by proname)
   from pg_proc where pronamespace = 'public'::regnamespace and has_function_privilege('anon', oid, 'EXECUTE'));
insert into t select 38, 'trigger functions authenticated can execute', '0',
  (select count(*)::text from pg_proc p where p.pronamespace = 'public'::regnamespace and p.prorettype = 'trigger'::regtype
     and has_function_privilege('authenticated', p.oid, 'EXECUTE'));
insert into t select 39, 'functions without fixed search_path', '0',
  (select count(*)::text from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proconfig is null
     and not exists (select 1 from pg_depend d where d.objid = p.oid and d.deptype = 'e'));

select n, test, expected, actual from t order by n, test;

rollback;
