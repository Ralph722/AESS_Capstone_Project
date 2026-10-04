-- Notifications Phase 1: foundation.
--  * user_notifications: priority, dedupe_key, route, read_at, expires_at, source.
--  * Unique (user_id, dedupe_key) so one logical notice exists once per user.
--  * notification_preferences (per-type in-app / push switches, quiet hours).
--  * enqueue_notifications(): the single server-side entry point used by
--    triggers, scheduled jobs and admin RPCs. Not callable from clients.

begin;

-- ---------------------------------------------------------------------------
-- user_notifications columns
-- ---------------------------------------------------------------------------
alter table public.user_notifications
  add column if not exists priority text not null default 'normal',
  add column if not exists dedupe_key text,
  add column if not exists route text,
  add column if not exists read_at timestamptz,
  add column if not exists expires_at timestamptz,
  add column if not exists source text not null default 'app';

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'user_notifications_priority_check'
  ) then
    alter table public.user_notifications
      add constraint user_notifications_priority_check
      check (priority in ('low', 'normal', 'high', 'urgent'));
  end if;
end $$;

-- Backfill keys for notices that later code dedupes on (first row wins).
with keyed as (
  select
    id,
    user_id,
    created_at,
    case
      when type = 'message' and data ? 'messageId'
        then 'msg:' || (data->>'messageId')
      when type = 'survey' and title like 'New survey:%' and data ? 'relatedId'
        then 'survey:' || (data->>'relatedId') || ':assigned'
      when type = 'job' and (data->>'kind') like 'job_deadline_%' and data ? 'jobId'
        then 'job:' || (data->>'jobId') || ':deadline:'
          || replace(data->>'kind', 'job_deadline_', '')
    end as k
  from public.user_notifications
  where dedupe_key is null
),
ranked as (
  select id, k, row_number() over (partition by user_id, k order by created_at) as rn
  from keyed
  where k is not null
)
update public.user_notifications un
set dedupe_key = r.k
from ranked r
where un.id = r.id and r.rn = 1;

create unique index if not exists user_notifications_user_dedupe_key
  on public.user_notifications (user_id, dedupe_key);

-- read_at follows is_read.
create or replace function public.user_notifications_track_read()
returns trigger
language plpgsql
as $$
begin
  if new.is_read and not coalesce(old.is_read, false) then
    new.read_at := now();
  elsif not new.is_read then
    new.read_at := null;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_user_notifications_track_read on public.user_notifications;
create trigger trg_user_notifications_track_read
before update of is_read on public.user_notifications
for each row execute function public.user_notifications_track_read();

-- ---------------------------------------------------------------------------
-- Preferences
-- ---------------------------------------------------------------------------
create table if not exists public.notification_preferences (
  user_id uuid primary key references auth.users (id) on delete cascade,
  -- { "<notification type>": true|false } — missing keys mean "on".
  in_app jsonb not null default '{}'::jsonb,
  push jsonb not null default '{}'::jsonb,
  quiet_hours_enabled boolean not null default false,
  quiet_start time not null default '22:00',
  quiet_end time not null default '07:00',
  timezone text not null default 'Asia/Manila',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.notification_preferences enable row level security;

drop policy if exists notification_preferences_select_own on public.notification_preferences;
create policy notification_preferences_select_own
on public.notification_preferences for select
using (user_id = auth.uid());

drop policy if exists notification_preferences_insert_own on public.notification_preferences;
create policy notification_preferences_insert_own
on public.notification_preferences for insert
with check (user_id = auth.uid());

drop policy if exists notification_preferences_update_own on public.notification_preferences;
create policy notification_preferences_update_own
on public.notification_preferences for update
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop trigger if exists trg_notification_preferences_updated_at on public.notification_preferences;
create trigger trg_notification_preferences_updated_at
before update on public.notification_preferences
for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

-- Channel switch for one user / type. Account notices, urgent notices and
-- in-app survey assignments (tracer is required) cannot be switched off.
create or replace function public.notification_channel_allowed(
  p_user uuid,
  p_type text,
  p_channel text,
  p_priority text default 'normal'
)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  prefs public.notification_preferences%rowtype;
  raw text;
begin
  if p_type = 'system' or p_priority = 'urgent' then
    return true;
  end if;
  if p_channel = 'in_app' and p_type = 'survey' then
    return true;
  end if;

  select * into prefs from public.notification_preferences where user_id = p_user;
  if not found then
    return true;
  end if;

  raw := case when p_channel = 'push' then prefs.push->>p_type else prefs.in_app->>p_type end;
  return coalesce(lower(raw), 'true') <> 'false';
end;
$$;

-- When a push should wait for the end of the user's quiet hours (null = now).
create or replace function public.notification_quiet_until(
  p_user uuid,
  p_priority text default 'normal'
)
returns timestamptz
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  prefs public.notification_preferences%rowtype;
  tz text;
  local_now timestamp;
  local_t time;
  resume_at timestamp;
begin
  if p_priority = 'urgent' then
    return null;
  end if;

  select * into prefs from public.notification_preferences where user_id = p_user;
  if not found or not prefs.quiet_hours_enabled or prefs.quiet_start = prefs.quiet_end then
    return null;
  end if;

  tz := coalesce(nullif(trim(prefs.timezone), ''), 'Asia/Manila');
  begin
    local_now := now() at time zone tz;
  exception when others then
    tz := 'Asia/Manila';
    local_now := now() at time zone tz;
  end;
  local_t := local_now::time;

  if prefs.quiet_start < prefs.quiet_end then
    if local_t >= prefs.quiet_start and local_t < prefs.quiet_end then
      resume_at := local_now::date + prefs.quiet_end;
    end if;
  else
    if local_t >= prefs.quiet_start then
      resume_at := (local_now::date + 1) + prefs.quiet_end;
    elsif local_t < prefs.quiet_end then
      resume_at := local_now::date + prefs.quiet_end;
    end if;
  end if;

  if resume_at is null then
    return null;
  end if;
  return resume_at at time zone tz;
end;
$$;

-- Non-admin, not deactivated in the roster.
create or replace function public.notification_is_active_alumni(p_user uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.users u
    where u.id = p_user and coalesce(u.role, 'user') <> 'admin'
  )
  and not exists (
    select 1 from public.alumni_members m
    where m.auth_uid = p_user and coalesce(m.is_deactivated, false)
  );
$$;

create or replace function public.notification_admin_ids()
returns uuid[]
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(array_agg(id), '{}'::uuid[]) from public.users where role = 'admin';
$$;

-- CHED GTS lives on the Tracer tab; other surveys open directly.
create or replace function public.notification_survey_route(p_survey_id uuid)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select case
    when coalesce(s.data->>'kind', '') = 'ched_gts_builtin'
      or coalesce(s.data->>'template_key', '') = 'ched_gts_builtin'
      then 'tracer'
    else 'survey/' || p_survey_id::text
  end
  from public.surveys s
  where s.id = p_survey_id;
$$;

-- ---------------------------------------------------------------------------
-- Single entry point
-- ---------------------------------------------------------------------------
create or replace function public.enqueue_notifications(
  p_user_ids uuid[],
  p_type text,
  p_title text,
  p_body text,
  p_data jsonb default '{}'::jsonb,
  p_priority text default 'normal',
  p_dedupe_key text default null,
  p_route text default null,
  p_push boolean default true,
  p_expires_at timestamptz default null
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer := 0;
begin
  if p_user_ids is null or cardinality(p_user_ids) = 0
     or coalesce(trim(p_title), '') = '' then
    return 0;
  end if;

  with recipients as (
    select distinct r.uid
    from unnest(p_user_ids) as r(uid)
    where r.uid is not null
      and exists (select 1 from auth.users au where au.id = r.uid)
      and public.notification_channel_allowed(r.uid, p_type, 'in_app', p_priority)
  ),
  ins as (
    insert into public.user_notifications (
      user_id, title, body, type, is_read, data, priority, dedupe_key,
      route, source, expires_at, created_at, updated_at
    )
    select
      uid,
      left(trim(p_title), 200),
      left(coalesce(p_body, ''), 500),
      p_type,
      false,
      coalesce(p_data, '{}'::jsonb) || jsonb_build_object('push', p_push),
      coalesce(p_priority, 'normal'),
      p_dedupe_key,
      p_route,
      'server',
      p_expires_at,
      now(),
      now()
    from recipients
    on conflict (user_id, dedupe_key) do nothing
    returning 1
  )
  select count(*) into v_count from ins;

  return v_count;
end;
$$;

revoke all on function public.enqueue_notifications(uuid[], text, text, text, jsonb, text, text, text, boolean, timestamptz)
  from public, anon, authenticated;
revoke all on function public.notification_quiet_until(uuid, text) from public, anon, authenticated;
revoke all on function public.notification_channel_allowed(uuid, text, text, text) from public, anon, authenticated;
revoke all on function public.notification_is_active_alumni(uuid) from public, anon, authenticated;
revoke all on function public.notification_admin_ids() from public, anon, authenticated;
revoke all on function public.notification_survey_route(uuid) from public, anon, authenticated;

commit;
