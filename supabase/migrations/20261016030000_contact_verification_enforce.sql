-- Contact verification, part 2: changed contacts are saved only through
-- apply_verified_contact().
--
-- The tracer and Profile information now save Q3/Q5 and the contact fields
-- through apply_verified_contact. This closes the direct paths:
-- 1. users: an alumnus can type a mobile number directly only when none is
--    on file (first-time onboarding). Changing or clearing one is ignored;
--    it goes through apply_verified_contact.
-- 2. alumni_members: alumni can no longer write email_address or
--    contact_number. Other roster fields they keep in sync (address, gender,
--    ...) are unaffected; the two contact columns are kept, not rejected, so
--    the app's best-effort roster sync still saves the rest.
-- 3. users -> alumni_members mirror: whenever mobile_number or contact_email
--    changes on users (onboarding, apply_verified_contact, admin edits), the
--    linked roster row follows.
-- 4. Any change to a contact clears its verification, including admin
--    edits, except the change apply_verified_contact makes (it sets the
--    transaction-local flag app.contact_verified).

-- ---------------------------------------------------------------------------
-- 1. users
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
    if tg_op = 'UPDATE'
       and coalesce(current_setting('app.contact_verified', true), '') <> 'on' then
      if new.mobile_number is distinct from old.mobile_number then
        new.mobile_verified_at := null;
        new.mobile_verification_method := null;
      end if;
      if new.contact_email is distinct from old.contact_email then
        new.contact_email_verified_at := null;
      end if;
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
  if new.mobile_number is distinct from old.mobile_number
     and btrim(coalesce(old.mobile_number, '')) = '' then
    -- First number on file (onboarding): allowed, not verified.
    new.mobile_verified_at := null;
    new.mobile_verification_method := null;
  else
    new.mobile_number := old.mobile_number;
    new.mobile_verified_at := old.mobile_verified_at;
    new.mobile_verification_method := old.mobile_verification_method;
  end if;
  return new;
end;
$$;

-- Same as 20261016010000, plus the app.contact_verified flag around the
-- profile update so the guard keeps the verification it records.
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

  perform set_config('app.contact_verified', 'on', true);
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
  perform set_config('app.contact_verified', '', true);

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
-- 2. alumni_members
-- ---------------------------------------------------------------------------

create or replace function public.alumni_members_guard_owner_update()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if current_user not in ('authenticated', 'anon') or public.is_admin() then
    return new;
  end if;
  -- Mirrored from users (see users_mirror_contacts_to_roster).
  new.email_address := old.email_address;
  new.contact_number := old.contact_number;
  if new.id is distinct from old.id
     or new.full_name is distinct from old.full_name
     or new.course is distinct from old.course
     or new.student_id is distinct from old.student_id
     or new.auth_uid is distinct from old.auth_uid
     or new.registered_email is distinct from old.registered_email
     or new.is_registered_user is distinct from old.is_registered_user
     or new.is_deactivated is distinct from old.is_deactivated
     or new.admin_viewed_at is distinct from old.admin_viewed_at
     or new.year_graduated is distinct from old.year_graduated
     or new.created_at is distinct from old.created_at then
    raise exception 'Only the alumni office can change official roster details.'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- 3. Mirror
-- ---------------------------------------------------------------------------

create or replace function public.users_mirror_contacts_to_roster()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.alumni_members m
  set contact_number = case
        when new.mobile_number is distinct from old.mobile_number
          then coalesce(new.mobile_number, '')
        else m.contact_number
      end,
      email_address = case
        when new.contact_email is distinct from old.contact_email
          then coalesce(new.contact_email, '')
        else m.email_address
      end,
      updated_at = now()
  where m.auth_uid = new.id;
  return null;
end;
$$;

revoke all on function public.users_mirror_contacts_to_roster() from public, anon, authenticated;

drop trigger if exists users_mirror_contacts_to_roster on public.users;
create trigger users_mirror_contacts_to_roster
  after update of mobile_number, contact_email on public.users
  for each row
  when (new.mobile_number is distinct from old.mobile_number
        or new.contact_email is distinct from old.contact_email)
  execute function public.users_mirror_contacts_to_roster();
