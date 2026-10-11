begin;
-- Phase 16: DSS Phase 6, accountability (owner office, responsible person,
-- start / due / review dates, dss_flag_evidence with soft removal, the
-- 'evidence' note event, cause-specific playbooks). Fixture flags sit in
-- course P16C, batch 2099, so real flags never change the results.
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

-- ----- Fixture flags: 1601 open, 1602 superseded (older wave).
insert into public.dss_flags (id, rule_id, cohort_level, course, batch_year, survey_id,
  survey_title, metric_value, threshold_snapshot, sample_n, title, evidence, status,
  superseded_at, owner_office)
values
  ('00000000-0000-4000-8000-0000000d1601', 'UNEMPLOYMENT_HIGH', 'batch', 'P16C', '2099',
   '00000000-0000-4000-8000-0000000d16a1', 'P16 S1', 0.5, 0.25, 12, 'P16 open',
   '{"evidence_strength":"limited","valid_answers":12}', 'open', null, '   '),
  ('00000000-0000-4000-8000-0000000d1602', 'UNEMPLOYMENT_HIGH', 'batch', 'P16C', '2099',
   '00000000-0000-4000-8000-0000000d16a0', 'P16 S0', 0.5, 0.25, 12, 'P16 superseded',
   '{"evidence_strength":"limited","valid_answers":12}', 'superseded', now(), 'Registrar''s Office');

-- ===== 1. owner and dates =====
insert into t select 1, 'five accountability columns exist', '5',
  (select count(*)::text from information_schema.columns
   where table_schema = 'public' and table_name = 'dss_flags'
     and column_name in ('owner_office', 'responsible_name', 'start_date', 'due_date', 'review_date'));
insert into t select 2, 'blank office stored as null', 'null',
  (select coalesce(owner_office, 'null') from public.dss_flags
   where id = '00000000-0000-4000-8000-0000000d1601');
update public.dss_flags
set owner_office = '  Alumni Affairs Office ', responsible_name = ' Dr. P16 Chair '
where id = '00000000-0000-4000-8000-0000000d1601';
insert into t select 3, 'office and person trimmed', 'Alumni Affairs Office|Dr. P16 Chair',
  (select owner_office || '|' || responsible_name from public.dss_flags
   where id = '00000000-0000-4000-8000-0000000d1601');
insert into t select 4, 'office longer than 120 characters rejected', 'dss_flags_owner_office_check',
  pg_temp.try_sql($q$update public.dss_flags set owner_office = repeat('x', 121)
    where id = '00000000-0000-4000-8000-0000000d1601'$q$);
insert into t select 5, 'due date before start rejected', 'dss_flags_plan_dates_check',
  pg_temp.try_sql($q$update public.dss_flags set start_date = '2026-03-10', due_date = '2026-03-09'
    where id = '00000000-0000-4000-8000-0000000d1601'$q$);
insert into t select 6, 'review date before start rejected', 'dss_flags_plan_dates_check',
  pg_temp.try_sql($q$update public.dss_flags set start_date = '2026-03-10', review_date = '2026-03-01'
    where id = '00000000-0000-4000-8000-0000000d1601'$q$);
insert into t select 7, 'admin can set the plan dates', 'ok',
  pg_temp.try_as('authenticated', '8a845be5-5870-437f-95e6-7ea3b0ad7a06',
    $q$update public.dss_flags set start_date = '2026-03-10', due_date = '2026-04-30',
       review_date = '2026-04-01' where id = '00000000-0000-4000-8000-0000000d1601'$q$);
insert into t select 8, 'plan dates saved', '2026-03-10|2026-04-30|2026-04-01',
  (select start_date || '|' || due_date || '|' || review_date from public.dss_flags
   where id = '00000000-0000-4000-8000-0000000d1601');
insert into t select 9, 'superseded flag keeps its office', 'A superseded flag is final',
  pg_temp.try_sql($q$update public.dss_flags set owner_office = 'Guidance Office'
    where id = '00000000-0000-4000-8000-0000000d1602'$q$);
insert into t select 10, 'superseded flag keeps its owner account', 'A superseded flag is final',
  pg_temp.try_sql($q$update public.dss_flags set assigned_to = (select id from auth.users limit 1)
    where id = '00000000-0000-4000-8000-0000000d1602'$q$);
insert into t select 11, 'superseded flag: other columns still update', 'ok',
  pg_temp.try_sql($q$update public.dss_flags set title = 'P16 superseded (renamed)'
    where id = '00000000-0000-4000-8000-0000000d1602'$q$);
insert into t select 12, 'alumnus cannot set the office', '0',
  (select case when pg_temp.try_as('authenticated', '6f6c569a-9ded-4c90-acab-19d78ab2a3f3',
     $q$update public.dss_flags set owner_office = 'P16 hijack'
        where id = '00000000-0000-4000-8000-0000000d1601'$q$) like 'ERROR%' then '0'
   else (select count(*)::text from public.dss_flags where owner_office = 'P16 hijack') end);

-- ===== 2. evidence =====
insert into t select 13, 'admin can add evidence', 'ok',
  pg_temp.try_as('authenticated', '8a845be5-5870-437f-95e6-7ea3b0ad7a06',
    $q$insert into public.dss_flag_evidence (id, flag_id, evidence_type, title, evidence_date,
         description, link, created_by, created_by_name)
       values ('00000000-0000-4000-8000-0000000d16e1', '00000000-0000-4000-8000-0000000d1601',
               'meeting', '  P16 meeting  ', current_date - 1, 'Met the program chair.',
               'https://example.org/minutes', '6f6c569a-9ded-4c90-acab-19d78ab2a3f3'::uuid, 'Someone else')$q$);
insert into t select 14, 'author is the caller, not what the app sent', 'true|false|P16 meeting',
  (select (created_by::text = '8a845be5-5870-437f-95e6-7ea3b0ad7a06')::text || '|'
          || (created_by_name = 'Someone else')::text || '|' || title
   from public.dss_flag_evidence where id = '00000000-0000-4000-8000-0000000d16e1');
insert into t select 15, 'adding evidence is logged on the flag', 'evidence|added|Evidence added: Meeting / consultation, "P16 meeting"',
  (select event_type || '|' || (metadata ->> 'action') || '|' || note from public.dss_flag_notes
   where flag_id = '00000000-0000-4000-8000-0000000d1601' and event_type = 'evidence');
insert into t select 16, 'future evidence date rejected', 'cannot be in the future',
  pg_temp.try_as('authenticated', '8a845be5-5870-437f-95e6-7ea3b0ad7a06',
    $q$insert into public.dss_flag_evidence (flag_id, evidence_type, title, evidence_date)
       values ('00000000-0000-4000-8000-0000000d1601', 'event', 'P16 future', current_date + 2)$q$);
insert into t select 17, 'non-web link rejected', 'dss_flag_evidence_link_check',
  pg_temp.try_as('authenticated', '8a845be5-5870-437f-95e6-7ea3b0ad7a06',
    $q$insert into public.dss_flag_evidence (flag_id, evidence_type, title, evidence_date, link)
       values ('00000000-0000-4000-8000-0000000d1601', 'document', 'P16 link', current_date, 'javascript:alert(1)')$q$);
insert into t select 18, 'blank title rejected', 'dss_flag_evidence_title_check',
  pg_temp.try_as('authenticated', '8a845be5-5870-437f-95e6-7ea3b0ad7a06',
    $q$insert into public.dss_flag_evidence (flag_id, evidence_type, title, evidence_date)
       values ('00000000-0000-4000-8000-0000000d1601', 'document', '   ', current_date)$q$);
insert into t select 19, 'unknown evidence type rejected', 'dss_flag_evidence_evidence_type_check',
  pg_temp.try_as('authenticated', '8a845be5-5870-437f-95e6-7ea3b0ad7a06',
    $q$insert into public.dss_flag_evidence (flag_id, evidence_type, title, evidence_date)
       values ('00000000-0000-4000-8000-0000000d1601', 'photo', 'P16 photo', current_date)$q$);
insert into t select 20, 'no evidence on a superseded flag', 'Add evidence to the newer flag',
  pg_temp.try_as('authenticated', '8a845be5-5870-437f-95e6-7ea3b0ad7a06',
    $q$insert into public.dss_flag_evidence (flag_id, evidence_type, title, evidence_date)
       values ('00000000-0000-4000-8000-0000000d1602', 'report', 'P16 late', current_date)$q$);
insert into t select 21, 'admin cannot edit an entry', 'permission denied',
  pg_temp.try_as('authenticated', '8a845be5-5870-437f-95e6-7ea3b0ad7a06',
    $q$update public.dss_flag_evidence set title = 'P16 edited'
       where id = '00000000-0000-4000-8000-0000000d16e1'$q$);
insert into t select 22, 'admin cannot set who removed it', 'permission denied',
  pg_temp.try_as('authenticated', '8a845be5-5870-437f-95e6-7ea3b0ad7a06',
    $q$update public.dss_flag_evidence set removed_at = now(),
       removed_by = '6f6c569a-9ded-4c90-acab-19d78ab2a3f3'::uuid
       where id = '00000000-0000-4000-8000-0000000d16e1'$q$);
insert into t select 23, 'admin cannot delete an entry', 'permission denied',
  pg_temp.try_as('authenticated', '8a845be5-5870-437f-95e6-7ea3b0ad7a06',
    $q$delete from public.dss_flag_evidence where id = '00000000-0000-4000-8000-0000000d16e1'$q$);
insert into t select 24, 'alumnus cannot add evidence', 'row-level security',
  pg_temp.try_as('authenticated', '6f6c569a-9ded-4c90-acab-19d78ab2a3f3',
    $q$insert into public.dss_flag_evidence (flag_id, evidence_type, title, evidence_date)
       values ('00000000-0000-4000-8000-0000000d1601', 'other', 'P16 alumnus', current_date)$q$);
insert into t select 25, 'alumnus sees no evidence', '0',
  pg_temp.try_as('authenticated', '6f6c569a-9ded-4c90-acab-19d78ab2a3f3',
    $q$select count(*)::text from public.dss_flag_evidence$q$);
insert into t select 26, 'anon blocked', 'permission denied',
  pg_temp.try_as('anon', null, $q$select count(*)::text from public.dss_flag_evidence$q$);
insert into t select 27, 'alumnus cannot remove evidence', 'null',
  (select case when pg_temp.try_as('authenticated', '6f6c569a-9ded-4c90-acab-19d78ab2a3f3',
     $q$update public.dss_flag_evidence set removed_at = now()
        where id = '00000000-0000-4000-8000-0000000d16e1'$q$) like 'ERROR%' then 'null'
   else (select coalesce(removed_at::text, 'null') from public.dss_flag_evidence
         where id = '00000000-0000-4000-8000-0000000d16e1') end);

-- ===== 3. soft removal =====
insert into t select 28, 'admin can remove an entry', 'ok',
  pg_temp.try_as('authenticated', '8a845be5-5870-437f-95e6-7ea3b0ad7a06',
    $q$update public.dss_flag_evidence set removed_at = '2000-01-01'
       where id = '00000000-0000-4000-8000-0000000d16e1'$q$);
insert into t select 29, 'removal keeps the row, stamps caller and time', 'true|true|P16 meeting',
  (select (removed_by::text = '8a845be5-5870-437f-95e6-7ea3b0ad7a06')::text || '|'
          || (removed_at > now() - interval '1 hour')::text || '|' || title
   from public.dss_flag_evidence where id = '00000000-0000-4000-8000-0000000d16e1');
insert into t select 30, 'removal is logged on the flag', 'removed|Evidence removed: Meeting / consultation',
  (select (metadata ->> 'action') || '|' || note from public.dss_flag_notes
   where flag_id = '00000000-0000-4000-8000-0000000d1601' and event_type = 'evidence'
     and metadata ->> 'action' = 'removed');
insert into t select 31, 'cannot remove twice or restore', 'already removed',
  pg_temp.try_as('authenticated', '8a845be5-5870-437f-95e6-7ea3b0ad7a06',
    $q$update public.dss_flag_evidence set removed_at = null
       where id = '00000000-0000-4000-8000-0000000d16e1'$q$);

-- ===== 4. note event types =====
insert into t select 32, 'unknown note event type rejected', 'dss_flag_notes_event_type_check',
  pg_temp.try_sql($q$insert into public.dss_flag_notes (flag_id, note, event_type)
    values ('00000000-0000-4000-8000-0000000d1601', 'P16 bogus', 'bogus')$q$);
insert into t select 33, 'existing event types still accepted', 'ok',
  pg_temp.try_sql($q$insert into public.dss_flag_notes (flag_id, note, event_type)
    values ('00000000-0000-4000-8000-0000000d1601', 'P16 action', 'action')$q$);

-- ===== 5. playbooks =====
insert into t select 34, 'data quality steps per cause', 'both:3,default:3,low_rate:3,sparse:3',
  (select string_agg(c || ':' || n, ',' order by c) from (
     select s ->> 'cause' c, count(*) n
     from public.dss_rules, jsonb_array_elements(playbook) s
     where rule_id = 'DATA_QUALITY_LOW' group by 1) x);
insert into t select 35, 'not employed steps per cause', 'always:2,default:3,not_seeking:3,seeking:2',
  (select string_agg(c || ':' || n, ',' order by c) from (
     select coalesce(s ->> 'cause', 'always') c, count(*) n
     from public.dss_rules, jsonb_array_elements(playbook) s
     where rule_id = 'UNEMPLOYMENT_HIGH' group by 1) x);
insert into t select 36, 'looking for work steps per cause', 'always:2,default:2,lack_experience:2,no_opportunity:2',
  (select string_agg(c || ':' || n, ',' order by c) from (
     select coalesce(s ->> 'cause', 'always') c, count(*) n
     from public.dss_rules, jsonb_array_elements(playbook) s
     where rule_id = 'SEEKING_WORK_HIGH' group by 1) x);
insert into t select 37, 'other rules keep untagged playbooks', '0',
  (select count(*)::text from public.dss_rules, jsonb_array_elements(playbook) s
   where rule_id not in ('DATA_QUALITY_LOW', 'UNEMPLOYMENT_HIGH', 'SEEKING_WORK_HIGH')
     and s ? 'cause');

-- ===== 6. deleting a flag =====
delete from public.dss_flags where id = '00000000-0000-4000-8000-0000000d1601';
insert into t select 38, 'deleting a flag removes its evidence rows', '0',
  (select count(*)::text from public.dss_flag_evidence
   where flag_id = '00000000-0000-4000-8000-0000000d1601');

select n, test, expected,
  case when actual like '%' || expected || '%' then actual else 'MISMATCH: ' || actual end as actual
from t order by n;
rollback;
