-- Auto-assign open published surveys to alumni who register, or who update
-- their program / batch, after the survey was published.
--
-- Matching mirrors lib/core/constants/audience_targeting.dart
-- (AudienceTargeting.matches). Keep the two in sync.
--
-- Per-survey opt-out: surveys.data->>'autoAssignNewAlumni' = 'false'.
-- Only ever adds assignments; never removes or resets existing ones.

begin;

-- ---------------------------------------------------------------------------
-- Matching helpers
-- ---------------------------------------------------------------------------

-- First 4-digit year from batch_year, falling back to year_graduated.
create or replace function public.profile_batch_year_digits(
  p_batch_year text,
  p_year_graduated text
)
returns text
language sql
immutable
as $$
  select substring(
    coalesce(nullif(trim(p_batch_year), ''), trim(coalesce(p_year_graduated, '')))
    from '\d{4}'
  );
$$;

-- True when p_year is covered by any target token (`2024` or `2020-2027`).
create or replace function public.batch_targets_include(
  p_targets text[],
  p_year text
)
returns boolean
language plpgsql
immutable
as $$
declare
  token text;
  parts text[];
  y integer;
begin
  if p_year is null or p_year !~ '^\d{4}$' then
    return false;
  end if;
  y := p_year::integer;

  foreach token in array coalesce(p_targets, '{}'::text[]) loop
    token := trim(token);
    if token ~ '^\d{4}$' then
      if token::integer = y then
        return true;
      end if;
    else
      parts := regexp_match(token, '^(\d{4})\s*[-–]\s*(\d{4})$');
      if parts is not null
         and y between least(parts[1]::integer, parts[2]::integer)
                   and greatest(parts[1]::integer, parts[2]::integer) then
        return true;
      end if;
    end if;
  end loop;

  return false;
end;
$$;

-- True when the profile program matches any target program.
create or replace function public.program_targets_include(
  p_targets text[],
  p_program text
)
returns boolean
language sql
immutable
as $$
  select trim(coalesce(p_program, '')) <> ''
    and exists (
      select 1
      from unnest(coalesce(p_targets, '{}'::text[])) as t(target)
      where trim(t.target) <> ''
        and lower(coalesce(public.normalize_course(t.target), trim(t.target)))
          = lower(coalesce(public.normalize_course(p_program), trim(p_program)))
    );
$$;

-- Survey audience check (empty filters = everyone).
create or replace function public.survey_audience_matches(
  p_target_programs text[],
  p_target_batch_years text[],
  p_program text,
  p_batch_year text,
  p_year_graduated text
)
returns boolean
language plpgsql
immutable
as $$
declare
  has_programs boolean;
  has_batches boolean;
begin
  select exists (
    select 1 from unnest(coalesce(p_target_programs, '{}'::text[])) t
    where trim(t) <> ''
  ) into has_programs;

  select exists (
    select 1 from unnest(coalesce(p_target_batch_years, '{}'::text[])) t
    where trim(t) <> ''
  ) into has_batches;

  if has_programs
     and not public.program_targets_include(p_target_programs, p_program) then
    return false;
  end if;

  if has_batches
     and not public.batch_targets_include(
       p_target_batch_years,
       public.profile_batch_year_digits(p_batch_year, p_year_graduated)
     ) then
    return false;
  end if;

  return true;
end;
$$;

-- ---------------------------------------------------------------------------
-- Assign every open, auto-assign-enabled survey the user matches
-- ---------------------------------------------------------------------------

create or replace function public.auto_assign_open_surveys(p_user_id uuid)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  u public.users%rowtype;
  s record;
  inserted_id uuid;
  assigned integer := 0;
begin
  select * into u from public.users where id = p_user_id;
  if not found or coalesce(u.role, 'user') = 'admin' then
    return 0;
  end if;

  for s in
    select sv.id, sv.title, sv.target_programs, sv.target_batch_years
    from public.surveys sv
    where sv.status = 'published'
      and coalesce(sv.data->>'archived', 'false') <> 'true'
      and coalesce(sv.data->>'autoAssignNewAlumni', 'true') <> 'false'
      and (sv.close_at is null or sv.close_at > now())
  loop
    if not public.survey_audience_matches(
      s.target_programs,
      s.target_batch_years,
      u.program,
      u.batch_year,
      u.year_graduated
    ) then
      continue;
    end if;

    inserted_id := null;
    insert into public.survey_assignments (
      survey_id, user_id, survey_title, status, assigned_at
    ) values (
      s.id, p_user_id, coalesce(s.title, ''), 'notStarted', now()
    )
    on conflict (survey_id, user_id) do nothing
    returning id into inserted_id;

    if inserted_id is null then
      continue;
    end if;

    assigned := assigned + 1;

    update public.surveys
    set assignment_count = assignment_count + 1
    where id = s.id;

    insert into public.user_notifications (
      user_id, title, body, type, is_read, data
    ) values (
      p_user_id,
      'New survey: ' || coalesce(s.title, ''),
      'Please complete the graduate tracer survey.',
      'survey',
      false,
      jsonb_build_object('relatedId', s.id::text, 'autoAssigned', true)
    );
  end loop;

  return assigned;
end;
$$;

revoke all on function public.auto_assign_open_surveys(uuid)
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Trigger: run on signup and when targeting fields change
-- ---------------------------------------------------------------------------

create or replace function public.trg_users_auto_assign_surveys()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'UPDATE'
     and new.program is not distinct from old.program
     and new.batch_year is not distinct from old.batch_year
     and new.year_graduated is not distinct from old.year_graduated
     and new.role is not distinct from old.role then
    return new;
  end if;

  -- Never block a signup or profile save because of assignment problems.
  begin
    perform public.auto_assign_open_surveys(new.id);
  exception when others then
    raise warning 'auto_assign_open_surveys failed for %: %', new.id, sqlerrm;
  end;

  return new;
end;
$$;

drop trigger if exists trg_users_auto_assign_surveys on public.users;
create trigger trg_users_auto_assign_surveys
after insert or update of program, batch_year, year_graduated, role
on public.users
for each row execute function public.trg_users_auto_assign_surveys();

-- ---------------------------------------------------------------------------
-- Registration: carry batch year from the official roster
-- ---------------------------------------------------------------------------

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
    batch_year,
    year_graduated,
    updated_at
  ) values (
    auth_user_id,
    'user',
    coalesce(nullif(p_full_name, ''), member.full_name),
    coalesce(p_email, ''),
    sid,
    course_norm,
    trim(coalesce(member.batch_year, '')),
    trim(coalesce(member.year_graduated, '')),
    now()
  )
  on conflict (id) do update set
    display_name = coalesce(nullif(excluded.display_name, ''), public.users.display_name),
    email = coalesce(nullif(excluded.email, ''), public.users.email),
    student_id = coalesce(nullif(excluded.student_id, ''), public.users.student_id),
    program = coalesce(nullif(excluded.program, ''), public.users.program),
    batch_year = coalesce(nullif(public.users.batch_year, ''), excluded.batch_year),
    year_graduated = coalesce(nullif(public.users.year_graduated, ''), excluded.year_graduated),
    updated_at = now();

  return jsonb_build_object(
    'ok', true,
    'memberId', member.id::text
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- One-time catch-up for alumni who registered after a survey was published
-- ---------------------------------------------------------------------------

do $$
declare
  r record;
begin
  for r in
    select id from public.users where coalesce(role, 'user') <> 'admin'
  loop
    perform public.auto_assign_open_surveys(r.id);
  end loop;
end;
$$;

commit;
