-- Phase 7: legacy cleanup.
--
-- 1. Drop unused legacy tables: notifications (replaced by user_notifications),
--    reminders (event reminders come from RSVPs), archived_employment_records
--    (employment comes from CHED GTS answers since Phase 5).
-- 2. Drop the roster employment mirror columns (current_position,
--    current_company); nothing writes them any more.
-- 3. Drop users.batch_year and alumni_members.batch_year. Batch is the
--    graduation year (year_graduated). events.batch_year, dss_flags.batch_year
--    and surveys.target_batch_years are unrelated and stay.
-- 4. Typed event times: events.starts_at / ends_at, derived from the
--    date + start_time/end_time text by a trigger. Server reminders use them.

-- ---------------------------------------------------------------------------
-- 1. Legacy tables
-- ---------------------------------------------------------------------------

drop table if exists public.notifications;
drop table if exists public.reminders;
drop table if exists public.archived_employment_records;

-- ---------------------------------------------------------------------------
-- 2. Roster employment mirror columns
-- ---------------------------------------------------------------------------

create or replace function public.admin_remove_alumni_account(p_member_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin uuid := auth.uid();
  v_member public.alumni_members%rowtype;
  v_uid uuid;
  v_avatar text;
  v_placeholder text;
  v_anon_name constant text := 'Deleted alumni';
begin
  if v_admin is null or not public.is_admin() then
    raise exception 'Admin access required.' using errcode = '42501';
  end if;
  select * into v_member from public.alumni_members where id = p_member_id for update;
  if not found then
    raise exception 'Roster entry not found.';
  end if;
  v_uid := v_member.auth_uid;
  if v_uid is null then
    raise exception 'This roster entry has no linked portal account.';
  end if;
  if v_uid = v_admin then
    raise exception 'You cannot remove your own account.' using errcode = '42501';
  end if;
  if exists (select 1 from public.users where id = v_uid and role = 'admin') then
    raise exception 'Admin accounts cannot be removed here.' using errcode = '42501';
  end if;
  select profile_image_base64 into v_avatar from public.users where id = v_uid;
  v_placeholder := 'removed+' || v_uid::text || '@removed.invalid';
  update auth.users
  set email = v_placeholder,
      phone = null,
      raw_user_meta_data = jsonb_build_object('display_name', v_anon_name),
      banned_until = '2999-12-31 00:00:00+00',
      updated_at = now()
  where id = v_uid;
  update auth.identities
  set identity_data = coalesce(identity_data, '{}'::jsonb)
        || jsonb_build_object('email', v_placeholder, 'email_verified', false),
      updated_at = now()
  where user_id = v_uid;
  delete from auth.sessions where user_id = v_uid;
  update public.users
  set display_name = v_anon_name,
      email = '',
      student_id = '',
      address = '',
      birth_date = null,
      telephone_number = '',
      mobile_number = '',
      honors_awards = '',
      profile_image_base64 = null,
      deactivated_at = coalesce(deactivated_at, now()),
      anonymized_at = now(),
      updated_at = now()
  where id = v_uid;
  update public.survey_responses
  set answers = answers - array['ched_1', 'ched_2', 'ched_3', 'ched_4', 'ched_5', 'ched_8']
  where user_id = v_uid;
  update public.messages
  set sender_name = v_anon_name, sender_email = ''
  where sender_id = v_uid;
  update public.forum_topics
  set author_name = v_anon_name, author_program = '', author_batch = ''
  where author_uid = v_uid;
  update public.forum_posts
  set author_name = v_anon_name
  where author_uid = v_uid;
  update public.audit_logs
  set details = details || jsonb_build_object('userName', v_anon_name, 'userEmail', '')
  where user_id = v_uid;
  delete from public.push_tokens where user_id = v_uid;
  delete from public.notification_preferences where user_id = v_uid;
  delete from public.tracer_draft_reminders where user_id = v_uid;
  update public.alumni_members
  set auth_uid = null,
      is_registered_user = false,
      registered_email = null,
      is_deactivated = true,
      contact_number = '',
      email_address = '',
      address = null,
      birth_date = null,
      gender = null,
      civil_status = null,
      profile_image_url = null,
      tracer_profile_complete = false,
      has_profile_updates = false,
      updated_at = now()
  where id = p_member_id;
  insert into public.audit_logs (user_id, action, entity_type, entity_id, details)
  values (
    v_admin,
    'REMOVE_ALUMNI_ACCOUNT',
    'AlumniMember',
    p_member_id::text,
    jsonb_build_object(
      'description', 'Removed portal account for ' || v_member.full_name
        || ' (deactivated and anonymized; tracer answers kept)',
      'status', 'SUCCESS',
      'changes', jsonb_build_object('authUid', v_uid::text)
    )
  );
  return jsonb_build_object(
    'ok', true,
    'userId', v_uid,
    'avatarUrl', v_avatar
  );
end;
$$;

alter table public.alumni_members
  drop column if exists current_position,
  drop column if exists current_company;

-- ---------------------------------------------------------------------------
-- 3. batch_year -> year_graduated
-- ---------------------------------------------------------------------------

create or replace function public.survey_audience_matches(
  p_target_programs text[],
  p_target_batch_years text[],
  p_program text,
  p_year_graduated text
)
returns boolean
language plpgsql
immutable
set search_path = public
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
       substring(trim(coalesce(p_year_graduated, '')) from '\d{4}')
     ) then
    return false;
  end if;
  return true;
end;
$$;

revoke all on function public.survey_audience_matches(text[], text[], text, text) from public, anon;
grant execute on function public.survey_audience_matches(text[], text[], text, text) to authenticated, service_role;

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
      s.target_programs, s.target_batch_years,
      u.program, u.year_graduated
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
  end loop;
  return assigned;
end;
$$;

create or replace function public.notify_announcement_published()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  recipients uuid[];
  excerpt text;
  is_urgent boolean;
begin
  begin
    if coalesce(new.status, '') <> 'published' then
      return new;
    end if;
    if tg_op = 'UPDATE' and old.status = 'published' then
      return new;
    end if;
    if lower(coalesce(new.data->>'notifyInApp', 'true')) = 'false' then
      return new;
    end if;
    recipients := array(
      select u.id
      from public.users u
      where u.id = any (public.notification_active_alumni_ids())
        and public.survey_audience_matches(
          public.notification_jsonb_text_array(new.data->'targetPrograms'),
          public.notification_jsonb_text_array(new.data->'targetBatchYears'),
          u.program, u.year_graduated
        )
    );
    excerpt := case when length(coalesce(new.body, '')) > 200
      then left(new.body, 200) || '…' else coalesce(new.body, '') end;
    is_urgent := lower(coalesce(new.data->>'urgent', 'false')) = 'true';
    perform public.enqueue_notifications(
      recipients,
      'announcement',
      new.title,
      excerpt,
      jsonb_build_object('relatedId', new.id::text, 'announcementId', new.id::text),
      case when is_urgent then 'urgent' else 'normal' end,
      'announcement:' || new.id::text || ':published',
      'announcement/' || new.id::text,
      lower(coalesce(new.data->>'notifyPush', 'true')) <> 'false'
    );
  exception when others then
    raise warning 'notify_announcement_published(%): %', new.id, sqlerrm;
  end;
  return new;
end;
$$;

drop function if exists public.survey_audience_matches(text[], text[], text, text, text);
drop function if exists public.profile_batch_year_digits(text, text);

drop function if exists public.get_public_profiles(uuid[]);
create function public.get_public_profiles(p_ids uuid[])
returns table (
  id uuid,
  display_name text,
  profile_image_base64 text,
  program text,
  year_graduated text,
  role text,
  email text
)
language sql
stable
security definer
set search_path = public
as $$
  select
    u.id,
    case
      when u.anonymized_at is not null then 'Deleted alumni'
      when nullif(trim(u.display_name), '') is not null then u.display_name
      when u.role = 'admin' then 'Admin'
      else 'Alumnus'
    end,
    case when u.anonymized_at is null then u.profile_image_base64 end,
    u.program,
    u.year_graduated,
    u.role,
    case when public.is_admin() or u.id = auth.uid() then u.email else '' end
  from public.users u
  where public.is_signed_in()
    and u.id = any (p_ids[1:500]);
$$;

revoke all on function public.get_public_profiles(uuid[]) from public, anon;
grant execute on function public.get_public_profiles(uuid[]) to authenticated, service_role;

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
  uid uuid := auth.uid();
  sid text := public.normalize_student_id(p_student_id);
  course_norm text := public.normalize_course(p_course);
  member public.alumni_members%rowtype;
  account_email text;
  confirmed_at timestamptz;
begin
  if uid is null then
    return jsonb_build_object(
      'ok', false,
      'code', 'unauthenticated',
      'message', 'You must be signed in to complete registration.'
    );
  end if;
  select lower(u.email), u.email_confirmed_at
  into account_email, confirmed_at
  from auth.users u
  where u.id = uid;
  if confirmed_at is null then
    return jsonb_build_object(
      'ok', false,
      'code', 'failed_precondition',
      'message', 'Verify your email address before completing registration.'
    );
  end if;
  if coalesce(p_member_id, '') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    return jsonb_build_object(
      'ok', false,
      'code', 'not_found',
      'message', 'Alumni roster record was not found.'
    );
  end if;
  select * into member
  from public.alumni_members m
  where m.id = p_member_id::uuid
  for update;
  if not found then
    return jsonb_build_object(
      'ok', false,
      'code', 'not_found',
      'message', 'Alumni roster record was not found.'
    );
  end if;
  if public.normalize_student_id(member.student_id) <> sid
     or public.normalize_course(member.course) is distinct from course_norm
     or public.normalize_person_name(member.full_name) <> public.normalize_person_name(p_full_name) then
    return jsonb_build_object(
      'ok', false,
      'code', 'failed_precondition',
      'message', 'Your details do not match the official alumni roster.'
    );
  end if;
  if member.is_deactivated then
    return jsonb_build_object(
      'ok', false,
      'code', 'failed_precondition',
      'message', 'This alumni record has been deactivated. Please contact the alumni office.'
    );
  end if;
  if member.auth_uid is not null and member.auth_uid <> uid then
    return jsonb_build_object(
      'ok', false,
      'code', 'already_exists',
      'message', 'This ID number is already registered. Try logging in instead.'
    );
  end if;
  if exists (
    select 1 from public.alumni_members m
    where m.auth_uid = uid and m.id <> member.id
  ) then
    return jsonb_build_object(
      'ok', false,
      'code', 'already_exists',
      'message', 'This account is already linked to another alumni record.'
    );
  end if;
  update public.alumni_members
  set
    is_registered_user = true,
    auth_uid = uid,
    registered_email = account_email,
    updated_at = now()
  where id = member.id;
  insert into public.users (
    id, role, display_name, email, student_id, program, year_graduated, updated_at
  ) values (
    uid,
    'user',
    coalesce(nullif(trim(member.full_name), ''), trim(p_full_name)),
    coalesce(account_email, ''),
    sid,
    course_norm,
    trim(coalesce(member.year_graduated, '')),
    now()
  )
  on conflict (id) do update set
    display_name = excluded.display_name,
    email = excluded.email,
    student_id = excluded.student_id,
    program = excluded.program,
    year_graduated = coalesce(nullif(public.users.year_graduated, ''), excluded.year_graduated),
    updated_at = now();
  return jsonb_build_object('ok', true, 'memberId', member.id::text);
end;
$$;

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
  if v_privileged then
    return new;
  end if;
  if tg_op = 'INSERT' then
    new.role := 'user';
    new.email := coalesce(auth.jwt() ->> 'email', '');
    new.student_id := coalesce(v_sid, '');
    new.program := coalesce(v_course, '');
    new.deactivated_at := null;
    new.anonymized_at := null;
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
  return new;
end;
$$;

create or replace function public.alumni_members_normalize_year()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_year text;
begin
  if tg_op = 'INSERT' or new.year_graduated is distinct from old.year_graduated then
    v_year := public.normalize_grad_year(new.year_graduated);
  else
    v_year := coalesce(old.year_graduated, '');
  end if;
  new.year_graduated := nullif(v_year, '');
  return new;
end;
$$;

create or replace function public.alumni_members_guard_owner_update()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if current_user not in ('authenticated', 'anon') or public.is_admin() then
    return new;
  end if;
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

create or replace function public.trg_users_auto_assign_surveys()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'UPDATE'
     and new.program is not distinct from old.program
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
  after insert or update of program, year_graduated, role on public.users
  for each row execute function public.trg_users_auto_assign_surveys();

alter table public.users drop constraint if exists users_batch_year_matches;
alter table public.alumni_members drop constraint if exists alumni_members_batch_year_matches;
alter table public.users drop column if exists batch_year;
alter table public.alumni_members drop column if exists batch_year;

-- ---------------------------------------------------------------------------
-- 4. Typed event times
-- ---------------------------------------------------------------------------

-- Parses '7:00 AM', '7:00PM', '19:00' and '19:00:00'; null when unreadable.
create or replace function public.event_clock_time(p_text text)
returns time
language plpgsql
immutable
set search_path = public
as $$
declare
  m text[];
  h integer;
  mi integer;
begin
  m := regexp_match(
    coalesce(p_text, ''),
    '^\s*(\d{1,2}):(\d{2})(?::\d{2})?\s*(?:([AaPp])\.?\s*[Mm]\.?)?\s*$'
  );
  if m is null then
    return null;
  end if;
  h := m[1]::integer;
  mi := m[2]::integer;
  if mi > 59 then
    return null;
  end if;
  if m[3] is not null then
    if h < 1 or h > 12 then
      return null;
    end if;
    h := h % 12 + case when upper(m[3]) = 'P' then 12 else 0 end;
  elsif h > 23 then
    return null;
  end if;
  return make_time(h, mi, 0);
end;
$$;

revoke all on function public.event_clock_time(text) from public, anon;
grant execute on function public.event_clock_time(text) to authenticated, service_role;

-- Event day is the Manila calendar date of events.date. An end time earlier
-- than the start time means the event runs past midnight.
create or replace function public.events_set_times()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_day date := (new.date at time zone 'Asia/Manila')::date;
  v_start time := coalesce(public.event_clock_time(new.start_time), time '00:00');
  v_end time := public.event_clock_time(new.end_time);
begin
  new.starts_at := (v_day + v_start) at time zone 'Asia/Manila';
  new.ends_at := case
    when v_end is null then new.starts_at
    when v_end < v_start then ((v_day + 1) + v_end) at time zone 'Asia/Manila'
    else (v_day + v_end) at time zone 'Asia/Manila'
  end;
  return new;
end;
$$;

revoke all on function public.events_set_times() from public, anon, authenticated;

alter table public.events
  add column if not exists starts_at timestamptz,
  add column if not exists ends_at timestamptz;

alter table public.events disable trigger trg_notify_event_changes;
alter table public.events disable trigger trg_events_updated_at;

update public.events e
set starts_at = (d.day + d.st) at time zone 'Asia/Manila',
    ends_at = case
      when d.et is null then (d.day + d.st) at time zone 'Asia/Manila'
      when d.et < d.st then ((d.day + 1) + d.et) at time zone 'Asia/Manila'
      else (d.day + d.et) at time zone 'Asia/Manila'
    end
from (
  select id,
         (date at time zone 'Asia/Manila')::date as day,
         coalesce(public.event_clock_time(start_time), time '00:00') as st,
         public.event_clock_time(end_time) as et
  from public.events
) d
where d.id = e.id;

alter table public.events enable trigger trg_notify_event_changes;
alter table public.events enable trigger trg_events_updated_at;

alter table public.events
  alter column starts_at set not null,
  alter column ends_at set not null;

drop trigger if exists trg_events_set_times on public.events;
create trigger trg_events_set_times
  before insert or update of date, start_time, end_time, starts_at, ends_at
  on public.events
  for each row execute function public.events_set_times();

create index if not exists events_starts_at_idx on public.events (starts_at);

create or replace function public.run_event_reminders()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  today date := public.notification_manila_today();
  e record;
  theme text;
  details text;
  sent integer := 0;
begin
  for e in
    select ev.id, ev.theme, ev.venue, ev.start_time,
           (ev.starts_at at time zone 'Asia/Manila')::date as event_day,
           (ev.starts_at at time zone 'Asia/Manila')::date - today as days_left
    from public.events ev
    where coalesce(ev.status, 'Active') = 'Active'
      and not coalesce(ev.cancelled, false)
      and ev.ends_at > now()
      and (ev.starts_at at time zone 'Asia/Manila')::date - today in (0, 1)
  loop
    theme := coalesce(nullif(trim(e.theme), ''), 'Event');
    details := coalesce(' at ' || nullif(trim(e.start_time), ''), '')
      || coalesce(' — ' || nullif(trim(e.venue), ''), '');
    sent := sent + public.enqueue_notifications(
      array(
        select r.user_id from public.event_rsvps r
        where r.event_id = e.id
          and r.status = 'going'
          and public.notification_is_active_alumni(r.user_id)
      ),
      'event',
      case when e.days_left = 0 then 'Today: ' else 'Tomorrow: ' end || theme,
      theme || case when e.days_left = 0 then ' is today' else ' is tomorrow' end || details || '.',
      jsonb_build_object(
        'relatedId', e.id::text,
        'eventId', e.id::text,
        'eventTitle', theme,
        'kind', 'reminder_' || e.days_left || 'd'
      ),
      'normal',
      'event:' || e.id::text || ':reminder:' || e.days_left || 'd',
      'event/' || e.id::text,
      false,
      (e.event_day + 1)::timestamp at time zone 'Asia/Manila'
    );
  end loop;
  return sent;
end;
$$;
