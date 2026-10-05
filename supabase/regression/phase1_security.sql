begin;

create function pg_temp.try_as(p_role text, p_uid text, p_sql text) returns text
language plpgsql as $$
declare r text;
begin
  perform set_config(
    'request.jwt.claims',
    case when p_uid is null then json_build_object('role', p_role)::text
         else json_build_object('role', p_role, 'sub', p_uid)::text end,
    true
  );
  execute format('set local role %I', p_role);
  begin
    execute p_sql into r;
  exception when others then
    r := 'ERROR: ' || sqlerrm;
  end;
  reset role;
  perform set_config('request.jwt.claims', '', true);
  return coalesce(r, '(null)');
end $$;

create temp table t(n int, test text, expected text, actual text);

-- Anonymous visitor
insert into t select 1, 'anon reads roster rows', '0',
  pg_temp.try_as('anon', null, 'select count(*)::text from public.alumni_members');
insert into t select 2, 'anon eligibility check still works', 'eligible false',
  pg_temp.try_as('anon', null, $q$select public.validate_alumni_eligibility('Nobody Here','000000','BSIT')->>'code'$q$);
insert into t select 3, 'anon calls link RPC', 'permission denied',
  pg_temp.try_as('anon', null, $q$select public.link_alumni_registration('b81e02b2-3aba-4eb7-83cd-754b56be9ca4','x','1','BSIT','a@b.c')::text$q$);
insert into t select 4, 'anon bumps job views', 'permission denied',
  pg_temp.try_as('anon', null, $q$select 'ran' from (select public.increment_job_views(gen_random_uuid())) s$q$);
insert into t select 5, 'anon lists images bucket', '0',
  pg_temp.try_as('anon', null, $q$select count(*)::text from storage.objects where bucket_id = 'images'$q$);

-- Alumnus A (registered, roster 305517b7)
insert into t select 6, 'alumnus reads roster rows', '1 (own)',
  pg_temp.try_as('authenticated', '6f6c569a-9ded-4c90-acab-19d78ab2a3f3', 'select count(*)::text from public.alumni_members');
insert into t select 7, 'alumnus updates own last_active_at', '1',
  pg_temp.try_as('authenticated', '6f6c569a-9ded-4c90-acab-19d78ab2a3f3',
    $q$with u as (update public.alumni_members set last_active_at = now() where id = '305517b7-72b9-4746-9156-cf362e7ded6b' returning 1) select count(*)::text from u$q$);
insert into t select 8, 'alumnus changes own official name', 'blocked',
  pg_temp.try_as('authenticated', '6f6c569a-9ded-4c90-acab-19d78ab2a3f3',
    $q$with u as (update public.alumni_members set full_name = 'Changed Name' where id = '305517b7-72b9-4746-9156-cf362e7ded6b' returning 1) select count(*)::text from u$q$);
insert into t select 9, 'alumnus flips own is_deactivated', 'blocked',
  pg_temp.try_as('authenticated', '6f6c569a-9ded-4c90-acab-19d78ab2a3f3',
    $q$with u as (update public.alumni_members set is_deactivated = true where id = '305517b7-72b9-4746-9156-cf362e7ded6b' returning 1) select count(*)::text from u$q$);
insert into t select 10, 'alumnus claims unclaimed row directly', '0',
  pg_temp.try_as('authenticated', '6f6c569a-9ded-4c90-acab-19d78ab2a3f3',
    $q$with u as (update public.alumni_members set auth_uid = '6f6c569a-9ded-4c90-acab-19d78ab2a3f3', is_registered_user = true where id = 'b81e02b2-3aba-4eb7-83cd-754b56be9ca4' returning 1) select count(*)::text from u$q$);
insert into t select 11, 'alumnus links B''s roster row (correct details)', 'already_exists',
  pg_temp.try_as('authenticated', '6f6c569a-9ded-4c90-acab-19d78ab2a3f3',
    (select format('select public.link_alumni_registration(%L,%L,%L,%L,%L)->>''code''', id, full_name, student_id, course, 'x@example.invalid')
     from public.alumni_members where id = 'a9bb659a-a452-40e1-8bdc-8b65085a507f'));
insert into t select 12, 'alumnus links an unclaimed row (correct details)', 'already_exists',
  pg_temp.try_as('authenticated', '6f6c569a-9ded-4c90-acab-19d78ab2a3f3',
    (select format('select public.link_alumni_registration(%L,%L,%L,%L,%L)->>''code''', id, full_name, student_id, course, 'x@example.invalid')
     from public.alumni_members where id = 'b81e02b2-3aba-4eb7-83cd-754b56be9ca4'));
insert into t select 13, 'alumnus links with wrong name', 'failed_precondition',
  pg_temp.try_as('authenticated', 'dfdf41bb-e201-4446-abee-e6b6ac67d82b',
    (select format('select public.link_alumni_registration(%L,%L,%L,%L,%L)->>''code''', id, 'Wrong Person', student_id, course, 'x@example.invalid')
     from public.alumni_members where id = 'b81e02b2-3aba-4eb7-83cd-754b56be9ca4'));

-- Private chat image (sent by admin to alumnus A)
insert into t select 14, 'recipient A sees chat image', '1',
  pg_temp.try_as('authenticated', '6f6c569a-9ded-4c90-acab-19d78ab2a3f3', $q$select count(*)::text from storage.objects where bucket_id = 'message-attachments'$q$);
insert into t select 15, 'other alumnus B sees chat image', '0',
  pg_temp.try_as('authenticated', 'dfdf41bb-e201-4446-abee-e6b6ac67d82b', $q$select count(*)::text from storage.objects where bucket_id = 'message-attachments'$q$);
insert into t select 16, 'admin sees chat image', '1',
  pg_temp.try_as('authenticated', '8a845be5-5870-437f-95e6-7ea3b0ad7a06', $q$select count(*)::text from storage.objects where bucket_id = 'message-attachments'$q$);
insert into t select 17, 'alumnus sends message with public image URL', 'invalid reference',
  pg_temp.try_as('authenticated', 'dfdf41bb-e201-4446-abee-e6b6ac67d82b',
    $q$with i as (insert into public.messages (sender_id, recipient_id, body, image_base64) values ('dfdf41bb-e201-4446-abee-e6b6ac67d82b', '8a845be5-5870-437f-95e6-7ea3b0ad7a06', 'x', 'https://x.supabase.co/storage/v1/object/public/images/messages/dfdf41bb-e201-4446-abee-e6b6ac67d82b/a.jpg') returning 1) select count(*)::text from i$q$);
insert into t select 18, 'alumnus uploads chat image to images bucket', 'blocked',
  pg_temp.try_as('authenticated', 'dfdf41bb-e201-4446-abee-e6b6ac67d82b',
    $q$with i as (insert into storage.objects (bucket_id, name, owner) values ('images', 'messages/dfdf41bb-e201-4446-abee-e6b6ac67d82b/t.jpg', 'dfdf41bb-e201-4446-abee-e6b6ac67d82b') returning 1) select count(*)::text from i$q$);

-- Deactivation bans the login (run as the database owner, as the admin UI's update would trigger it)
update public.alumni_members set is_deactivated = true where id = 'a9bb659a-a452-40e1-8bdc-8b65085a507f';
insert into t select 19, 'deactivate B: login banned, sessions ended', 'banned, 0 sessions',
  (select coalesce(to_char(banned_until, 'YYYY'), 'not banned') || ', ' ||
          (select count(*) from auth.sessions s where s.user_id = u.id) || ' sessions'
   from auth.users u where u.id = 'dfdf41bb-e201-4446-abee-e6b6ac67d82b');
update public.alumni_members set is_deactivated = false where id = 'a9bb659a-a452-40e1-8bdc-8b65085a507f';
insert into t select 20, 'reactivate B: ban lifted', 'not banned',
  (select coalesce(to_char(banned_until, 'YYYY'), 'not banned') from auth.users where id = 'dfdf41bb-e201-4446-abee-e6b6ac67d82b');

-- public.users rows appear only after email confirmation
insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data)
values ('00000000-0000-4000-8000-00000000f1a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'phase1-test@example.invalid', '{"display_name":"Test"}');
insert into t select 21, 'unconfirmed sign-up creates users row', '0',
  (select count(*)::text from public.users where id = '00000000-0000-4000-8000-00000000f1a1');
update auth.users set email_confirmed_at = now() where id = '00000000-0000-4000-8000-00000000f1a1';
insert into t select 22, 'confirmed sign-up creates users row', '1',
  (select count(*)::text from public.users where id = '00000000-0000-4000-8000-00000000f1a1');

insert into t select 23, 'functions anon can execute', '3',
  (select count(*)::text || ': ' || string_agg(proname, ', ' order by proname)
   from pg_proc where pronamespace = 'public'::regnamespace and has_function_privilege('anon', oid, 'EXECUTE'));

select n, test, expected, actual from t order by n;
rollback;
