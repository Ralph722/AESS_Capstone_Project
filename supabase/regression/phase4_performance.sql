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

create temp table vis(phase text, who text, tbl text, n text);
create temp table t(n int, test text, expected text, actual text);

create function pg_temp.snapshot(p_phase text) returns void
language plpgsql as $$
declare
  r record;
  w record;
begin
  for w in select * from (values
      ('alumnus A', '6f6c569a-9ded-4c90-acab-19d78ab2a3f3', 'authenticated'),
      ('alumnus B', 'dfdf41bb-e201-4446-abee-e6b6ac67d82b', 'authenticated'),
      ('admin', '8a845be5-5870-437f-95e6-7ea3b0ad7a06', 'authenticated'),
      ('anon', null, 'anon')) v(who, uid, role)
  loop
    for r in select c.relname from pg_class c
             where c.relnamespace = 'public'::regnamespace and c.relkind = 'r' and c.relrowsecurity
             order by 1
    loop
      insert into vis values (p_phase, w.who, r.relname,
        pg_temp.try_as(w.role, w.uid, format('select count(*)::text from public.%I', r.relname)));
    end loop;
  end loop;
end $$;

select pg_temp.snapshot('before');

select pg_temp.snapshot('after');

insert into t select 1, 'row visibility identical for A, B, admin, anon on every RLS table', '0 differences',
  (select count(*) || ' differences' || coalesce(': ' || string_agg(a.who || '/' || a.tbl || ' ' || b.n || '->' || a.n, '; '), '')
   from vis a join vis b on b.phase = 'before' and b.who = a.who and b.tbl = a.tbl
   where a.phase = 'after' and a.n is distinct from b.n);
insert into t select 2, 'tables compared', '>= 40',
  (select count(distinct tbl)::text from vis where phase = 'after');
insert into t select 3, 'policies with per-row auth/is_admin calls', '0',
  (select count(*)::text || coalesce(': ' || string_agg(tablename || '.' || policyname, ', '), '') from pg_policies
   where schemaname = 'public'
     and (coalesce(qual, '') || ' ' || coalesce(with_check, '')) ~ '(?<!SELECT )(auth\.(uid|role|jwt)\(\)|(?<![a-z_.])is_admin\(\)|(?<![a-z_.])is_signed_in\(\))');
insert into t select 4, 'overlapping permissive policies', '0',
  (select count(*)::text || coalesce(': ' || string_agg(a.tablename || ' ' || a.policyname || '+' || b.policyname, ', '), '')
   from pg_policies a join pg_policies b
     on a.schemaname = b.schemaname and a.tablename = b.tablename and a.policyname < b.policyname
    and a.permissive = 'PERMISSIVE' and b.permissive = 'PERMISSIVE'
    and (a.cmd = b.cmd or a.cmd = 'ALL' or b.cmd = 'ALL')
    and a.roles && b.roles
   where a.schemaname = 'public');
insert into t select 5, 'foreign keys without an index', '0',
  (select count(*)::text from pg_constraint c
   where c.contype = 'f' and c.connamespace = 'public'::regnamespace
     and not exists (
       select 1 from pg_index i
       where i.indrelid = c.conrelid
         and (i.indkey::int2[])[0:cardinality(c.conkey) - 1] @> c.conkey
         and (i.indkey::int2[])[0:cardinality(c.conkey) - 1] <@ c.conkey));
insert into t select 6, 'realtime tables', '11, no forum_reports/helpful',
  (select count(*)::text || case when bool_or(tablename in ('forum_reports', 'forum_helpful_reactions')) then ', STILL THERE' else ', no forum_reports/helpful' end
   from pg_publication_tables where pubname = 'supabase_realtime');
insert into t select 7, 'BFPT name', 'BFPT', (select name from public.programs where code = 'BFPT');

-- Merged policies still behave
insert into t select 8, 'admin creates announcement', 'ok',
  pg_temp.try_as('authenticated', '8a845be5-5870-437f-95e6-7ea3b0ad7a06',
    $q$insert into public.announcements (id, title, body) values ('00000000-0000-4000-8000-0000000f4001', 'P4', 'P4 body')$q$);
insert into t select 9, 'admin edits + deletes it', '1/1',
  pg_temp.try_as('authenticated', '8a845be5-5870-437f-95e6-7ea3b0ad7a06',
    $q$with u as (update public.announcements set title = 'P4b' where id = '00000000-0000-4000-8000-0000000f4001' returning 1) select count(*)::text from u$q$)
  || '/' ||
  pg_temp.try_as('authenticated', '8a845be5-5870-437f-95e6-7ea3b0ad7a06',
    $q$with d as (delete from public.announcements where id = '00000000-0000-4000-8000-0000000f4001' returning 1) select count(*)::text from d$q$);
insert into t select 10, 'alumnus creates announcement', 'blocked',
  pg_temp.try_as('authenticated', '6f6c569a-9ded-4c90-acab-19d78ab2a3f3',
    $q$insert into public.announcements (title, body) values ('x', 'y')$q$);
insert into t select 11, 'alumnus edits a survey question', '0',
  pg_temp.try_as('authenticated', '6f6c569a-9ded-4c90-acab-19d78ab2a3f3',
    $q$with u as (update public.survey_questions set updated_at = now() returning 1) select count(*)::text from u$q$);
insert into t select 12, 'admin edits survey questions', '>0',
  pg_temp.try_as('authenticated', '8a845be5-5870-437f-95e6-7ea3b0ad7a06',
    $q$with u as (update public.survey_questions set updated_at = updated_at returning 1) select case when count(*) > 0 then '>0' else '0' end from u$q$);
insert into t select 13, 'alumnus RSVPs for self / for B', 'ok / blocked',
  pg_temp.try_as('authenticated', '6f6c569a-9ded-4c90-acab-19d78ab2a3f3',
    format($q$insert into public.event_rsvps (event_id, user_id, status) select id, '6f6c569a-9ded-4c90-acab-19d78ab2a3f3', 'going' from public.events where id not in (select event_id from public.event_rsvps where user_id = '6f6c569a-9ded-4c90-acab-19d78ab2a3f3') limit 1$q$))
  || ' / ' ||
  case when pg_temp.try_as('authenticated', '6f6c569a-9ded-4c90-acab-19d78ab2a3f3',
    $q$insert into public.event_rsvps (event_id, user_id, status) select id, 'dfdf41bb-e201-4446-abee-e6b6ac67d82b', 'going' from public.events where id not in (select event_id from public.event_rsvps where user_id = 'dfdf41bb-e201-4446-abee-e6b6ac67d82b') limit 1$q$) like 'ERROR%' then 'blocked' else 'ALLOWED' end;
insert into t select 14, 'admin deletes all RSVPs', 'all',
  pg_temp.try_as('authenticated', '8a845be5-5870-437f-95e6-7ea3b0ad7a06',
    $q$with d as (delete from public.event_rsvps returning 1) select case when count(*) = (select count(*) from public.event_rsvps) then 'all' else 'some' end from d$q$);
insert into t select 15, 'alumnus deletes B''s job interests', '0',
  pg_temp.try_as('authenticated', '6f6c569a-9ded-4c90-acab-19d78ab2a3f3',
    $q$with d as (delete from public.job_interests where user_id = 'dfdf41bb-e201-4446-abee-e6b6ac67d82b' returning 1) select count(*)::text from d$q$);
insert into t select 16, 'admin deletes job interests', 'all visible',
  pg_temp.try_as('authenticated', '8a845be5-5870-437f-95e6-7ea3b0ad7a06',
    $q$with d as (delete from public.job_interests returning 1) select 'all visible' from d limit 1$q$);
insert into t select 17, 'alumnus inserts an admin-role users row', 'blocked',
  pg_temp.try_as('authenticated', '6f6c569a-9ded-4c90-acab-19d78ab2a3f3',
    $q$insert into public.users (id, role) values (gen_random_uuid(), 'admin')$q$);
insert into t select 18, 'alumnus writes user_notifications table', 'blocked',
  pg_temp.try_as('authenticated', '6f6c569a-9ded-4c90-acab-19d78ab2a3f3',
    $q$insert into public.user_notifications (user_id, title) values ('6f6c569a-9ded-4c90-acab-19d78ab2a3f3', 'x')$q$);

select n, test, expected, actual from t order by n;

rollback;
