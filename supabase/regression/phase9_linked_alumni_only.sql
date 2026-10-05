begin;
-- Phase 9: only admins and alumni linked to an active roster row may use the
-- data API. O is a confirmed Supabase Auth account that never linked to the
-- roster. A = alumnus A, admin = 8a845be5-...
-- Returns "select/update/delete/foreign": rows visible, rows updatable, rows
-- deletable (both rolled back), and visible rows not owned by the caller.
create function pg_temp.probe(p_role text, p_uid text, p_rel regclass) returns text
language plpgsql as $$
declare
  n_sel bigint; n_upd text; n_del text; n_for text := '-';
  v_col text; v_owner text; n bigint; v_kind char;
begin
  select relkind into v_kind from pg_class where oid = p_rel;
  select string_agg(format('%I::text is distinct from %L', attname, coalesce(p_uid, '')), ' and ')
  into v_owner
  from pg_attribute
  where attrelid = p_rel and attnum > 0 and not attisdropped
    and attname in ('user_id', 'author_uid', 'auth_uid', 'sender_id', 'recipient_id', 'reporter_uid', 'created_by');
  if p_rel = 'public.users'::regclass then v_owner := format('id::text is distinct from %L', coalesce(p_uid, '')); end if;
  select attname into v_col from pg_attribute
  where attrelid = p_rel and attnum > 0 and not attisdropped
    and has_column_privilege(p_role, p_rel, attnum, 'UPDATE')
  order by (attname = 'updated_at') desc, attnum limit 1;

  perform set_config('request.jwt.claims',
    case when p_uid is null then json_build_object('role', p_role)::text
         else json_build_object('role', p_role, 'sub', p_uid, 'email',
           (select email from auth.users where id = p_uid::uuid))::text end, true);
  execute format('set local role %I', p_role);

  begin
    execute format('select count(*) from %s', p_rel) into n_sel;
    if v_owner is not null then
      execute format('select count(*) from %s where %s', p_rel, v_owner) into n;
      n_for := n::text;
    end if;
  exception when others then
    n_sel := null;
    n_for := '-';
  end;

  if v_kind <> 'r' then
    n_upd := 'view'; n_del := 'view';
  else
    if v_col is null then
      n_upd := 'x';
    else
      begin
        execute format('with u as (update %s set %I = %I returning 1) select count(*) from u', p_rel, v_col, v_col) into n;
        raise exception using message = '__rollback__';
      exception when others then
        n_upd := case when sqlerrm = '__rollback__' then n::text
                      when sqlerrm like 'permission denied%' then 'x'
                      else 'E:' || left(sqlerrm, 40) end;
      end;
    end if;
    begin
      execute format('with d as (delete from %s returning 1) select count(*) from d', p_rel) into n;
      raise exception using message = '__rollback__';
    exception when others then
      n_del := case when sqlerrm = '__rollback__' then n::text
                    when sqlerrm like 'permission denied%' then 'x'
                    else 'E:' || left(sqlerrm, 40) end;
    end;
  end if;

  reset role;
  perform set_config('request.jwt.claims', '', true);
  return coalesce(n_sel::text, 'x') || '/' || n_upd || '/' || n_del || '/' || n_for;
end $$;

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

create temp table t(n int, test text, expected text, actual text);

insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data, email_confirmed_at)
values ('00000000-0000-4000-8000-00000000c0c0', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'outsider-test@example.invalid', '{"display_name":"Outsider Test"}', now());
insert into t select 1, 'confirmed outsider still gets a users row', '1 user',
  (select count(*) || ' ' || coalesce(max(role), '-') from public.users where id = '00000000-0000-4000-8000-00000000c0c0');

-- Every table, view and storage.objects
create temp table rels as
select c.oid::regclass as rel, c.relname
from pg_class c
where c.relnamespace = 'public'::regnamespace and c.relkind in ('r', 'v')
union all select 'storage.objects'::regclass, 'storage.objects';
create temp table m as select relname, pg_temp.probe('authenticated', '00000000-0000-4000-8000-00000000c0c0', rel) as res from rels;
insert into t select 2, 'outsider: every table, view and storage blocked', 'all blocked',
  (select case when count(*) = 0 then 'all blocked' else 'OPEN: ' || string_agg(relname || '=' || res, ', ' order by relname) end
   from m
   where not (split_part(res, '/', 1) in ('0', 'x')
     and split_part(res, '/', 2) in ('0', 'x', 'view')
     and (split_part(res, '/', 3) in ('0', 'x', 'view') or split_part(res, '/', 3) like 'E:Direct deletion%')));

-- SECURITY DEFINER functions
insert into t select 3, 'outsider: caller_is_active', 'false',
  pg_temp.try_as('authenticated', '00000000-0000-4000-8000-00000000c0c0', 'select public.caller_is_active()::text');
insert into t select 4, 'outsider: get_public_profiles', '0',
  pg_temp.try_as('authenticated', '00000000-0000-4000-8000-00000000c0c0', 'select count(*)::text from public.get_public_profiles(array[''6f6c569a-9ded-4c90-acab-19d78ab2a3f3''::uuid, ''8a845be5-5870-437f-95e6-7ea3b0ad7a06''::uuid])');
insert into t select 5, 'outsider: mention search', 'refused',
  pg_temp.try_as('authenticated', '00000000-0000-4000-8000-00000000c0c0', 'select count(*)::text from public.search_forum_mention_users(''a'')');
create temp table jv as select id, views from public.jobs order by created_at limit 1;
insert into t select 6, 'outsider: increment_job_views changes nothing', 'unchanged',
  pg_temp.try_as('authenticated', '00000000-0000-4000-8000-00000000c0c0', format('select public.increment_job_views(%L)::text', (select id from jv)));
update t set actual = case when (select j.views from public.jobs j join jv on jv.id = j.id) = (select views from jv) then 'unchanged' else 'CHANGED' end where n = 6;
insert into t select 7, 'outsider: edit_forum_post', 'not authorized',
  pg_temp.try_as('authenticated', '00000000-0000-4000-8000-00000000c0c0', format('select public.edit_forum_post(%L, ''x'')::text', (select id from public.forum_posts limit 1)));
insert into t select 8, 'outsider: notify_forum_mentions', 'refused',
  pg_temp.try_as('authenticated', '00000000-0000-4000-8000-00000000c0c0', format('select public.notify_forum_mentions(%L, array[''6f6c569a-9ded-4c90-acab-19d78ab2a3f3''::uuid])::text', (select id from public.forum_posts limit 1)));
insert into t select 9, 'outsider: record_survey_opened', 'not authorized',
  pg_temp.try_as('authenticated', '00000000-0000-4000-8000-00000000c0c0', format('select public.record_survey_opened(%L)::text', (select id from public.surveys limit 1)));
insert into t select 10, 'outsider: register_push_token', 'not authorized',
  pg_temp.try_as('authenticated', '00000000-0000-4000-8000-00000000c0c0', 'select public.register_push_token(''fcm'', ''android'', ''outsider-token-0123456789'')::text');
insert into t select 11, 'outsider: forum topic insert', 'blocked',
  pg_temp.try_as('authenticated', '00000000-0000-4000-8000-00000000c0c0', $q$insert into public.forum_topics (author_uid, title, body) values ('00000000-0000-4000-8000-00000000c0c0', 'x', 'x')$q$);
insert into t select 12, 'outsider: event comment insert', 'blocked',
  pg_temp.try_as('authenticated', '00000000-0000-4000-8000-00000000c0c0', format($q$insert into public.event_comments (event_id, user_id, body) values (%L, '00000000-0000-4000-8000-00000000c0c0', 'x')$q$, (select id from public.events limit 1)));

-- Registration still works for the outsider once they pass the roster check
insert into public.alumni_members (full_name, course, student_id, year_graduated)
values ('Outsider Test', 'BSIT', '9999-0001', '2030');
insert into t select 13, 'eligibility check still open to signed-in users', 'eligible',
  pg_temp.try_as('authenticated', '00000000-0000-4000-8000-00000000c0c0', 'select case when (public.validate_alumni_eligibility(''Outsider Test'', ''9999-0001'', ''BSIT'')->>''eligible'')::boolean then ''eligible'' else ''not eligible'' end');
insert into t select 14, 'link to roster row', 'true',
  pg_temp.try_as('authenticated', '00000000-0000-4000-8000-00000000c0c0', format('select public.link_alumni_registration(%L, ''Outsider Test'', ''9999-0001'', ''BSIT'', ''outsider-test@example.invalid'')->>''ok''',
    (select id from public.alumni_members where student_id = '9999-0001')));
insert into t select 15, 'linked: caller_is_active', 'true',
  pg_temp.try_as('authenticated', '00000000-0000-4000-8000-00000000c0c0', 'select public.caller_is_active()::text');
insert into t select 16, 'linked: reads announcements', 'same as alumnus A',
  case when pg_temp.try_as('authenticated', '00000000-0000-4000-8000-00000000c0c0', 'select count(*)::text from public.announcements')
          = pg_temp.try_as('authenticated', '6f6c569a-9ded-4c90-acab-19d78ab2a3f3', 'select count(*)::text from public.announcements')
       then 'same as alumnus A' else 'DIFF' end;
insert into t select 17, 'linked: get_public_profiles', '2',
  pg_temp.try_as('authenticated', '00000000-0000-4000-8000-00000000c0c0', 'select count(*)::text from public.get_public_profiles(array[''6f6c569a-9ded-4c90-acab-19d78ab2a3f3''::uuid, ''8a845be5-5870-437f-95e6-7ea3b0ad7a06''::uuid])');
update public.alumni_members set is_registered_user = false where student_id = '9999-0001';
insert into t select 18, 'roster link flag cleared: blocked again', 'false',
  pg_temp.try_as('authenticated', '00000000-0000-4000-8000-00000000c0c0', 'select public.caller_is_active()::text');

-- Existing users unaffected
insert into t select 19, 'alumnus A: caller_is_active', 'true',
  pg_temp.try_as('authenticated', '6f6c569a-9ded-4c90-acab-19d78ab2a3f3', 'select public.caller_is_active()::text');
insert into t select 20, 'admin: caller_is_active', 'true',
  pg_temp.try_as('authenticated', '8a845be5-5870-437f-95e6-7ea3b0ad7a06', 'select public.caller_is_active()::text');
insert into t select 21, 'mention search no longer matches emails', '0',
  pg_temp.try_as('authenticated', '6f6c569a-9ded-4c90-acab-19d78ab2a3f3', 'select count(*)::text from public.search_forum_mention_users(''@'')');
insert into t select 22, 'mention search returns no email-shaped names', '0',
  pg_temp.try_as('authenticated', '6f6c569a-9ded-4c90-acab-19d78ab2a3f3', 'select count(*)::text from public.search_forum_mention_users(''a'') where display_name like ''%@%''');
insert into t select 23, 'mention search: % is literal, not a wildcard', '0',
  pg_temp.try_as('authenticated', '6f6c569a-9ded-4c90-acab-19d78ab2a3f3', 'select count(*)::text from public.search_forum_mention_users(''%'')');
insert into t select 24, 'anon cannot execute caller_is_active', 'no',
  case when has_function_privilege('anon', 'public.caller_is_active()', 'execute') then 'YES' else 'no' end;

select n, test, expected, actual from t order by n;
rollback;