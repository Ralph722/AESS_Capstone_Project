begin;
-- Phase 13: DSS Phase 2, Q17 reasons for not being employed (gts_multi,
-- gts_respondent_facts.not_employed_reasons, gts_metric seeking_work_rate,
-- SEEKING_WORK_HIGH rule). Fixture alumni sit in batch 2099 of a fixture
-- survey so real data never changes the results.
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

create temp table t(n int, test text, expected text, actual text);

-- ----- Fixture: one CHED survey, 10 alumni in BSIT 2099.
insert into public.surveys (id, title, status, created_by, data) values
  ('00000000-0000-4000-8000-0000000d1201', 'P13 GTS', 'closed',
   (select id from public.users where role = 'admin' limit 1),
   jsonb_build_object('kind', 'ched_gts_builtin', 'template_key', 'ched_gts_builtin'));

create function pg_temp.alumnus(p_n int, p_answers jsonb)
returns void language plpgsql as $$
declare
  v_uid uuid := ('00000000-0000-4000-8000-0000000d13' || lpad(p_n::text, 2, '0'))::uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, email_confirmed_at)
  values (v_uid, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'p13-' || p_n || '@example.invalid', now());
  insert into public.alumni_members (full_name, course, student_id, year_graduated, auth_uid)
  values ('P13 Alumnus ' || p_n, 'BSIT', 'P13-' || p_n, '2099', v_uid);
  insert into public.survey_responses (survey_id, user_id, answers, status, submitted_at)
  values ('00000000-0000-4000-8000-0000000d1201', v_uid, p_answers, 'submitted', now());
end $$;

-- employed
select pg_temp.alumnus(1, '{"ched_16":"Yes"}');
select pg_temp.alumnus(2, '{"ched_16":"Yes","ched_17":["No job opportunity"]}');
-- looking for work
select pg_temp.alumnus(3, '{"ched_16":"No","ched_17":["No job opportunity"]}');
select pg_temp.alumnus(4, '{"ched_16":"Never Employed","ched_17":[" Lack of work experience ",""]}');
select pg_temp.alumnus(5, '{"ched_16":"No","ched_17":"No job opportunity"}');
-- not looking
select pg_temp.alumnus(6, '{"ched_16":"No","ched_17":["No job opportunity","Did not look for a job"]}');
select pg_temp.alumnus(7, '{"ched_16":"No","ched_17":["Advance or further study"]}');
select pg_temp.alumnus(8, '{"ched_16":"No","ched_17":["Other reason(s), please specify"],"ched_17_other":"Caregiving"}');
-- no reason given / Q16 unanswered
select pg_temp.alumnus(9, '{"ched_16":"No"}');
select pg_temp.alumnus(10, '{"ched_29":"Less than a month"}');

create function pg_temp.metric(p_key text, p_course text, p_year text) returns text
language sql as $$
  select format('hits=%s total=%s sample=%s eligible=%s v%s',
                m.hits, m.total, m.sample_n, m.eligible_n, m.metric_version)
  from public.gts_metric(p_key, '00000000-0000-4000-8000-0000000d1201', p_course, p_year) m;
$$;

-- ===== 1. gts_multi =====
insert into t select 1, 'gts_multi trims and drops blanks', '{a,b}',
  public.gts_multi('[" a ", "", "  ", "b"]')::text;
insert into t select 2, 'gts_multi: text answer, null, object', '{x}|{}|{}',
  public.gts_multi('" x "')::text || '|' || public.gts_multi(null)::text
  || '|' || public.gts_multi('{"k":"v"}')::text;
insert into t select 3, 'gts_multi: anon blocked', 'permission denied',
  pg_temp.try_as('anon', null, $q$select public.gts_multi('[]')::text$q$);

-- ===== 2. facts view =====
insert into t select 4, 'not_employed_reasons is the last column, earlier columns unchanged',
  'response_id,survey_id,user_id,submitted_at,member_id,on_active_roster,course,year_graduated,presently_employed,employment_type,occupation,industry,place_of_work,first_job_related,time_to_first_job,job_level,initial_salary,salary_rank,curriculum_relevant,not_employed_reasons',
  (select string_agg(column_name, ',' order by ordinal_position)
   from information_schema.columns
   where table_schema = 'public' and table_name = 'gts_respondent_facts');
insert into t select 5, 'facts view still security_invoker', 'security_invoker=true',
  (select array_to_string(reloptions, ',') from pg_class where oid = 'public.gts_respondent_facts'::regclass);
insert into t select 6, 'facts carry trimmed Q17 reasons', '{"Lack of work experience"}',
  (select f.not_employed_reasons::text from public.gts_respondent_facts f
   where f.user_id = '00000000-0000-4000-8000-0000000d1304');
insert into t select 7, 'alumnus sees no fixture facts', '0',
  pg_temp.try_as('authenticated', '6f6c569a-9ded-4c90-acab-19d78ab2a3f3',
    $q$select count(*)::text from public.gts_respondent_facts where survey_id = '00000000-0000-4000-8000-0000000d1201'$q$);

-- ===== 3. gts_metric =====
insert into t select 8, 'seeking_work_rate: 3 looking of 5 employed + looking', 'hits=3 total=5 sample=10 eligible=10 v2',
  pg_temp.metric('seeking_work_rate', 'BSIT', '2099');
insert into t select 9, 'seeking_work_rate value', '0.6',
  (select round(m.value, 4)::text from public.gts_metric('seeking_work_rate',
     '00000000-0000-4000-8000-0000000d1201', 'BSIT', '2099') m);
insert into t select 10, 'unemployment unchanged in meaning (all No / Never Employed)', 'hits=7 total=9 sample=10 eligible=10 v2',
  pg_temp.metric('unemployment_rate', 'BSIT', '2099');
insert into t select 11, 'seeking_work_rate: alumnus blocked', 'Admin access required',
  pg_temp.try_as('authenticated', '6f6c569a-9ded-4c90-acab-19d78ab2a3f3',
    $q$select value::text from public.gts_metric('seeking_work_rate', '00000000-0000-4000-8000-0000000d1201')$q$);
insert into t select 12, 'seeking_work_rate: admin allowed', '0.6',
  pg_temp.try_as('authenticated', '8a845be5-5870-437f-95e6-7ea3b0ad7a06',
    $q$select round(value, 4)::text from public.gts_metric('seeking_work_rate', '00000000-0000-4000-8000-0000000d1201', 'BSIT', '2099')$q$);

-- ===== 4. rule =====
insert into t select 13, 'SEEKING_WORK_HIGH seeded switched off', 'false|seeking_work_rate|gte|0.15|10|outcome',
  (select format('%s|%s|%s|%s|%s|%s', enabled::text, metric_key, operator, threshold::numeric(4,2), min_n, category)
   from public.dss_rules where rule_id = 'SEEKING_WORK_HIGH');
insert into t select 14, 'UNEMPLOYMENT_HIGH keeps its metric', 'unemployment_rate',
  (select metric_key from public.dss_rules where rule_id = 'UNEMPLOYMENT_HIGH');

-- ===== 5. nightly re-check knows the new metric =====
insert into public.dss_flags (id, rule_id, cohort_level, course, batch_year, survey_id,
  survey_title, metric_value, threshold_snapshot, sample_n, title, evidence)
values
  ('00000000-0000-4000-8000-0000000d1401', 'SEEKING_WORK_HIGH', 'batch', 'BSIT', '2099',
   '00000000-0000-4000-8000-0000000d1201', 'P13 GTS', 0.6, 0.15, 10, 'P13 watch',
   '{"evidence_strength":"watch","valid_answers":5}');
select public.dss_recheck_open_flags();
insert into t select 15, 're-check: watch flag with 5 answers still triggered', 'still_triggered|0.6',
  (select c.state || '|' || round(c.metric_value, 4) from public.dss_flag_checks c
   where c.flag_id = '00000000-0000-4000-8000-0000000d1401');

select n, test, expected,
  case when actual like '%' || expected || '%' then actual else 'MISMATCH: ' || actual end as actual
from t order by n;
rollback;
