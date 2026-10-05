-- Phase 2: data integrity.
--   DI-1  unique roster identity (student id + course, one roster row per account)
--   DI-2  users.email unique and synced from auth.users
--   DI-3  submitted survey responses are locked for alumni
--   S-11  alumni can't change role, email, ID number or course on public.users
--   S-12  audit_logs is append-only, identity stamped by the server, retention cron
--   S-13  message sender name/email stamped by the server
--   M-9   account removal = deactivate + anonymize (replaces admin-delete-user)
--   DI-12 FK delete rules (history rows survive; tracer evidence can't cascade away)
--   DI-13 DSS status transitions enforced; status change + note written atomically
--   DI-7  status CHECK constraints
--   DI-10 notification_push_deliveries.user_id FK

-- ---------------------------------------------------------------------------
-- Account state columns
-- ---------------------------------------------------------------------------
alter table public.users
  add column if not exists deactivated_at timestamptz,
  add column if not exists anonymized_at timestamptz;

update public.users u
set deactivated_at = coalesce(u.deactivated_at, m.updated_at)
from public.alumni_members m
where m.auth_uid = u.id and m.is_deactivated;

-- ---------------------------------------------------------------------------
-- DI-1: roster identity
-- ---------------------------------------------------------------------------
drop index if exists public.idx_alumni_members_student_course;

create unique index if not exists alumni_members_student_course_key
  on public.alumni_members (
    public.normalize_student_id(student_id),
    coalesce(public.normalize_course(course), upper(trim(course)))
  )
  where public.normalize_student_id(student_id) <> '';

create unique index if not exists alumni_members_auth_uid_key
  on public.alumni_members (auth_uid)
  where auth_uid is not null;

-- ---------------------------------------------------------------------------
-- DI-2: users.email mirrors auth.users.email
-- ---------------------------------------------------------------------------
update public.users u
set email = coalesce(a.email, '')
from auth.users a
where a.id = u.id and u.email is distinct from coalesce(a.email, '');

create unique index if not exists users_email_lower_key
  on public.users (lower(email))
  where email <> '';

create or replace function public.sync_user_email_from_auth()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.users
  set email = coalesce(new.email, ''), updated_at = now()
  where id = new.id and email is distinct from coalesce(new.email, '');
  return new;
end;
$$;

drop trigger if exists on_auth_user_email_changed on auth.users;
create trigger on_auth_user_email_changed
  after update of email on auth.users
  for each row
  when (old.email is distinct from new.email)
  execute function public.sync_user_email_from_auth();

-- ---------------------------------------------------------------------------
-- S-11: protected columns on public.users
-- Alumni clients send whole profile rows; server-owned columns are kept as-is
-- instead of failing the save.
-- ---------------------------------------------------------------------------
create or replace function public.users_guard_protected_columns()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_sid text;
  v_course text;
begin
  if current_user not in ('authenticated', 'anon') or public.is_admin() then
    return new;
  end if;

  if tg_op = 'INSERT' then
    select m.student_id, m.course into v_sid, v_course
    from public.alumni_members m
    where m.auth_uid = new.id;
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

drop trigger if exists trg_users_guard_protected_columns on public.users;
create trigger trg_users_guard_protected_columns
  before insert or update on public.users
  for each row execute function public.users_guard_protected_columns();

-- ---------------------------------------------------------------------------
-- DI-3: submitted survey responses are final for alumni
-- ---------------------------------------------------------------------------
create or replace function public.survey_responses_guard_owner_update()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if current_user not in ('authenticated', 'anon') or public.is_admin() then
    return new;
  end if;
  if new.user_id is distinct from old.user_id
     or new.survey_id is distinct from old.survey_id then
    raise exception 'A survey response cannot be moved to another survey or account.'
      using errcode = '42501';
  end if;
  if old.status = 'submitted'
     and (new.status is distinct from old.status
          or new.answers is distinct from old.answers
          or new.submitted_at is distinct from old.submitted_at) then
    raise exception 'This survey response was already submitted and can no longer be changed.'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_survey_responses_guard_owner_update on public.survey_responses;
create trigger trg_survey_responses_guard_owner_update
  before update on public.survey_responses
  for each row execute function public.survey_responses_guard_owner_update();

create or replace function public.enforce_assignment_owner_update()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if coalesce(auth.role(), '') in ('service_role', 'postgres') then
    return new;
  end if;
  if public.is_admin() then
    return new;
  end if;
  if old.user_id <> auth.uid() then
    raise exception 'not owner';
  end if;
  if new.survey_id is distinct from old.survey_id
     or new.user_id is distinct from old.user_id
     or new.survey_title is distinct from old.survey_title
     or new.assigned_at is distinct from old.assigned_at
     or new.last_reminder_at is distinct from old.last_reminder_at
     or new.reminder_count is distinct from old.reminder_count
     or new.created_at is distinct from old.created_at then
    raise exception 'owner may only update status';
  end if;
  if old.status = 'completed' then
    new.status := 'completed';
  elsif new.status = 'completed'
     and not exists (
       select 1 from public.survey_responses r
       where r.survey_id = old.survey_id
         and r.user_id = old.user_id
         and r.status = 'submitted'
     ) then
    raise exception 'Submit the survey before marking it completed.'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

-- Deleting a survey that already has submitted answers would wipe official
-- tracer evidence; close or archive it instead.
create or replace function public.surveys_block_delete_with_submissions()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if exists (
    select 1 from public.survey_responses r
    where r.survey_id = old.id and r.status = 'submitted'
  ) then
    raise exception 'This survey already has submitted responses. Close or archive it instead of deleting it.'
      using errcode = '23503';
  end if;
  return old;
end;
$$;

drop trigger if exists trg_surveys_block_delete_with_submissions on public.surveys;
create trigger trg_surveys_block_delete_with_submissions
  before delete on public.surveys
  for each row execute function public.surveys_block_delete_with_submissions();

-- ---------------------------------------------------------------------------
-- S-12: audit_logs append-only, server-stamped identity, retention
-- ---------------------------------------------------------------------------
drop policy if exists audit_logs_delete_admin on public.audit_logs;
drop policy if exists audit_logs_update_delete_admin on public.audit_logs;
revoke update, delete, truncate on public.audit_logs from anon, authenticated;

create or replace function public.audit_logs_stamp_actor()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_role text;
  v_name text;
  v_email text;
begin
  new.created_at := now();
  new.updated_at := now();
  if v_uid is null then
    return new;
  end if;

  select u.role, nullif(trim(u.display_name), ''), nullif(trim(u.email), '')
  into v_role, v_name, v_email
  from public.users u
  where u.id = v_uid;

  if v_email is null or v_name is null then
    select coalesce(v_email, a.email),
           coalesce(v_name, nullif(trim(a.raw_user_meta_data ->> 'display_name'), ''))
    into v_email, v_name
    from auth.users a
    where a.id = v_uid;
  end if;

  new.user_id := v_uid;
  new.details := coalesce(new.details, '{}'::jsonb) || jsonb_build_object(
    'userRole', coalesce(v_role, 'user'),
    'userName', coalesce(v_name, 'Unknown'),
    'userEmail', coalesce(v_email, '')
  );
  return new;
end;
$$;

drop trigger if exists trg_audit_logs_stamp_actor on public.audit_logs;
create trigger trg_audit_logs_stamp_actor
  before insert on public.audit_logs
  for each row execute function public.audit_logs_stamp_actor();

create or replace function public.purge_expired_audit_logs()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_sessions integer;
  v_other integer;
begin
  delete from public.audit_logs
  where action in ('LOGIN', 'LOGOUT')
    and created_at < now() - interval '90 days';
  get diagnostics v_sessions = row_count;

  delete from public.audit_logs
  where action not in ('LOGIN', 'LOGOUT')
    and created_at < now() - interval '1 year';
  get diagnostics v_other = row_count;

  return v_sessions + v_other;
end;
$$;

revoke all on function public.purge_expired_audit_logs() from public, anon, authenticated;

do $$
begin
  if exists (select 1 from cron.job where jobname = 'aess-audit-retention') then
    perform cron.unschedule('aess-audit-retention');
  end if;
  -- 03:45 Asia/Manila
  perform cron.schedule(
    'aess-audit-retention',
    '45 19 * * *',
    'select public.purge_expired_audit_logs();'
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- S-13: message display identity comes from public.users
-- ---------------------------------------------------------------------------
create or replace function public.enforce_message_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  jwt_role text := coalesce(auth.role(), '');
  uid uuid := auth.uid();
  max_body int := 4000;
  v_admin boolean;
  v_name text;
  v_email text;
begin
  if jwt_role in ('service_role', 'postgres') then
    return new;
  end if;
  if uid is null then
    raise exception 'not authenticated';
  end if;
  if new.sender_id is distinct from uid then
    raise exception 'sender_id must be the authenticated user';
  end if;
  if length(coalesce(new.body, '')) > max_body then
    raise exception 'message body too long';
  end if;
  if nullif(trim(coalesce(new.image_base64, '')), '') is not null
     and new.image_base64 !~ ('^message-attachments/' || uid::text || '/[A-Za-z0-9_-]{1,128}\.jpg$') then
    raise exception 'invalid message image reference';
  end if;

  v_admin := public.is_admin();
  select nullif(trim(u.display_name), ''), coalesce(u.email, '')
  into v_name, v_email
  from public.users u
  where u.id = uid;

  new.sender_role := case when v_admin then 'admin' else 'user' end;
  new.sender_name := coalesce(v_name, case when v_admin then 'Admin' else 'User' end);
  new.sender_email := coalesce(v_email, '');
  return new;
end;
$$;

create or replace function public.enforce_message_update()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  jwt_role text := coalesce(auth.role(), '');
  max_body int := 4000;
begin
  if jwt_role in ('service_role', 'postgres') then
    return new;
  end if;
  if public.is_admin() then
    if length(coalesce(new.body, '')) > max_body then
      raise exception 'message body too long';
    end if;
    return new;
  end if;
  if uid is null then
    raise exception 'not authenticated';
  end if;
  if length(coalesce(new.body, '')) > max_body then
    raise exception 'message body too long';
  end if;
  if old.sender_id = uid then
    if new.sender_id is distinct from old.sender_id
       or new.recipient_id is distinct from old.recipient_id
       or new.created_at is distinct from old.created_at
       or new.sender_role is distinct from old.sender_role
       or new.sender_name is distinct from old.sender_name
       or new.sender_email is distinct from old.sender_email then
      raise exception 'sender cannot reassign message participants';
    end if;
    if nullif(trim(coalesce(new.image_base64, '')), '') is not null
       and new.image_base64 is distinct from old.image_base64
       and new.image_base64 !~ ('^message-attachments/' || uid::text || '/[A-Za-z0-9_-]{1,128}\.jpg$') then
      raise exception 'invalid message image reference';
    end if;
    return new;
  end if;
  if old.recipient_id = uid then
    if new.body is distinct from old.body
       or new.image_base64 is distinct from old.image_base64
       or new.sender_id is distinct from old.sender_id
       or new.recipient_id is distinct from old.recipient_id
       or new.created_at is distinct from old.created_at
       or new.sender_role is distinct from old.sender_role
       or new.sender_name is distinct from old.sender_name
       or new.sender_email is distinct from old.sender_email then
      raise exception 'recipient cannot modify message content';
    end if;
    if new.is_read = true or new.reactions is distinct from old.reactions then
      return new;
    end if;
    raise exception 'recipient update not allowed';
  end if;
  raise exception 'not a participant';
end;
$$;

-- ---------------------------------------------------------------------------
-- DI-12 / DI-10: foreign-key delete rules
-- ---------------------------------------------------------------------------
alter table public.audit_logs
  drop constraint if exists audit_logs_user_id_fkey,
  add constraint audit_logs_user_id_fkey
    foreign key (user_id) references auth.users (id) on delete set null;

alter table public.surveys
  drop constraint if exists surveys_created_by_fkey,
  add constraint surveys_created_by_fkey
    foreign key (created_by) references auth.users (id) on delete set null;

alter table public.employment_records
  drop constraint if exists employment_records_verified_by_fkey,
  add constraint employment_records_verified_by_fkey
    foreign key (verified_by) references auth.users (id) on delete set null;

alter table public.alumni_members
  drop constraint if exists alumni_members_auth_uid_fkey,
  add constraint alumni_members_auth_uid_fkey
    foreign key (auth_uid) references auth.users (id) on delete set null;

-- Tracer evidence must never disappear with an account.
alter table public.survey_responses
  drop constraint if exists survey_responses_user_id_fkey,
  add constraint survey_responses_user_id_fkey
    foreign key (user_id) references auth.users (id) on delete restrict;

alter table public.survey_response_events
  drop constraint if exists survey_response_events_user_id_fkey,
  add constraint survey_response_events_user_id_fkey
    foreign key (user_id) references auth.users (id) on delete restrict;

alter table public.survey_assignments
  drop constraint if exists survey_assignments_user_id_fkey,
  add constraint survey_assignments_user_id_fkey
    foreign key (user_id) references auth.users (id) on delete restrict;

-- Forum threads keep other people's replies when an author account goes away.
alter table public.forum_topics alter column author_uid drop not null;
alter table public.forum_topics
  drop constraint if exists forum_topics_author_uid_fkey,
  add constraint forum_topics_author_uid_fkey
    foreign key (author_uid) references auth.users (id) on delete set null;

alter table public.forum_posts alter column author_uid drop not null;
alter table public.forum_posts
  drop constraint if exists forum_posts_author_uid_fkey,
  add constraint forum_posts_author_uid_fkey
    foreign key (author_uid) references auth.users (id) on delete set null;

alter table public.notification_push_deliveries
  drop constraint if exists notification_push_deliveries_user_id_fkey,
  add constraint notification_push_deliveries_user_id_fkey
    foreign key (user_id) references auth.users (id) on delete cascade;

-- The SET NULL cascade runs without a JWT; author guards must let it through.
create or replace function public.forum_topics_guard_author_update()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if coalesce(auth.role(), '') not in ('authenticated', 'anon') or public.is_admin() then
    return new;
  end if;
  -- Allow reply-count maintenance from forum_posts triggers (any authenticated poster).
  if new.title is not distinct from old.title
     and new.body is not distinct from old.body
     and new.author_uid is not distinct from old.author_uid
     and new.author_name is not distinct from old.author_name
     and new.author_program is not distinct from old.author_program
     and new.author_batch is not distinct from old.author_batch
     and new.is_locked is not distinct from old.is_locked
     and new.is_pinned is not distinct from old.is_pinned
     and new.is_solved is not distinct from old.is_solved
     and new.is_announcement is not distinct from old.is_announcement
     and new.is_featured is not distinct from old.is_featured
     and new.moderation_reason is not distinct from old.moderation_reason
     and new.edited_at is not distinct from old.edited_at
     and new.view_count is not distinct from old.view_count
     and new.created_at is not distinct from old.created_at
  then
    return new;
  end if;
  if old.author_uid is distinct from auth.uid() then
    raise exception 'not owner';
  end if;
  -- Authors may only change content + solved (not announcements)
  if new.is_locked is distinct from old.is_locked
     or new.is_pinned is distinct from old.is_pinned
     or new.is_announcement is distinct from old.is_announcement
     or new.is_featured is distinct from old.is_featured
     or new.moderation_reason is distinct from old.moderation_reason
     or new.view_count is distinct from old.view_count
     or new.author_uid is distinct from old.author_uid
  then
    raise exception 'authors cannot change moderation fields';
  end if;
  if new.is_announcement and new.is_solved is distinct from old.is_solved and new.is_solved = true then
    raise exception 'announcements cannot be marked solved';
  end if;
  return new;
end;
$$;

create or replace function public.forum_posts_guard_author_update()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if coalesce(auth.role(), '') not in ('authenticated', 'anon') or public.is_admin() then
    return new;
  end if;
  if old.author_uid is distinct from auth.uid() then
    raise exception 'not owner';
  end if;
  if new.topic_id is distinct from old.topic_id
     or new.author_uid is distinct from old.author_uid
     or new.parent_post_id is distinct from old.parent_post_id
  then
    raise exception 'invalid post update';
  end if;
  if new.body is distinct from old.body then
    if old.created_at < now() - interval '30 minutes' then
      raise exception 'edit window expired';
    end if;
    new.edited_at := now();
  end if;
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- Deactivation keeps users.deactivated_at in step with the roster flag
-- ---------------------------------------------------------------------------
create or replace function public.alumni_members_sync_auth_ban()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.auth_uid is null
     or exists (select 1 from public.users u where u.id = new.auth_uid and u.role = 'admin') then
    return new;
  end if;
  if new.is_deactivated and not coalesce(old.is_deactivated, false) then
    update auth.users set banned_until = '2999-12-31 00:00:00+00' where id = new.auth_uid;
    delete from auth.sessions where user_id = new.auth_uid;
    update public.users set deactivated_at = now() where id = new.auth_uid;
  elsif not new.is_deactivated and coalesce(old.is_deactivated, false) then
    update auth.users set banned_until = null
    where id = new.auth_uid
      and not exists (
        select 1 from public.users u where u.id = new.auth_uid and u.anonymized_at is not null
      );
    update public.users set deactivated_at = null
    where id = new.auth_uid and anonymized_at is null;
  end if;
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- M-9: remove an alumni account = deactivate + anonymize.
-- GTS answers stay (identifying items blanked); program and year stay on the
-- anonymized users row so statistics keep their cohort.
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
      current_company = null,
      current_position = null,
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

revoke all on function public.admin_remove_alumni_account(uuid) from public, anon;
grant execute on function public.admin_remove_alumni_account(uuid) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- DI-13: DSS flag status
-- ---------------------------------------------------------------------------
create or replace function public.dss_flags_guard_status_transition()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.status is distinct from old.status
     and old.status in ('resolved', 'dismissed')
     and new.status in ('resolved', 'dismissed') then
    raise exception 'Reopen this flag before marking it %.', new.status
      using errcode = '23514';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_dss_flags_guard_status_transition on public.dss_flags;
create trigger trg_dss_flags_guard_status_transition
  before update of status on public.dss_flags
  for each row execute function public.dss_flags_guard_status_transition();

create or replace function public.dss_flag_notes_stamp_author()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    return new;
  end if;
  new.author_id := v_uid;
  select coalesce(nullif(trim(u.display_name), ''), nullif(trim(u.email), ''), 'Admin')
  into new.author_name
  from public.users u
  where u.id = v_uid;
  new.author_name := coalesce(new.author_name, 'Admin');
  return new;
end;
$$;

drop trigger if exists trg_dss_flag_notes_stamp_author on public.dss_flag_notes;
create trigger trg_dss_flag_notes_stamp_author
  before insert on public.dss_flag_notes
  for each row execute function public.dss_flag_notes_stamp_author();

create or replace function public.dss_update_flag_status(
  p_flag_id uuid,
  p_status text,
  p_note text default '',
  p_intervention_type text default null,
  p_intervention_detail text default null,
  p_followup_value numeric default null,
  p_followup_sample_n integer default null,
  p_impact_verdict text default null,
  p_verify_due_at timestamptz default null,
  p_clear_resolved_at boolean default false
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  f public.dss_flags%rowtype;
  v_note text := trim(coalesce(p_note, ''));
  v_was_closed boolean;
  v_reopening boolean;
  v_label text;
begin
  if not public.is_admin() then
    raise exception 'Admin access required.' using errcode = '42501';
  end if;
  if p_status not in ('open', 'in_progress', 'resolved', 'dismissed') then
    raise exception 'Unknown flag status: %', p_status;
  end if;

  select * into f from public.dss_flags where id = p_flag_id for update;
  if not found then
    raise exception 'DSS flag not found.';
  end if;

  v_was_closed := f.status in ('resolved', 'dismissed');
  v_reopening := v_was_closed and p_status in ('open', 'in_progress');

  update public.dss_flags
  set status = p_status,
      updated_by = auth.uid(),
      resolved_at = case
        when p_status in ('resolved', 'dismissed') then now()
        when v_was_closed and (p_clear_resolved_at or p_status in ('open', 'in_progress')) then null
        else resolved_at
      end,
      verify_due_at = case
        when p_verify_due_at is not null then p_verify_due_at
        when v_was_closed and (p_clear_resolved_at or p_status in ('open', 'in_progress')) then null
        else verify_due_at
      end,
      intervention_type = coalesce(p_intervention_type, intervention_type),
      intervention_detail = coalesce(p_intervention_detail, intervention_detail),
      followup_value = coalesce(p_followup_value, followup_value),
      followup_at = case when p_followup_value is not null then now() else followup_at end,
      followup_sample_n = coalesce(p_followup_sample_n, followup_sample_n),
      impact_verdict = coalesce(p_impact_verdict, impact_verdict)
  where id = p_flag_id;

  if v_note <> '' or p_status <> f.status then
    v_label := case p_status
      when 'open' then 'Open'
      when 'in_progress' then 'In Progress'
      when 'resolved' then 'Resolved'
      else 'Dismissed'
    end;
    insert into public.dss_flag_notes (
      flag_id, note, status_from, status_to, event_type, metadata
    )
    values (
      p_flag_id,
      case when v_note = '' then 'Status changed to ' || v_label else v_note end,
      f.status,
      p_status,
      case when v_reopening then 'reopen' else 'status' end,
      jsonb_strip_nulls(jsonb_build_object(
        'intervention', p_intervention_type,
        'intervention_detail', nullif(p_intervention_detail, ''),
        'impact_verdict', p_impact_verdict,
        'followup_value', p_followup_value,
        'followup_sample_n', p_followup_sample_n
      ))
    );
  end if;
end;
$$;

revoke all on function public.dss_update_flag_status(uuid, text, text, text, text, numeric, integer, text, timestamptz, boolean) from public, anon;
grant execute on function public.dss_update_flag_status(uuid, text, text, text, text, numeric, integer, text, timestamptz, boolean) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- DI-7: status CHECKs (values match what the app writes today)
-- ---------------------------------------------------------------------------
update public.jobs set status = lower(status) where status <> lower(status);
alter table public.jobs alter column status set default 'active';
alter table public.jobs drop constraint if exists jobs_status_check;
alter table public.jobs add constraint jobs_status_check
  check (status in ('active', 'expired', 'closed', 'archived'));

alter table public.events drop constraint if exists events_status_check;
alter table public.events add constraint events_status_check
  check (status in ('Active', 'Archived'));

alter table public.announcements drop constraint if exists announcements_status_check;
alter table public.announcements add constraint announcements_status_check
  check (status in ('draft', 'published', 'archived'));

alter table public.feedback drop constraint if exists feedback_status_check;
alter table public.feedback add constraint feedback_status_check
  check (status in ('submitted', 'inReview', 'resolved', 'closed'));

alter table public.forum_reports drop constraint if exists forum_reports_status_check;
alter table public.forum_reports add constraint forum_reports_status_check
  check (status in ('open', 'resolved', 'dismissed'));

-- ---------------------------------------------------------------------------
-- Advisor tidy-up: trigger functions don't need EXECUTE; pin search_path
-- ---------------------------------------------------------------------------
do $$
declare
  fn record;
begin
  for fn in
    select p.oid::regprocedure as sig
    from pg_proc p
    where p.pronamespace = 'public'::regnamespace
      and p.prorettype = 'trigger'::regtype
      and not exists (select 1 from pg_depend d where d.objid = p.oid and d.deptype = 'e')
  loop
    execute format('revoke execute on function %s from public, anon, authenticated', fn.sig);
  end loop;

  for fn in
    select p.oid::regprocedure as sig
    from pg_proc p
    where p.pronamespace = 'public'::regnamespace
      and p.proconfig is null
      and not exists (select 1 from pg_depend d where d.objid = p.oid and d.deptype = 'e')
  loop
    execute format('alter function %s set search_path = public', fn.sig);
  end loop;
end;
$$;

notify pgrst, 'reload schema';
