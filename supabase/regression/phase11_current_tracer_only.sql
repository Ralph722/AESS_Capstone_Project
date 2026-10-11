begin;
-- Phase 11: alumni who register while several CHED tracers are open get only
-- the newest one that matches them. OLD = forgotten older tracer, NEW = current
-- tracer, OTHER = a regular survey. Test tracers are dated in the future so
-- they are newer than any real tracer in the project. Nothing is assigned
-- until the roster link, so check 3 cannot also pick up OLD at sign-up.
create temp table t(n int, test text, expected text, actual text);

create function pg_temp.assigned(p_uid uuid) returns text
language sql as $$
  select coalesce(string_agg(s.title, ',' order by s.title), 'none')
  from public.survey_assignments a
  join public.surveys s on s.id = a.survey_id
  where a.user_id = p_uid and s.title like 'P11 %';
$$;

-- The real sign-up order: the email code is confirmed (handle_new_user creates
-- an empty profile), then link_alumni_registration links the roster row.
create function pg_temp.confirm_email(p_uid uuid) returns void
language sql as $$
  insert into auth.users (id, instance_id, aud, role, email, email_confirmed_at)
  values (p_uid, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'p11-' || p_uid || '@example.invalid', now());
$$;

create function pg_temp.link_roster(p_uid uuid, p_year text) returns text
language plpgsql as $$
declare
  sid text := 'P11-' || right(p_uid::text, 4);
  member_id uuid;
  r text;
begin
  insert into public.alumni_members (full_name, course, student_id, year_graduated)
  values ('P11 Alumnus ' || right(p_uid::text, 4), 'BSIT', sid, p_year)
  returning id into member_id;
  perform set_config('request.jwt.claims',
    json_build_object('role', 'authenticated', 'sub', p_uid)::text, true);
  select public.link_alumni_registration(member_id::text,
    'P11 Alumnus ' || right(p_uid::text, 4), sid, 'BSIT',
    'p11-' || p_uid || '@example.invalid')->>'ok' into r;
  perform set_config('request.jwt.claims', '', true);
  return r;
end $$;

create function pg_temp.register(p_uid uuid, p_year text) returns void
language plpgsql as $$
begin
  perform pg_temp.confirm_email(p_uid);
  if pg_temp.link_roster(p_uid, p_year) is distinct from 'true' then
    raise exception 'roster link failed for %', p_uid;
  end if;
end $$;

insert into public.surveys (id, title, status, created_by, data) values
  ('00000000-0000-4000-8000-0000000b1101', 'P11 OLD', 'published',
   (select id from public.users where role = 'admin' limit 1),
   jsonb_build_object('kind', 'ched_gts_builtin',
     'publishedAt', (now() + interval '1 day')::text)),
  ('00000000-0000-4000-8000-0000000b1102', 'P11 NEW', 'published',
   (select id from public.users where role = 'admin' limit 1),
   jsonb_build_object('kind', 'ched_gts_builtin',
     'publishedAt', (now() + interval '2 days')::text)),
  ('00000000-0000-4000-8000-0000000b1103', 'P11 OTHER', 'published',
   (select id from public.users where role = 'admin' limit 1),
   '{}'::jsonb);

-- Confirming the email code alone assigns nothing.
select pg_temp.confirm_email('00000000-0000-4000-8000-0000000b1201');
insert into t select 0, 'email confirmed, not linked yet', 'none',
  pg_temp.assigned('00000000-0000-4000-8000-0000000b1201');

-- Both tracers open and open to everyone.
select pg_temp.link_roster('00000000-0000-4000-8000-0000000b1201', '2019');
insert into t select 1, 'late registrant gets only the newest tracer',
  'P11 NEW,P11 OTHER', pg_temp.assigned('00000000-0000-4000-8000-0000000b1201');

-- Newest tracer targets other batches: the newest one that matches wins.
update public.surveys set target_batch_years = array['2024-2026']
where id = '00000000-0000-4000-8000-0000000b1102';
select pg_temp.register('00000000-0000-4000-8000-0000000b1202', '2019');
insert into t select 2, 'newest tracer not for this batch', 'P11 OLD,P11 OTHER',
  pg_temp.assigned('00000000-0000-4000-8000-0000000b1202');
select pg_temp.register('00000000-0000-4000-8000-0000000b1203', '2025');
insert into t select 3, 'newest tracer for this batch', 'P11 NEW,P11 OTHER',
  pg_temp.assigned('00000000-0000-4000-8000-0000000b1203');
update public.surveys set target_batch_years = '{}'
where id = '00000000-0000-4000-8000-0000000b1102';

-- Newest tracer closed: the forgotten one is still skipped.
update public.surveys set status = 'closed'
where id = '00000000-0000-4000-8000-0000000b1102';
select pg_temp.register('00000000-0000-4000-8000-0000000b1204', '2019');
insert into t select 4, 'newest tracer closed', 'P11 OTHER',
  pg_temp.assigned('00000000-0000-4000-8000-0000000b1204');

-- Newest tracer has auto-assign off: no older tracer is assigned instead.
update public.surveys set status = 'published',
  data = data || '{"autoAssignNewAlumni": false}'::jsonb
where id = '00000000-0000-4000-8000-0000000b1102';
select pg_temp.register('00000000-0000-4000-8000-0000000b1205', '2019');
insert into t select 5, 'newest tracer opted out', 'P11 OTHER',
  pg_temp.assigned('00000000-0000-4000-8000-0000000b1205');

insert into t select 6, 'assignment_count matches rows', 'yes',
  case when not exists (
    select 1 from public.surveys s
    where s.title like 'P11 %'
      and s.assignment_count <> (
        select count(*) from public.survey_assignments a where a.survey_id = s.id)
  ) then 'yes' else 'NO' end;

insert into t select 7, 'clients cannot call auto-assign', 'no',
  case when has_function_privilege('authenticated',
    'public.auto_assign_open_surveys(uuid)', 'execute') then 'YES' else 'no' end;

select n, test, expected, actual from t order by n;
rollback;
