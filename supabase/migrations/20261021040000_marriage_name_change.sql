-- Marriage-gated name change (docs/marriage-name-change-plan.md).
--
-- Alumni names are verified at registration and tied to the official roster,
-- so users.display_name is locked for alumni. The only self-service rename is
-- apply_marriage_name_change(), called from Tracer after the alumnus opts in
-- when civil status becomes Married. It updates the live name and the roster
-- name together and writes a NAME_CHANGE audit row for admin.

-- ---------------------------------------------------------------------------
-- 1. Lock users.display_name for non-privileged updates
--    (same body as 20261016030000, plus the display_name guard at the end)
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
  -- Name is verified at registration; only apply_marriage_name_change()
  -- (which sets the transaction-local flag) may change it for alumni.
  if coalesce(current_setting('app.allow_marriage_name_change', true), '') <> 'on' then
    new.display_name := old.display_name;
  end if;
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- 2. Optional rename after marriage: live + roster + audit
-- ---------------------------------------------------------------------------

create or replace function public.apply_marriage_name_change(p_new_name text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_new text := btrim(regexp_replace(coalesce(p_new_name, ''), '\s+', ' ', 'g'));
  v_old text;
  v_status text;
begin
  if v_uid is null or not public.caller_is_active() then
    raise exception 'Sign in required.' using errcode = '42501';
  end if;
  if v_new = '' or char_length(v_new) > 200 then
    raise exception 'Enter your full name.' using errcode = '22023';
  end if;

  select btrim(coalesce(display_name, '')), btrim(coalesce(civil_status, ''))
  into v_old, v_status
  from public.users
  where id = v_uid;
  if not found then
    raise exception 'Profile not found.' using errcode = 'P0002';
  end if;
  if lower(v_status) <> 'married' then
    raise exception 'Name can only be updated after setting civil status to Married.'
      using errcode = '42501';
  end if;
  if lower(v_old) = lower(v_new) then
    return jsonb_build_object('ok', true, 'changed', false, 'from', v_old, 'to', v_old);
  end if;

  perform set_config('app.allow_marriage_name_change', 'on', true);
  update public.users
  set display_name = v_new,
      updated_at = now()
  where id = v_uid;
  perform set_config('app.allow_marriage_name_change', '', true);

  update public.alumni_members
  set full_name = v_new,
      updated_at = now()
  where auth_uid = v_uid;

  insert into public.audit_logs (user_id, action, entity_type, entity_id, details)
  values (
    v_uid,
    'NAME_CHANGE',
    'Profile',
    v_uid::text,
    jsonb_build_object(
      'description', 'Name updated after setting civil status to Married in Tracer',
      'changes', jsonb_build_object(
        'from', v_old,
        'to', v_new,
        'reason', 'civil_status_married',
        'source', 'tracer'
      ),
      'status', 'SUCCESS',
      'userRole', 'user'
    )
  );

  return jsonb_build_object('ok', true, 'changed', true, 'from', v_old, 'to', v_new);
end;
$$;

revoke all on function public.apply_marriage_name_change(text) from public, anon;
grant execute on function public.apply_marriage_name_change(text) to authenticated, service_role;
