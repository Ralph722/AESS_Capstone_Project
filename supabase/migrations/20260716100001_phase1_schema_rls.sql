-- Phase 1: Supabase (Postgres) schema + RLS policies
-- Mirrors intent of firestore.rules as closely as practical in SQL.
--
-- Apply in Supabase SQL editor, or via migrations if you use the CLI.
-- NOTE: This creates tables only; Phase 2+ rewires the Flutter app to use them.

begin;

-- Needed for gen_random_uuid()
create extension if not exists pgcrypto;

-- -----------------------------
-- Core profile/users
-- -----------------------------

create table if not exists public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  role text not null default 'user' check (role in ('user', 'admin')),

  display_name text not null default '',
  email text not null default '',

  student_id text not null default '',
  program text not null default '',
  course text not null default '',

  batch_year text not null default '',
  year_graduated text not null default '',
  contact_number text not null default '',
  phone_number text not null default '',
  address text not null default '',
  gender text not null default '',
  civil_status text not null default '',

  onboarding_complete boolean not null default false,
  tracer_profile_completion integer not null default 0,
  tracer_profile_complete boolean not null default false,

  -- Images are currently stored as base64 in Firestore; keep a slot for migration.
  profile_image_base64 text,

  last_active_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- -----------------------------
-- Helpers
-- -----------------------------

-- Utility to require a signed-in user in RLS (more readable).
create or replace function public.is_signed_in()
returns boolean
language sql
stable
as $$
  select auth.uid() is not null;
$$;

-- Admin = exists in public.users with role='admin'
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.users u
    where u.id = auth.uid()
      and u.role = 'admin'
  );
$$;

alter table public.users enable row level security;

-- Firestore rule: users read if owner OR admin OR target is admin.
create policy "users_select_owner_admin_or_admin_target"
on public.users
for select
to authenticated
using (
  public.is_signed_in() and (
    id = auth.uid()
    or public.is_admin()
    or role = 'admin'
  )
);

-- Firestore rule: create/update only self and must keep role='user'
create policy "users_insert_self_user_role"
on public.users
for insert
to authenticated
with check (
  id = auth.uid()
  and role = 'user'
);

create policy "users_update_self_user_role"
on public.users
for update
to authenticated
using (id = auth.uid())
with check (
  id = auth.uid()
  and role = 'user'
);

create policy "users_delete_admin_only"
on public.users
for delete
to authenticated
using (public.is_admin());

-- Keep updated_at fresh.
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_users_updated_at on public.users;
create trigger trg_users_updated_at
before update on public.users
for each row execute function public.set_updated_at();

-- -----------------------------
-- Official roster (alumni_members)
-- -----------------------------

create table if not exists public.alumni_members (
  id uuid primary key default gen_random_uuid(),
  full_name text not null default '',
  course text not null default '',
  student_id text not null default '',

  auth_uid uuid references auth.users(id),
  registered_email text,
  is_registered_user boolean not null default false,
  is_deactivated boolean not null default false,

  profile_image_url text,
  last_active_at timestamptz,
  has_profile_updates boolean not null default false,
  admin_viewed_at timestamptz,

  batch_year text not null default '',
  contact_number text not null default '',
  email_address text not null default '',
  linkedin_url text,
  current_position text,
  current_company text,
  address text,
  gender text,
  civil_status text,
  birth_date date,
  year_graduated text,
  tracer_profile_complete boolean not null default false,
  employment_status text,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_alumni_members_student_course
  on public.alumni_members (student_id, course);

alter table public.alumni_members enable row level security;

-- Firestore: get allowed to admin OR guests OR signed-in if own row or unclaimed.
-- In Supabase, "guests" are anon. We'll allow anon SELECT only by primary key,
-- but cannot enforce "by id only" purely in RLS. Practical compromise:
-- - anon can select rows where is_registered_user=false (used for eligibility checks)
-- - authenticated can select if admin OR owns row OR row unclaimed
create policy "alumni_members_select_anon_unclaimed"
on public.alumni_members
for select
to anon
using (is_registered_user = false);

create policy "alumni_members_select_auth_admin_or_owner_or_unclaimed"
on public.alumni_members
for select
to authenticated
using (
  public.is_admin()
  or auth_uid = auth.uid()
  or is_registered_user = false
);

create policy "alumni_members_insert_admin_only"
on public.alumni_members
for insert
to authenticated
with check (public.is_admin());

create policy "alumni_members_delete_admin_only"
on public.alumni_members
for delete
to authenticated
using (public.is_admin());

-- Updates: admin always; alumni can claim + update only their own row.
create policy "alumni_members_update_admin_or_owner"
on public.alumni_members
for update
to authenticated
using (
  public.is_admin()
  or auth_uid = auth.uid()
  or (auth_uid is null and is_registered_user = false)
)
with check (
  public.is_admin()
  or auth_uid = auth.uid()
);

drop trigger if exists trg_alumni_members_updated_at on public.alumni_members;
create trigger trg_alumni_members_updated_at
before update on public.alumni_members
for each row execute function public.set_updated_at();

-- -----------------------------
-- Audit logs
-- -----------------------------

create table if not exists public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id),
  action text not null default '',
  entity_type text not null default '',
  entity_id text not null default '',
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.audit_logs enable row level security;

create policy "audit_logs_select_admin"
on public.audit_logs
for select
to authenticated
using (public.is_admin());

create policy "audit_logs_insert_own"
on public.audit_logs
for insert
to authenticated
with check (user_id = auth.uid());

create policy "audit_logs_update_delete_admin"
on public.audit_logs
for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy "audit_logs_delete_admin"
on public.audit_logs
for delete
to authenticated
using (public.is_admin());

drop trigger if exists trg_audit_logs_updated_at on public.audit_logs;
create trigger trg_audit_logs_updated_at
before update on public.audit_logs
for each row execute function public.set_updated_at();

-- -----------------------------
-- Events + comments + replies
-- -----------------------------

create table if not exists public.events (
  id uuid primary key default gen_random_uuid(),
  theme text not null default '',
  batch_year text not null default '',
  date timestamptz not null,
  venue text not null default '',
  status text not null default 'Active',
  comments_count integer not null default 0,
  start_time text not null default '09:00',
  end_time text not null default '17:00',
  description text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.events enable row level security;

create policy "events_select_signed_in"
on public.events
for select
to authenticated
using (public.is_signed_in());

create policy "events_admin_write"
on public.events
for insert
to authenticated
with check (public.is_admin());

create policy "events_admin_update"
on public.events
for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy "events_admin_delete"
on public.events
for delete
to authenticated
using (public.is_admin());

drop trigger if exists trg_events_updated_at on public.events;
create trigger trg_events_updated_at
before update on public.events
for each row execute function public.set_updated_at();

create table if not exists public.event_comments (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  body text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_event_comments_event on public.event_comments(event_id);

alter table public.event_comments enable row level security;

create policy "event_comments_select_signed_in"
on public.event_comments
for select
to authenticated
using (public.is_signed_in());

create policy "event_comments_insert_own"
on public.event_comments
for insert
to authenticated
with check (user_id = auth.uid());

create policy "event_comments_update_admin_or_author"
on public.event_comments
for update
to authenticated
using (public.is_admin() or user_id = auth.uid())
with check (public.is_admin() or user_id = auth.uid());

create policy "event_comments_delete_admin_or_author"
on public.event_comments
for delete
to authenticated
using (public.is_admin() or user_id = auth.uid());

drop trigger if exists trg_event_comments_updated_at on public.event_comments;
create trigger trg_event_comments_updated_at
before update on public.event_comments
for each row execute function public.set_updated_at();

create table if not exists public.event_replies (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  comment_id uuid not null references public.event_comments(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  body text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_event_replies_comment on public.event_replies(comment_id);

alter table public.event_replies enable row level security;

create policy "event_replies_select_signed_in"
on public.event_replies
for select
to authenticated
using (public.is_signed_in());

-- Firestore: replies create/update/delete admin only
create policy "event_replies_admin_insert"
on public.event_replies
for insert
to authenticated
with check (public.is_admin());

create policy "event_replies_admin_update"
on public.event_replies
for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy "event_replies_admin_delete"
on public.event_replies
for delete
to authenticated
using (public.is_admin());

drop trigger if exists trg_event_replies_updated_at on public.event_replies;
create trigger trg_event_replies_updated_at
before update on public.event_replies
for each row execute function public.set_updated_at();

-- -----------------------------
-- Jobs
-- -----------------------------

create table if not exists public.jobs (
  id uuid primary key default gen_random_uuid(),
  title text not null default '',
  company text not null default '',
  location text not null default '',
  description text not null default '',
  status text not null default 'Active',
  data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.jobs enable row level security;

create policy "jobs_select_signed_in"
on public.jobs
for select
to authenticated
using (public.is_signed_in());

create policy "jobs_admin_insert"
on public.jobs
for insert
to authenticated
with check (public.is_admin());

create policy "jobs_admin_update"
on public.jobs
for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy "jobs_admin_delete"
on public.jobs
for delete
to authenticated
using (public.is_admin());

drop trigger if exists trg_jobs_updated_at on public.jobs;
create trigger trg_jobs_updated_at
before update on public.jobs
for each row execute function public.set_updated_at();

-- -----------------------------
-- Messages (simplified + guardrails via triggers)
-- -----------------------------

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references auth.users(id) on delete cascade,
  recipient_id uuid not null references auth.users(id) on delete cascade,
  body text not null default '',
  image_base64 text,
  is_read boolean not null default false,
  reactions jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_messages_participants
  on public.messages(sender_id, recipient_id, created_at desc);

alter table public.messages enable row level security;

create policy "messages_select_participant_or_admin"
on public.messages
for select
to authenticated
using (
  public.is_admin()
  or sender_id = auth.uid()
  or recipient_id = auth.uid()
);

create policy "messages_insert_signed_in"
on public.messages
for insert
to authenticated
with check (public.is_signed_in());

-- Firestore: updates are nuanced; we approximate with trigger-based enforcement.
create policy "messages_update_participant_or_admin"
on public.messages
for update
to authenticated
using (
  public.is_admin()
  or sender_id = auth.uid()
  or recipient_id = auth.uid()
)
with check (
  public.is_admin()
  or sender_id = auth.uid()
  or recipient_id = auth.uid()
);

create policy "messages_delete_sender_or_admin"
on public.messages
for delete
to authenticated
using (public.is_admin() or sender_id = auth.uid());

drop trigger if exists trg_messages_updated_at on public.messages;
create trigger trg_messages_updated_at
before update on public.messages
for each row execute function public.set_updated_at();

-- Guardrail: non-admin recipients can only flip is_read; participants can only edit reactions.
create or replace function public.enforce_message_update()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
begin
  if public.is_admin() then
    return new;
  end if;

  if uid is null then
    raise exception 'not authenticated';
  end if;

  -- Sender can update anything (matches Firestore sender update privilege).
  if old.sender_id = uid then
    return new;
  end if;

  -- Recipient: allow only marking read (is_read true) and reactions changes.
  if old.recipient_id = uid then
    -- If body/image changed, reject.
    if new.body is distinct from old.body
       or new.image_base64 is distinct from old.image_base64
       or new.sender_id is distinct from old.sender_id
       or new.recipient_id is distinct from old.recipient_id
       or new.created_at is distinct from old.created_at then
      raise exception 'recipient cannot modify message content';
    end if;

    -- Allow: is_read change (to true) and/or reactions updates.
    if new.is_read = true or new.reactions is distinct from old.reactions then
      return new;
    end if;

    raise exception 'recipient update not allowed';
  end if;

  -- Non-participant cannot update.
  raise exception 'not a participant';
end;
$$;

drop trigger if exists trg_messages_enforce_update on public.messages;
create trigger trg_messages_enforce_update
before update on public.messages
for each row execute function public.enforce_message_update();

-- -----------------------------
-- Notifications (global table)
-- -----------------------------

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null default '',
  body text not null default '',
  type text not null default '',
  is_read boolean not null default false,
  data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_notifications_user on public.notifications(user_id, created_at desc);

alter table public.notifications enable row level security;

create policy "notifications_select_owner_or_admin"
on public.notifications
for select
to authenticated
using (public.is_admin() or user_id = auth.uid());

-- Firestore: only admin writes (top-level notifications)
create policy "notifications_write_admin_only"
on public.notifications
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop trigger if exists trg_notifications_updated_at on public.notifications;
create trigger trg_notifications_updated_at
before update on public.notifications
for each row execute function public.set_updated_at();

-- -----------------------------
-- Employment records
-- -----------------------------

create table if not exists public.employment_records (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,

  status text not null default '',
  company text not null default '',
  position text not null default '',
  start_date date,
  end_date date,
  data jsonb not null default '{}'::jsonb,

  verification_status text not null default 'Pending',
  verified_by uuid references auth.users(id),
  verified_at timestamptz,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_employment_records_user on public.employment_records(user_id);

alter table public.employment_records enable row level security;

create policy "employment_records_select_owner_or_admin"
on public.employment_records
for select
to authenticated
using (public.is_admin() or user_id = auth.uid());

create policy "employment_records_insert_own"
on public.employment_records
for insert
to authenticated
with check (user_id = auth.uid());

create policy "employment_records_update_admin_or_owner"
on public.employment_records
for update
to authenticated
using (public.is_admin() or user_id = auth.uid())
with check (public.is_admin() or user_id = auth.uid());

create policy "employment_records_delete_admin"
on public.employment_records
for delete
to authenticated
using (public.is_admin());

drop trigger if exists trg_employment_records_updated_at on public.employment_records;
create trigger trg_employment_records_updated_at
before update on public.employment_records
for each row execute function public.set_updated_at();

-- Enforce: owners cannot change verification_* fields (mirrors userCanUpdateEmploymentRecord()).
create or replace function public.enforce_employment_owner_update()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.is_admin() then
    return new;
  end if;

  if old.user_id <> auth.uid() then
    raise exception 'not owner';
  end if;

  if new.verification_status is distinct from old.verification_status
     or new.verified_by is distinct from old.verified_by
     or new.verified_at is distinct from old.verified_at then
    raise exception 'owner cannot change verification fields';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_employment_owner_update on public.employment_records;
create trigger trg_employment_owner_update
before update on public.employment_records
for each row execute function public.enforce_employment_owner_update();

-- -----------------------------
-- Survey templates + questions
-- -----------------------------

create table if not exists public.survey_templates (
  id uuid primary key default gen_random_uuid(),
  title text not null default '',
  description text not null default '',
  version text not null default '',
  data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.survey_templates enable row level security;

create policy "survey_templates_select_signed_in"
on public.survey_templates
for select
to authenticated
using (public.is_signed_in());

create policy "survey_templates_admin_write"
on public.survey_templates
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop trigger if exists trg_survey_templates_updated_at on public.survey_templates;
create trigger trg_survey_templates_updated_at
before update on public.survey_templates
for each row execute function public.set_updated_at();

create table if not exists public.survey_template_questions (
  id uuid primary key default gen_random_uuid(),
  template_id uuid not null references public.survey_templates(id) on delete cascade,
  "order" integer not null default 0,
  type text not null default 'text',
  prompt text not null default '',
  required boolean not null default true,
  options text[] not null default '{}',
  scale_min integer,
  scale_max integer,
  section text,
  ched_item_number text,
  prefill_key text,
  is_standard_item boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_survey_template_questions_template
  on public.survey_template_questions(template_id, "order");

alter table public.survey_template_questions enable row level security;

create policy "survey_template_questions_select_signed_in"
on public.survey_template_questions
for select
to authenticated
using (public.is_signed_in());

create policy "survey_template_questions_admin_write"
on public.survey_template_questions
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop trigger if exists trg_survey_template_questions_updated_at on public.survey_template_questions;
create trigger trg_survey_template_questions_updated_at
before update on public.survey_template_questions
for each row execute function public.set_updated_at();

-- -----------------------------
-- Surveys + questions + responses + assignments
-- -----------------------------

create table if not exists public.surveys (
  id uuid primary key default gen_random_uuid(),
  title text not null default '',
  description text not null default '',
  status text not null default 'draft' check (status in ('draft','published','closed')),
  target_programs text[] not null default '{}',
  target_batch_years text[] not null default '{}',
  open_at timestamptz,
  close_at timestamptz,
  created_by uuid not null references auth.users(id),
  assignment_count integer not null default 0,
  response_count integer not null default 0,
  template_id uuid references public.survey_templates(id),
  template_version text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.surveys enable row level security;

create policy "surveys_select_signed_in"
on public.surveys
for select
to authenticated
using (public.is_signed_in());

create policy "surveys_insert_admin"
on public.surveys
for insert
to authenticated
with check (public.is_admin());

-- Allow admin update; allow alumni "response_count bump" not enforced here (can be handled in RPC later).
create policy "surveys_update_admin"
on public.surveys
for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy "surveys_delete_admin"
on public.surveys
for delete
to authenticated
using (public.is_admin());

drop trigger if exists trg_surveys_updated_at on public.surveys;
create trigger trg_surveys_updated_at
before update on public.surveys
for each row execute function public.set_updated_at();

create table if not exists public.survey_questions (
  id uuid primary key default gen_random_uuid(),
  survey_id uuid not null references public.surveys(id) on delete cascade,
  "order" integer not null default 0,
  type text not null default 'text',
  prompt text not null default '',
  required boolean not null default true,
  options text[] not null default '{}',
  scale_min integer,
  scale_max integer,
  section text,
  ched_item_number text,
  prefill_key text,
  is_standard_item boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_survey_questions_survey
  on public.survey_questions(survey_id, "order");

alter table public.survey_questions enable row level security;

create policy "survey_questions_select_signed_in"
on public.survey_questions
for select
to authenticated
using (public.is_signed_in());

create policy "survey_questions_admin_write"
on public.survey_questions
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop trigger if exists trg_survey_questions_updated_at on public.survey_questions;
create trigger trg_survey_questions_updated_at
before update on public.survey_questions
for each row execute function public.set_updated_at();

create table if not exists public.survey_responses (
  id uuid primary key default gen_random_uuid(),
  survey_id uuid not null references public.surveys(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'draft' check (status in ('draft','submitted')),
  answers jsonb not null default '{}'::jsonb,
  submitted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (survey_id, user_id)
);

alter table public.survey_responses enable row level security;

create policy "survey_responses_select_admin_or_owner"
on public.survey_responses
for select
to authenticated
using (public.is_admin() or user_id = auth.uid());

create policy "survey_responses_insert_owner"
on public.survey_responses
for insert
to authenticated
with check (user_id = auth.uid());

create policy "survey_responses_update_owner"
on public.survey_responses
for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

create policy "survey_responses_delete_admin"
on public.survey_responses
for delete
to authenticated
using (public.is_admin());

drop trigger if exists trg_survey_responses_updated_at on public.survey_responses;
create trigger trg_survey_responses_updated_at
before update on public.survey_responses
for each row execute function public.set_updated_at();

create table if not exists public.survey_assignments (
  id uuid primary key default gen_random_uuid(),
  survey_id uuid not null references public.surveys(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  survey_title text not null default '',
  status text not null default 'notStarted' check (status in ('notStarted','inProgress','completed')),
  assigned_at timestamptz not null default now(),
  last_reminder_at timestamptz,
  reminder_count integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_survey_assignments_user on public.survey_assignments(user_id);

alter table public.survey_assignments enable row level security;

create policy "survey_assignments_select_owner_or_admin"
on public.survey_assignments
for select
to authenticated
using (public.is_admin() or user_id = auth.uid());

create policy "survey_assignments_insert_delete_admin"
on public.survey_assignments
for insert
to authenticated
with check (public.is_admin());

create policy "survey_assignments_delete_admin"
on public.survey_assignments
for delete
to authenticated
using (public.is_admin());

-- Allow admin update; allow owner update only status (enforced by trigger).
create policy "survey_assignments_update_admin_or_owner"
on public.survey_assignments
for update
to authenticated
using (public.is_admin() or user_id = auth.uid())
with check (public.is_admin() or user_id = auth.uid());

drop trigger if exists trg_survey_assignments_updated_at on public.survey_assignments;
create trigger trg_survey_assignments_updated_at
before update on public.survey_assignments
for each row execute function public.set_updated_at();

create or replace function public.enforce_assignment_owner_update()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.is_admin() then
    return new;
  end if;

  if old.user_id <> auth.uid() then
    raise exception 'not owner';
  end if;

  -- Owner may only change status.
  if new.survey_id is distinct from old.survey_id
     or new.user_id is distinct from old.user_id
     or new.survey_title is distinct from old.survey_title
     or new.assigned_at is distinct from old.assigned_at
     or new.last_reminder_at is distinct from old.last_reminder_at
     or new.reminder_count is distinct from old.reminder_count
     or new.created_at is distinct from old.created_at then
    raise exception 'owner may only update status';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_assignment_owner_update on public.survey_assignments;
create trigger trg_assignment_owner_update
before update on public.survey_assignments
for each row execute function public.enforce_assignment_owner_update();

-- -----------------------------
-- Announcements
-- -----------------------------

create table if not exists public.announcements (
  id uuid primary key default gen_random_uuid(),
  title text not null default '',
  body text not null default '',
  status text not null default 'draft',
  published_at timestamptz,
  data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.announcements enable row level security;

create policy "announcements_select_signed_in"
on public.announcements
for select
to authenticated
using (public.is_signed_in());

create policy "announcements_admin_write"
on public.announcements
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop trigger if exists trg_announcements_updated_at on public.announcements;
create trigger trg_announcements_updated_at
before update on public.announcements
for each row execute function public.set_updated_at();

-- -----------------------------
-- Feedback
-- -----------------------------

create table if not exists public.feedback (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'submitted',
  message text not null default '',
  admin_reply text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.feedback enable row level security;

create policy "feedback_select_owner_or_admin"
on public.feedback
for select
to authenticated
using (public.is_admin() or user_id = auth.uid());

create policy "feedback_insert_owner_constraints"
on public.feedback
for insert
to authenticated
with check (
  user_id = auth.uid()
  and status = 'submitted'
  and length(message) >= 10
);

create policy "feedback_update_delete_admin_only"
on public.feedback
for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy "feedback_delete_admin_only"
on public.feedback
for delete
to authenticated
using (public.is_admin());

drop trigger if exists trg_feedback_updated_at on public.feedback;
create trigger trg_feedback_updated_at
before update on public.feedback
for each row execute function public.set_updated_at();

-- -----------------------------
-- Forum topics + posts
-- -----------------------------

create table if not exists public.forum_topics (
  id uuid primary key default gen_random_uuid(),
  title text not null default '',
  body text not null default '',
  author_uid uuid not null references auth.users(id) on delete cascade,
  author_name text not null default '',
  author_program text not null default '',
  reply_count integer not null default 0,
  last_reply_at timestamptz,
  is_locked boolean not null default false,
  is_pinned boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.forum_topics enable row level security;

create policy "forum_topics_select_signed_in"
on public.forum_topics
for select
to authenticated
using (public.is_signed_in());

create policy "forum_topics_insert_author"
on public.forum_topics
for insert
to authenticated
with check (author_uid = auth.uid());

create policy "forum_topics_update_admin_or_author"
on public.forum_topics
for update
to authenticated
using (public.is_admin() or author_uid = auth.uid())
with check (public.is_admin() or author_uid = auth.uid());

create policy "forum_topics_delete_admin_or_author"
on public.forum_topics
for delete
to authenticated
using (public.is_admin() or author_uid = auth.uid());

drop trigger if exists trg_forum_topics_updated_at on public.forum_topics;
create trigger trg_forum_topics_updated_at
before update on public.forum_topics
for each row execute function public.set_updated_at();

create table if not exists public.forum_posts (
  id uuid primary key default gen_random_uuid(),
  topic_id uuid not null references public.forum_topics(id) on delete cascade,
  body text not null default '',
  author_uid uuid not null references auth.users(id) on delete cascade,
  author_name text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_forum_posts_topic on public.forum_posts(topic_id, created_at);

alter table public.forum_posts enable row level security;

create policy "forum_posts_select_signed_in"
on public.forum_posts
for select
to authenticated
using (public.is_signed_in());

-- Firestore: create only if author matches and topic not locked.
create policy "forum_posts_insert_author_when_unlocked"
on public.forum_posts
for insert
to authenticated
with check (
  author_uid = auth.uid()
  and exists (
    select 1 from public.forum_topics t
    where t.id = topic_id and t.is_locked = false
  )
);

-- Firestore: delete admin or author; update false.
create policy "forum_posts_delete_admin_or_author"
on public.forum_posts
for delete
to authenticated
using (public.is_admin() or author_uid = auth.uid());

create policy "forum_posts_update_never"
on public.forum_posts
for update
to authenticated
using (false)
with check (false);

-- -----------------------------
-- User-owned subcollections (reminders, user_notifications, favorite_jobs)
-- -----------------------------

create table if not exists public.reminders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null default '',
  body text not null default '',
  scheduled_at timestamptz,
  sent_at timestamptz,
  data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.reminders enable row level security;
create policy "reminders_owner_rw"
on public.reminders
for all
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop trigger if exists trg_reminders_updated_at on public.reminders;
create trigger trg_reminders_updated_at
before update on public.reminders
for each row execute function public.set_updated_at();

create table if not exists public.user_notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null default '',
  body text not null default '',
  type text not null default '',
  is_read boolean not null default false,
  data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.user_notifications enable row level security;

create policy "user_notifications_select_owner"
on public.user_notifications
for select
to authenticated
using (user_id = auth.uid());

create policy "user_notifications_insert_admin_or_owner"
on public.user_notifications
for insert
to authenticated
with check (public.is_admin() or user_id = auth.uid());

create policy "user_notifications_update_delete_owner"
on public.user_notifications
for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

create policy "user_notifications_delete_owner"
on public.user_notifications
for delete
to authenticated
using (user_id = auth.uid());

drop trigger if exists trg_user_notifications_updated_at on public.user_notifications;
create trigger trg_user_notifications_updated_at
before update on public.user_notifications
for each row execute function public.set_updated_at();

create table if not exists public.favorite_jobs (
  user_id uuid not null references auth.users(id) on delete cascade,
  job_id uuid not null references public.jobs(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, job_id)
);

alter table public.favorite_jobs enable row level security;
create policy "favorite_jobs_owner_rw"
on public.favorite_jobs
for all
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

commit;

