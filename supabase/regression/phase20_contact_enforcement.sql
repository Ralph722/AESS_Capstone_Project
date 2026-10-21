begin;
-- Phase 20: contact verification part 2 (direct contact writes closed,
-- users -> roster mirror). Uses alumnus A and the admin test account.
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

create function pg_temp.alumnus(p_sql text) returns text
language sql as $$
  select pg_temp.try_as('authenticated', '6f6c569a-9ded-4c90-acab-19d78ab2a3f3', p_sql);
$$;

create function pg_temp.admin(p_sql text) returns text
language sql as $$
  select pg_temp.try_as('authenticated', '8a845be5-5870-437f-95e6-7ea3b0ad7a06', p_sql);
$$;

create function pg_temp.a_contacts() returns text
language sql as $$
  select u.mobile_number || '|' || coalesce(u.mobile_verification_method, 'null') || '|'
         || m.contact_number || '|' || u.contact_email || '|' || m.email_address
  from public.users u
  join public.alumni_members m on m.auth_uid = u.id
  where u.id = '6f6c569a-9ded-4c90-acab-19d78ab2a3f3';
$$;

create temp table t(n int, test text, expected text, actual text);
delete from public.contact_verifications where user_id = '6f6c569a-9ded-4c90-acab-19d78ab2a3f3';

-- Known starting point (as the service role, recorded like a verification).
select set_config('app.contact_verified', 'on', true);
update public.users
set mobile_number = '09171234567', mobile_verification_method = 'mock',
    contact_email = 'p20-start@example.com'
where id = '6f6c569a-9ded-4c90-acab-19d78ab2a3f3';
select set_config('app.contact_verified', '', true);
insert into t select 1, 'mirror copies users contacts to the roster',
  '09171234567|mock|09171234567|p20-start@example.com|p20-start@example.com',
  pg_temp.a_contacts();

-- ===== direct writes =====
select pg_temp.alumnus('update public.users set mobile_number = ''09998887777'' where id = auth.uid()');
insert into t select 2, 'alumni cannot change a mobile number on file directly',
  '09171234567|mock|09171234567', pg_temp.a_contacts();
select pg_temp.alumnus('update public.users set mobile_number = '''' where id = auth.uid()');
insert into t select 3, 'alumni cannot clear it either', '09171234567|mock', pg_temp.a_contacts();

create temp table p20_r4 on commit drop as
select pg_temp.alumnus('update public.alumni_members set contact_number = ''09990000000'', email_address = ''p20-hack@example.com'', address = ''P20 Street'' where auth_uid = auth.uid()') as r;
insert into t select 4, 'roster contact columns are kept, other fields still save', 'ok|09171234567|p20-start@example.com|P20 Street',
  (select r from p20_r4)
  || (select '|' || coalesce(contact_number, '') || '|' || coalesce(email_address, '') || '|' || coalesce(address, '')
      from public.alumni_members where auth_uid = '6f6c569a-9ded-4c90-acab-19d78ab2a3f3');

-- ===== first number on file =====
update public.users set mobile_number = '', mobile_verification_method = null
where id = '6f6c569a-9ded-4c90-acab-19d78ab2a3f3';
select pg_temp.alumnus('update public.users set mobile_number = ''09175550000'' where id = auth.uid()');
insert into t select 5, 'first number on file can be typed directly (not verified)',
  '09175550000|null|09175550000', pg_temp.a_contacts();

-- ===== verified path still works =====
select public.contact_verification_start('6f6c569a-9ded-4c90-acab-19d78ab2a3f3', 'mobile', '09176660000', 'h20', 'mock');
select public.contact_verification_check('6f6c569a-9ded-4c90-acab-19d78ab2a3f3', 'mobile', '09176660000', 'h20');
insert into t select 6, 'verified mobile saves and mirrors', 'true',
  pg_temp.alumnus('select (public.apply_verified_contact(''mobile'', ''09176660000'') ->> ''ok'')');
insert into t select 7, '... on users and the roster', '09176660000|mock|09176660000', pg_temp.a_contacts();

-- ===== admins =====
insert into t select 8, 'admin can still edit a mobile number', 'ok',
  pg_temp.admin('update public.users set mobile_number = ''09177770000'' where id = ''6f6c569a-9ded-4c90-acab-19d78ab2a3f3''');
insert into t select 9, '... and the roster follows', '09177770000|null|09177770000', pg_temp.a_contacts();

select n, test, expected,
  case when actual like '%' || expected || '%' then actual else 'MISMATCH: ' || actual end as actual
from t order by n;
rollback;
