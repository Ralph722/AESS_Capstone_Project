begin;
-- Phase 21: verified email becomes the login email (sync to roster,
-- contact_email_taken, service_apply, alumni apply_verified_contact closed
-- for email). Uses alumnus A and the admin test account.
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

create temp table t(n int, test text, expected text, actual text);
delete from public.contact_verifications
where user_id = '6f6c569a-9ded-4c90-acab-19d78ab2a3f3';

-- Known contact email for roster sync checks.
select set_config('app.contact_verified', 'on', true);
update public.users
set contact_email = 'p21-start@example.com',
    contact_email_verified_at = now()
where id = '6f6c569a-9ded-4c90-acab-19d78ab2a3f3';
select set_config('app.contact_verified', '', true);
update public.alumni_members
set email_address = 'p21-start@example.com',
    registered_email = (select email from auth.users
      where id = '6f6c569a-9ded-4c90-acab-19d78ab2a3f3')
where auth_uid = '6f6c569a-9ded-4c90-acab-19d78ab2a3f3';

-- ===== grants =====
insert into t select 1, 'alumni cannot call contact_email_taken', 'ERROR: permission denied',
  pg_temp.alumnus('select public.contact_email_taken(''x@y.co'', auth.uid())::text');
insert into t select 2, 'alumni cannot call service_apply_verified_contact', 'ERROR: permission denied',
  pg_temp.alumnus(
    'select public.service_apply_verified_contact(auth.uid(), ''email'', ''x@y.co'')::text');

-- ===== email taken =====
insert into t select 3, 'own login email is not taken for self', 'false',
  (select public.contact_email_taken(
     (select email from auth.users where id = '6f6c569a-9ded-4c90-acab-19d78ab2a3f3'),
     '6f6c569a-9ded-4c90-acab-19d78ab2a3f3')::text);
insert into t select 4, 'another account''s email is taken', 'true',
  (select public.contact_email_taken(
     (select email from auth.users where id = '8a845be5-5870-437f-95e6-7ea3b0ad7a06'),
     '6f6c569a-9ded-4c90-acab-19d78ab2a3f3')::text);
insert into t select 5, 'invalid email is not taken', 'false',
  (select public.contact_email_taken('not-an-email', null)::text);

-- ===== alumni apply closed for email; mobile still works =====
insert into t select 6, 'alumni apply_verified_contact refuses email',
  'ERROR: To change your email, verify it first.',
  pg_temp.alumnus('select public.apply_verified_contact(''email'', ''p21-new@example.com'')::text');

insert into public.contact_verifications
  (user_id, channel, target, code_hash, method, expires_at, verified_at)
values
  ('6f6c569a-9ded-4c90-acab-19d78ab2a3f3', 'mobile', '09171112233', 'p21-m', 'mock',
   now() + interval '10 minutes', now());
insert into t select 7, 'alumni can still apply a verified mobile', 'true',
  pg_temp.alumnus('select (public.apply_verified_contact(''mobile'', ''09171112233'') ->> ''ok'')');

-- ===== service apply email + Auth sync to roster =====
insert into public.contact_verifications
  (user_id, channel, target, code_hash, method, expires_at, verified_at)
values
  ('6f6c569a-9ded-4c90-acab-19d78ab2a3f3', 'email', 'p21-new@example.com', 'p21-e', 'email',
   now() + interval '10 minutes', now());

-- Simulate Auth email change (what apply_email does via Admin API).
update auth.users
set email = 'p21-new@example.com',
    email_confirmed_at = coalesce(email_confirmed_at, now()),
    updated_at = now()
where id = '6f6c569a-9ded-4c90-acab-19d78ab2a3f3';

insert into t select 8, 'auth email sync updates users.email', 'p21-new@example.com',
  (select email from public.users where id = '6f6c569a-9ded-4c90-acab-19d78ab2a3f3');
insert into t select 9, 'auth email sync updates registered_email', 'p21-new@example.com',
  (select registered_email from public.alumni_members
   where auth_uid = '6f6c569a-9ded-4c90-acab-19d78ab2a3f3');
insert into t select 10, 'auth email sync updates email_address', 'p21-new@example.com',
  (select email_address from public.alumni_members
   where auth_uid = '6f6c569a-9ded-4c90-acab-19d78ab2a3f3');

insert into t select 11, 'service apply saves contact email as verified', 'true|p21-new@example.com',
  (select (j ->> 'ok') || '|' || (j ->> 'target')
   from public.service_apply_verified_contact(
     '6f6c569a-9ded-4c90-acab-19d78ab2a3f3', 'email', 'p21-new@example.com') j);
insert into t select 12, 'contact email verified after service apply', 'p21-new@example.com|true',
  (select contact_email || '|' || (contact_email_verified_at is not null)::text
   from public.users where id = '6f6c569a-9ded-4c90-acab-19d78ab2a3f3');

select n, test, expected,
  case when actual like '%' || expected || '%' then actual else 'MISMATCH: ' || actual end as actual
from t order by n;
rollback;
