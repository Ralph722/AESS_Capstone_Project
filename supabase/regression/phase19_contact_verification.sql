begin;
-- Phase 19: contact verification (contact_email, contact_verifications,
-- contact_verification_start/check/cancel, apply_verified_contact and the
-- users guard changes). Uses alumnus A and the admin test account; code
-- hashes are plain strings here because the Edge Function computes the HMAC.
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

-- Lets the next code start without waiting out the 60 second gap.
create function pg_temp.age_codes() returns void
language sql as $$
  update public.contact_verifications
  set created_at = created_at - interval '61 seconds'
  where user_id = '6f6c569a-9ded-4c90-acab-19d78ab2a3f3';
$$;

create function pg_temp.start(p_channel text, p_target text, p_hash text, p_method text) returns jsonb
language sql as $$
  select public.contact_verification_start(
    '6f6c569a-9ded-4c90-acab-19d78ab2a3f3', p_channel, p_target, p_hash, p_method);
$$;

create function pg_temp.check_code(p_channel text, p_target text, p_hash text) returns jsonb
language sql as $$
  select public.contact_verification_check(
    '6f6c569a-9ded-4c90-acab-19d78ab2a3f3', p_channel, p_target, p_hash);
$$;

create temp table t(n int, test text, expected text, actual text);
delete from public.contact_verifications where user_id = '6f6c569a-9ded-4c90-acab-19d78ab2a3f3';

-- ===== 1. normalising =====
insert into t select 1, 'email trimmed and lower-cased', 'ana@gmail.com',
  public.contact_normalize_target('email', '  Ana@Gmail.COM ');
insert into t select 2, 'invalid email rejected', '(null)',
  coalesce(public.contact_normalize_target('email', 'ana@gmail'), '(null)');
insert into t select 3, 'PH mobile forms become 09XXXXXXXXX', '09171234567|09171234567|09171234567',
  public.contact_normalize_target('mobile', '+63 917 123 4567') || '|'
  || public.contact_normalize_target('mobile', '639171234567') || '|'
  || public.contact_normalize_target('mobile', '(917) 123-4567');
insert into t select 4, 'foreign mobile kept, junk rejected', '+14155550123|(null)',
  public.contact_normalize_target('mobile', '+1 415 555 0123') || '|'
  || coalesce(public.contact_normalize_target('mobile', '12345'), '(null)');

-- ===== 2. backfill and access =====
insert into t select 5, 'every active account has a contact email', '0',
  (select count(*)::text from public.users
   where anonymized_at is null and btrim(coalesce(email, '')) <> '' and contact_email = '');
insert into t select 6, 'alumni cannot read codes',
  'ERROR: permission denied',
  pg_temp.alumnus('select count(*)::text from public.contact_verifications');
insert into t select 7, 'alumni cannot start a code themselves',
  'ERROR: permission denied',
  pg_temp.alumnus('select public.contact_verification_start(auth.uid(), ''email'', ''a@b.co'', ''x'', ''email'')::text');
insert into t select 8, 'alumni cannot check a code themselves',
  'ERROR: permission denied',
  pg_temp.alumnus('select public.contact_verification_check(auth.uid(), ''email'', ''a@b.co'', ''x'')::text');

-- ===== 3. email: start, limits, check, apply =====
insert into t select 9, 'start returns the normalised target', 'true|p19-new@example.com|60',
  (select (j ->> 'ok') || '|' || (j ->> 'target') || '|' || (j ->> 'resendAfter')
   from pg_temp.start('email', ' P19-New@Example.com ', 'hash-111111', 'email') j);
insert into t select 10, 'second code within 60 seconds is refused', 'false|cooldown|true',
  (select (j ->> 'ok') || '|' || (j ->> 'error') || '|' || ((j ->> 'retryAfter')::int between 1 and 60)::text
   from pg_temp.start('email', 'p19-new@example.com', 'hash-222222', 'email') j);
insert into t select 11, 'email channel needs the email method', 'invalid_input',
  (select j ->> 'error' from pg_temp.start('email', 'p19-new@example.com', 'hash-1', 'mock') j);
-- Alumni cannot save email through apply_verified_contact (login-email path).
insert into t select 12, 'alumni cannot apply a verified email themselves',
  'ERROR: To change your email, verify it first.',
  pg_temp.alumnus('select public.apply_verified_contact(''email'', ''p19-new@example.com'')::text');
insert into t select 13, 'wrong code counts a try', 'false|wrong_code|4',
  (select (j ->> 'ok') || '|' || (j ->> 'error') || '|' || (j ->> 'attemptsLeft')
   from pg_temp.check_code('email', 'p19-new@example.com', 'hash-999999') j);
insert into t select 14, 'right code verifies (any letter case)', 'true|p19-new@example.com|email',
  (select (j ->> 'ok') || '|' || (j ->> 'target') || '|' || (j ->> 'method')
   from pg_temp.check_code('email', 'P19-NEW@example.com', 'hash-111111') j);
create function pg_temp.svc_apply(p_channel text, p_target text) returns text
language plpgsql as $$
declare r text;
begin
  begin
    r := public.service_apply_verified_contact(
      '6f6c569a-9ded-4c90-acab-19d78ab2a3f3', p_channel, p_target)::text;
  exception when others then
    r := 'ERROR: ' || sqlerrm;
  end;
  return r;
end $$;

insert into t select 15, 'service apply of a different email fails',
  'ERROR: This contact has not been verified.',
  pg_temp.svc_apply('email', 'other@example.com');
insert into t select 16, 'verified email is saved by the service path', 'true',
  (select public.service_apply_verified_contact(
     '6f6c569a-9ded-4c90-acab-19d78ab2a3f3', 'email', 'p19-new@example.com') ->> 'ok');
insert into t select 17, 'profile and roster both hold the new email', 'p19-new@example.com|true|p19-new@example.com',
  (select u.contact_email || '|' || (u.contact_email_verified_at is not null)::text || '|' || m.email_address
   from public.users u
   join public.alumni_members m on m.auth_uid = u.id
   where u.id = '6f6c569a-9ded-4c90-acab-19d78ab2a3f3');
-- Auth login is only changed by contact-verify apply_email; this suite does not.
insert into t select 18, 'login email unchanged without apply_email',
  (select email from auth.users where id = '6f6c569a-9ded-4c90-acab-19d78ab2a3f3'),
  (select email from public.users where id = '6f6c569a-9ded-4c90-acab-19d78ab2a3f3');
insert into t select 19, 'a verification is used only once',
  'ERROR: This contact has not been verified.',
  pg_temp.svc_apply('email', 'p19-new@example.com');

-- ===== 4. protected columns =====
select pg_temp.alumnus('update public.users set contact_email = ''hack@example.com'', contact_email_verified_at = now() where id = auth.uid()');
insert into t select 20, 'alumni cannot write the contact email directly', 'p19-new@example.com',
  (select contact_email from public.users where id = '6f6c569a-9ded-4c90-acab-19d78ab2a3f3');

-- ===== 5. mobile (mock) =====
insert into t select 21, 'mobile code starts in mock mode', 'true|09171234567',
  (select (j ->> 'ok') || '|' || (j ->> 'target')
   from pg_temp.start('mobile', '+63 917 123 4567', 'hash-333333', 'mock') j);
insert into t select 22, 'mobile code verifies', 'true|mock',
  (select (j ->> 'ok') || '|' || (j ->> 'method')
   from pg_temp.check_code('mobile', '0917 123 4567', 'hash-333333') j);
insert into t select 23, 'mock-checked number saved', 'true',
  pg_temp.alumnus('select (public.apply_verified_contact(''mobile'', ''09171234567'') ->> ''ok'')');
insert into t select 24, 'mock number is saved but not marked verified', '09171234567|mock|null|09171234567',
  (select u.mobile_number || '|' || u.mobile_verification_method || '|'
          || coalesce(u.mobile_verified_at::text, 'null') || '|' || m.contact_number
   from public.users u
   join public.alumni_members m on m.auth_uid = u.id
   where u.id = '6f6c569a-9ded-4c90-acab-19d78ab2a3f3');
select pg_temp.alumnus('update public.users set mobile_number = ''09998887777'' where id = auth.uid()');
-- Since 20261016030000 a number on file changes only through apply_verified_contact.
insert into t select 25, 'direct mobile change is ignored', '09171234567|mock',
  (select mobile_number || '|' || coalesce(mobile_verification_method, 'null')
   from public.users where id = '6f6c569a-9ded-4c90-acab-19d78ab2a3f3');

-- ===== 6. expiry, attempts and the hourly cap =====
select pg_temp.age_codes();
select pg_temp.start('email', 'p19-lock@example.com', 'hash-444444', 'email');
select pg_temp.check_code('email', 'p19-lock@example.com', 'bad-1');
select pg_temp.check_code('email', 'p19-lock@example.com', 'bad-2');
select pg_temp.check_code('email', 'p19-lock@example.com', 'bad-3');
select pg_temp.check_code('email', 'p19-lock@example.com', 'bad-4');
insert into t select 26, 'fifth wrong try ends the code', 'too_many_attempts',
  (select j ->> 'error' from pg_temp.check_code('email', 'p19-lock@example.com', 'bad-5') j);
insert into t select 27, 'right code no longer works after five wrong tries', 'too_many_attempts',
  (select j ->> 'error' from pg_temp.check_code('email', 'p19-lock@example.com', 'hash-444444') j);

select pg_temp.age_codes();
select pg_temp.start('email', 'p19-late@example.com', 'hash-555555', 'email');
update public.contact_verifications set expires_at = now() - interval '1 second'
where user_id = '6f6c569a-9ded-4c90-acab-19d78ab2a3f3' and target = 'p19-late@example.com';
insert into t select 28, 'expired code refused', 'expired',
  (select j ->> 'error' from pg_temp.check_code('email', 'p19-late@example.com', 'hash-555555') j);

select pg_temp.age_codes();
select pg_temp.start('email', 'p19-new-code@example.com', 'hash-666666', 'email');
insert into t select 29, 'a new code ends the previous unused one', 'expired',
  (select j ->> 'error' from pg_temp.check_code('email', 'p19-late@example.com', 'hash-555555') j);

select pg_temp.age_codes();
select pg_temp.start('email', 'p19-cap@example.com', 'hash-777777', 'email');
select pg_temp.age_codes();
insert into t select 30, 'sixth email code in an hour is refused', 'too_many_requests',
  (select j ->> 'error'
   from pg_temp.start('email', 'p19-cap@example.com', 'hash-888888', 'email') j);

-- ===== 7. login email changes and anonymizing =====
update public.users set email = 'p19-admin-new@example.com'
where id = '8a845be5-5870-437f-95e6-7ea3b0ad7a06'
  and contact_email = lower(btrim(email));
insert into t select 31, 'contact email follows the login email while they match', 'p19-admin-new@example.com',
  (select contact_email from public.users where id = '8a845be5-5870-437f-95e6-7ea3b0ad7a06');

update public.users set anonymized_at = now() where id = '6f6c569a-9ded-4c90-acab-19d78ab2a3f3';
insert into t select 32, 'anonymizing clears the contact email and the codes', '|0',
  (select u.contact_email || '|'
          || (select count(*) from public.contact_verifications c where c.user_id = u.id)::text
   from public.users u where u.id = '6f6c569a-9ded-4c90-acab-19d78ab2a3f3');

select n, test, expected,
  case when actual like '%' || expected || '%' then actual else 'MISMATCH: ' || actual end as actual
from t order by n;
rollback;
