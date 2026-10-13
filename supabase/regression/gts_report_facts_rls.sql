-- Report builder view: admins see every submitted CHED GTS response, an
-- alumnus sees only their own, an unlinked account and anon see nothing, and
-- personal items (1-5, 8) never leave the view.
--
-- One statement so it runs through `supabase db query --db-url` (demo); it
-- picks its accounts from the data and always ends with an error that carries
-- the results, so nothing it does is kept. Not part of run_all.ps1, which
-- targets the linked project.
do $suite$
declare
  v_admin uuid;
  v_alumnus uuid;
  v_unlinked constant uuid := '00000000-0000-4000-8000-00000000d1d1';
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
        case when p_expected = p_actual then 'PASS' else 'FAIL' end,
        p_test, p_expected, p_actual)
    $b$
  $f$;

  select id into v_admin from public.users where role = 'admin' order by id limit 1;
  select f.user_id into v_alumnus
  from public.gts_report_facts f
  join public.alumni_members m
    on m.auth_uid = f.user_id and m.is_registered_user and not m.is_deactivated
  order by f.user_id limit 1;
  if exists (select 1 from public.alumni_members where auth_uid = v_unlinked) then
    raise exception 'test id % is linked to the roster', v_unlinked;
  end if;

  v_out := v_out || pg_temp.line('test accounts found', 'yes',
    case when v_admin is not null and v_alumnus is not null then 'yes' else 'NO' end);

  v_out := v_out || pg_temp.line('view runs with the caller''s rights', 'security_invoker=true',
    (select array_to_string(reloptions, ',') from pg_class
      where oid = 'public.gts_report_facts'::regclass));

  v_out := v_out || pg_temp.line('anon has no select grant', 'no',
    case when has_table_privilege('anon', 'public.gts_report_facts', 'select') then 'YES' else 'no' end);

  v_out := v_out || pg_temp.line('anon cannot read', 'denied',
    case when pg_temp.try_as('anon', null, 'select count(*)::text from public.gts_report_facts')
              like 'ERROR: permission denied%' then 'denied' else 'OPEN' end);

  v_out := v_out || pg_temp.line('admin sees every response',
    (select count(*)::text from public.gts_report_facts),
    pg_temp.try_as('authenticated', v_admin, 'select count(*)::text from public.gts_report_facts'));

  v_out := v_out || pg_temp.line('alumnus sees own responses',
    (select count(*)::text from public.gts_report_facts where user_id = v_alumnus),
    pg_temp.try_as('authenticated', v_alumnus, 'select count(*)::text from public.gts_report_facts'));

  v_out := v_out || pg_temp.line('alumnus sees no one else', '0',
    pg_temp.try_as('authenticated', v_alumnus, format(
      'select count(*)::text from public.gts_report_facts where user_id is distinct from %L', v_alumnus)));

  v_out := v_out || pg_temp.line('unlinked account sees nothing', '0',
    pg_temp.try_as('authenticated', v_unlinked, 'select count(*)::text from public.gts_report_facts'));

  v_out := v_out || pg_temp.line('no personal items in answers', '0',
    (select count(*)::text from public.gts_report_facts
      where answers ?| array['ched_1', 'ched_2', 'ched_3', 'ched_4', 'ched_5', 'ched_8']));

  raise exception 'gts_report_facts RLS results (rolled back):%', v_out;
end
$suite$;
