-- Drop redundant / unused columns after GTS profile consolidation.

begin;

-- Consolidate contact fields onto mobile_number (never NULL — column is NOT NULL).
update public.users
set mobile_number = coalesce(
  nullif(mobile_number, ''),
  nullif(contact_number, ''),
  nullif(phone_number, ''),
  ''
)
where coalesce(mobile_number, '') = '';

-- Consolidate duplicate program/course on users.
update public.users
set program = course
where coalesce(program, '') = ''
  and coalesce(course, '') <> '';

alter table public.users
  drop column if exists contact_number,
  drop column if exists phone_number,
  drop column if exists course;

alter table public.alumni_members
  drop column if exists linkedin_url;

-- Idempotent cleanup for any legacy bridge columns still present.
alter table public.users drop column if exists legacy_firebase_uid;
alter table public.events drop column if exists legacy_firestore_id;
alter table public.jobs drop column if exists legacy_firestore_id;
alter table public.announcements drop column if exists legacy_firestore_id;
alter table public.messages
  drop column if exists legacy_firestore_id,
  drop column if exists sender_legacy_firebase_uid,
  drop column if exists recipient_legacy_firebase_uid;
alter table public.feedback drop column if exists legacy_firestore_id;
alter table public.forum_topics
  drop column if exists legacy_firestore_id,
  drop column if exists author_legacy_firebase_uid;
alter table public.forum_posts
  drop column if exists legacy_firestore_id,
  drop column if exists author_legacy_firebase_uid,
  drop column if exists topic_legacy_firestore_id;
alter table public.survey_templates drop column if exists legacy_firestore_id;
alter table public.survey_template_questions drop column if exists legacy_firestore_id;
alter table public.surveys
  drop column if exists legacy_firestore_id,
  drop column if exists template_legacy_firestore_id,
  drop column if exists created_by_legacy_firebase_uid;
alter table public.survey_questions drop column if exists legacy_firestore_id;
alter table public.survey_assignments
  drop column if exists legacy_firestore_id,
  drop column if exists legacy_firebase_user_id,
  drop column if exists survey_legacy_firestore_id;
alter table public.survey_responses
  drop column if exists legacy_firebase_user_id;
alter table public.alumni_members
  drop column if exists legacy_firestore_id,
  drop column if exists auth_legacy_firebase_uid;
alter table public.user_notifications drop column if exists legacy_firestore_id;

create or replace function public.link_alumni_registration(
  p_member_id text,
  p_full_name text,
  p_student_id text,
  p_course text,
  p_email text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  sid text := public.normalize_student_id(p_student_id);
  course_norm text := public.normalize_course(p_course);
  member public.alumni_members%rowtype;
  auth_user_id uuid := auth.uid();
begin
  if auth_user_id is null then
    return jsonb_build_object(
      'ok', false,
      'code', 'unauthenticated',
      'message', 'You must be signed in to complete registration.'
    );
  end if;

  if p_member_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    select * into member
    from public.alumni_members m
    where m.id = p_member_id::uuid
    limit 1;
  end if;

  if not found then
    select * into member
    from public.alumni_members m
    where public.normalize_student_id(m.student_id) = sid
      and public.normalize_course(m.course) = course_norm
    order by m.created_at desc
    limit 1;
  end if;

  if not found then
    return jsonb_build_object(
      'ok', false,
      'code', 'not_found',
      'message', 'Alumni roster record was not found.'
    );
  end if;

  update public.alumni_members
  set
    is_registered_user = true,
    auth_uid = auth_user_id,
    registered_email = coalesce(nullif(p_email, ''), registered_email),
    updated_at = now()
  where id = member.id;

  insert into public.users (
    id,
    role,
    display_name,
    email,
    student_id,
    program,
    updated_at
  ) values (
    auth_user_id,
    'user',
    coalesce(nullif(p_full_name, ''), member.full_name),
    coalesce(p_email, ''),
    sid,
    course_norm,
    now()
  )
  on conflict (id) do update set
    display_name = coalesce(nullif(excluded.display_name, ''), public.users.display_name),
    email = coalesce(nullif(excluded.email, ''), public.users.email),
    student_id = coalesce(nullif(excluded.student_id, ''), public.users.student_id),
    program = coalesce(nullif(excluded.program, ''), public.users.program),
    updated_at = now();

  return jsonb_build_object(
    'ok', true,
    'memberId', member.id::text
  );
end;
$$;

commit;
