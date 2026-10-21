-- Contact verification for the tracer (Q3 email, Q5 mobile) and Profile
-- information.
--
-- The contact email is separate from the login email: changing it never
-- changes how the alumnus signs in. A changed contact email or mobile number
-- is saved only after a one-time code has been checked.
--
-- 1. users gains contact_email and verification columns. Existing rows copy
--    their login email. A contact email equal to the login email counts as
--    verified (Supabase Auth confirmed it at registration).
-- 2. contact_verifications holds hashed 6-digit codes. Only the
--    contact-verify Edge Function (service role) reads or writes it.
-- 3. apply_verified_contact() is the only way a signed-in alumnus can save a
--    new contact email. Mobile numbers are still saved directly by the app
--    until the app switches to this function; a direct change clears any
--    verification.
-- 4. users_guard_protected_columns() locks the new columns, keeps the contact
--    email in step with login email changes, and clears contact data when an
--    account is anonymized.
--
-- SMS is not integrated yet. Mobile codes are "mock": the function shows the
-- code in the app instead of texting it, and the number is saved with
-- mobile_verification_method = 'mock' and mobile_verified_at = null, so it is
-- never reported as verified.

-- ---------------------------------------------------------------------------
-- 1. Columns
-- ---------------------------------------------------------------------------

alter table public.users
  add column if not exists contact_email text not null default '',
  add column if not exists contact_email_verified_at timestamptz,
  add column if not exists mobile_verified_at timestamptz,
  add column if not exists mobile_verification_method text;

alter table public.users
  drop constraint if exists users_mobile_verification_method_check,
  add constraint users_mobile_verification_method_check
    check (mobile_verification_method is null or mobile_verification_method in ('sms', 'mock'));

comment on column public.users.contact_email is
  'Email used for tracer and alumni contact. Not the login email. Verified when contact_email_verified_at is set or it equals email.';
comment on column public.users.mobile_verified_at is
  'Set only after a real SMS code check. Null for mock (SMS pending) or unverified numbers.';
comment on column public.users.mobile_verification_method is
  'sms = verified by text message; mock = code shown in the app while SMS is not integrated; null = never checked.';

-- One-off copy; updated_at is left alone so profiles don't all look edited.
alter table public.users disable trigger trg_users_updated_at;
update public.users
set contact_email = lower(btrim(email))
where contact_email = ''
  and btrim(coalesce(email, '')) <> ''
  and anonymized_at is null;
alter table public.users enable trigger trg_users_updated_at;

-- ---------------------------------------------------------------------------
-- 2. Normalising emails and mobile numbers
-- ---------------------------------------------------------------------------

-- Returns the stored form of a contact, or null when it is not valid.
-- Email: trimmed, lower case. Mobile: Philippine numbers become 09XXXXXXXXX;
-- other countries must be in +<country><number> form.
create or replace function public.contact_normalize_target(p_channel text, p_value text)
returns text
language plpgsql
immutable
set search_path = public
as $$
declare
  v text := btrim(coalesce(p_value, ''));
begin
  if p_channel = 'email' then
    v := lower(v);
    if length(v) > 254 or v !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then
      return null;
    end if;
    return v;
  elsif p_channel = 'mobile' then
    v := regexp_replace(v, '[[:space:]().-]', '', 'g');
    if v ~ '^\+63[0-9]{10}$' then
      v := '0' || substr(v, 4);
    elsif v ~ '^63[0-9]{10}$' then
      v := '0' || substr(v, 3);
    elsif v ~ '^9[0-9]{9}$' then
      v := '0' || v;
    end if;
    if v ~ '^09[0-9]{9}$' or v ~ '^\+[1-9][0-9]{7,14}$' then
      return v;
    end if;
    return null;
  end if;
  return null;
end;
$$;

grant execute on function public.contact_normalize_target(text, text)
  to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 3. Codes
-- ---------------------------------------------------------------------------

create table if not exists public.contact_verifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  channel text not null check (channel in ('email', 'mobile')),
  target text not null,
  code_hash text not null,
  method text not null check (method in ('email', 'sms', 'mock')),
  attempts integer not null default 0 check (attempts >= 0),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  verified_at timestamptz,
  consumed_at timestamptz,
  check ((channel = 'email') = (method = 'email'))
);

create index if not exists idx_contact_verifications_user_channel
  on public.contact_verifications (user_id, channel, created_at desc);

alter table public.contact_verifications enable row level security;
-- No permissive policies: clients cannot read or write; the service role and
-- the SECURITY DEFINER functions below bypass row level security.
drop policy if exists active_caller_only on public.contact_verifications;
create policy active_caller_only
  on public.contact_verifications as restrictive for all to authenticated
  using ((select public.caller_is_active()))
  with check ((select public.caller_is_active()));

revoke all on public.contact_verifications from anon, authenticated;

-- Records a new code. Limits: one code per channel every 60 seconds, five per
-- channel per hour. Starting a new code ends the previous unused one.
-- Returns {ok, id, target, expiresAt, resendAfter} or {ok:false, error, retryAfter?}.
create or replace function public.contact_verification_start(
  p_user_id uuid,
  p_channel text,
  p_target text,
  p_code_hash text,
  p_method text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_target text := public.contact_normalize_target(p_channel, p_target);
  v_last timestamptz;
  v_oldest_in_hour timestamptz;
  v_recent integer;
  v_id uuid;
  v_expires timestamptz := now() + interval '10 minutes';
begin
  if p_channel is null or p_channel not in ('email', 'mobile')
     or p_method is null or p_method not in ('email', 'sms', 'mock')
     or (p_channel = 'email') <> (p_method = 'email')
     or coalesce(p_code_hash, '') = '' then
    return jsonb_build_object('ok', false, 'error', 'invalid_input');
  end if;
  if v_target is null then
    return jsonb_build_object('ok', false, 'error', 'invalid_target');
  end if;
  if not exists (
    select 1 from public.users
    where id = p_user_id and deactivated_at is null and anonymized_at is null
  ) then
    return jsonb_build_object('ok', false, 'error', 'inactive_account');
  end if;

  perform pg_advisory_xact_lock(hashtext('contact_verification:' || p_user_id::text));

  delete from public.contact_verifications where created_at < now() - interval '1 day';

  select max(created_at),
         min(created_at) filter (where created_at > now() - interval '1 hour'),
         count(*) filter (where created_at > now() - interval '1 hour')
  into v_last, v_oldest_in_hour, v_recent
  from public.contact_verifications
  where user_id = p_user_id and channel = p_channel;

  if v_last is not null and v_last > now() - interval '60 seconds' then
    return jsonb_build_object(
      'ok', false, 'error', 'cooldown',
      'retryAfter', greatest(1, ceil(extract(epoch from (v_last + interval '60 seconds' - now())))::int));
  end if;
  if v_recent >= 5 then
    return jsonb_build_object(
      'ok', false, 'error', 'too_many_requests',
      'retryAfter', greatest(1, ceil(extract(epoch from (v_oldest_in_hour + interval '1 hour' - now())))::int));
  end if;

  update public.contact_verifications
  set expires_at = now()
  where user_id = p_user_id
    and channel = p_channel
    and verified_at is null
    and expires_at > now();

  insert into public.contact_verifications (user_id, channel, target, code_hash, method, expires_at)
  values (p_user_id, p_channel, v_target, p_code_hash, p_method, v_expires)
  returning id into v_id;

  return jsonb_build_object(
    'ok', true,
    'id', v_id,
    'target', v_target,
    'expiresAt', v_expires,
    'resendAfter', 60);
end;
$$;

-- Removes a code whose email could not be sent, so it does not count against
-- the resend limits.
create or replace function public.contact_verification_cancel(p_user_id uuid, p_id uuid)
returns void
language sql
security definer
set search_path = public
as $$
  delete from public.contact_verifications
  where id = p_id and user_id = p_user_id and verified_at is null;
$$;

-- Checks a code against the newest unused one for this contact. Five wrong
-- tries end the code. Returns {ok:true, target, method} or
-- {ok:false, error, attemptsLeft?} with error in
-- invalid_target | not_found | expired | too_many_attempts | wrong_code.
create or replace function public.contact_verification_check(
  p_user_id uuid,
  p_channel text,
  p_target text,
  p_code_hash text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_target text := public.contact_normalize_target(p_channel, p_target);
  r public.contact_verifications;
  v_attempts integer;
begin
  if v_target is null then
    return jsonb_build_object('ok', false, 'error', 'invalid_target');
  end if;

  select * into r
  from public.contact_verifications
  where user_id = p_user_id
    and channel = p_channel
    and target = v_target
    and consumed_at is null
  order by created_at desc
  limit 1
  for update;

  if not found then
    return jsonb_build_object('ok', false, 'error', 'not_found');
  end if;
  if r.verified_at is not null then
    return jsonb_build_object('ok', true, 'target', r.target, 'method', r.method);
  end if;
  if r.attempts >= 5 then
    return jsonb_build_object('ok', false, 'error', 'too_many_attempts');
  end if;
  if r.expires_at <= now() then
    return jsonb_build_object('ok', false, 'error', 'expired');
  end if;
  if r.code_hash <> coalesce(p_code_hash, '') then
    update public.contact_verifications
    set attempts = attempts + 1
    where id = r.id
    returning attempts into v_attempts;
    if v_attempts >= 5 then
      return jsonb_build_object('ok', false, 'error', 'too_many_attempts');
    end if;
    return jsonb_build_object('ok', false, 'error', 'wrong_code', 'attemptsLeft', 5 - v_attempts);
  end if;

  update public.contact_verifications set verified_at = now() where id = r.id;
  return jsonb_build_object('ok', true, 'target', r.target, 'method', r.method);
end;
$$;

revoke all on function public.contact_verification_start(uuid, text, text, text, text)
  from public, anon, authenticated;
revoke all on function public.contact_verification_cancel(uuid, uuid)
  from public, anon, authenticated;
revoke all on function public.contact_verification_check(uuid, text, text, text)
  from public, anon, authenticated;
grant execute on function public.contact_verification_start(uuid, text, text, text, text) to service_role;
grant execute on function public.contact_verification_cancel(uuid, uuid) to service_role;
grant execute on function public.contact_verification_check(uuid, text, text, text) to service_role;

-- ---------------------------------------------------------------------------
-- 4. Saving a verified contact (called by the app)
-- ---------------------------------------------------------------------------

-- Saves a contact the caller verified in the last 30 minutes, on the profile
-- and the roster mirror. Each verification can be used once.
create or replace function public.apply_verified_contact(p_channel text, p_target text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_target text := public.contact_normalize_target(p_channel, p_target);
  r public.contact_verifications;
begin
  if v_uid is null or not public.caller_is_active() then
    raise exception 'Sign in required.' using errcode = '42501';
  end if;
  if p_channel is null or p_channel not in ('email', 'mobile') or v_target is null then
    raise exception 'Enter a valid email address or mobile number.' using errcode = '22023';
  end if;

  select * into r
  from public.contact_verifications
  where user_id = v_uid
    and channel = p_channel
    and target = v_target
    and verified_at is not null
    and verified_at > now() - interval '30 minutes'
    and consumed_at is null
  order by verified_at desc
  limit 1
  for update;

  if not found then
    raise exception 'This contact has not been verified.' using errcode = '42501';
  end if;

  if p_channel = 'email' then
    update public.users
    set contact_email = v_target,
        contact_email_verified_at = r.verified_at,
        updated_at = now()
    where id = v_uid;
    update public.alumni_members
    set email_address = v_target,
        updated_at = now()
    where auth_uid = v_uid;
  else
    update public.users
    set mobile_number = v_target,
        mobile_verified_at = case when r.method = 'sms' then r.verified_at end,
        mobile_verification_method = r.method,
        updated_at = now()
    where id = v_uid;
    update public.alumni_members
    set contact_number = v_target,
        updated_at = now()
    where auth_uid = v_uid;
  end if;

  update public.contact_verifications set consumed_at = now() where id = r.id;

  return jsonb_build_object(
    'ok', true,
    'channel', p_channel,
    'target', v_target,
    'method', r.method,
    'verifiedAt', r.verified_at);
end;
$$;

revoke all on function public.apply_verified_contact(text, text) from public, anon;
grant execute on function public.apply_verified_contact(text, text) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 5. Protected columns
-- ---------------------------------------------------------------------------

create or replace function public.users_guard_protected_columns()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_privileged boolean := current_user not in ('authenticated', 'anon') or public.is_admin();
  v_sid text;
  v_course text;
  v_roster_year text;
  v_year text;
begin
  if tg_op = 'INSERT' then
    v_year := public.normalize_grad_year(new.year_graduated);
  elsif new.year_graduated is distinct from old.year_graduated then
    v_year := public.normalize_grad_year(new.year_graduated);
    if v_year = '' and not v_privileged then
      v_year := old.year_graduated;
    end if;
  else
    v_year := old.year_graduated;
  end if;
  if not v_privileged then
    select m.student_id, m.course, m.year_graduated
    into v_sid, v_course, v_roster_year
    from public.alumni_members m
    where m.auth_uid = new.id;
    if v_roster_year is not null then
      v_year := v_roster_year;
    end if;
  end if;
  new.year_graduated := coalesce(v_year, '');

  if tg_op = 'UPDATE' then
    -- Contact email follows the login email while the two are the same.
    if new.email is distinct from old.email
       and (old.contact_email = '' or old.contact_email = lower(btrim(coalesce(old.email, ''))))
       and new.contact_email is not distinct from old.contact_email then
      new.contact_email := lower(btrim(coalesce(new.email, '')));
      new.contact_email_verified_at := null;
    end if;
    if new.anonymized_at is not null and old.anonymized_at is null then
      new.contact_email := '';
      new.contact_email_verified_at := null;
      new.mobile_verified_at := null;
      new.mobile_verification_method := null;
    end if;
  elsif new.anonymized_at is not null then
    new.contact_email := '';
    new.contact_email_verified_at := null;
    new.mobile_verified_at := null;
    new.mobile_verification_method := null;
  end if;

  if v_privileged then
    if tg_op = 'INSERT' and new.contact_email = '' and new.anonymized_at is null then
      new.contact_email := lower(btrim(coalesce(new.email, '')));
    end if;
    return new;
  end if;
  if tg_op = 'INSERT' then
    new.role := 'user';
    new.email := coalesce(auth.jwt() ->> 'email', '');
    new.student_id := coalesce(v_sid, '');
    new.program := coalesce(v_course, '');
    new.deactivated_at := null;
    new.anonymized_at := null;
    new.contact_email := lower(btrim(new.email));
    new.contact_email_verified_at := null;
    new.mobile_verified_at := null;
    new.mobile_verification_method := null;
    return new;
  end if;
  new.id := old.id;
  new.role := old.role;
  new.email := old.email;
  new.student_id := old.student_id;
  new.program := old.program;
  new.created_at := old.created_at;
  new.deactivated_at := old.deactivated_at;
  new.anonymized_at := old.anonymized_at;
  new.contact_email := old.contact_email;
  new.contact_email_verified_at := old.contact_email_verified_at;
  if new.mobile_number is distinct from old.mobile_number then
    new.mobile_verified_at := null;
    new.mobile_verification_method := null;
  else
    new.mobile_verified_at := old.mobile_verified_at;
    new.mobile_verification_method := old.mobile_verification_method;
  end if;
  return new;
end;
$$;

-- Codes name the contact being checked, so they go when the account is
-- anonymized.
create or replace function public.users_clear_contact_verifications()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.contact_verifications where user_id = new.id;
  return null;
end;
$$;

revoke all on function public.users_clear_contact_verifications() from public, anon, authenticated;

drop trigger if exists users_clear_contact_verifications on public.users;
create trigger users_clear_contact_verifications
  after update of anonymized_at on public.users
  for each row
  when (new.anonymized_at is not null and old.anonymized_at is null)
  execute function public.users_clear_contact_verifications();
