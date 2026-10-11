begin;
-- Phase 18: DSS Phase 8, server evaluation (dss_evaluate_all, stored
-- priority, wording helpers, the switched-off cron job).
-- Fixture courses (batches after 2026, so the newest real wave never expects
-- them to answer):
--   P18C 2091: 50 on the roster; wave A (2001) 12 answers, 1 not employed;
--              wave B (2002) 12 answers, 6 not employed (3 looking for work),
--              6 course mismatch (3 suggestions), salary bracket 1
--   P18C 2092: 7 answers in wave B, 4 not employed (Watch)
--   P18C 2093: 3 answers in wave B, 2 not employed (not judged)
--   P18E 2091: 10 answers in wave B, all employed, salary bracket 5 (peers)
--   P18D 2020 / 2099: roster only, used by the newest-wave scenario
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

create function pg_temp.admin(p_sql text) returns text
language sql as $$
  select pg_temp.try_as('authenticated', '8a845be5-5870-437f-95e6-7ea3b0ad7a06', p_sql);
$$;

create temp table t(n int, test text, expected text, actual text);

-- Rule values this script relies on (rolled back with everything else).
update public.dss_rules set enabled = true, operator = 'lt', threshold = 0.40, min_n = 1
where rule_id = 'DATA_QUALITY_LOW';
update public.dss_rules set enabled = true, operator = 'gte', threshold = 0.25, min_n = 10, severity = 'critical'
where rule_id = 'UNEMPLOYMENT_HIGH';
update public.dss_rules set enabled = true, operator = 'gte', threshold = 0.40, min_n = 10
where rule_id = 'RELATEDNESS_LOW';
update public.dss_rules set enabled = true, operator = 'gte', threshold = 0.75, min_n = 10
where rule_id = 'RELATEDNESS_HIGH';
update public.dss_rules set enabled = true, operator = 'gte', threshold = 1.0, min_n = 10
where rule_id = 'SALARY_STAGNATION';
update public.dss_rules set enabled = true, operator = 'gte', threshold = 0.10, min_n = 10
where rule_id = 'UNEMPLOYMENT_TREND_UP';
update public.dss_rules set enabled = false where rule_id = 'SEEKING_WORK_HIGH';

insert into public.programs (code, name, sort_order) values
  ('P18C', 'P18 fixture course', 9018),
  ('P18D', 'P18 targeted course', 9019),
  ('P18E', 'P18 peer course', 9020);

insert into public.surveys (id, title, status, created_by, data, open_at, close_at) values
  ('00000000-0000-4000-8000-0000000e18a0', 'P18 wave A', 'closed',
   (select id from public.users where role = 'admin' limit 1),
   jsonb_build_object('kind', 'ched_gts_builtin', 'template_key', 'ched_gts_builtin',
                      'publishedAt', '2001-01-01T00:00:00Z'), null, null),
  ('00000000-0000-4000-8000-0000000e18b0', 'P18 wave B', 'closed',
   (select id from public.users where role = 'admin' limit 1),
   jsonb_build_object('kind', 'ched_gts_builtin', 'template_key', 'ched_gts_builtin',
                      'publishedAt', '2002-01-01T00:00:00Z'), null, null);

create function pg_temp.uid(p_k int) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-00000e18' || lpad(p_k::text, 4, '0'))::uuid;
$$;

create function pg_temp.people(p_course text, p_batch text, p_first int, p_n int)
returns void language plpgsql as $$
begin
  for k in p_first .. p_first + p_n - 1 loop
    insert into auth.users (id, instance_id, aud, role, email, email_confirmed_at)
    values (pg_temp.uid(k), '00000000-0000-0000-0000-000000000000', 'authenticated',
            'authenticated', 'p18-' || k || '@example.invalid', now());
    insert into public.alumni_members (full_name, course, student_id, year_graduated, auth_uid)
    values ('P18 Alumnus ' || k, p_course, 'P18-' || k, p_batch, pg_temp.uid(k));
  end loop;
end $$;

create function pg_temp.answer(p_wave text, p_k int, p_answers jsonb)
returns void language sql as $$
  insert into public.survey_responses (survey_id, user_id, answers, status, submitted_at)
  values (('00000000-0000-4000-8000-0000000e18' || p_wave || '0')::uuid, pg_temp.uid(p_k), p_answers,
          'submitted', '2002-02-01T00:00:00Z'::timestamptz + p_k * interval '1 minute');
$$;

select pg_temp.people('P18C', '2091', 1, 50);
select pg_temp.people('P18C', '2092', 51, 7);
select pg_temp.people('P18C', '2093', 58, 3);
select pg_temp.people('P18E', '2091', 61, 10);
select pg_temp.people('P18D', '2020', 71, 5);
select pg_temp.people('P18D', '2099', 76, 3);

-- wave A: P18C 2091, 1 of 12 not employed
select pg_temp.answer('a', k, jsonb_build_object('ched_16', case when k = 1 then 'No' else 'Yes' end))
from generate_series(1, 12) k;

-- wave B
select pg_temp.answer('b', k, jsonb_build_object(
    'ched_16', case when k <= 6 then 'No' else 'Yes' end,
    'ched_17', case when k <= 3 then '["No job opportunity"]'::jsonb
                    when k <= 6 then '["Did not look for a job"]'::jsonb end,
    'ched_24a', case when k <= 6 then 'No' else 'Yes' end,
    'ched_34', case k when 1 then 'More OJT and internship' when 2 then 'Industry partners please'
                      when 3 then 'OJT' end,
    'ched_31', 'P5,000.00 to less than P10,000.00'))
from generate_series(1, 12) k;
select pg_temp.answer('b', k, jsonb_build_object('ched_16', case when k <= 54 then 'No' else 'Yes' end))
from generate_series(51, 57) k;
select pg_temp.answer('b', k, jsonb_build_object('ched_16', case when k <= 59 then 'No' else 'Yes' end))
from generate_series(58, 60) k;
select pg_temp.answer('b', k, jsonb_build_object('ched_16', 'Yes', 'ched_31', 'P25,000.00 and above'))
from generate_series(61, 70) k;

-- Stored flags exercising every sync path.
insert into public.dss_flags (id, rule_id, cohort_level, course, batch_year, survey_id,
  survey_title, metric_value, threshold_snapshot, sample_n, title, evidence, status, superseded_at)
values
  ('00000000-0000-4000-8000-0000000d1801', 'UNEMPLOYMENT_HIGH', 'batch', 'P18C', '2091',
   '00000000-0000-4000-8000-0000000e18a0', 'P18 wave A', 0.30, 0.25, 12, 'P18 older open',
   '{"evidence_strength":"limited"}', 'open', null),
  ('00000000-0000-4000-8000-0000000d1802', 'DATA_QUALITY_LOW', 'batch', 'P18C', '2091',
   '00000000-0000-4000-8000-0000000e18a0', 'P18 wave A', 0.10, 0.40, 5, 'P18 older in progress',
   '{}', 'in_progress', null),
  ('00000000-0000-4000-8000-0000000d1803', 'UNEMPLOYMENT_HIGH', 'course', 'P18C', 'All',
   '00000000-0000-4000-8000-0000000e18b0', 'P18 wave B', 0.50, 0.25, 22, 'P18 resolved',
   '{"evidence_strength":"limited"}', 'resolved', null),
  ('00000000-0000-4000-8000-0000000d1804', 'UNEMPLOYMENT_HIGH', 'batch', 'P18C', '2092',
   '00000000-0000-4000-8000-0000000e18b0', 'P18 wave B', 0.50, 0.25, 12, 'P18 becomes watch',
   '{"evidence_strength":"limited"}', 'open', null),
  ('00000000-0000-4000-8000-0000000d1805', 'UNEMPLOYMENT_TREND_UP', 'batch', 'P18C', '2091',
   '00000000-0000-4000-8000-0000000e18b0', 'P18 wave B', 0.40, 0.10, 12, 'P18 superseded',
   '{"evidence_strength":"limited"}', 'superseded', now()),
  ('00000000-0000-4000-8000-0000000d1806', 'RELATEDNESS_HIGH', 'batch', 'P18C', '2091',
   '00000000-0000-4000-8000-0000000e18a0', 'P18 wave A', 0.80, 0.75, 7, 'P18 older watch',
   '{"evidence_strength":"watch"}', 'watch', null);
update public.dss_flags set resolved_at = now() where id = '00000000-0000-4000-8000-0000000d1803';

-- ===== 1. schema, helpers, cron =====
insert into t select 1, 'priority columns', 'priority|priority_score|priority_reasons|priority_at',
  (select string_agg(column_name, '|' order by ordinal_position) from information_schema.columns
   where table_schema = 'public' and table_name = 'dss_flags' and column_name like 'priority%');
insert into t select 2, 'unknown priority rejected', 'dss_flags_priority_check',
  pg_temp.try_sql($q$update public.dss_flags set priority = 'urgent'
    where id = '00000000-0000-4000-8000-0000000d1801'$q$);
insert into t select 3, 'cron job created switched off', '25 19 * * *|false|select public.dss_evaluate_all(''scheduled'');',
  (select schedule || '|' || active || '|' || command from cron.job where jobname = 'aess-dss-evaluate');
insert into t select 4, 'dss_fixed rounds the exact double half away from zero',
  '0.14|3|0.13|14|-0.0|33.3|0.0|40|0.9|100',
  public.dss_fixed(0.145, 2) || '|' || public.dss_fixed(2.5, 0) || '|' || public.dss_fixed(0.125, 2)
  || '|' || public.dss_fixed(14.499999999999998, 0) || '|' || public.dss_fixed(-0.04, 1)
  || '|' || public.dss_fixed(1::float8 / 3 * 100, 1) || '|' || public.dss_fixed(0, 1)
  || '|' || public.dss_fixed(0.4::float8 * 100, 0) || '|' || public.dss_fixed(0.95, 1)
  || '|' || public.dss_fixed(99.5, 0);
insert into t select 5, 'dss_points', '+42 pts|−5 pts|0 pts',
  public.dss_points(0.4166666666666667) || '|' || public.dss_points(-0.05) || '|' || public.dss_points(0);
insert into t select 6, 'theme hints: count, then first appearance',
  '["Internships / OJT (2)", "Industry exposure and partnerships (1)", "Updated tools and technology (1)"]',
  public.dss_theme_hints(array['More OJT and internship', 'Industry partners please', 'OJT', 'Better software tools'])::text;

-- ===== 2. access =====
insert into t select 7, 'anonymous callers cannot run it', 'permission denied',
  pg_temp.try_as('anon', null, $q$select public.dss_evaluate_all('manual', true)::text$q$);
insert into t select 8, 'alumni cannot run it', 'Admin access required',
  pg_temp.try_as('authenticated', '6f6c569a-9ded-4c90-acab-19d78ab2a3f3',
    $q$select public.dss_evaluate_all('manual', true)::text$q$);
insert into t select 9, 'unknown trigger rejected', 'Unknown run trigger',
  pg_temp.try_sql($q$select public.dss_evaluate_all('weekly', true)$q$);

-- ===== 3. dry run: the plan, nothing written =====
create temp table before_counts as
select (select count(*) from public.dss_flags) as flags,
       (select count(*) from public.dss_evaluation_events) as events,
       (select count(*) from public.dss_flag_notes) as notes;
create temp table dry as select pg_temp.admin($q$select public.dss_evaluate_all('manual', true)::text$q$)::jsonb as j;
create temp table dry_rows as
select e as r from dry, jsonb_array_elements(dry.j -> 'rows') e
where e ->> 'course' in ('P18C', 'P18D', 'P18E');
create function pg_temp.row_of(p_key text, p_wave text) returns jsonb language sql as $$
  select r from dry_rows
  where r ->> 'finding_key' = p_key
    and r ->> 'survey_id' = '00000000-0000-4000-8000-0000000e18' || p_wave || '0';
$$;

insert into t select 10, 'dry run writes nothing', 'true|0|0|0',
  (select (j ->> 'dry_run') from dry)
  || '|' || ((select count(*) from public.dss_flags) - (select flags from before_counts))
  || '|' || ((select count(*) from public.dss_evaluation_events) - (select events from before_counts))
  || '|' || ((select count(*) from public.dss_flag_notes) - (select notes from before_counts));
insert into t select 11, 'batch finding row',
  '0.5|open|limited|true|low|12|50|Not currently employed: P18C · Batch 2091',
  (select (r ->> 'metric_value') || '|' || (r ->> 'status') || '|' || (r -> 'evidence' ->> 'evidence_strength')
     || '|' || (r -> 'evidence' ->> 'coverage_warning') || '|' || (r ->> 'confidence')
     || '|' || (r ->> 'sample_n') || '|' || (r ->> 'eligible_n') || '|' || (r ->> 'title')
   from (select pg_temp.row_of('UNEMPLOYMENT_HIGH|batch|P18C|2091', 'b') r) z);
insert into t select 12, 'batch finding wording',
  '50.0% of 12 respondents in P18C · Batch 2091 are not currently employed; 3 of them are looking for work.',
  (select r ->> 'body' from (select pg_temp.row_of('UNEMPLOYMENT_HIGH|batch|P18C|2091', 'b') r) z);
insert into t select 13, 'batch finding evidence',
  '{"No": 6, "Yes": 6}|{"reasons": {"No job opportunity": 3, "Did not look for a job": 3}, "seeking": 3, "not_seeking": 3, "reason_unknown": 0}|confirmed|0.24',
  (select (r -> 'evidence' -> 'breakdown')::text || '|' || (r -> 'evidence' -> 'q17')::text
     || '|' || (r -> 'evidence' ->> 'certainty') || '|' || (r -> 'evidence' ->> 'response_rate')
   from (select pg_temp.row_of('UNEMPLOYMENT_HIGH|batch|P18C|2091', 'b') r) z);
insert into t select 14, 'Watch row (7 answers)',
  'watch|Watch (small sample): 57.1% of 7 respondents in P18C · Batch 2092 are not currently employed; 0 of them are looking for work.',
  (select (r ->> 'status') || '|' || (r ->> 'body')
   from (select pg_temp.row_of('UNEMPLOYMENT_HIGH|batch|P18C|2092', 'b') r) z);
insert into t select 15, 'fewer than 5 answers: not judged, logged', '3|false',
  (select (e ->> 'valid_answers') from dry, jsonb_array_elements(dry.j -> 'suppressed') e
   where e ->> 'finding_key' = 'UNEMPLOYMENT_HIGH|batch|P18C|2093')
  || '|' || exists (select 1 from dry_rows where r ->> 'finding_key' = 'UNEMPLOYMENT_HIGH|batch|P18C|2093');
insert into t select 16, 'small batches pooled into the course',
  '0.5454545454545454|true|{"2092": 7, "2093": 3}|10|Not currently employed: P18C (all batches)',
  (select (r ->> 'metric_value') || '|' || (r -> 'evidence' ->> 'rolled_up') || '|'
     || (r -> 'evidence' -> 'small_groups')::text || '|' || (r -> 'evidence' ->> 'min_responses_required')
     || '|' || (r ->> 'title')
   from (select pg_temp.row_of('UNEMPLOYMENT_HIGH|course|P18C|All', 'b') r) z);
insert into t select 17, 'mismatch suggestions and themes',
  '3|["Internships / OJT (2)", "Industry exposure and partnerships (1)"]|["More OJT and internship", "Industry partners please", "OJT"]',
  (select (r -> 'evidence' ->> 'suggestion_count') || '|' || (r -> 'evidence' -> 'suggestion_themes')::text
     || '|' || (r -> 'evidence' -> 'suggestion_samples')::text
   from (select pg_temp.row_of('RELATEDNESS_LOW|batch|P18C|2091', 'b') r) z);
insert into t select 18, 'salary gap against other courses',
  '4|First-job salary for P18C · Batch 2091 is 4.0 bracket(s) below the median of other courses in this wave.|1|5',
  (select (r ->> 'metric_value') || '|' || (r ->> 'body') || '|' || (r -> 'evidence' ->> 'cohort_median_rank')
     || '|' || (r -> 'evidence' ->> 'peer_median_rank')
   from (select pg_temp.row_of('SALARY_STAGNATION|batch|P18C|2091', 'b') r) z);
insert into t select 19, 'data-quality row wording',
  'Low survey response rate: P18C · Batch 2091|Only 24% of alumni on the roster for P18C · Batch 2091 answered "P18 wave B" (12 of 50). Coverage is below the 40% target.|low_rate',
  (select (r ->> 'title') || '|' || (r ->> 'body') || '|' || (r -> 'evidence' ->> 'reason')
   from (select pg_temp.row_of('DATA_QUALITY_LOW|batch|P18C|2091', 'b') r) z);
insert into t select 20, 'trend across waves (course)',
  'Not employed rose from 8% (12 answers in "P18 wave A") to 55% (22 answers in "P18 wave B") for P18C (all batches): +46 pts.|00000000-0000-4000-8000-0000000e18a0|{}',
  (select (r ->> 'body') || '|' || (r -> 'evidence' ->> 'previous_survey_id') || '|'
     || (r -> 'evidence' -> 'small_groups')::text
   from (select pg_temp.row_of('UNEMPLOYMENT_TREND_UP|course|P18C|All', 'b') r) z);
insert into t select 21, 'no institution group when every course is big enough', 'false',
  exists (select 1 from dry, jsonb_array_elements(dry.j -> 'rows') e
          where e ->> 'cohort_level' = 'institution'
            and e ->> 'survey_id' = '00000000-0000-4000-8000-0000000e18b0'
            and e ->> 'rule_id' <> 'UNEMPLOYMENT_TREND_UP')::text;
insert into t select 22, 'planned sync actions',
  'supersede:newer_wave_raised|update:refreshed|suppress:closed_in_wave|update:became_watch|suppress:superseded_in_wave|supersede:newer_wave_clear',
  (select string_agg(a ->> 'action' || ':' || (a ->> 'reason'), '|' order by
     case a ->> 'finding_key'
       when 'UNEMPLOYMENT_HIGH|batch|P18C|2091' then 1
       when 'DATA_QUALITY_LOW|batch|P18C|2091' then 2
       when 'UNEMPLOYMENT_HIGH|course|P18C|All' then 3
       when 'UNEMPLOYMENT_HIGH|batch|P18C|2092' then 4
       when 'UNEMPLOYMENT_TREND_UP|batch|P18C|2091' then 5
       else 6 end)
   from dry, jsonb_array_elements(dry.j -> 'actions') a
   where a ->> 'flag_id' in ('00000000-0000-4000-8000-0000000d1801', '00000000-0000-4000-8000-0000000d1802',
                             '00000000-0000-4000-8000-0000000d1804', '00000000-0000-4000-8000-0000000d1806')
      or (a ->> 'action' = 'suppress' and a ->> 'finding_key' in
            ('UNEMPLOYMENT_HIGH|course|P18C|All', 'UNEMPLOYMENT_TREND_UP|batch|P18C|2091')
          and a ->> 'survey_id' = '00000000-0000-4000-8000-0000000e18b0'));

-- ===== 4. write run =====
create temp table run1 as select pg_temp.admin($q$select public.dss_evaluate_all('scheduled')::text$q$)::jsonb as j;
create function pg_temp.flag(p_key text, p_wave text) returns public.dss_flags language sql as $$
  select * from public.dss_flags
  where finding_key = p_key
    and survey_id = '00000000-0000-4000-8000-0000000e18' || p_wave || '0'
    and status in ('open', 'in_progress', 'watch')
  order by created_at desc
  limit 1;
$$;

insert into t select 23, 'admin runs are logged as manual', 'false|manual',
  (select (j ->> 'dry_run') || '|' || (j ->> 'trigger') from run1);
insert into t select 24, 'new finding stored with its priority', 'open|high|6|0.5',
  (select f.status || '|' || f.priority || '|' || f.priority_score || '|' || f.metric_value::text
   from pg_temp.flag('UNEMPLOYMENT_HIGH|batch|P18C|2091', 'b') f);
insert into t select 25, 'priority reasons',
  '["Rule severity: Critical", "50.0% against a threshold of 25.0%: far past", "Limited evidence: 12 valid answers", "Confirmed: the whole 95% range is past the threshold", "6 alumni affected"]',
  (select jsonb_agg(e ->> 'text')::text
   from pg_temp.flag('UNEMPLOYMENT_HIGH|batch|P18C|2091', 'b') f,
        jsonb_array_elements(f.priority_reasons) e);
insert into t select 26, 'older open flag superseded by the new one', 'superseded|true',
  (select status || '|' || (superseded_by = (select id from pg_temp.flag('UNEMPLOYMENT_HIGH|batch|P18C|2091', 'b')))
   from public.dss_flags where id = '00000000-0000-4000-8000-0000000d1801');
insert into t select 27, 'older Watch flag superseded with no newer flag', 'superseded|null',
  (select status || '|' || coalesce(superseded_by::text, 'null')
   from public.dss_flags where id = '00000000-0000-4000-8000-0000000d1806');
insert into t select 28, 'in-progress flag refreshed, never superseded', 'in_progress|0.24|12|50',
  (select status || '|' || metric_value::text || '|' || sample_n || '|' || eligible_n
   from public.dss_flags where id = '00000000-0000-4000-8000-0000000d1802');
insert into t select 29, 'resolved flag not raised again in its wave', 'resolved|1',
  (select status || '|' || (select count(*) from public.dss_flags
     where finding_key = 'UNEMPLOYMENT_HIGH|course|P18C|All'
       and survey_id = '00000000-0000-4000-8000-0000000e18b0')
   from public.dss_flags where id = '00000000-0000-4000-8000-0000000d1803');
insert into t select 30, 'open flag with too few answers moves to Watch', 'watch|watch|Moved to Watch: the latest Refresh found too few valid answers for a finding.',
  (select f.status || '|' || f.priority || '|'
     || (select note from public.dss_flag_notes where flag_id = f.id and status_to = 'watch' limit 1)
   from public.dss_flags f where f.id = '00000000-0000-4000-8000-0000000d1804');
insert into t select 31, 'superseded flag keeps its wave closed', '0',
  (select count(*)::text from public.dss_flags
   where finding_key = 'UNEMPLOYMENT_TREND_UP|batch|P18C|2091'
     and survey_id = '00000000-0000-4000-8000-0000000e18b0' and status <> 'superseded');
insert into t select 32, 'run log for the fixture',
  'raised:data_quality=1|raised:finding=6|superseded:newer_wave_clear=1|superseded:newer_wave_raised=1|suppressed:closed_in_wave=1|suppressed:not_enough_data=1|suppressed:superseded_in_wave=1|updated:became_watch=1|updated:refreshed=1',
  (select string_agg(k || '=' || c, '|' order by k)
   from (select outcome || ':' || reason as k, count(*) as c
         from public.dss_evaluation_events
         where run_id = (select (j ->> 'run_id')::uuid from run1)
           and finding_key like '%|P18C|%'
         group by 1) z);
insert into t select 33, 'run log carries the trigger and author', 'manual|true',
  (select min(run_trigger) || '|' || bool_and(created_by = '8a845be5-5870-437f-95e6-7ea3b0ad7a06'::uuid)
   from public.dss_evaluation_events where run_id = (select (j ->> 'run_id')::uuid from run1));

-- ===== 5. second run: idempotent =====
create temp table run2 as select pg_temp.admin($q$select public.dss_evaluate_all()::text$q$)::jsonb as j;
insert into t select 34, 'second run raises nothing new for the fixture', '0|0',
  (select count(*) from public.dss_evaluation_events
   where run_id = (select (j ->> 'run_id')::uuid from run2)
     and finding_key like '%|P18C|%' and outcome in ('raised', 'superseded'))
  || '|' || (select count(*) from (
       select finding_key, survey_id from public.dss_flags
       where status in ('open', 'in_progress', 'watch')
       group by 1, 2 having count(*) > 1) d);
insert into t select 35, 'second run refreshes the active fixture flags', 'updated:refreshed',
  (select string_agg(distinct outcome || ':' || reason, '|')
   from public.dss_evaluation_events
   where run_id = (select (j ->> 'run_id')::uuid from run2)
     and finding_key like '%|P18C|%' and outcome = 'updated');

-- ===== 6. priority details =====
update public.dss_flags set created_at = now() - interval '40 days'
where id = (select id from pg_temp.flag('UNEMPLOYMENT_HIGH|batch|P18C|2091', 'b'));
insert into t select 36, 'open 40 days adds a point', 'critical|7|Not started for 40 days',
  (select (p ->> 'level') || '|' || (p ->> 'score') || '|' || (p -> 'reasons' -> -1 ->> 'text')
   from (select public.dss_flag_priority(f) p
         from pg_temp.flag('UNEMPLOYMENT_HIGH|batch|P18C|2091', 'b') f) z);
insert into t select 37, 'closed flags keep no fresh priority', 'null',
  (select coalesce(priority, 'null') from public.dss_flags where id = '00000000-0000-4000-8000-0000000d1803');

-- ===== 7. newest wave: roster groups with no responses =====
insert into public.surveys (id, title, status, created_by, data, open_at, close_at, target_programs) values
  ('00000000-0000-4000-8000-0000000e18c0', 'P18 wave C', 'published',
   (select id from public.users where role = 'admin' limit 1),
   jsonb_build_object('kind', 'ched_gts_builtin', 'template_key', 'ched_gts_builtin',
                      'publishedAt', now() + interval '1 second'),
   now() - interval '1 day', now() + interval '30 days', array['P18D']);
create temp table dry_c as select pg_temp.admin($q$select public.dss_evaluate_all('manual', true)::text$q$)::jsonb as j;
insert into t select 38, 'targeted roster group with no answers gets the coverage check',
  'Weak survey coverage: P18D · Batch 2020|P18D · Batch 2020 has weak coverage for "P18 wave C": 0 of 5 on the roster answered (0%). Raise participation before trusting employment outcome flags.|both|open_wave',
  (select (e ->> 'title') || '|' || (e ->> 'body') || '|' || (e -> 'evidence' ->> 'reason')
     || '|' || (e -> 'evidence' ->> 'roster_basis')
   from dry_c, jsonb_array_elements(dry_c.j -> 'rows') e
   where e ->> 'finding_key' = 'DATA_QUALITY_LOW|batch|P18D|2020');
insert into t select 39, 'batches after the wave year and untargeted courses are skipped', '0|0',
  (select count(*) from dry_c, jsonb_array_elements(dry_c.j -> 'rows') e
   where e ->> 'finding_key' = 'DATA_QUALITY_LOW|batch|P18D|2099')
  || '|' || (select count(*) from dry_c, jsonb_array_elements(dry_c.j -> 'rows') e
   where e ->> 'survey_id' = '00000000-0000-4000-8000-0000000e18c0'
     and e ->> 'course' <> 'P18D');

-- ===== 8. scheduled run without a user =====
-- an open flag in wave B for the group wave C now checks
insert into public.dss_flags (id, rule_id, cohort_level, course, batch_year, survey_id,
  survey_title, metric_value, threshold_snapshot, sample_n, title, evidence, status)
values ('00000000-0000-4000-8000-0000000d1807', 'DATA_QUALITY_LOW', 'batch', 'P18D', '2020',
  '00000000-0000-4000-8000-0000000e18b0', 'P18 wave B', 0, 0.40, 0, 'P18 older coverage', '{}', 'open');
create temp table run3 as select public.dss_evaluate_all('scheduled') as j;
insert into t select 40, 'cron run logged as scheduled with no author', 'scheduled|true',
  (select min(run_trigger) || '|' || bool_and(created_by is null)
   from public.dss_evaluation_events where run_id = (select (j ->> 'run_id')::uuid from run3));
insert into t select 41, 'open wave roster saved for later rates', 'true',
  ((select count(*) from public.dss_wave_cohort_snapshots
    where survey_id = '00000000-0000-4000-8000-0000000e18c0') > 0)::text;
insert into t select 42, 'cron supersede note carries a system author', 'superseded|true|DSS evaluation|null',
  (select f.status || '|' || (f.superseded_by = (select id from pg_temp.flag('DATA_QUALITY_LOW|batch|P18D|2020', 'c')))
     || '|' || n.author_name || '|' || coalesce(n.author_id::text, 'null')
   from public.dss_flags f
   join public.dss_flag_notes n on n.flag_id = f.id and n.status_to = 'superseded'
   where f.id = '00000000-0000-4000-8000-0000000d1807');

select n, test, expected,
  case when actual like '%' || expected || '%' then actual else 'MISMATCH: ' || actual end as actual
from t order by n;
rollback;
