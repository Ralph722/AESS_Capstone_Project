-- Phase 4: replace Firebase Cloud Functions with Postgres RPCs.
-- validate_alumni_eligibility  → anon/authenticated (pre-registration)
-- link_alumni_registration     → authenticated only

begin;

create or replace function public.normalize_student_id(raw text)
returns text
language sql
immutable
as $$
  select upper(regexp_replace(trim(coalesce(raw, '')), '\s+', '', 'g'));
$$;

create or replace function public.normalize_person_name(raw text)
returns text
language sql
immutable
as $$
  select lower(regexp_replace(trim(coalesce(raw, '')), '\s+', ' ', 'g'));
$$;

create or replace function public.normalize_course(raw text)
returns text
language plpgsql
immutable
as $$
declare
  trimmed text := trim(coalesce(raw, ''));
  uppered text := upper(trimmed);
begin
  if uppered in ('BSIT', 'BFPT', 'BTLED-IA', 'BTLED-ICT', 'BTLED-HE') then
    return uppered;
  end if;
  if uppered in ('BTLED HE', 'BTLED- HE') then
    return 'BTLED-HE';
  end if;
  if uppered = 'BTLED IA' then
    return 'BTLED-IA';
  end if;
  if uppered = 'BTLED ICT' then
    return 'BTLED-ICT';
  end if;
  return null;
end;
$$;

-- Pre-registration eligibility check (no auth required).
create or replace function public.validate_alumni_eligibility(
  p_full_name text,
  p_student_id text,
  p_course text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  sid text := public.normalize_student_id(p_student_id);
  course text := public.normalize_course(p_course);
  member public.alumni_members%rowtype;
begin
  if trim(coalesce(p_full_name, '')) = '' or sid = '' or course is null then
    return jsonb_build_object(
      'eligible', false,
      'code', 'invalid_argument',
      'message', 'Full name, course, and ID number are required.'
    );
  end if;

  select * into member
  from public.alumni_members m
  where public.normalize_student_id(m.student_id) = sid
    and public.normalize_course(m.course) = course
  order by m.created_at desc
  limit 1;

  if not found then
    -- Also try stable legacy doc id pattern used by the Flutter app.
    select * into member
    from public.alumni_members m
    where m.legacy_firestore_id = regexp_replace(course || '_' || sid, '[^A-Za-z0-9_-]', '_', 'g')
    limit 1;
  end if;

  if not found then
    return jsonb_build_object(
      'eligible', false,
      'code', 'not_found',
      'message', 'You are not listed as an official alumni member. Please contact the alumni office.'
    );
  end if;

  if member.is_deactivated then
    return jsonb_build_object(
      'eligible', false,
      'code', 'failed_precondition',
      'message', 'This alumni record has been deactivated. Please contact the alumni office.'
    );
  end if;

  if member.is_registered_user
     and coalesce(member.auth_uid::text, '') <> '' then
    return jsonb_build_object(
      'eligible', false,
      'code', 'already_exists',
      'message', 'This ID number is already registered in the app. Try logging in or reset your password.'
    );
  end if;

  if public.normalize_person_name(member.full_name)
     <> public.normalize_person_name(p_full_name) then
    return jsonb_build_object(
      'eligible', false,
      'code', 'failed_precondition',
      'message', 'The full name does not match our official records. Use the exact name on your school records.'
    );
  end if;

  return jsonb_build_object(
    'eligible', true,
    'memberId', coalesce(member.legacy_firestore_id, member.id::text),
    'rosterFullName', coalesce(nullif(member.full_name, ''), p_full_name),
    'course', course,
    'studentId', sid
  );
end;
$$;

-- Post-auth roster + profile link (authenticated Supabase session required).
create or replace function public.link_alumni_registration(
  p_member_id text,
  p_full_name text,
  p_student_id text,
  p_course text,
  p_email text,
  p_legacy_firebase_uid text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  sid text := public.normalize_student_id(p_student_id);
  course text := public.normalize_course(p_course);
  email text := lower(trim(coalesce(p_email, '')));
  member public.alumni_members%rowtype;
  display_name text;
begin
  if uid is null then
    return jsonb_build_object(
      'success', false,
      'code', 'unauthenticated',
      'message', 'You must be signed in to complete registration.'
    );
  end if;

  if trim(coalesce(p_full_name, '')) = ''
     or sid = ''
     or course is null
     or trim(coalesce(p_member_id, '')) = ''
     or email = '' then
    return jsonb_build_object(
      'success', false,
      'code', 'invalid_argument',
      'message', 'Registration data is incomplete.'
    );
  end if;

  select * into member
  from public.alumni_members m
  where m.legacy_firestore_id = p_member_id
     or m.id::text = p_member_id
  limit 1;

  if not found then
    return jsonb_build_object(
      'success', false,
      'code', 'not_found',
      'message', 'Roster record not found. Please start registration again.'
    );
  end if;

  if public.normalize_student_id(member.student_id) <> sid
     or public.normalize_course(member.course) <> course then
    return jsonb_build_object(
      'success', false,
      'code', 'failed_precondition',
      'message', 'Roster details do not match. Please verify your information.'
    );
  end if;

  if public.normalize_person_name(member.full_name)
     <> public.normalize_person_name(p_full_name) then
    return jsonb_build_object(
      'success', false,
      'code', 'failed_precondition',
      'message', 'Full name does not match roster.'
    );
  end if;

  if member.is_registered_user
     and member.auth_uid is not null
     and member.auth_uid <> uid then
    return jsonb_build_object(
      'success', false,
      'code', 'already_exists',
      'message', 'This alumni ID is already linked to another account.'
    );
  end if;

  display_name := coalesce(nullif(member.full_name, ''), p_full_name);

  update public.alumni_members
  set
    auth_uid = uid,
    auth_legacy_firebase_uid = coalesce(p_legacy_firebase_uid, auth_legacy_firebase_uid),
    is_registered_user = true,
    registered_email = email,
    full_name = display_name,
    student_id = sid,
    course = course,
    updated_at = now()
  where id = member.id;

  insert into public.users as u (
    id,
    role,
    email,
    display_name,
    student_id,
    program,
    course,
    onboarding_complete,
    tracer_profile_completion,
    tracer_profile_complete,
    legacy_firebase_uid,
    last_active_at,
    updated_at
  )
  values (
    uid,
    'user',
    email,
    display_name,
    sid,
    course,
    course,
    false,
    0,
    false,
    p_legacy_firebase_uid,
    now(),
    now()
  )
  on conflict (id) do update
  set
    email = excluded.email,
    display_name = excluded.display_name,
    student_id = excluded.student_id,
    program = excluded.program,
    course = excluded.course,
    legacy_firebase_uid = coalesce(excluded.legacy_firebase_uid, u.legacy_firebase_uid),
    last_active_at = now(),
    updated_at = now();

  return jsonb_build_object(
    'success', true,
    'memberId', coalesce(member.legacy_firestore_id, member.id::text)
  );
end;
$$;

grant execute on function public.validate_alumni_eligibility(text, text, text)
  to anon, authenticated;

grant execute on function public.link_alumni_registration(text, text, text, text, text, text)
  to authenticated;

commit;
