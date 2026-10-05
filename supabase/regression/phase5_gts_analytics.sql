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

create temp table t(n int, test text, expected text, actual text);

-- Base-table expectations, computed before the migration runs.
create temp table exp as
select
  (select count(*) from public.survey_responses r join public.surveys s on s.id = r.survey_id
    where s.data ->> 'template_key' = 'ched_gts_builtin' and r.status = 'submitted') as ched_submitted,
  (select count(*) from public.survey_responses r join public.surveys s on s.id = r.survey_id
    where s.data ->> 'template_key' = 'ched_gts_builtin' and r.status = 'submitted'
      and r.user_id = '6f6c569a-9ded-4c90-acab-19d78ab2a3f3') as ched_submitted_a,
  (select count(distinct r.user_id) from public.survey_responses r join public.surveys s on s.id = r.survey_id
    where s.data ->> 'template_key' = 'ched_gts_builtin' and r.status = 'submitted'
      and nullif(btrim(r.answers ->> 'ched_16'), '') is not null) as ched_users,
  (select count(*) from public.dss_flags where status in ('open', 'in_progress')) as open_flags,
  (select max(updated_at) from public.dss_flags) as flags_updated_at;

-- ===== Phase 5 tests =====
insert into t select 1, 'gts_single: list / padded text / blank / null / number', 'a|b|(null)|(null)|5',
  coalesce(public.gts_single('["a","z"]'), '(null)') || '|' || coalesce(public.gts_single('"  b "'), '(null)') || '|' ||
  coalesce(public.gts_single('""'), '(null)') || '|' || coalesce(public.gts_single('null'), '(null)') || '|' ||
  coalesce(public.gts_single('5'), '(null)');
insert into t select 2, 'gts_job_level: current job wins, first job fallback, non-object', 'Managerial or Executive|Rank or Clerical|(null)',
  coalesce(public.gts_job_level('{"Rank or Clerical": {"30.1. First Job": true}, "Managerial or Executive": {"30.2. Current or Present Job": true}}'), '(null)') || '|' ||
  coalesce(public.gts_job_level('{"Managerial or Executive": {"30.1. First Job": false}, "Rank or Clerical": {"30.1. First Job": true}}'), '(null)') || '|' ||
  coalesce(public.gts_job_level('"x"'), '(null)');
insert into t select 3, 'gts_salary_rank', '0|5|(null)',
  coalesce(public.gts_salary_rank('Below P5,000.00')::text, '(null)') || '|' ||
  coalesce(public.gts_salary_rank(' P25,000.00 and above ')::text, '(null)') || '|' ||
  coalesce(public.gts_salary_rank('nope')::text, '(null)');

insert into t select 4, 'facts: admin sees every submitted CHED response', (select ched_submitted::text from exp),
  pg_temp.try_as('authenticated', '8a845be5-5870-437f-95e6-7ea3b0ad7a06', 'select count(*)::text from public.gts_respondent_facts');
insert into t select 5, 'facts: alumnus A sees only own', (select ched_submitted_a::text from exp),
  pg_temp.try_as('authenticated', '6f6c569a-9ded-4c90-acab-19d78ab2a3f3', 'select count(*)::text from public.gts_respondent_facts');
insert into t select 6, 'facts: anon blocked', 'permission denied',
  pg_temp.try_as('anon', null, 'select count(*)::text from public.gts_respondent_facts');

insert into t select 7, 'gts_metric matches stored Dart metric for every open flag', '0 differences',
  (select count(*) || ' differences of ' || (select open_flags from exp)
     || coalesce(': ' || string_agg(x.rule_id || ' ' || x.stored || '->' || coalesce(x.computed::text, 'null'), '; '), '')
   from (
     select fl.rule_id, fl.metric_value as stored, m.value as computed, fl.sample_n, m.sample_n as msample, fl.eligible_n, m.eligible_n as meligible
     from public.dss_flags fl
     join public.dss_rules r on r.rule_id = fl.rule_id
     cross join lateral public.gts_metric(r.metric_key, fl.survey_id::uuid,
       case when fl.cohort_level = 'institution' then null else fl.course end,
       case when fl.cohort_level in ('institution', 'course') then null else fl.batch_year end) m
     where fl.status in ('open', 'in_progress')
   ) x
   where round(x.stored, 6) is distinct from round(x.computed, 6)
      or x.sample_n is distinct from x.msample
      or x.eligible_n is distinct from x.meligible);
insert into t select 8, 'gts_metric: alumnus blocked', 'Admin access required',
  pg_temp.try_as('authenticated', '6f6c569a-9ded-4c90-acab-19d78ab2a3f3',
    $q$select value::text from public.gts_metric('unemployment_rate', (select survey_id from public.survey_responses limit 1))$q$);
insert into t select 9, 'gts_metric: anon blocked', 'permission denied',
  pg_temp.try_as('anon', null,
    $q$select value::text from public.gts_metric('unemployment_rate', gen_random_uuid())$q$);
insert into t select 10, 'gts_metric: admin, unknown key', 'Unknown metric key',
  pg_temp.try_as('authenticated', '8a845be5-5870-437f-95e6-7ea3b0ad7a06',
    $q$select value::text from public.gts_metric('nope', gen_random_uuid())$q$);
insert into t select 11, 'gts_metric: response_rate with empty wave is 0, not null', '0',
  pg_temp.try_as('authenticated', '8a845be5-5870-437f-95e6-7ea3b0ad7a06',
    $q$select value::text from public.gts_metric('response_rate', gen_random_uuid(), 'BSIT', '2027')$q$);
insert into t select 12, 'gts_metric: institution unemployment over all waves'' latest flags (sanity)', 'value between 0 and 1',
  pg_temp.try_as('authenticated', '8a845be5-5870-437f-95e6-7ea3b0ad7a06',
    $q$select case when value between 0 and 1 then 'value between 0 and 1' else coalesce(value::text, 'null') end
       from public.gts_metric('unemployment_rate', (select fl.survey_id::uuid from public.dss_flags fl where fl.rule_id = 'UNEMPLOYMENT_HIGH' limit 1))$q$);

insert into t select 13, 'employment view: one row per alumnus with a CHED answer (admin)', (select ched_users::text from exp),
  pg_temp.try_as('authenticated', '8a845be5-5870-437f-95e6-7ea3b0ad7a06', 'select count(*)::text from public.gts_employment_records');
insert into t select 14, 'employment view: statuses', 'Employed/Unemployed only',
  pg_temp.try_as('authenticated', '8a845be5-5870-437f-95e6-7ea3b0ad7a06',
    $q$select string_agg(distinct status, '/' order by status) from public.gts_employment_records$q$);
insert into t select 15, 'employment view: alumnus A sees only own row', '0 foreign rows',
  pg_temp.try_as('authenticated', '6f6c569a-9ded-4c90-acab-19d78ab2a3f3',
    $q$select count(*) filter (where user_id <> '6f6c569a-9ded-4c90-acab-19d78ab2a3f3') || ' foreign rows' from public.gts_employment_records$q$);
insert into t select 16, 'employment view: anon blocked', 'permission denied',
  pg_temp.try_as('anon', null, 'select count(*)::text from public.gts_employment_records');
insert into t select 17, 'employment view: alumnus cannot write', 'blocked',
  pg_temp.try_as('authenticated', '6f6c569a-9ded-4c90-acab-19d78ab2a3f3',
    $q$insert into public.gts_employment_records (id, user_id, status) values (gen_random_uuid(), '6f6c569a-9ded-4c90-acab-19d78ab2a3f3', 'Employed')$q$);
insert into t select 18, 'employment view: employed rows carry CHED fields', 'all employed rows have position/industry/type',
  pg_temp.try_as('authenticated', '8a845be5-5870-437f-95e6-7ea3b0ad7a06',
    $q$select case when bool_and(position is not null and data ? 'industry' and data ? 'employmentType' and data ? 'salaryRange')
         then 'all employed rows have position/industry/type' else 'missing fields' end
       from public.gts_employment_records where status = 'Employed'$q$);

insert into t select 19, 'employment_records retired', 'gone',
  case when to_regclass('public.employment_records') is null then 'gone' else 'still live' end;
insert into t select 20, 'archived_employment_records dropped (Phase 7)', 'gone',
  case when to_regclass('public.archived_employment_records') is null then 'gone' else 'still present' end;
insert into t select 21, 'no policies left on retired employment tables', '0',
  (select count(*)::text from pg_policies where schemaname = 'public'
     and tablename in ('employment_records', 'archived_employment_records'));

insert into t select 22, 'dss_flag_checks: one row per open flag', (select open_flags::text from exp),
  (select count(*)::text from public.dss_flag_checks);
insert into t select 23, 'dss_flag_checks: states', 'listed',
  (select string_agg(fl.rule_id || '=' || c.state || '(' || coalesce(round(c.metric_value, 3)::text, 'null') || ')', ', ' order by fl.rule_id)
   from public.dss_flag_checks c join public.dss_flags fl on fl.id = c.flag_id);
insert into t select 24, 'dss_flags not modified by the re-check', 'unchanged',
  case when (select max(updated_at) from public.dss_flags) is not distinct from (select flags_updated_at from exp)
    then 'unchanged' else 'CHANGED' end;
insert into t select 25, 'dss_flag_checks: alumnus sees none', '0',
  pg_temp.try_as('authenticated', '6f6c569a-9ded-4c90-acab-19d78ab2a3f3', 'select count(*)::text from public.dss_flag_checks');
insert into t select 26, 'dss_flag_checks: admin can read', (select open_flags::text from exp),
  pg_temp.try_as('authenticated', '8a845be5-5870-437f-95e6-7ea3b0ad7a06', 'select count(*)::text from public.dss_flag_checks');
insert into t select 27, 'dss_flag_checks: admin cannot write', 'permission denied',
  pg_temp.try_as('authenticated', '8a845be5-5870-437f-95e6-7ea3b0ad7a06', 'delete from public.dss_flag_checks');
insert into t select 28, 'dss_recheck_open_flags: clients cannot run it', 'permission denied',
  pg_temp.try_as('authenticated', '8a845be5-5870-437f-95e6-7ea3b0ad7a06', 'select public.dss_recheck_open_flags()::text');
update public.dss_flag_checks set recovered_since = '2020-01-01' where state = 'recovered';
insert into t select 29, 'recheck is repeatable and keeps recovered_since', 'same count, recovered_since kept', 'pending';
update t set actual = (
  select case when public.dss_recheck_open_flags() = (select open_flags from exp)
     and not exists (select 1 from public.dss_flag_checks where state = 'recovered' and recovered_since <> '2020-01-01')
    then 'same count, recovered_since kept' else 'MISMATCH' end)
where n = 29;
insert into t select 30, 'cron job scheduled', '15 19 * * *',
  (select schedule from cron.job where jobname = 'aess-dss-recheck');
insert into t select 31, 'new views are security_invoker', '2',
  (select count(*)::text from pg_class where relname in ('gts_respondent_facts', 'gts_employment_records')
     and reloptions @> array['security_invoker=true']);
insert into t select 32, 'new functions pin search_path', '6',
  (select count(*)::text from pg_proc where pronamespace = 'public'::regnamespace
     and proname in ('gts_single', 'gts_job_level', 'gts_salary_rank', 'dss_crosses', 'gts_metric', 'dss_recheck_open_flags')
     and proconfig::text like '%search_path%');
insert into t select 33, 'anon cannot execute helper functions', 'permission denied',
  pg_temp.try_as('anon', null, $q$select public.gts_single('"x"')$q$);

select n, test, expected, actual from t order by n;

rollback;
