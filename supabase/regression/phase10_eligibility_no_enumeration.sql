begin;
-- Phase 10: the anonymous eligibility check reveals roster status only when
-- name, course and ID all match. R = registered, D = deactivated, F = free.
create function pg_temp.check_as_anon(p_name text, p_sid text, p_course text) returns text
language plpgsql as $$
declare r text;
begin
  perform set_config('request.jwt.claims', json_build_object('role', 'anon')::text, true);
  set local role anon;
  begin
    select public.validate_alumni_eligibility(p_name, p_sid, p_course)->>'code' into r;
    r := coalesce(r, 'eligible');
  exception when others then
    r := 'ERROR: ' || sqlerrm;
  end;
  reset role;
  perform set_config('request.jwt.claims', '', true);
  return r;
end $$;

create temp table t(n int, test text, expected text, actual text);

insert into auth.users (id, instance_id, aud, role, email, email_confirmed_at)
values ('00000000-0000-4000-8000-00000000e1e1', '00000000-0000-0000-0000-000000000000',
        'authenticated', 'authenticated', 'enum-test-r@example.invalid', now());
insert into public.alumni_members (full_name, course, student_id, year_graduated, is_registered_user, auth_uid)
values ('Enum Registered', 'BSIT', '9999-1001', '2030', true, '00000000-0000-4000-8000-00000000e1e1');
insert into public.alumni_members (full_name, course, student_id, year_graduated, is_deactivated)
values ('Enum Deactivated', 'BSIT', '9999-1002', '2030', true);
insert into public.alumni_members (full_name, course, student_id, year_graduated)
values ('Enum Free', 'BSIT', '9999-1003', '2030');

-- Wrong name: every case looks like an unknown ID.
insert into t select 1, 'R with wrong name', 'not_found',
  pg_temp.check_as_anon('Someone Else', '9999-1001', 'BSIT');
insert into t select 2, 'D with wrong name', 'not_found',
  pg_temp.check_as_anon('Someone Else', '9999-1002', 'BSIT');
insert into t select 3, 'F with wrong name', 'not_found',
  pg_temp.check_as_anon('Someone Else', '9999-1003', 'BSIT');
insert into t select 4, 'unknown ID', 'not_found',
  pg_temp.check_as_anon('Someone Else', '9999-1999', 'BSIT');
insert into t select 5, 'R with wrong course', 'not_found',
  pg_temp.check_as_anon('Enum Registered', '9999-1001', 'BFPT');

-- Full match: status is shown to the record's owner.
insert into t select 6, 'R full match', 'already_exists',
  pg_temp.check_as_anon('enum  registered', '9999-1001', 'BSIT');
insert into t select 7, 'D full match', 'failed_precondition',
  pg_temp.check_as_anon('Enum Deactivated', '9999-1002', 'BSIT');
insert into t select 8, 'F full match', 'eligible',
  pg_temp.check_as_anon('Enum Free', '9999-1003', 'BSIT');

insert into t select 9, 'anon can still execute', 'yes',
  case when has_function_privilege('anon', 'public.validate_alumni_eligibility(text, text, text)', 'execute')
       then 'yes' else 'NO' end;

select n, test, expected, actual from t order by n;
rollback;
