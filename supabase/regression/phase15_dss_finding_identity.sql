begin;
-- Phase 15: DSS Phase 4, finding identity across waves (finding_key,
-- Watch and Superseded statuses, status guard, dss_update_flag_status,
-- active-flag index, nightly re-check, dss_evaluation_events). Fixture
-- flags sit in course P15C, batch 2099, so real flags never change the
-- results.
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

-- ----- Fixture flags. S0 = older wave, S1 = newer wave.
-- 1501 Watch (S1) · 1502 open (S0) · 1503 in progress (S0)
-- 1504 resolved (S0) · 1505 open (S1)
insert into public.dss_flags (id, rule_id, cohort_level, course, batch_year, survey_id,
  survey_title, metric_value, threshold_snapshot, sample_n, title, evidence, status, resolved_at)
values
  ('00000000-0000-4000-8000-0000000d1501', 'UNEMPLOYMENT_HIGH', 'batch', 'P15C', '2099',
   '00000000-0000-4000-8000-0000000d15a1', 'P15 S1', 0.5, 0.25, 7, 'P15 watch',
   '{"evidence_strength":"watch","valid_answers":7}', 'watch', null),
  ('00000000-0000-4000-8000-0000000d1502', 'UNEMPLOYMENT_HIGH', 'batch', 'P15C', '2099',
   '00000000-0000-4000-8000-0000000d15a0', 'P15 S0', 0.5, 0.25, 12, 'P15 old open',
   '{"evidence_strength":"limited","valid_answers":12}', 'open', null),
  ('00000000-0000-4000-8000-0000000d1503', 'RELATEDNESS_LOW', 'batch', 'P15C', '2099',
   '00000000-0000-4000-8000-0000000d15a0', 'P15 S0', 0.5, 0.4, 12, 'P15 old in progress',
   '{"evidence_strength":"limited","valid_answers":12}', 'in_progress', null),
  ('00000000-0000-4000-8000-0000000d1504', 'UNDEREMPLOYMENT', 'batch', 'P15C', '2099',
   '00000000-0000-4000-8000-0000000d15a0', 'P15 S0', 0.5, 0.35, 12, 'P15 old resolved',
   '{"evidence_strength":"limited","valid_answers":12}', 'resolved', now()),
  ('00000000-0000-4000-8000-0000000d1505', 'TIME_TO_JOB_LONG', 'batch', 'P15C', '2099',
   '00000000-0000-4000-8000-0000000d15a1', 'P15 S1', 0.5, 0.4, 12, 'P15 open',
   '{"evidence_strength":"limited","valid_answers":12}', 'open', null);

-- ===== 1. schema =====
insert into t select 1, 'finding_key is rule|level|course|batch', 'UNEMPLOYMENT_HIGH|batch|P15C|2099',
  (select finding_key from public.dss_flags where id = '00000000-0000-4000-8000-0000000d1501');
insert into t select 2, 'finding_key index exists', '1',
  (select count(*)::text from pg_indexes
   where schemaname = 'public' and indexname = 'idx_dss_flags_finding_key');
insert into t select 3, 'exactly one status check (old one replaced)', '1',
  (select count(*)::text from pg_constraint
   where conrelid = 'public.dss_flags'::regclass and contype = 'c'
     and pg_get_constraintdef(oid) ~ 'in_progress');
insert into t select 4, 'unknown status rejected', 'dss_flags_status_check',
  pg_temp.try_sql($q$update public.dss_flags set status = 'bogus' where id = '00000000-0000-4000-8000-0000000d1505'$q$);
insert into t select 5, 'superseded needs superseded_at', 'dss_flags_superseded_check',
  pg_temp.try_sql($q$update public.dss_flags set status = 'superseded' where id = '00000000-0000-4000-8000-0000000d1502'$q$);
insert into t select 6, 'active-flag index includes watch', 'watch',
  (select indexdef from pg_indexes
   where schemaname = 'public' and indexname = 'uq_dss_flags_active_cohort');

-- ===== 2. status guard =====
insert into t select 7, 'open flag can be superseded', 'ok',
  pg_temp.try_sql($q$update public.dss_flags set status = 'superseded', superseded_at = now(),
    superseded_by = '00000000-0000-4000-8000-0000000d1501'
    where id = '00000000-0000-4000-8000-0000000d1502'$q$);
insert into t select 8, 'superseded is final', 'A superseded flag is final',
  pg_temp.try_sql($q$update public.dss_flags set status = 'open', superseded_at = null
    where id = '00000000-0000-4000-8000-0000000d1502'$q$);
insert into t select 9, 'in-progress flag cannot be superseded', 'Only open or Watch flags can be superseded',
  pg_temp.try_sql($q$update public.dss_flags set status = 'superseded', superseded_at = now()
    where id = '00000000-0000-4000-8000-0000000d1503'$q$);
insert into t select 10, 'resolved flag cannot go to Watch', 'Only open or dismissed flags can go back to Watch',
  pg_temp.try_sql($q$update public.dss_flags set status = 'watch' where id = '00000000-0000-4000-8000-0000000d1504'$q$);
insert into t select 11, 'in-progress flag cannot go to Watch', 'Only open or dismissed flags can go back to Watch',
  pg_temp.try_sql($q$update public.dss_flags set status = 'watch' where id = '00000000-0000-4000-8000-0000000d1503'$q$);
insert into t select 12, 'Watch cannot jump to in progress', 'A Watch item can only become a finding',
  pg_temp.try_sql($q$update public.dss_flags set status = 'in_progress' where id = '00000000-0000-4000-8000-0000000d1501'$q$);
insert into t select 13, 'closed to closed still blocked', 'Reopen this flag before marking it dismissed',
  pg_temp.try_sql($q$update public.dss_flags set status = 'dismissed' where id = '00000000-0000-4000-8000-0000000d1504'$q$);
insert into t select 14, 'one active flag per finding and wave (Watch counts)', 'uq_dss_flags_active_cohort',
  pg_temp.try_sql($q$insert into public.dss_flags (rule_id, cohort_level, course, batch_year, survey_id,
    metric_value, threshold_snapshot, title, status)
    values ('UNEMPLOYMENT_HIGH', 'batch', 'P15C', '2099', '00000000-0000-4000-8000-0000000d15a1',
            0.5, 0.25, 'P15 duplicate', 'open')$q$);

-- ===== 3. dss_update_flag_status =====
insert into t select 15, 'RPC: Watch item cannot be started', 'A Watch item can only be dismissed',
  pg_temp.try_as('authenticated', '8a845be5-5870-437f-95e6-7ea3b0ad7a06',
    $q$select 'done' from public.dss_update_flag_status('00000000-0000-4000-8000-0000000d1501', 'in_progress')$q$);
insert into t select 16, 'RPC: note on a Watch item keeps it on Watch', 'ok',
  case when pg_temp.try_as('authenticated', '8a845be5-5870-437f-95e6-7ea3b0ad7a06',
    $q$select 'done' from public.dss_update_flag_status('00000000-0000-4000-8000-0000000d1501', 'watch', 'P15 note only')$q$)
    like 'ERROR%' then 'failed' else 'ok' end;
insert into t select 17, 'RPC: note logged, status unchanged', 'watch|watch|status|P15 note only',
  (select f.status || '|' || n.status_to || '|' || n.event_type || '|' || n.note
   from public.dss_flags f join public.dss_flag_notes n on n.flag_id = f.id
   where f.id = '00000000-0000-4000-8000-0000000d1501' and n.note = 'P15 note only');
insert into t select 18, 'RPC: admins cannot set Watch', 'set by Refresh insights',
  pg_temp.try_as('authenticated', '8a845be5-5870-437f-95e6-7ea3b0ad7a06',
    $q$select 'done' from public.dss_update_flag_status('00000000-0000-4000-8000-0000000d1505', 'watch')$q$);
insert into t select 19, 'RPC: admins cannot set Superseded', 'set by Refresh insights',
  pg_temp.try_as('authenticated', '8a845be5-5870-437f-95e6-7ea3b0ad7a06',
    $q$select 'done' from public.dss_update_flag_status('00000000-0000-4000-8000-0000000d1505', 'superseded')$q$);
insert into t select 20, 'RPC: superseded flag cannot change', 'superseded by a newer wave',
  pg_temp.try_as('authenticated', '8a845be5-5870-437f-95e6-7ea3b0ad7a06',
    $q$select 'done' from public.dss_update_flag_status('00000000-0000-4000-8000-0000000d1502', 'dismissed')$q$);
insert into t select 21, 'RPC: alumnus blocked', 'Admin access required',
  pg_temp.try_as('authenticated', '6f6c569a-9ded-4c90-acab-19d78ab2a3f3',
    $q$select 'done' from public.dss_update_flag_status('00000000-0000-4000-8000-0000000d1505', 'dismissed')$q$);
-- A statement does not see its own function's writes: call, then read back.
create temp table rpc(n int, res text);
insert into rpc select 22, pg_temp.try_as('authenticated', '8a845be5-5870-437f-95e6-7ea3b0ad7a06',
  $q$select 'done' from public.dss_update_flag_status('00000000-0000-4000-8000-0000000d1501', 'dismissed')$q$);
insert into t select 22, 'RPC: Watch item can be dismissed', 'done|dismissed|true',
  (select r.res || '|' || f.status || '|' || (f.resolved_at is not null)::text
   from rpc r, public.dss_flags f
   where r.n = 22 and f.id = '00000000-0000-4000-8000-0000000d1501');
insert into rpc select 23, pg_temp.try_as('authenticated', '8a845be5-5870-437f-95e6-7ea3b0ad7a06',
  $q$select 'done' from public.dss_update_flag_status('00000000-0000-4000-8000-0000000d1501', 'open', '', null, null, null, null, null, null, true)$q$);
insert into t select 23, 'RPC: reopening a dismissed Watch item returns it to Watch', 'done|watch|false|reopen|Watch',
  coalesce((select r.res || '|' || f.status || '|' || (f.resolved_at is not null)::text
                   || '|' || n.event_type || '|' || split_part(n.note, ' ', 4)
            from rpc r
            join public.dss_flags f on f.id = '00000000-0000-4000-8000-0000000d1501'
            join public.dss_flag_notes n on n.flag_id = f.id and n.event_type = 'reopen'
            where r.n = 23),
           (select res from rpc where n = 23));
insert into rpc select 24, pg_temp.try_as('authenticated', '8a845be5-5870-437f-95e6-7ea3b0ad7a06',
  $q$select 'done' from public.dss_update_flag_status('00000000-0000-4000-8000-0000000d1505', 'in_progress')$q$);
insert into t select 24, 'RPC: open flag still moves to in progress', 'done|in_progress',
  (select r.res || '|' || f.status from rpc r, public.dss_flags f
   where r.n = 24 and f.id = '00000000-0000-4000-8000-0000000d1505');

-- ===== 4. nightly re-check =====
select public.dss_recheck_open_flags();
insert into t select 25, 're-check covers Watch items', '1',
  (select count(*)::text from public.dss_flag_checks
   where flag_id = '00000000-0000-4000-8000-0000000d1501');
insert into t select 26, 're-check skips superseded flags', '0',
  (select count(*)::text from public.dss_flag_checks
   where flag_id = '00000000-0000-4000-8000-0000000d1502');

-- ===== 5. dss_evaluation_events =====
insert into t select 27, 'events: admin can log', 'ok',
  pg_temp.try_as('authenticated', '8a845be5-5870-437f-95e6-7ea3b0ad7a06',
    $q$insert into public.dss_evaluation_events (run_id, finding_key, survey_id, flag_id, outcome, reason, valid_answers)
       values ('00000000-0000-4000-8000-0000000d15e1', 'TIME_TO_JOB_LONG|batch|P15C|2099',
               '00000000-0000-4000-8000-0000000d15a1', '00000000-0000-4000-8000-0000000d1505',
               'raised', 'finding', 12)$q$);
insert into t select 28, 'events: created_by is the caller, trigger defaults to manual', 'true|manual',
  (select (created_by::text = '8a845be5-5870-437f-95e6-7ea3b0ad7a06')::text || '|' || run_trigger
   from public.dss_evaluation_events where run_id = '00000000-0000-4000-8000-0000000d15e1');
insert into t select 29, 'events: admin cannot log as someone else', 'row-level security',
  pg_temp.try_as('authenticated', '8a845be5-5870-437f-95e6-7ea3b0ad7a06',
    $q$insert into public.dss_evaluation_events (run_id, finding_key, survey_id, outcome, reason, created_by)
       values ('00000000-0000-4000-8000-0000000d15e2', 'k', 's', 'suppressed', 'not_enough_data',
               '6f6c569a-9ded-4c90-acab-19d78ab2a3f3'::uuid)$q$);
insert into t select 30, 'events: unknown reason rejected', 'dss_evaluation_events_reason_check',
  pg_temp.try_as('authenticated', '8a845be5-5870-437f-95e6-7ea3b0ad7a06',
    $q$insert into public.dss_evaluation_events (run_id, finding_key, survey_id, outcome, reason)
       values ('00000000-0000-4000-8000-0000000d15e2', 'k', 's', 'suppressed', 'because')$q$);
insert into t select 31, 'events: admin cannot edit the log', 'permission denied',
  pg_temp.try_as('authenticated', '8a845be5-5870-437f-95e6-7ea3b0ad7a06',
    $q$update public.dss_evaluation_events set reason = 'watch' where run_id = '00000000-0000-4000-8000-0000000d15e1'$q$);
insert into t select 32, 'events: alumnus cannot log', 'row-level security',
  pg_temp.try_as('authenticated', '6f6c569a-9ded-4c90-acab-19d78ab2a3f3',
    $q$insert into public.dss_evaluation_events (run_id, finding_key, survey_id, outcome, reason)
       values ('00000000-0000-4000-8000-0000000d15e3', 'k', 's', 'suppressed', 'not_enough_data')$q$);
insert into t select 33, 'events: alumnus sees nothing', '0',
  pg_temp.try_as('authenticated', '6f6c569a-9ded-4c90-acab-19d78ab2a3f3',
    $q$select count(*)::text from public.dss_evaluation_events$q$);
insert into t select 34, 'events: anon blocked', 'permission denied',
  pg_temp.try_as('anon', null, $q$select count(*)::text from public.dss_evaluation_events$q$);

-- ===== 6. deletes never cascade into history =====
delete from public.dss_flags where id = '00000000-0000-4000-8000-0000000d1505';
insert into t select 35, 'deleting a flag keeps its log rows', '1|true',
  (select count(*)::text || '|' || bool_and(flag_id is null)::text
   from public.dss_evaluation_events where run_id = '00000000-0000-4000-8000-0000000d15e1');
delete from public.dss_flags where id = '00000000-0000-4000-8000-0000000d1501';
insert into t select 36, 'deleting the newer flag keeps the superseded one', 'superseded|true',
  (select status || '|' || (superseded_by is null)::text from public.dss_flags
   where id = '00000000-0000-4000-8000-0000000d1502');

select n, test, expected,
  case when actual like '%' || expected || '%' then actual else 'MISMATCH: ' || actual end as actual
from t order by n;
rollback;
