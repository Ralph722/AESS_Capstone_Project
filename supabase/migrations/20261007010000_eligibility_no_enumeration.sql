-- Registration eligibility check no longer reveals roster facts to strangers.
--
-- validate_alumni_eligibility is callable without signing in. It used to look
-- the roster up by student ID + course alone and report "deactivated" or
-- "already registered" before comparing the name, so anyone with a guessed ID
-- could learn whether that person is an alumnus and has a portal account.
--
-- Now name, course and ID must all match one roster row first. Any mismatch
-- returns the same not_found message; status messages are only shown to
-- someone who already knows all three. link_alumni_registration still
-- re-checks everything on the server.

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
  course_norm text := public.normalize_course(p_course);
  name_norm text := public.normalize_person_name(p_full_name);
  member public.alumni_members%rowtype;
begin
  if trim(coalesce(p_full_name, '')) = '' or sid = '' or course_norm is null then
    return jsonb_build_object(
      'eligible', false,
      'code', 'invalid_argument',
      'message', 'Full name, course, and ID number are required.'
    );
  end if;

  select * into member
  from public.alumni_members m
  where public.normalize_student_id(m.student_id) = sid
    and public.normalize_course(m.course) = course_norm
    and public.normalize_person_name(m.full_name) = name_norm
  order by m.created_at desc
  limit 1;

  if not found then
    return jsonb_build_object(
      'eligible', false,
      'code', 'not_found',
      'message', 'We couldn''t find a matching alumni record. Check your full '
        || 'name, course and ID number exactly as they appear in your school '
        || 'records, or contact the alumni office.'
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
      'message', 'This alumni record already has an account. Log in, or use '
        || 'Forgot password if you can''t remember it. If you didn''t create '
        || 'this account, contact the alumni office.'
    );
  end if;

  return jsonb_build_object(
    'eligible', true,
    'memberId', member.id::text,
    'rosterFullName', coalesce(nullif(member.full_name, ''), p_full_name),
    'course', course_norm,
    'studentId', sid
  );
end;
$$;

revoke all on function public.validate_alumni_eligibility(text, text, text) from public;
grant execute on function public.validate_alumni_eligibility(text, text, text)
  to anon, authenticated, service_role;

notify pgrst, 'reload schema';
