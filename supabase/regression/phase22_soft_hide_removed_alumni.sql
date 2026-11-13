-- Soft-hide removed alumni: peers cannot select anonymized authors' forum /
-- event rows; admins still can; interaction rows are not deleted.
begin;

create temp table t (n int, test text, expected text, actual text);

create function pg_temp.try_as(p_role text, p_uid text, p_sql text)
returns text
language plpgsql as $$
declare
  v text;
begin
  perform set_config(
    'request.jwt.claims',
    json_build_object(
      'role', p_role,
      'sub', p_uid,
      'email', (select email from auth.users where id = p_uid::uuid)
    )::text,
    true
  );
  execute format('set local role %I', p_role);
  begin
    execute 'select (' || p_sql || ')::text' into v;
  exception when others then
    v := 'ERR:' || left(sqlerrm, 80);
  end;
  reset role;
  perform set_config('request.jwt.claims', '', true);
  return coalesce(v, 'null');
end $$;

-- Seed: alumni B authors a topic + post + event comment (rolled back).
set local role service_role;

insert into public.forum_topics (
  id, title, body, author_uid, author_name, reply_count
) values (
  '00000000-0000-4000-8000-000000000a01',
  'Soft-hide topic',
  'body',
  'dfdf41bb-e201-4446-abee-e6b6ac67d82b',
  'Alumni B',
  0
) on conflict (id) do update
  set author_uid = excluded.author_uid,
      author_name = excluded.author_name,
      title = excluded.title;

insert into public.forum_posts (
  id, topic_id, body, author_uid, author_name
) values (
  '00000000-0000-4000-8000-000000000a02',
  '00000000-0000-4000-8000-000000000a01',
  'reply body',
  'dfdf41bb-e201-4446-abee-e6b6ac67d82b',
  'Alumni B'
) on conflict (id) do update
  set author_uid = excluded.author_uid,
      author_name = excluded.author_name;

-- Use an existing event if present; otherwise skip event comment asserts.
do $$
declare
  v_event uuid;
begin
  select id into v_event from public.events order by created_at desc nulls last limit 1;
  if v_event is null then
    return;
  end if;
  insert into public.event_comments (id, event_id, user_id, body)
  values (
    '00000000-0000-4000-8000-000000000a03',
    v_event,
    'dfdf41bb-e201-4446-abee-e6b6ac67d82b',
    'comment before remove'
  )
  on conflict (id) do update
    set body = excluded.body, user_id = excluded.user_id;
end $$;

reset role;

insert into t select 1, 'before remove: peer sees topic', '1',
  pg_temp.try_as(
    'authenticated',
    '6f6c569a-9ded-4c90-acab-19d78ab2a3f3',
    $q$select count(*)::text from public.forum_topics
       where id = '00000000-0000-4000-8000-000000000a01'$q$
  );

insert into t select 2, 'admin_remove_alumni_account ok', 'true',
  pg_temp.try_as(
    'authenticated',
    '8a845be5-5870-437f-95e6-7ea3b0ad7a06',
    $q$select public.admin_remove_alumni_account(
         (select id from public.alumni_members
          where auth_uid = 'dfdf41bb-e201-4446-abee-e6b6ac67d82b'
             or former_auth_uid = 'dfdf41bb-e201-4446-abee-e6b6ac67d82b'
          order by updated_at desc nulls last limit 1)
       )->>'ok'$q$
  );

insert into t select 3, 'after remove: peer cannot see topic', '0',
  pg_temp.try_as(
    'authenticated',
    '6f6c569a-9ded-4c90-acab-19d78ab2a3f3',
    $q$select count(*)::text from public.forum_topics
       where id = '00000000-0000-4000-8000-000000000a01'$q$
  );

insert into t select 4, 'after remove: peer cannot see post', '0',
  pg_temp.try_as(
    'authenticated',
    '6f6c569a-9ded-4c90-acab-19d78ab2a3f3',
    $q$select count(*)::text from public.forum_posts
       where id = '00000000-0000-4000-8000-000000000a02'$q$
  );

insert into t select 5, 'after remove: admin still sees topic', '1',
  pg_temp.try_as(
    'authenticated',
    '8a845be5-5870-437f-95e6-7ea3b0ad7a06',
    $q$select count(*)::text from public.forum_topics
       where id = '00000000-0000-4000-8000-000000000a01'$q$
  );

insert into t select 6, 'forum author_name not rewritten to Deleted alumni', 'kept',
  pg_temp.try_as(
    'authenticated',
    '8a845be5-5870-437f-95e6-7ea3b0ad7a06',
    $q$select case
         when author_name = 'Deleted alumni' then 'rewritten'
         when author_name is null or btrim(author_name) = '' then 'blank'
         else 'kept'
       end
       from public.forum_topics
       where id = '00000000-0000-4000-8000-000000000a01'$q$
  );

insert into t select 7, 'roster keeps former_auth_uid', 'true',
  pg_temp.try_as(
    'authenticated',
    '8a845be5-5870-437f-95e6-7ea3b0ad7a06',
    $q$select (former_auth_uid = 'dfdf41bb-e201-4446-abee-e6b6ac67d82b'
              and auth_uid is null and is_deactivated)::text
       from public.alumni_members
       where former_auth_uid = 'dfdf41bb-e201-4446-abee-e6b6ac67d82b'
       limit 1$q$
  );

insert into t select 8, 'admin get_public_profiles uses roster name', 'ok',
  pg_temp.try_as(
    'authenticated',
    '8a845be5-5870-437f-95e6-7ea3b0ad7a06',
    $q$select case
         when display_name = 'Deleted alumni' then 'anon_label'
         when display_name is null or btrim(display_name) = '' then 'blank'
         else 'ok'
       end
       from public.get_public_profiles(
         array['dfdf41bb-e201-4446-abee-e6b6ac67d82b'::uuid]
       )$q$
  );

insert into t
select 9,
       'event comment hidden from peer when seeded',
       case when exists (
         select 1 from public.event_comments
         where id = '00000000-0000-4000-8000-000000000a03'
       ) then '0' else 'skip' end,
       case
         when not exists (
           select 1 from public.event_comments
           where id = '00000000-0000-4000-8000-000000000a03'
         ) then 'skip'
         else pg_temp.try_as(
           'authenticated',
           '6f6c569a-9ded-4c90-acab-19d78ab2a3f3',
           $q$select count(*)::text from public.event_comments
              where id = '00000000-0000-4000-8000-000000000a03'$q$
         )
       end;

select n, test, expected, actual,
       case when expected = actual then 'PASS' else 'FAIL' end as result
from t
order by n;

rollback;
