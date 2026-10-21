-- Part 2 of contact verification: a verified contact email becomes the
-- login email.
--
-- 1. When auth.users.email changes, sync also updates the roster's
--    registered_email and email_address (messaging and admin views use them).
-- 2. Alumni can no longer save an email through apply_verified_contact; that
--    path is only for mobile. Email is applied by the contact-verify Edge
--    Function (service role) after it changes the Auth login email.
-- 3. service_apply_verified_contact(p_user_id, ...) is the service-role twin
--    of apply_verified_contact, used by that function.
-- 4. contact_email_taken(email, except_user) lets the function refuse an
--    address that already belongs to another account.

-- ---------------------------------------------------------------------------
-- 1. Auth email sync also updates the roster
-- ---------------------------------------------------------------------------

create or replace function public.sync_user_email_from_auth()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_email text := lower(btrim(coalesce(new.email, '')));
begin
  update public.users
  set email = coalesce(new.email, ''),
      updated_at = now()
  where id = new.id
    and email is distinct from coalesce(new.email, '');

  -- Messaging and admin directory prefer registered_email; email_address is
  -- the contact mirror (also kept by users_mirror_contacts_to_roster when
  -- contact_email changes).
  update public.alumni_members
  set registered_email = nullif(v_email, ''),
      email_address = coalesce(nullif(v_email, ''), email_address),
      updated_at = now()
  where auth_uid = new.id
    and (
      registered_email is distinct from nullif(v_email, '')
      or email_address is distinct from coalesce(nullif(v_email, ''), email_address)
    );

  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- 2. Email-taken check (service role / Edge Function)
-- ---------------------------------------------------------------------------

create or replace function public.contact_email_taken(
  p_email text,
  p_except_user_id uuid default null
)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_email text := public.contact_normalize_target('email', p_email);
begin
  if v_email is null then
    return false;
  end if;
  return exists (
    select 1
    from auth.users a
    where lower(btrim(coalesce(a.email, ''))) = v_email
      and (p_except_user_id is null or a.id <> p_except_user_id)
  );
end;
$$;

revoke all on function public.contact_email_taken(text, uuid)
  from public, anon, authenticated;
grant execute on function public.contact_email_taken(text, uuid) to service_role;

-- ---------------------------------------------------------------------------
-- 3. Service-role apply (email and mobile)
-- ---------------------------------------------------------------------------

create or replace function public.service_apply_verified_contact(
  p_user_id uuid,
  p_channel text,
  p_target text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_target text := public.contact_normalize_target(p_channel, p_target);
  r public.contact_verifications;
begin
  if p_user_id is null then
    raise exception 'User required.' using errcode = '22023';
  end if;
  if p_channel is null or p_channel not in ('email', 'mobile') or v_target is null then
    raise exception 'Enter a valid email address or mobile number.' using errcode = '22023';
  end if;
  if not exists (
    select 1 from public.users u
    where u.id = p_user_id and u.anonymized_at is null and u.deactivated_at is null
  ) then
    raise exception 'Sign in required.' using errcode = '42501';
  end if;

  select * into r
  from public.contact_verifications
  where user_id = p_user_id
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
    where id = p_user_id;
    update public.alumni_members
    set email_address = v_target,
        registered_email = v_target,
        updated_at = now()
    where auth_uid = p_user_id;
  else
    update public.users
    set mobile_number = v_target,
        mobile_verified_at = case when r.method = 'sms' then r.verified_at end,
        mobile_verification_method = r.method,
        updated_at = now()
    where id = p_user_id;
    update public.alumni_members
    set contact_number = v_target,
        updated_at = now()
    where auth_uid = p_user_id;
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

revoke all on function public.service_apply_verified_contact(uuid, text, text)
  from public, anon, authenticated;
grant execute on function public.service_apply_verified_contact(uuid, text, text)
  to service_role;

-- ---------------------------------------------------------------------------
-- 4. Alumni apply_verified_contact: mobile only
-- ---------------------------------------------------------------------------

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
  if p_channel = 'email' then
    raise exception
      'To change your email, verify it first. Your sign-in email will update too.'
      using errcode = '42501';
  end if;
  if p_channel is null or p_channel <> 'mobile' or v_target is null then
    raise exception 'Enter a valid mobile number.' using errcode = '22023';
  end if;

  select * into r
  from public.contact_verifications
  where user_id = v_uid
    and channel = 'mobile'
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
  perform set_config('app.contact_verified', '', true);

  update public.contact_verifications set consumed_at = now() where id = r.id;

  return jsonb_build_object(
    'ok', true,
    'channel', 'mobile',
    'target', v_target,
    'method', r.method,
    'verifiedAt', r.verified_at);
end;
$$;

revoke all on function public.apply_verified_contact(text, text) from public, anon;
grant execute on function public.apply_verified_contact(text, text)
  to authenticated, service_role;

comment on function public.apply_verified_contact(text, text) is
  'Alumni save a verified mobile number. Emails go through contact-verify apply_email so the login email changes too.';
comment on function public.service_apply_verified_contact(uuid, text, text) is
  'Service-role apply used by contact-verify after changing auth.users.email.';
