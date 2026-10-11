begin;
-- Phase 12: DSS Phase 1 guardrails (evidence strength, roster snapshots,
-- rule minimums, gts_metric v2, nightly re-check floor). Fixture alumni sit
-- in batch 2099 of a fixture survey so real data never changes the results.
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

create function pg_temp.try_sql(p_sql text) returns text
language plpgsql as $$
begin
  execute p_sql;
  return 'ok';
exception when others then
  return 'ERROR: ' || sqlerrm;
end $$;

create temp table t(n int, test text, expected text, actual text);

-- ----- Fixture: one CHED survey, 6 alumni in BSIT 2099, 1 without a batch,
-- ----- 1 respondent without a roster record.
insert into public.surveys (id, title, status, created_by, data) values
  ('00000000-0000-4000-8000-0000000c1201', 'P12 GTS', 'closed',
   (select id from public.users where role = 'admin' limit 1),
   jsonb_build_object('kind', 'ched_gts_builtin', 'template_key', 'ched_gts_builtin'));

create function pg_temp.alumnus(p_n int, p_year text, p_on_roster boolean, p_answers jsonb)
returns void language plpgsql as $$
declare
  v_uid uuid := ('00000000-0000-4000-8000-0000000c13' || lpad(p_n::text, 2, '0'))::uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, email_confirmed_at)
  values (v_uid, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'p12-' || p_n || '@example.invalid', now());
  if p_on_roster then
    insert into public.alumni_members (full_name, course, student_id, year_graduated, auth_uid)
    values ('P12 Alumnus ' || p_n, 'BSIT', 'P12-' || p_n, p_year, v_uid);
  end if;
  insert into public.survey_responses (survey_id, user_id, answers, status, submitted_at)
  values ('00000000-0000-4000-8000-0000000c1201', v_uid, p_answers, 'submitted', now());
end $$;

select pg_temp.alumnus(1, '2099', true, '{"ched_16":"No","ched_29":"1 year to less than 2 years","ched_31":"Below P5,000.00"}');
select pg_temp.alumnus(2, '2099', true, '{"ched_16":"No","ched_29":"2 years to less than 3 years","ched_31":"P5,000.00 to less than P10,000.00"}');
select pg_temp.alumnus(3, '2099', true, '{"ched_16":"Yes","ched_29":"Less than a month","ched_31":"P10,000.00 to less than P15,000.00"}');
select pg_temp.alumnus(4, '2099', true, '{"ched_16":"Yes","ched_29":"1 to 6 months"}');
select pg_temp.alumnus(5, '2099', true, '{"ched_16":"Yes","ched_29":"Others, please specify"}');
select pg_temp.alumnus(6, '2099', true, '{"ched_16":"Never Employed","ched_29":"Others, please specify"}');
select pg_temp.alumnus(7, null, true, '{"ched_16":"No","ched_29":"1 year to less than 2 years"}');
select pg_temp.alumnus(8, null, false, '{"ched_16":"No","ched_29":"3 years to less than 4 years"}');

create function pg_temp.metric(p_key text, p_course text, p_year text) returns text
language sql as $$
  select format('hits=%s total=%s sample=%s eligible=%s v%s',
                m.hits, m.total, m.sample_n, m.eligible_n, m.metric_version)
  from public.gts_metric(p_key, '00000000-0000-4000-8000-0000000c1201', p_course, p_year) m;
$$;

-- ===== 1. evidence_strength column =====
insert into t select 1, 'evidence_strength is a stored generated column', 's',
  (select attgenerated::text from pg_attribute
   where attrelid = 'public.dss_flags'::regclass and attname = 'evidence_strength');

insert into public.dss_flags (id, rule_id, cohort_level, course, batch_year, survey_id,
  survey_title, metric_value, threshold_snapshot, sample_n, title, evidence)
values
  ('00000000-0000-4000-8000-0000000c1401', 'TIME_TO_JOB_LONG', 'batch', 'BSIT', '2099',
   '00000000-0000-4000-8000-0000000c1201', 'P12 GTS', 0.5, 0.4, 6, 'P12 watch',
   '{"evidence_strength":"watch","valid_answers":4}'),
  ('00000000-0000-4000-8000-0000000c1402', 'UNEMPLOYMENT_HIGH', 'batch', 'BSIT', '2099',
   '00000000-0000-4000-8000-0000000c1201', 'P12 GTS', 0.5, 0.25, 6, 'P12 legacy',
   '{"answered":6}');

insert into t select 2, 'evidence_strength follows the evidence', 'watch|(null)',
  (select string_agg(coalesce(evidence_strength, '(null)'), '|' order by id)
   from public.dss_flags where id in ('00000000-0000-4000-8000-0000000c1401',
                                      '00000000-0000-4000-8000-0000000c1402'));
insert into t select 3, 'unknown evidence_strength rejected', 'dss_flags_evidence_strength_check',
  case when pg_temp.try_sql($q$update public.dss_flags
    set evidence = evidence || '{"evidence_strength":"bogus"}'
    where id = '00000000-0000-4000-8000-0000000c1401'$q$) like '%dss_flags_evidence_strength_check%'
  then 'dss_flags_evidence_strength_check' else 'accepted' end;

-- ===== 2. rule minimums =====
insert into t select 4, 'every rule meets its min_n floor', '0 below floor',
  (select count(*) || ' below floor' from public.dss_rules
   where min_n < case when category = 'data_quality' then 1 else 10 end);
insert into t select 5, 'constraint validated', 'true',
  (select convalidated::text from pg_constraint where conname = 'dss_rules_min_n_policy');
insert into t select 6, 'outcome rule min_n 9 rejected', 'rejected',
  case when pg_temp.try_sql($q$update public.dss_rules set min_n = 9 where rule_id = 'UNEMPLOYMENT_HIGH'$q$) like 'ERROR%'
  then 'rejected' else 'accepted' end;
insert into t select 7, 'trend rule min_n 5 rejected', 'rejected',
  case when pg_temp.try_sql($q$update public.dss_rules set min_n = 5 where rule_id = 'UNEMPLOYMENT_TREND_UP'$q$) like 'ERROR%'
  then 'rejected' else 'accepted' end;
insert into t select 8, 'data quality min_n 0 rejected, 1 accepted', 'rejected|ok',
  (case when pg_temp.try_sql($q$update public.dss_rules set min_n = 0 where rule_id = 'DATA_QUALITY_LOW'$q$) like 'ERROR%'
   then 'rejected' else 'accepted' end) || '|' ||
  pg_temp.try_sql($q$update public.dss_rules set min_n = 1 where rule_id = 'DATA_QUALITY_LOW'$q$);

-- ===== 3. roster snapshots =====
insert into t select 9, 'snapshots: admin can save', 'ok',
  pg_temp.try_as('authenticated', '8a845be5-5870-437f-95e6-7ea3b0ad7a06',
    $q$insert into public.dss_wave_cohort_snapshots (survey_id, course, batch_year, roster_count, registered_count)
       values ('00000000-0000-4000-8000-0000000c1201', 'BSIT', '2099', 6, 6)$q$);
insert into t select 10, 'snapshots: admin can read', '1',
  pg_temp.try_as('authenticated', '8a845be5-5870-437f-95e6-7ea3b0ad7a06',
    $q$select count(*)::text from public.dss_wave_cohort_snapshots where survey_id = '00000000-0000-4000-8000-0000000c1201'$q$);
insert into t select 11, 'snapshots: alumnus sees none', '0',
  pg_temp.try_as('authenticated', '6f6c569a-9ded-4c90-acab-19d78ab2a3f3',
    'select count(*)::text from public.dss_wave_cohort_snapshots');
insert into t select 12, 'snapshots: alumnus cannot write', 'blocked',
  case when pg_temp.try_as('authenticated', '6f6c569a-9ded-4c90-acab-19d78ab2a3f3',
    $q$insert into public.dss_wave_cohort_snapshots (survey_id, course, batch_year, roster_count, registered_count)
       values ('00000000-0000-4000-8000-0000000c1201', 'BSIT', '2098', 1, 0)$q$) like 'ERROR%'
  then 'blocked' else 'ALLOWED' end;
insert into t select 13, 'snapshots: anon blocked', 'permission denied',
  pg_temp.try_as('anon', null, 'select count(*)::text from public.dss_wave_cohort_snapshots');
insert into t select 14, 'snapshots: registered above roster rejected', 'rejected',
  case when pg_temp.try_sql($q$insert into public.dss_wave_cohort_snapshots (survey_id, course, batch_year, roster_count, registered_count)
       values ('00000000-0000-4000-8000-0000000c1201', 'BSIT', '2097', 1, 2)$q$) like 'ERROR%'
  then 'rejected' else 'accepted' end;
insert into t select 15, 'snapshots: RLS on, admin + restrictive policy', 'true|2',
  (select relrowsecurity::text from pg_class where oid = 'public.dss_wave_cohort_snapshots'::regclass)
  || '|' || (select count(*)::text from pg_policies where tablename = 'dss_wave_cohort_snapshots');

-- ===== 4. gts_metric v2 =====
insert into t select 16, 'Q29 "Others" leaves the denominator (batch)', 'hits=2 total=4 sample=6 eligible=6 v2',
  pg_temp.metric('long_time_to_first_job_rate', 'BSIT', '2099');
insert into t select 17, 'no batch counts at course level only', 'hits=3 total=5 sample=7',
  (select format('hits=%s total=%s sample=%s', m.hits, m.total, m.sample_n)
   from public.gts_metric('long_time_to_first_job_rate',
     '00000000-0000-4000-8000-0000000c1201', 'BSIT', null) m);
insert into t select 18, 'unlinked respondent left out of the institution', 'sample=7',
  (select 'sample=' || m.sample_n from public.gts_metric('unemployment_rate',
     '00000000-0000-4000-8000-0000000c1201') m);
insert into t select 19, '"Unknown" never matches a group', 'sample=0 eligible=0',
  (select format('sample=%s eligible=%s', m.sample_n, m.eligible_n)
   from public.gts_metric('unemployment_rate', '00000000-0000-4000-8000-0000000c1201', 'Unknown', null) m);
insert into t select 20, '"Unknown" batch never matches', 'sample=0',
  (select 'sample=' || m.sample_n
   from public.gts_metric('unemployment_rate', '00000000-0000-4000-8000-0000000c1201', 'BSIT', 'Unknown') m);
insert into t select 21, 'salary gap total = salary answers', '3',
  (select m.total::text from public.gts_metric('salary_peer_gap',
     '00000000-0000-4000-8000-0000000c1201', 'BSIT', '2099') m);
insert into t select 22, 'unemployment unchanged in meaning', 'hits=3 total=6 sample=6 eligible=6 v2',
  pg_temp.metric('unemployment_rate', 'BSIT', '2099');

-- ===== 5. nightly re-check floor =====
select public.dss_recheck_open_flags();
insert into t select 23, 're-check: watch flag below 5 answers and legacy flag below 10 are no_data',
  'no_data|no_data',
  (select string_agg(c.state, '|' order by c.flag_id) from public.dss_flag_checks c
   where c.flag_id in ('00000000-0000-4000-8000-0000000c1401', '00000000-0000-4000-8000-0000000c1402'));
insert into t select 24, 'dss_recheck_open_flags: clients cannot run it', 'permission denied',
  pg_temp.try_as('authenticated', '8a845be5-5870-437f-95e6-7ea3b0ad7a06', 'select public.dss_recheck_open_flags()::text');
insert into t select 25, 'gts_metric: alumnus still blocked', 'Admin access required',
  pg_temp.try_as('authenticated', '6f6c569a-9ded-4c90-acab-19d78ab2a3f3',
    $q$select value::text from public.gts_metric('unemployment_rate', '00000000-0000-4000-8000-0000000c1201')$q$);

select n, test, expected,
  case when actual like '%' || expected || '%' then actual else 'MISMATCH: ' || actual end as actual
from t order by n;
rollback;
