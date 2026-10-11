begin;
-- Phase 14: DSS Phase 3 server metric layer (dss_wilson, dss_cohort_metrics).
-- Same fixture and expected values as test/dss/dss_cohort_metrics_test.dart.
-- Fixture courses P14T / P14U exist only inside this transaction, so real
-- data never changes course and batch results (institution roster counts
-- include the real roster and are not checked).
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

insert into public.programs (code, name, sort_order) values
  ('P14T', 'P14 fixture course T', 9001),
  ('P14U', 'P14 fixture course U', 9002);

insert into public.surveys (id, title, status, created_by, data, open_at, close_at) values
  ('00000000-0000-4000-8000-0000000e1201', 'P14 GTS', 'closed',
   (select id from public.users where role = 'admin' limit 1),
   jsonb_build_object('kind', 'ched_gts_builtin', 'template_key', 'ched_gts_builtin'), null, null),
  ('00000000-0000-4000-8000-0000000e1202', 'P14 open GTS', 'published',
   (select id from public.users where role = 'admin' limit 1),
   jsonb_build_object('kind', 'ched_gts_builtin', 'template_key', 'ched_gts_builtin'),
   now() - interval '1 day', now() + interval '1 day'),
  ('00000000-0000-4000-8000-0000000e1203', 'P14 custom survey', 'closed',
   (select id from public.users where role = 'admin' limit 1),
   jsonb_build_object('kind', 'custom'), null, null);

-- p_course, p_year (null = no batch), account?, answers (null = no response),
-- on roster?
create function pg_temp.alumnus(p_n int, p_course text, p_year text, p_account boolean,
                                p_answers jsonb, p_on_roster boolean default true)
returns void language plpgsql as $$
declare
  v_uid uuid := ('00000000-0000-4000-8000-0000000e13' || lpad(p_n::text, 2, '0'))::uuid;
begin
  if p_account then
    insert into auth.users (id, instance_id, aud, role, email, email_confirmed_at)
    values (v_uid, '00000000-0000-0000-0000-000000000000', 'authenticated',
            'authenticated', 'p14-' || p_n || '@example.invalid', now());
  end if;
  if p_on_roster then
    insert into public.alumni_members (full_name, course, student_id, year_graduated, auth_uid)
    values ('P14 Alumnus ' || p_n, p_course, 'P14-' || p_n, p_year,
            case when p_account then v_uid end);
  end if;
  if p_answers is not null then
    insert into public.survey_responses (survey_id, user_id, answers, status, submitted_at)
    values ('00000000-0000-4000-8000-0000000e1201', v_uid, p_answers, 'submitted', now());
  end if;
end $$;

select pg_temp.alumnus(1, 'P14T', '2099', true, '{"ched_16":"Yes","ched_24a":"Yes","ched_32":"Yes","ched_29":"Less than a month","ched_31":"P10,000.00 to less than P15,000.00","ched_30":{"Rank or Clerical":{"30.2. Current or Present Job":true}}}');
select pg_temp.alumnus(2, 'P14T', '2099', true, '{"ched_16":"Yes","ched_24a":"No","ched_29":"1 year to less than 2 years","ched_31":"P5,000.00 to less than P10,000.00","ched_30":{"Professional, Technical or Supervisory":{"30.2. Current or Present Job":true}}}');
select pg_temp.alumnus(3, 'P14T', '2099', true, '{"ched_16":"No","ched_17":["No job opportunity"],"ched_29":"Others, please specify","ched_31":"Below P5,000.00"}');
select pg_temp.alumnus(4, 'P14T', '2099', true, '{"ched_16":"Never Employed","ched_17":["Advance or further study"],"ched_32":"No"}');
select pg_temp.alumnus(5, 'P14T', '2099', true, '{"ched_16":"No","ched_17":["Lack of work experience"],"ched_29":"2 years to less than 3 years"}');
select pg_temp.alumnus(6, 'P14T', '2099', true, '{"ched_16":"Yes","ched_24a":"Yes","ched_32":"Yes","ched_31":"P15,000.00 to less than P20,000.00","ched_30":{"Rank or Clerical":{"30.1. First Job":true}}}');
select pg_temp.alumnus(7, 'P14T', '2099', true, null);
select pg_temp.alumnus(8, 'P14T', '2099', true, null);
select pg_temp.alumnus(9, 'P14T', '2098', true, '{"ched_16":"Yes","ched_31":"P20,000.00 to less than P25,000.00"}');
select pg_temp.alumnus(10, 'P14T', '2098', true, null);
select pg_temp.alumnus(11, 'P14T', null, true, '{"ched_16":"No","ched_17":["Did not look for a job"]}');
select pg_temp.alumnus(12, 'P14T', '2097', false, null);
select pg_temp.alumnus(13, null, null, true, '{"ched_16":"No"}', false);
select pg_temp.alumnus(14, 'P14U', '2099', true, '{"ched_16":"Yes","ched_31":"P25,000.00 and above"}');

create temp table m as
select * from public.dss_cohort_metrics('00000000-0000-4000-8000-0000000e1201');

create function pg_temp.r(p_level text, p_course text, p_batch text, p_key text) returns text
language sql as $$
  select coalesce((
    select format('%s/%s v=%s n=%s e=%s s=%s',
                  coalesce(x.hits::text, 'null'), x.total,
                  coalesce(to_char(x.value, 'FM9990.0000'), 'null'),
                  x.respondents, x.eligible, coalesce(x.evidence_strength, 'null'))
    from m x
    where x.level = p_level and x.course = p_course and x.batch_year = p_batch and x.metric_key = p_key
  ), 'missing');
$$;

-- ===== 1. batch P14T 2099 =====
insert into t select 1, 'batch response rate', '6/8 v=0.7500 n=6 e=8 s=null', pg_temp.r('batch', 'P14T', '2099', 'response_rate');
insert into t select 2, 'batch not employed', '3/6 v=0.5000 n=6 e=8 s=watch', pg_temp.r('batch', 'P14T', '2099', 'unemployment_rate');
insert into t select 3, 'batch looking for work', '2/5 v=0.4000 n=6 e=8 s=watch', pg_temp.r('batch', 'P14T', '2099', 'seeking_work_rate');
insert into t select 4, 'batch mismatch', '2/4 v=0.5000 n=6 e=8 s=insufficient', pg_temp.r('batch', 'P14T', '2099', 'unrelated_or_irrelevant_rate');
insert into t select 5, 'batch aligned', '2/4 v=0.5000 n=6 e=8 s=insufficient', pg_temp.r('batch', 'P14T', '2099', 'related_and_relevant_rate');
insert into t select 6, 'batch clerical (current, then first job)', '2/3 v=0.6667 n=6 e=8 s=insufficient', pg_temp.r('batch', 'P14T', '2099', 'clerical_among_employed_rate');
insert into t select 7, 'batch Q29 without "Others"', '2/3 v=0.6667 n=6 e=8 s=insufficient', pg_temp.r('batch', 'P14T', '2099', 'long_time_to_first_job_rate');
insert into t select 8, 'batch salary gap vs other courses', 'null/4 v=3.5000 n=6 e=8 s=insufficient', pg_temp.r('batch', 'P14T', '2099', 'salary_peer_gap');
insert into t select 9, 'batch extras: non-response, registered, basis, coverage, interval',
  '0|8|current|false|0.1876|0.8124|3|null|null',
  (select format('%s|%s|%s|%s|%s|%s', x.non_response, x.registered, x.roster_basis, x.coverage_warning::text,
                 to_char(x.ci_low, 'FM0.0000'), to_char(x.ci_high, 'FM0.0000'))
   from m x where x.level = 'batch' and x.course = 'P14T' and x.batch_year = '2099' and x.metric_key = 'unemployment_rate')
  || '|' || (select x.non_response from m x where x.level = 'batch' and x.course = 'P14T' and x.batch_year = '2099' and x.metric_key = 'long_time_to_first_job_rate')
  || '|' || (select coalesce(x.non_response::text, 'null') from m x where x.level = 'batch' and x.course = 'P14T' and x.batch_year = '2099' and x.metric_key = 'response_rate')
  || '|' || (select coalesce(x.ci_low::text, 'null') from m x where x.level = 'batch' and x.course = 'P14T' and x.batch_year = '2099' and x.metric_key = 'salary_peer_gap');

-- ===== 2. course P14T =====
insert into t select 10, 'course response rate (unlinked respondent left out)', '8/12 v=0.6667 n=8 e=12 s=null', pg_temp.r('course', 'P14T', 'All', 'response_rate');
insert into t select 11, 'course not employed (batch-less respondent counts)', '4/8 v=0.5000 n=8 e=12 s=watch', pg_temp.r('course', 'P14T', 'All', 'unemployment_rate');
insert into t select 12, 'course looking for work', '2/6 v=0.3333 n=8 e=12 s=watch', pg_temp.r('course', 'P14T', 'All', 'seeking_work_rate');
insert into t select 13, 'course salary gap', 'null/5 v=3.0000 n=8 e=12 s=watch', pg_temp.r('course', 'P14T', 'All', 'salary_peer_gap');
insert into t select 14, 'course registered', '11',
  (select x.registered::text from m x where x.level = 'course' and x.course = 'P14T' and x.metric_key = 'response_rate');

-- ===== 3. small and empty batches =====
insert into t select 15, 'batch 2098 response rate', '1/2 v=0.5000 n=1 e=2 s=null', pg_temp.r('batch', 'P14T', '2098', 'response_rate');
insert into t select 16, 'batch 2098 salary gap', 'null/1 v=1.0000 n=1 e=2 s=insufficient', pg_temp.r('batch', 'P14T', '2098', 'salary_peer_gap');
insert into t select 17, 'empty batch 2097: response rate only', '0/1 v=0.0000 n=0 e=1 s=null|true|0|1',
  pg_temp.r('batch', 'P14T', '2097', 'response_rate')
  || '|' || (select x.coverage_warning::text || '|' || x.registered from m x where x.level = 'batch' and x.course = 'P14T' and x.batch_year = '2097')
  || '|' || (select count(*) from m x where x.course = 'P14T' and x.batch_year = '2097');
insert into t select 18, 'no batch row for "Batch not recorded"', '0',
  (select count(*)::text from m x where x.batch_year = 'Batch not recorded');

-- ===== 4. peers and institution =====
insert into t select 19, 'P14U salary gap uses the other courses', 'null/1 v=-3.0000 n=1 e=1 s=insufficient', pg_temp.r('course', 'P14U', 'All', 'salary_peer_gap');
insert into t select 20, 'institution: classified respondents only', '4/9 n=9 s=watch',
  (select format('%s/%s n=%s s=%s', x.hits, x.total, x.respondents, x.evidence_strength)
   from m x where x.level = 'institution' and x.metric_key = 'unemployment_rate');
insert into t select 21, 'institution: no salary gap', '0',
  (select count(*)::text from m x where x.level = 'institution' and x.metric_key = 'salary_peer_gap');
insert into t select 22, 'row order: institution, courses, batches; metrics in key order',
  'institution|All|All,course|P14T|All,course|P14U|All,batch|P14T|2097,batch|P14T|2098,batch|P14T|2099,batch|P14U|2099',
  (select string_agg(g, ',' order by first_row) from (
     select x.level || '|' || x.course || '|' || x.batch_year as g, min(x.rn) as first_row
     from (select y.*, row_number() over () as rn
           from public.dss_cohort_metrics('00000000-0000-4000-8000-0000000e1201') y) x
     where x.level = 'institution' or x.course in ('P14T', 'P14U')
     group by 1) z);
insert into t select 23, 'metric version 2 everywhere', '2',
  (select string_agg(distinct x.metric_version::text, ',') from m x);

-- ===== 5. roster basis =====
insert into public.dss_wave_cohort_snapshots (survey_id, course, batch_year, roster_count, registered_count)
values ('00000000-0000-4000-8000-0000000e1201', 'P14T', '2099', 20, 10),
       ('00000000-0000-4000-8000-0000000e1202', 'P14T', '2099', 20, 10);
create temp table ms as
select * from public.dss_cohort_metrics('00000000-0000-4000-8000-0000000e1201');
insert into t select 24, 'closed wave with a snapshot uses it', 'snapshot|6/20|false|8/20|1/1|0',
  (select x.roster_basis || '|' || x.hits || '/' || x.total || '|' || x.coverage_warning
   from ms x where x.level = 'batch' and x.course = 'P14T' and x.batch_year = '2099' and x.metric_key = 'response_rate')
  || '|' || (select x.hits || '/' || x.total from ms x where x.level = 'course' and x.course = 'P14T' and x.metric_key = 'response_rate')
  || '|' || (select x.hits || '/' || x.total from ms x where x.level = 'batch' and x.course = 'P14T' and x.batch_year = '2098' and x.metric_key = 'response_rate')
  || '|' || (select count(*) from ms x where x.course = 'P14T' and x.batch_year = '2097');
insert into t select 25, 'open wave uses today''s roster even with a snapshot', 'open_wave|0/8',
  (select x.roster_basis || '|' || x.hits || '/' || x.total
   from public.dss_cohort_metrics('00000000-0000-4000-8000-0000000e1202') x
   where x.level = 'batch' and x.course = 'P14T' and x.batch_year = '2099' and x.metric_key = 'response_rate');

-- ===== 6. scope and access =====
insert into t select 26, 'non-CHED survey returns nothing', '0',
  (select count(*)::text from public.dss_cohort_metrics('00000000-0000-4000-8000-0000000e1203'));
insert into t select 27, 'dss_wilson matches DssMetrics.wilson; 0 hits = 0 low; no answers = null', '0.1876|0.8124|0|null',
  (select to_char(w.low, 'FM0.0000') || '|' || to_char(w.high, 'FM0.0000') from public.dss_wilson(3, 6) w)
  || '|' || (select w.low::text from public.dss_wilson(0, 5) w)
  || '|' || (select coalesce(w.low::text, 'null') from public.dss_wilson(0, 0) w);
insert into t select 28, 'alumnus blocked', 'Admin access required',
  pg_temp.try_as('authenticated', '6f6c569a-9ded-4c90-acab-19d78ab2a3f3',
    $q$select count(*)::text from public.dss_cohort_metrics('00000000-0000-4000-8000-0000000e1201')$q$);
insert into t select 29, 'anon blocked', 'permission denied',
  pg_temp.try_as('anon', null,
    $q$select count(*)::text from public.dss_cohort_metrics('00000000-0000-4000-8000-0000000e1201')$q$);
insert into t select 30, 'admin allowed', 'ok',
  case when pg_temp.try_as('authenticated', '8a845be5-5870-437f-95e6-7ea3b0ad7a06',
    $q$select count(*)::text from public.dss_cohort_metrics('00000000-0000-4000-8000-0000000e1201')$q$) ~ '^\d+$'
  then 'ok' else 'blocked' end;

select n, test, expected,
  case when actual like '%' || expected || '%' then actual else 'MISMATCH: ' || actual end as actual
from t order by n;
rollback;
