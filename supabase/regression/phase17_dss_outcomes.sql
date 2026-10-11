begin;
-- Phase 17: DSS Phase 7, intervention outcomes (dss_interventions,
-- dss_evaluate_intervention, dss_decide_intervention, the 'outcome' note
-- event). Fixture course P17C: flags on a baseline wave published in 2000,
-- interventions started yesterday, and a follow-up wave published now.
-- Batches: 2091 1/10 not employed, 2092 3/10, 2093 4/10, 2094 3/6 (Watch),
-- 2095 1/3 (too few), 2096 nobody.
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

-- Runs as the admin; returns the function result as text.
create function pg_temp.admin(p_sql text) returns text
language sql as $$
  select pg_temp.try_as('authenticated', '8a845be5-5870-437f-95e6-7ea3b0ad7a06', p_sql);
$$;

create temp table t(n int, test text, expected text, actual text);

insert into public.programs (code, name, sort_order) values ('P17C', 'P17 fixture course', 9017);

insert into public.surveys (id, title, status, created_by, data, open_at, close_at) values
  ('00000000-0000-4000-8000-0000000e17a0', 'P17 baseline wave', 'closed',
   (select id from public.users where role = 'admin' limit 1),
   jsonb_build_object('kind', 'ched_gts_builtin', 'template_key', 'ched_gts_builtin',
                      'publishedAt', '2000-01-01T00:00:00Z'), null, null),
  ('00000000-0000-4000-8000-0000000e17a1', 'P17 follow-up wave', 'closed',
   (select id from public.users where role = 'admin' limit 1),
   jsonb_build_object('kind', 'ched_gts_builtin', 'template_key', 'ched_gts_builtin',
                      'publishedAt', now()), null, null);

create function pg_temp.cohort(p_batch text, p_first int, p_n int, p_unemployed int)
returns void language plpgsql as $$
declare
  v_uid uuid;
begin
  for j in 0 .. p_n - 1 loop
    v_uid := ('00000000-0000-4000-8000-0000000e17' || lpad((p_first + j)::text, 2, '0'))::uuid;
    insert into auth.users (id, instance_id, aud, role, email, email_confirmed_at)
    values (v_uid, '00000000-0000-0000-0000-000000000000', 'authenticated',
            'authenticated', 'p17-' || (p_first + j) || '@example.invalid', now());
    insert into public.alumni_members (full_name, course, student_id, year_graduated, auth_uid)
    values ('P17 Alumnus ' || (p_first + j), 'P17C', 'P17-' || (p_first + j), p_batch, v_uid);
    insert into public.survey_responses (survey_id, user_id, answers, status, submitted_at)
    values ('00000000-0000-4000-8000-0000000e17a1', v_uid,
            jsonb_build_object('ched_16', case when j < p_unemployed then 'No' else 'Yes' end),
            'submitted', now());
  end loop;
end $$;

select pg_temp.cohort('2091', 1, 10, 1);
select pg_temp.cohort('2092', 11, 10, 3);
select pg_temp.cohort('2093', 21, 10, 4);
select pg_temp.cohort('2094', 31, 6, 3);
select pg_temp.cohort('2095', 37, 3, 1);

insert into public.dss_flags (id, rule_id, cohort_level, course, batch_year, survey_id,
  survey_title, metric_value, threshold_snapshot, sample_n, title, evidence, status, superseded_at)
values
  ('00000000-0000-4000-8000-0000000d1701', 'UNEMPLOYMENT_HIGH', 'batch', 'P17C', '2091',
   '00000000-0000-4000-8000-0000000e17a0', 'P17 baseline wave', 0.40, 0.25, 12, 'P17 2091',
   '{"evidence_strength":"limited"}', 'open', null),
  ('00000000-0000-4000-8000-0000000d1702', 'UNEMPLOYMENT_HIGH', 'batch', 'P17C', '2092',
   '00000000-0000-4000-8000-0000000e17a0', 'P17 baseline wave', 0.40, 0.25, 12, 'P17 2092',
   '{"evidence_strength":"limited"}', 'open', null),
  ('00000000-0000-4000-8000-0000000d1703', 'UNEMPLOYMENT_HIGH', 'batch', 'P17C', '2093',
   '00000000-0000-4000-8000-0000000e17a0', 'P17 baseline wave', 0.42, 0.25, 12, 'P17 2093',
   '{"evidence_strength":"limited"}', 'open', null),
  ('00000000-0000-4000-8000-0000000d1704', 'UNEMPLOYMENT_HIGH', 'batch', 'P17C', '2094',
   '00000000-0000-4000-8000-0000000e17a0', 'P17 baseline wave', 0.40, 0.25, 12, 'P17 2094',
   '{"evidence_strength":"limited"}', 'open', null),
  ('00000000-0000-4000-8000-0000000d1705', 'UNEMPLOYMENT_HIGH', 'batch', 'P17C', '2095',
   '00000000-0000-4000-8000-0000000e17a0', 'P17 baseline wave', 0.40, 0.25, 12, 'P17 2095',
   '{"evidence_strength":"limited"}', 'open', null),
  ('00000000-0000-4000-8000-0000000d1706', 'UNEMPLOYMENT_HIGH', 'batch', 'P17C', '2096',
   '00000000-0000-4000-8000-0000000e17a0', 'P17 baseline wave', 0.40, 0.25, 12, 'P17 2096',
   '{"evidence_strength":"limited"}', 'open', null),
  ('00000000-0000-4000-8000-0000000d1707', 'DATA_QUALITY_LOW', 'batch', 'P17C', '2091',
   '00000000-0000-4000-8000-0000000e17a0', 'P17 baseline wave', 0.20, 0.40, 2, 'P17 DQ',
   '{}', 'open', null),
  ('00000000-0000-4000-8000-0000000d1708', 'UNEMPLOYMENT_TREND_UP', 'course', 'P17C', 'All',
   '00000000-0000-4000-8000-0000000e17a0', 'P17 baseline wave', 0.18, 0.10, 39, 'P17 trend',
   '{"evidence_strength":"strong","previous_rate":0.12,"current_rate":0.30,"current_answered":39}', 'open', null),
  ('00000000-0000-4000-8000-0000000d1709', 'RELATEDNESS_HIGH', 'course', 'P17C', 'All',
   '00000000-0000-4000-8000-0000000e17a0', 'P17 baseline wave', 0.80, 0.75, 30, 'P17 strength',
   '{"evidence_strength":"strong"}', 'open', null),
  ('00000000-0000-4000-8000-0000000d1710', 'UNEMPLOYMENT_HIGH', 'batch', 'P17C', '2097',
   '00000000-0000-4000-8000-0000000e17a0', 'P17 baseline wave', 0.40, 0.25, 7, 'P17 watch',
   '{"evidence_strength":"watch"}', 'watch', null),
  ('00000000-0000-4000-8000-0000000d1711', 'UNEMPLOYMENT_HIGH', 'batch', 'P17C', '2098',
   '00000000-0000-4000-8000-0000000e17a0', 'P17 baseline wave', 0.40, 0.25, 12, 'P17 superseded',
   '{"evidence_strength":"limited"}', 'superseded', now()),
  ('00000000-0000-4000-8000-0000000d1712', 'SALARY_STAGNATION', 'batch', 'P17C', '2091',
   '00000000-0000-4000-8000-0000000e17a0', 'P17 baseline wave', 1.5, 1.0, 12, 'P17 salary',
   '{"evidence_strength":"limited"}', 'open', null),
  ('00000000-0000-4000-8000-0000000d1713', 'UNEMPLOYMENT_HIGH', 'batch', 'P17C', '2099',
   '00000000-0000-4000-8000-0000000e17a0', 'P17 baseline wave', 0.40, 0.25, 12, 'P17 pending',
   '{"evidence_strength":"limited"}', 'open', null);

-- Interventions started yesterday on flags 1-8 (fixture ids end in b1-b8).
insert into public.dss_interventions (id, flag_id, intervention_type, description, started_on)
select ('00000000-0000-4000-8000-0000000d17b' || k)::uuid,
       ('00000000-0000-4000-8000-0000000d170' || k)::uuid,
       'Job fair', 'P17 intervention ' || k, current_date - 1
from generate_series(1, 8) k;

create function pg_temp.i(p_k int) returns public.dss_interventions
language sql as $$
  select * from public.dss_interventions
  where id = ('00000000-0000-4000-8000-0000000d17b' || p_k)::uuid;
$$;

-- ===== 1. table, defaults and guards =====
insert into t select 1, 'table exists with RLS', 'true',
  (select relrowsecurity::text from pg_class where oid = 'public.dss_interventions'::regclass);
insert into t select 2, 'outcome rule: success test and baseline from the flag',
  'unemployment_rate|lt|0.25|0.40|12|P17 baseline wave|not_evaluated',
  (select x.success_metric || '|' || x.success_operator || '|' || x.success_target || '|'
          || x.baseline_value || '|' || x.baseline_n || '|' || x.baseline_survey_title || '|' || x.outcome_status
   from pg_temp.i(1) x);
insert into t select 3, 'data quality: response rate at least the threshold', 'response_rate|gte|0.40|0.20',
  (select x.success_metric || '|' || x.success_operator || '|' || x.success_target || '|' || x.baseline_value
   from pg_temp.i(7) x);
insert into t select 4, 'trend: back to the previous wave''s rate', 'unemployment_rate|lte|0.12|0.30|39',
  (select x.success_metric || '|' || x.success_operator || '|' || x.success_target || '|'
          || x.baseline_value || '|' || x.baseline_n
   from pg_temp.i(8) x);
insert into public.dss_interventions (id, flag_id, intervention_type)
values ('00000000-0000-4000-8000-0000000d17b9', '00000000-0000-4000-8000-0000000d1709', 'Showcase');
insert into t select 5, 'strength: stays at least the threshold', 'related_and_relevant_rate|gte|0.75',
  (select x.success_metric || '|' || x.success_operator || '|' || x.success_target from pg_temp.i(9) x);
insert into t select 6, 'recording is logged on the flag', 'outcome|recorded|Intervention recorded: Job fair (started',
  (select event_type || '|' || (metadata ->> 'action') || '|' || note from public.dss_flag_notes
   where flag_id = '00000000-0000-4000-8000-0000000d1701' and event_type = 'outcome');
insert into t select 7, 'one undecided intervention per finding', 'uq_dss_interventions_undecided_finding',
  pg_temp.try_sql($q$insert into public.dss_interventions (flag_id, intervention_type)
    values ('00000000-0000-4000-8000-0000000d1701', 'Second')$q$);
insert into t select 8, 'not on a Watch item', 'Interventions can only be recorded',
  pg_temp.try_sql($q$insert into public.dss_interventions (flag_id, intervention_type)
    values ('00000000-0000-4000-8000-0000000d1710', 'P17')$q$);
insert into t select 9, 'not on a superseded flag', 'Interventions can only be recorded',
  pg_temp.try_sql($q$insert into public.dss_interventions (flag_id, intervention_type)
    values ('00000000-0000-4000-8000-0000000d1711', 'P17')$q$);
insert into t select 10, 'start date cannot be in the future', 'cannot be in the future',
  pg_temp.try_sql($q$insert into public.dss_interventions (flag_id, intervention_type, started_on)
    values ('00000000-0000-4000-8000-0000000d1713', 'P17', current_date + 3)$q$);
insert into t select 11, 'salary target within -10..10 brackets', 'dss_interventions_target_check',
  pg_temp.try_sql($q$insert into public.dss_interventions (flag_id, intervention_type, success_target)
    values ('00000000-0000-4000-8000-0000000d1712', 'P17', 20)$q$);
insert into t select 12, 'share target within 0..1', 'dss_interventions_target_check',
  pg_temp.try_sql($q$insert into public.dss_interventions (flag_id, intervention_type, success_target)
    values ('00000000-0000-4000-8000-0000000d1713', 'P17', 1.5)$q$);
insert into t select 13, 'admin can record an intervention', 'ok',
  pg_temp.admin($q$insert into public.dss_interventions (flag_id, intervention_type, description, expected_outcome)
    values ('00000000-0000-4000-8000-0000000d1713', '  Career coaching ', 'P17 pending', 'Fewer not employed')$q$);
insert into t select 14, 'author is the caller; started today; trimmed', 'true|true|Career coaching',
  (select (created_by::text = '8a845be5-5870-437f-95e6-7ea3b0ad7a06')::text || '|'
          || (started_on = (now() at time zone 'Asia/Manila')::date)::text || '|' || intervention_type
   from public.dss_interventions where flag_id = '00000000-0000-4000-8000-0000000d1713');
insert into t select 15, 'admin cannot write outcome columns on insert', 'permission denied',
  pg_temp.admin($q$insert into public.dss_interventions (flag_id, intervention_type, outcome_status)
    values ('00000000-0000-4000-8000-0000000d1712', 'P17', 'successful')$q$);
insert into t select 16, 'admin cannot set the outcome directly', 'permission denied',
  pg_temp.admin($q$update public.dss_interventions set outcome_status = 'successful'
    where id = '00000000-0000-4000-8000-0000000d17b1'$q$);
insert into t select 17, 'admin cannot set a decision directly', 'permission denied',
  pg_temp.admin($q$update public.dss_interventions set decision = 'resolve', decision_note = 'x'
    where id = '00000000-0000-4000-8000-0000000d17b1'$q$);
insert into t select 18, 'admin cannot delete', 'permission denied',
  pg_temp.admin($q$delete from public.dss_interventions where id = '00000000-0000-4000-8000-0000000d17b1'$q$);
insert into t select 19, 'alumnus sees nothing', '0',
  pg_temp.try_as('authenticated', '6f6c569a-9ded-4c90-acab-19d78ab2a3f3',
    $q$select count(*)::text from public.dss_interventions$q$);
insert into t select 20, 'alumnus cannot record', 'row-level security',
  pg_temp.try_as('authenticated', '6f6c569a-9ded-4c90-acab-19d78ab2a3f3',
    $q$insert into public.dss_interventions (flag_id, intervention_type)
       values ('00000000-0000-4000-8000-0000000d1712', 'P17')$q$);
insert into t select 21, 'anon blocked', 'permission denied',
  pg_temp.try_as('anon', null, $q$select count(*)::text from public.dss_interventions$q$);
insert into t select 22, 'alumnus cannot evaluate', 'Admin access required',
  pg_temp.try_as('authenticated', '6f6c569a-9ded-4c90-acab-19d78ab2a3f3',
    $q$select public.dss_evaluate_intervention('00000000-0000-4000-8000-0000000d17b1')::text$q$);
insert into t select 23, 'no decision before an outcome', 'Decide after the outcome is evaluated',
  pg_temp.admin($q$select public.dss_decide_intervention('00000000-0000-4000-8000-0000000d17b1', 'resolve', 'P17')::text$q$);

-- ===== 2. evaluation =====
select pg_temp.admin(format('select public.dss_evaluate_intervention(%L)::text',
  '00000000-0000-4000-8000-0000000d17b' || k)) from generate_series(1, 8) k;
select pg_temp.admin(format('select public.dss_evaluate_intervention(%L)::text', id))
from public.dss_interventions where flag_id = '00000000-0000-4000-8000-0000000d1713';

create function pg_temp.o(p_k int) returns text language sql as $$
  select x.outcome_status || '|' || coalesce(round(x.followup_value, 4)::text, 'null') || '|'
         || coalesce(x.followup_n::text, 'null') || '|' || coalesce(x.followup_survey_title, 'null')
  from pg_temp.i(p_k) x;
$$;
insert into t select 24, 'target met: successful', 'successful|0.1000|10|P17 follow-up wave', pg_temp.o(1);
insert into t select 25, 'improved 10 points, target missed: partially successful', 'partially_successful|0.3000|10|', pg_temp.o(2);
insert into t select 26, 'improved 2 points: unsuccessful', 'unsuccessful|0.4000|10|', pg_temp.o(3);
insert into t select 27, '6 valid answers (Watch): inconclusive', 'inconclusive|0.5000|6|', pg_temp.o(4);
insert into t select 28, '3 valid answers: no comparable data, no rate', 'no_comparable_data|null|3|P17 follow-up wave', pg_temp.o(5);
insert into t select 29, 'group absent from the wave: no comparable data', 'no_comparable_data|null|null|P17 follow-up wave', pg_temp.o(6);
insert into t select 30, 'response rate 10/10: successful', 'successful|1.0000|10|', pg_temp.o(7);
insert into t select 31, 'trend: 31% vs previous 12%: unsuccessful', 'unsuccessful|0.3077|39|', pg_temp.o(8);
insert into t select 32, 'started today: pending follow-up', 'pending_followup|null|null|null|No CHED tracer wave has been published since',
  (select x.outcome_status || '|' || coalesce(x.followup_value::text, 'null') || '|'
          || coalesce(x.followup_n::text, 'null') || '|' || coalesce(x.followup_survey_title, 'null') || '|' || x.evaluation_note
   from public.dss_interventions x where x.flag_id = '00000000-0000-4000-8000-0000000d1713');
insert into t select 33, 'outcome logged with non-causal wording',
  'Outcome: Successful. P17 follow-up wave: 10% from 10 answers (target below 25%; baseline 40%). This is an observed change, not proof',
  (select note from public.dss_flag_notes
   where flag_id = '00000000-0000-4000-8000-0000000d1701' and metadata ->> 'action' = 'evaluated');
select pg_temp.admin($q$select public.dss_evaluate_intervention('00000000-0000-4000-8000-0000000d17b1')::text$q$);
insert into t select 34, 'same result again is not logged twice', '1',
  (select count(*)::text from public.dss_flag_notes
   where flag_id = '00000000-0000-4000-8000-0000000d1701' and metadata ->> 'action' = 'evaluated');
insert into t select 35, 'plan locked once the outcome is known', 'The plan cannot change after the outcome is known',
  pg_temp.admin($q$update public.dss_interventions set success_target = 0.5
    where id = '00000000-0000-4000-8000-0000000d17b1'$q$);
insert into t select 36, 'plan editable while pending', 'ok',
  pg_temp.admin($q$update public.dss_interventions set description = 'P17 pending, edited'
    where flag_id = '00000000-0000-4000-8000-0000000d1713'$q$);
update t set actual = actual || '|' || (select description from public.dss_interventions
  where flag_id = '00000000-0000-4000-8000-0000000d1713'), expected = 'ok|P17 pending, edited'
where n = 36;

-- ===== 3. decisions =====
insert into t select 37, 'decision needs a note', 'Add a note explaining the decision',
  pg_temp.admin($q$select public.dss_decide_intervention('00000000-0000-4000-8000-0000000d17b1', 'resolve', '  ')::text$q$);
insert into t select 38, 'unknown decision rejected', 'Unknown decision',
  pg_temp.admin($q$select public.dss_decide_intervention('00000000-0000-4000-8000-0000000d17b1', 'close', 'P17')::text$q$);
insert into t select 39, 'alumnus cannot decide', 'Admin access required',
  pg_temp.try_as('authenticated', '6f6c569a-9ded-4c90-acab-19d78ab2a3f3',
    $q$select public.dss_decide_intervention('00000000-0000-4000-8000-0000000d17b1', 'resolve', 'P17')::text$q$);
select pg_temp.admin($q$select public.dss_decide_intervention('00000000-0000-4000-8000-0000000d17b1', 'resolve', ' Target met. ')::text$q$);
insert into t select 40, 'resolve: decision saved, flag resolved', 'resolve|Target met.|true|resolved',
  (select x.decision || '|' || x.decision_note || '|'
          || (x.decided_by::text = '8a845be5-5870-437f-95e6-7ea3b0ad7a06')::text || '|'
          || (select status from public.dss_flags where id = '00000000-0000-4000-8000-0000000d1701')
   from pg_temp.i(1) x);
insert into t select 41, 'a decided intervention is final', 'A decided intervention is final',
  pg_temp.admin($q$update public.dss_interventions set description = 'late edit'
    where id = '00000000-0000-4000-8000-0000000d17b1'$q$);
insert into t select 42, 'only one decision', 'already recorded',
  pg_temp.admin($q$select public.dss_decide_intervention('00000000-0000-4000-8000-0000000d17b1', 'continue', 'P17')::text$q$);

select pg_temp.admin($q$select public.dss_decide_intervention('00000000-0000-4000-8000-0000000d17b2', 'continue', 'Keep going.')::text$q$);
insert into t select 43, 'continue: new intervention from the follow-up baseline',
  'Job fair|P17 intervention 2|0.25|P17 follow-up wave|0.3|10|not_evaluated|true|open',
  (select x.intervention_type || '|' || x.description || '|' || x.success_target || '|'
          || x.baseline_survey_title || '|' || x.baseline_value || '|' || x.baseline_n || '|'
          || x.outcome_status || '|' || (x.started_on = (now() at time zone 'Asia/Manila')::date)::text || '|'
          || (select status from public.dss_flags where id = x.flag_id)
   from public.dss_interventions x where x.continues_id = '00000000-0000-4000-8000-0000000d17b2');
insert into t select 44, 'continued intervention waits for a later wave', 'pending_followup',
  (select pg_temp.admin(format('select public.dss_evaluate_intervention(%L)::jsonb ->> %L', x.id, 'outcome_status'))
   from public.dss_interventions x where x.continues_id = '00000000-0000-4000-8000-0000000d17b2');

select pg_temp.admin($q$select public.dss_decide_intervention('00000000-0000-4000-8000-0000000d17b3', 'modify',
  'Switch to mentoring.', null, 'Mentoring', 'Pair alumni with mentors', 'Half the gap closed', 0.30)::text$q$);
insert into t select 45, 'modify: new plan and target', 'Mentoring|Pair alumni with mentors|Half the gap closed|0.30|0.4',
  (select x.intervention_type || '|' || x.description || '|' || x.expected_outcome || '|'
          || x.success_target || '|' || x.baseline_value
   from public.dss_interventions x where x.continues_id = '00000000-0000-4000-8000-0000000d17b3');

select pg_temp.admin($q$select public.dss_decide_intervention('00000000-0000-4000-8000-0000000d17b4', 'escalate',
  'Needs the VP.', ' Office of the VP ')::text$q$);
insert into t select 46, 'escalate: office set on the flag, no new intervention', 'escalate|Office of the VP|Office of the VP|0',
  (select x.decision || '|' || x.escalated_to || '|'
          || (select owner_office from public.dss_flags where id = x.flag_id) || '|'
          || (select count(*) from public.dss_interventions y where y.continues_id = x.id)
   from pg_temp.i(4) x);
insert into t select 47, 'office ignored for other decisions', 'null',
  (select coalesce(escalated_to, 'null') from pg_temp.i(2));

select pg_temp.admin($q$select public.dss_update_flag_status('00000000-0000-4000-8000-0000000d1705', 'resolved', 'P17 closed')::text$q$);
select pg_temp.admin($q$select public.dss_decide_intervention('00000000-0000-4000-8000-0000000d17b5', 'continue', 'Try again.')::text$q$);
insert into t select 48, 'continue on a resolved flag reopens it', 'in_progress|1',
  (select status from public.dss_flags where id = '00000000-0000-4000-8000-0000000d1705')
  || '|' || (select count(*) from public.dss_interventions where continues_id = '00000000-0000-4000-8000-0000000d17b5');
insert into t select 49, 'decisions logged on the flag', 'Decision: Escalate to Office of the VP. Needs the VP.',
  (select note from public.dss_flag_notes
   where flag_id = '00000000-0000-4000-8000-0000000d1704' and metadata ->> 'action' = 'decided');

-- ===== 4. open follow-up wave: preview only =====
update public.surveys set status = 'published', close_at = now() + interval '7 days'
where id = '00000000-0000-4000-8000-0000000e17a1';
insert into t select 50, 'open wave: preview returned, not stored', 'pending_followup|successful|true|pending_followup|null|P17 follow-up wave',
  (select r ->> 'outcome_status' || '|' || (r ->> 'preview_status') || '|' || (r ->> 'provisional')
   from (select pg_temp.admin($q$select public.dss_evaluate_intervention('00000000-0000-4000-8000-0000000d17b7')::text$q$)::jsonb r) z)
  || '|' || (select x.outcome_status || '|' || coalesce(x.followup_value::text, 'null') || '|' || x.followup_survey_title
             from pg_temp.i(7) x);

-- ===== 5. note events and cascade =====
insert into t select 51, 'unknown note event type rejected', 'dss_flag_notes_event_type_check',
  pg_temp.try_sql($q$insert into public.dss_flag_notes (flag_id, note, event_type)
    values ('00000000-0000-4000-8000-0000000d1701', 'P17 bogus', 'bogus')$q$);
insert into t select 52, 'evidence events still accepted', 'ok',
  pg_temp.try_sql($q$insert into public.dss_flag_notes (flag_id, note, event_type)
    values ('00000000-0000-4000-8000-0000000d1701', 'P17 evidence', 'evidence')$q$);
delete from public.dss_flags where id = '00000000-0000-4000-8000-0000000d1706';
insert into t select 53, 'deleting a flag removes its interventions', '0',
  (select count(*)::text from public.dss_interventions
   where flag_id = '00000000-0000-4000-8000-0000000d1706');

select n, test, expected,
  case when actual like '%' || expected || '%' then actual else 'MISMATCH: ' || actual end as actual
from t order by n;
rollback;
