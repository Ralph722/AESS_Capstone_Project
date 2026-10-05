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
create temp table ctx as
select
  (select id from public.survey_responses where status = 'submitted' limit 1) as sub_id,
  (select user_id from public.survey_responses where status = 'submitted' limit 1) as sub_uid,
  (select a.id from public.survey_assignments a
    where a.status <> 'completed'
      and not exists (select 1 from public.survey_responses r where r.survey_id = a.survey_id and r.user_id = a.user_id and r.status = 'submitted')
    limit 1) as open_asg,
  (select a.user_id from public.survey_assignments a
    where a.status <> 'completed'
      and not exists (select 1 from public.survey_responses r where r.survey_id = a.survey_id and r.user_id = a.user_id and r.status = 'submitted')
    limit 1) as open_asg_uid,
  (select a.id from public.survey_assignments a where a.status = 'completed' limit 1) as done_asg,
  (select a.user_id from public.survey_assignments a where a.status = 'completed' limit 1) as done_asg_uid,
  (select id from public.dss_flags where status = 'resolved' limit 1) as resolved_flag,
  (select survey_id from public.survey_responses where status = 'submitted' limit 1) as sub_survey;
grant select on ctx to authenticated;

-- DI-3: submitted GTS lock
insert into t select 1, 'owner edits submitted answers', 'blocked',
  pg_temp.try_as('authenticated', (select sub_uid::text from ctx),
    format($q$with u as (update public.survey_responses set answers = answers || '{"x":1}' where id = %L returning 1) select count(*)::text from u$q$, (select sub_id from ctx)));
insert into t select 2, 'owner reverts submitted to draft', 'blocked',
  pg_temp.try_as('authenticated', (select sub_uid::text from ctx),
    format($q$with u as (update public.survey_responses set status = 'draft' where id = %L returning 1) select count(*)::text from u$q$, (select sub_id from ctx)));
insert into t select 3, 'owner touches telemetry on submitted', '1',
  pg_temp.try_as('authenticated', (select sub_uid::text from ctx),
    format($q$with u as (update public.survey_responses set browser_family = browser_family where id = %L returning 1) select count(*)::text from u$q$, (select sub_id from ctx)));
insert into t select 4, 'admin update (no admin UPDATE policy exists, unchanged)', '0',
  pg_temp.try_as('authenticated', '8a845be5-5870-437f-95e6-7ea3b0ad7a06',
    format($q$with u as (update public.survey_responses set updated_at = now() where id = %L returning 1) select count(*)::text from u$q$, (select sub_id from ctx)));
insert into t select 5, 'owner marks assignment completed without submitting', 'blocked',
  pg_temp.try_as('authenticated', (select open_asg_uid::text from ctx),
    format($q$with u as (update public.survey_assignments set status = 'completed' where id = %L returning 1) select count(*)::text from u$q$, (select open_asg from ctx)));
insert into t select 6, 'owner moves completed assignment back', 'completed',
  pg_temp.try_as('authenticated', (select done_asg_uid::text from ctx),
    format($q$with u as (update public.survey_assignments set status = 'inProgress' where id = %L returning status) select status from u$q$, (select done_asg from ctx)));
insert into t select 7, 'admin deletes survey with submissions', 'blocked',
  pg_temp.try_as('authenticated', '8a845be5-5870-437f-95e6-7ea3b0ad7a06',
    format($q$with d as (delete from public.surveys where id = %L returning 1) select count(*)::text from d$q$, (select sub_survey from ctx)));

-- S-11: protected users columns
insert into t select 8, 'alumnus A edits role/program/ID/email + name', 'user|program,ID,email kept|name changed',
  pg_temp.try_as('authenticated', '6f6c569a-9ded-4c90-acab-19d78ab2a3f3',
    $q$with b as (select program, student_id, email from public.users where id = '6f6c569a-9ded-4c90-acab-19d78ab2a3f3'),
       u as (update public.users set role = 'admin', program = 'ZZZ', student_id = 'FAKE', email = 'fake@x.invalid', display_name = 'Renamed A'
             where id = '6f6c569a-9ded-4c90-acab-19d78ab2a3f3' returning role, program, student_id, email, display_name)
       select u.role || '|' || case when u.program = b.program and u.student_id = b.student_id and u.email = b.email then 'program,ID,email kept' else 'CHANGED' end
              || '|' || case when u.display_name = 'Renamed A' then 'name changed' else 'name kept' end
       from u, b$q$);
insert into t select 9, 'users rows with mismatched auth email', '0',
  (select count(*)::text from public.users u join auth.users a on a.id = u.id where u.email is distinct from coalesce(a.email, ''));

-- S-12: audit log
select pg_temp.try_as('authenticated', '6f6c569a-9ded-4c90-acab-19d78ab2a3f3',
  $q$insert into public.audit_logs (user_id, action, details, created_at)
     values ('6f6c569a-9ded-4c90-acab-19d78ab2a3f3', 'TEST_FORGE', '{"userRole":"admin","userName":"Fake Admin","userEmail":"boss@x"}', '2000-01-01')$q$) as r10 into temp r10;
select pg_temp.try_as('authenticated', '6f6c569a-9ded-4c90-acab-19d78ab2a3f3',
  $q$insert into public.audit_logs (user_id, action) values ('dfdf41bb-e201-4446-abee-e6b6ac67d82b', 'TEST_IMPERSONATE')$q$) as r11 into temp r11;
insert into t select 10, 'alumnus forges audit identity', 'own uid|user|real name',
  coalesce((select case when user_id = '6f6c569a-9ded-4c90-acab-19d78ab2a3f3' then 'own uid' else 'other' end || '|' || (details->>'userRole') || '|' ||
              case when details->>'userName' = 'Fake Admin' then 'FORGED' else 'real name' end ||
              case when created_at < now() - interval '1 day' then '|BACKDATED' else '' end
            from public.audit_logs where action = 'TEST_FORGE'), (select r10 from r10));
insert into t select 11, 'alumnus logs as another user', 'stamped as self',
  coalesce((select case when user_id = '6f6c569a-9ded-4c90-acab-19d78ab2a3f3' then 'stamped as self' else 'IMPERSONATED' end
            from public.audit_logs where action = 'TEST_IMPERSONATE'), (select r11 from r11));
insert into t select 12, 'admin edits an audit row', 'permission denied',
  pg_temp.try_as('authenticated', '8a845be5-5870-437f-95e6-7ea3b0ad7a06',
    $q$with u as (update public.audit_logs set action = 'X' returning 1) select count(*)::text from u$q$);
insert into t select 13, 'admin deletes audit rows', 'permission denied',
  pg_temp.try_as('authenticated', '8a845be5-5870-437f-95e6-7ea3b0ad7a06',
    $q$with d as (delete from public.audit_logs returning 1) select count(*)::text from d$q$);
insert into t select 14, 'retention cron scheduled', '45 19 * * *',
  (select schedule from cron.job where jobname = 'aess-audit-retention');

-- S-13: message identity
select pg_temp.try_as('authenticated', 'dfdf41bb-e201-4446-abee-e6b6ac67d82b',
  $q$insert into public.messages (sender_id, recipient_id, body, sender_name, sender_email, sender_role)
     values ('dfdf41bb-e201-4446-abee-e6b6ac67d82b', '8a845be5-5870-437f-95e6-7ea3b0ad7a06', 'phase2-spoof-test', 'AESS Office', 'office@x', 'admin')$q$) as r15 into temp r15;
insert into t select 15, 'alumnus sends as "AESS Office"', 'real name, real email, user role',
  coalesce((select case when m.sender_name = u.display_name then 'real name' else 'SPOOFED ' || m.sender_name end || ', ' ||
                   case when m.sender_email = a.email then 'real email' else 'SPOOFED email' end || ', ' || m.sender_role || ' role'
            from public.messages m join public.users u on u.id = m.sender_id join auth.users a on a.id = m.sender_id
            where m.body = 'phase2-spoof-test'), (select r15 from r15));
insert into t select 16, 'sender renames own message later', 'blocked',
  pg_temp.try_as('authenticated', 'dfdf41bb-e201-4446-abee-e6b6ac67d82b',
    $q$with u as (update public.messages set sender_name = 'AESS Office' where body = 'phase2-spoof-test' returning 1) select count(*)::text from u$q$);
-- DI-13: DSS
insert into t select 17, 'admin: resolved -> dismissed directly', 'blocked',
  pg_temp.try_as('authenticated', '8a845be5-5870-437f-95e6-7ea3b0ad7a06',
    format($q$select 'ran' from (select public.dss_update_flag_status(%L, 'dismissed')) s$q$, (select resolved_flag from ctx)));
insert into t select 18, 'admin reopens resolved flag', 'ran',
  pg_temp.try_as('authenticated', '8a845be5-5870-437f-95e6-7ea3b0ad7a06',
    format($q$select 'ran' from (select public.dss_update_flag_status(%L, 'open', 'Reopened in test')) s$q$, (select resolved_flag from ctx)));
insert into t select 18, '...flag + note written together', 'open|reopen|admin name|resolved_at cleared',
  (select f.status || '|' ||
          (select n.event_type || '|' || case when n.author_name = (select display_name from public.users where id = '8a845be5-5870-437f-95e6-7ea3b0ad7a06') then 'admin name' else 'name=' || n.author_name end
           from public.dss_flag_notes n where n.flag_id = f.id and n.note = 'Reopened in test') || '|' ||
          case when f.resolved_at is null then 'resolved_at cleared' else 'resolved_at kept' end
   from public.dss_flags f where f.id = (select resolved_flag from ctx));
insert into t select 19, 'alumnus calls DSS status RPC', 'admin required',
  pg_temp.try_as('authenticated', '6f6c569a-9ded-4c90-acab-19d78ab2a3f3',
    format($q$select 'ran' from (select public.dss_update_flag_status(%L, 'open')) s$q$, (select resolved_flag from ctx)));
insert into t select 20, 'note author name forged by client', 'stamped',
  pg_temp.try_as('authenticated', '8a845be5-5870-437f-95e6-7ea3b0ad7a06',
    format($q$with i as (insert into public.dss_flag_notes (flag_id, note, author_name, author_id) values (%L, 'n', 'Someone Else', '6f6c569a-9ded-4c90-acab-19d78ab2a3f3') returning author_name, author_id)
              select case when author_id = '8a845be5-5870-437f-95e6-7ea3b0ad7a06' and author_name <> 'Someone Else' then 'stamped' else 'FORGED' end from i$q$, (select resolved_flag from ctx)));

-- M-9: account removal
insert into t select 21, 'alumnus calls account removal', 'admin required',
  pg_temp.try_as('authenticated', '6f6c569a-9ded-4c90-acab-19d78ab2a3f3',
    $q$select public.admin_remove_alumni_account('a9bb659a-a452-40e1-8bdc-8b65085a507f')::text$q$);
insert into t select 22, 'admin removes unclaimed roster row', 'no linked account',
  pg_temp.try_as('authenticated', '8a845be5-5870-437f-95e6-7ea3b0ad7a06',
    $q$select public.admin_remove_alumni_account('b81e02b2-3aba-4eb7-83cd-754b56be9ca4')::text$q$);

create temp table before_b as
select (select count(*) from public.survey_responses where user_id = 'dfdf41bb-e201-4446-abee-e6b6ac67d82b') as responses,
       (select count(*) from public.survey_response_events where user_id = 'dfdf41bb-e201-4446-abee-e6b6ac67d82b') as events,
       (select count(*) from public.messages where sender_id = 'dfdf41bb-e201-4446-abee-e6b6ac67d82b' or recipient_id = 'dfdf41bb-e201-4446-abee-e6b6ac67d82b') as msgs,
       (select program from public.users where id = 'dfdf41bb-e201-4446-abee-e6b6ac67d82b') as program;

insert into t select 23, 'admin removes alumnus B', 'ok',
  pg_temp.try_as('authenticated', '8a845be5-5870-437f-95e6-7ea3b0ad7a06',
    $q$select case when (public.admin_remove_alumni_account('a9bb659a-a452-40e1-8bdc-8b65085a507f')->>'ok')::boolean then 'ok' else 'not ok' end$q$);
insert into t select 24, 'B: users row anonymized, cohort kept', 'Deleted alumni|no email|program kept|anonymized',
  (select display_name || '|' || case when email = '' then 'no email' else 'HAS EMAIL' end || '|' ||
          case when program = (select program from before_b) then 'program kept' else 'PROGRAM LOST' end || '|' ||
          case when anonymized_at is not null and deactivated_at is not null then 'anonymized' else 'NOT FLAGGED' end
   from public.users where id = 'dfdf41bb-e201-4446-abee-e6b6ac67d82b');
insert into t select 25, 'B: auth login banned, real email gone, 0 sessions', 'banned|placeholder|0',
  (select coalesce(to_char(banned_until, 'YYYY'), 'NOT BANNED') || '|' ||
          case when email like 'removed+%@removed.invalid' then 'placeholder' else 'REAL EMAIL' end || '|' ||
          (select count(*) from auth.sessions s where s.user_id = u.id)
   from auth.users u where u.id = 'dfdf41bb-e201-4446-abee-e6b6ac67d82b');
insert into t select 26, 'B: tracer rows kept, identifying answers blanked', 'kept|0 identifying keys',
  (select case when (select count(*) from public.survey_responses where user_id = 'dfdf41bb-e201-4446-abee-e6b6ac67d82b') = responses
                and (select count(*) from public.survey_response_events where user_id = 'dfdf41bb-e201-4446-abee-e6b6ac67d82b') = events
                and (select count(*) from public.messages where sender_id = 'dfdf41bb-e201-4446-abee-e6b6ac67d82b' or recipient_id = 'dfdf41bb-e201-4446-abee-e6b6ac67d82b') = msgs
           then 'kept' else 'ROWS LOST' end || '|' ||
          (select count(*) from public.survey_responses r, jsonb_object_keys(r.answers) k
            where r.user_id = 'dfdf41bb-e201-4446-abee-e6b6ac67d82b' and k in ('ched_1','ched_2','ched_3','ched_4','ched_5','ched_8')) || ' identifying keys'
   from before_b);
insert into t select 27, 'B: roster row kept, deactivated, unlinked', 'deactivated|unlinked',
  (select case when is_deactivated then 'deactivated' else 'ACTIVE' end || '|' ||
          case when auth_uid is null and not is_registered_user and registered_email is null then 'unlinked' else 'STILL LINKED' end
   from public.alumni_members where id = 'a9bb659a-a452-40e1-8bdc-8b65085a507f');
insert into t select 28, 'B: messages show anonymized sender', '0 with old name',
  (select count(*)::text || ' with old name' from public.messages
    where sender_id = 'dfdf41bb-e201-4446-abee-e6b6ac67d82b' and sender_name <> 'Deleted alumni');
update public.alumni_members set is_deactivated = false where id = 'a9bb659a-a452-40e1-8bdc-8b65085a507f';
insert into t select 29, 'admin reactivates B roster: anonymized login stays banned', '2999',
  coalesce((select to_char(banned_until, 'YYYY') from auth.users where id = 'dfdf41bb-e201-4446-abee-e6b6ac67d82b'), 'NOT BANNED');
insert into t select 30, 'hard-deleting B''s auth user (tracer evidence)', 'blocked',
  pg_temp.try_raw($q$with d as (delete from auth.users where id = 'dfdf41bb-e201-4446-abee-e6b6ac67d82b' returning 1) select count(*)::text from d$q$);

-- Forum SET NULL: author deletion keeps other people's replies
insert into auth.users (id, instance_id, aud, role, email, email_confirmed_at, raw_user_meta_data)
values ('00000000-0000-4000-8000-00000000f2a2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'phase2-test@example.invalid', now(), '{"display_name":"Forum Tester"}');
-- Only roster-linked alumni may post (phase 9).
insert into public.alumni_members (full_name, course, student_id, year_graduated, auth_uid, is_registered_user)
values ('Forum Tester', 'BSIT', '9999-0002', '2030', '00000000-0000-4000-8000-00000000f2a2', true);
insert into t select 31, 'test user creates topic', '1',
  pg_temp.try_as('authenticated', '00000000-0000-4000-8000-00000000f2a2',
    $q$with i as (insert into public.forum_topics (id, title, body, author_uid, author_name) values ('00000000-0000-4000-8000-0000000f0000', 'T', 'B', '00000000-0000-4000-8000-00000000f2a2', 'Forum Tester') returning 1) select count(*)::text from i$q$);
insert into t select 32, 'alumnus A replies', '1',
  pg_temp.try_as('authenticated', '6f6c569a-9ded-4c90-acab-19d78ab2a3f3',
    $q$with i as (insert into public.forum_posts (topic_id, body, author_uid, author_name) values ('00000000-0000-4000-8000-0000000f0000', 'reply', '6f6c569a-9ded-4c90-acab-19d78ab2a3f3', 'A') returning 1) select count(*)::text from i$q$);
delete from public.survey_assignments where user_id = '00000000-0000-4000-8000-00000000f2a2';
insert into t select 33, 'delete topic author account', '1',
  pg_temp.try_raw($q$with d as (delete from auth.users where id = '00000000-0000-4000-8000-00000000f2a2' returning 1)
    select (select count(*) from d)::text$q$);
insert into t select 33, '...thread survives', 'topic kept, author null, A reply kept',
  (select case when count(*) = 1 and bool_and(author_uid is null) then 'topic kept, author null' else 'TOPIC GONE/AUTHOR SET' end
   from public.forum_topics where id = '00000000-0000-4000-8000-0000000f0000')
  || ', ' ||
  (select case when count(*) = 1 then 'A reply kept' else 'REPLY GONE' end
   from public.forum_posts where topic_id = '00000000-0000-4000-8000-0000000f0000');

-- Grants and advisor items
insert into t select 34, 'functions anon can execute', '3',
  (select count(*)::text || ': ' || string_agg(proname, ', ' order by proname)
   from pg_proc where pronamespace = 'public'::regnamespace and has_function_privilege('anon', oid, 'EXECUTE'));
insert into t select 35, 'trigger functions authenticated can execute', '0',
  (select count(*)::text from pg_proc p where p.pronamespace = 'public'::regnamespace and p.prorettype = 'trigger'::regtype
     and has_function_privilege('authenticated', p.oid, 'EXECUTE'));
insert into t select 36, 'functions without fixed search_path', '0',
  (select count(*)::text from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proconfig is null
     and not exists (select 1 from pg_depend d where d.objid = p.oid and d.deptype = 'e'));
insert into t select 37, 'job with "Active" status rejected', 'check violation',
  pg_temp.try_raw($q$with u as (update public.jobs set status = 'Active' returning 1) select count(*)::text from u$q$);
insert into t select 38, 'duplicate roster ID + course rejected', 'unique violation',
  pg_temp.try_raw($q$with i as (insert into public.alumni_members (full_name, course, student_id)
    select 'Dup', lower(course), ' ' || lower(student_id) from public.alumni_members where id = '305517b7-72b9-4746-9156-cf362e7ded6b' returning 1) select count(*)::text from i$q$);

select n, test, expected, actual from t order by n;

rollback;
