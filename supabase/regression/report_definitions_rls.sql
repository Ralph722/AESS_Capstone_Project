-- Saved report settings: admins share one list; alumni, unlinked accounts
-- and anon see nothing and cannot write; who/when stamps come from the
-- session; names are unique ignoring case and spaces.
--
-- One statement so it runs through `supabase db query --db-url` (demo); it
-- always ends with an error that carries the results, so nothing it does is
-- kept. Not part of run_all.ps1, which targets the linked project.
do $suite$
declare
  v_admin uuid;
  v_alumnus uuid;
  v_unlinked constant uuid := '00000000-0000-4000-8000-00000000d2d2';
  v_id text;
  v_out text := '';
begin
  execute $f$
    create function pg_temp.try_as(p_role text, p_uid uuid, p_sql text) returns text
    language plpgsql as $b$
    declare r text;
    begin
      perform set_config('request.jwt.claims',
        case when p_uid is null then json_build_object('role', p_role)::text
             else json_build_object('role', p_role, 'sub', p_uid)::text end, true);
      execute format('set local role %I', p_role);
      begin
        execute p_sql into r;
      exception when others then
        r := 'ERROR: ' || sqlerrm;
      end;
      reset role;
      perform set_config('request.jwt.claims', '', true);
      return coalesce(r, '(null)');
    end $b$
  $f$;

  execute $f$
    create function pg_temp.line(p_test text, p_expected text, p_actual text) returns text
    language sql as $b$
      select format(E'\n%s | %s | expected %s | actual %s',
        case when p_actual like p_expected then 'PASS' else 'FAIL' end,
        p_test, p_expected, p_actual)
    $b$
  $f$;

  select id into v_admin from public.users where role = 'admin' order by id limit 1;
  select m.auth_uid into v_alumnus
  from public.alumni_members m
  join public.users u on u.id = m.auth_uid and u.role <> 'admin'
  where m.is_registered_user and not m.is_deactivated and btrim(m.course) <> ''
  order by m.auth_uid limit 1;

  v_out := v_out || pg_temp.line('test accounts found', 'yes',
    case when v_admin is not null and v_alumnus is not null then 'yes' else 'NO' end);

  v_out := v_out || pg_temp.line('row level security on', 'true',
    (select relrowsecurity::text from pg_class
      where oid = 'public.report_definitions'::regclass));

  v_out := v_out || pg_temp.line('anon has no select grant', 'no',
    case when has_table_privilege('anon', 'public.report_definitions', 'select')
         then 'YES' else 'no' end);

  v_out := v_out || pg_temp.line('anon cannot read', 'ERROR: permission denied%',
    pg_temp.try_as('anon', null, 'select count(*)::text from public.report_definitions'));

  -- Admin saves a report, trying to claim someone else created it.
  v_id := pg_temp.try_as('authenticated', v_admin, format(
    $q$insert into public.report_definitions (name, config, created_by, created_at)
       values ('RLS test report', '{"version":1,"measure":"ched_16","surveyIds":[]}', %L, '2000-01-01')
       returning id::text$q$, v_alumnus));
  v_out := v_out || pg_temp.line('admin can save', '________-____-____-____-____________', v_id);

  v_out := v_out || pg_temp.line('stamps come from the session', 'admin/admin/now',
    (select concat_ws('/',
        case when created_by = v_admin then 'admin' else coalesce(created_by::text, 'null') end,
        case when updated_by = v_admin then 'admin' else coalesce(updated_by::text, 'null') end,
        case when created_at > now() - interval '1 minute' then 'now' else created_at::text end)
       from public.report_definitions where id::text = v_id));

  v_out := v_out || pg_temp.line('admin sees the shared list', '1',
    pg_temp.try_as('authenticated', v_admin, format(
      'select count(*)::text from public.report_definitions where id = %L', v_id)));

  v_out := v_out || pg_temp.line('admin can rename', 'Renamed',
    pg_temp.try_as('authenticated', v_admin, format(
      $q$update public.report_definitions set name = 'Renamed', created_by = %L
         where id = %L returning name$q$, v_alumnus, v_id)));

  v_out := v_out || pg_temp.line('rename keeps the creator', 'admin',
    (select case when created_by = v_admin then 'admin' else coalesce(created_by::text, 'null') end
       from public.report_definitions where id::text = v_id));

  v_out := v_out || pg_temp.line('names are unique ignoring case and spaces', 'ERROR: duplicate key%',
    pg_temp.try_as('authenticated', v_admin,
      $q$insert into public.report_definitions (name, config)
         values ('  renamed ', '{}') returning id::text$q$));

  v_out := v_out || pg_temp.line('config must be a JSON object', 'ERROR: %check constraint%',
    pg_temp.try_as('authenticated', v_admin,
      $q$insert into public.report_definitions (name, config)
         values ('Bad config', '[]') returning id::text$q$));

  v_out := v_out || pg_temp.line('alumnus sees nothing', '0',
    pg_temp.try_as('authenticated', v_alumnus,
      'select count(*)::text from public.report_definitions'));

  v_out := v_out || pg_temp.line('alumnus cannot save', 'ERROR: new row violates row-level security%',
    pg_temp.try_as('authenticated', v_alumnus,
      $q$insert into public.report_definitions (name, config)
         values ('Alumnus report', '{}') returning id::text$q$));

  v_out := v_out || pg_temp.line('alumnus cannot change or delete', '(null)/(null)',
    pg_temp.try_as('authenticated', v_alumnus, format(
      $q$update public.report_definitions set name = 'Hacked' where id = %L returning name$q$, v_id))
    || '/' ||
    pg_temp.try_as('authenticated', v_alumnus, format(
      $q$delete from public.report_definitions where id = %L returning id::text$q$, v_id)));

  v_out := v_out || pg_temp.line('unlinked account sees nothing', '0',
    pg_temp.try_as('authenticated', v_unlinked,
      'select count(*)::text from public.report_definitions'));

  v_out := v_out || pg_temp.line('admin can delete', '________-____-____-____-____________',
    pg_temp.try_as('authenticated', v_admin, format(
      $q$delete from public.report_definitions where id = %L returning id::text$q$, v_id)));

  raise exception 'report_definitions RLS results (rolled back):%', v_out;
end
$suite$;
