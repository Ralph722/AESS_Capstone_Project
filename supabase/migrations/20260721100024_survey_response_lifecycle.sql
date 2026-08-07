-- Survey response lifecycle: privacy-safe device metadata + append-only events.

begin;

alter table public.survey_responses
  add column if not exists opened_at timestamptz,
  add column if not exists first_draft_at timestamptz,
  add column if not exists device_category text
    check (
      device_category is null
      or device_category in ('mobile', 'tablet', 'desktop', 'other')
    ),
  add column if not exists platform_family text
    check (
      platform_family is null
      or platform_family in (
        'android', 'ios', 'web', 'windows', 'macos', 'linux', 'other'
      )
    ),
  add column if not exists browser_family text
    check (
      browser_family is null
      or browser_family in (
        'chrome', 'safari', 'firefox', 'edge', 'opera', 'other', 'native'
      )
    );

create index if not exists idx_survey_responses_survey_status
  on public.survey_responses (survey_id, status);

create table if not exists public.survey_response_events (
  id uuid primary key default gen_random_uuid(),
  survey_id uuid not null references public.surveys(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  response_id uuid references public.survey_responses(id) on delete set null,
  event_type text not null
    check (event_type in ('opened', 'draft_saved', 'submitted')),
  device_category text
    check (
      device_category is null
      or device_category in ('mobile', 'tablet', 'desktop', 'other')
    ),
  platform_family text
    check (
      platform_family is null
      or platform_family in (
        'android', 'ios', 'web', 'windows', 'macos', 'linux', 'other'
      )
    ),
  browser_family text
    check (
      browser_family is null
      or browser_family in (
        'chrome', 'safari', 'firefox', 'edge', 'opera', 'other', 'native'
      )
    ),
  meta jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_survey_response_events_survey_user_time
  on public.survey_response_events (survey_id, user_id, created_at);

alter table public.survey_response_events enable row level security;

drop policy if exists "survey_response_events_select_admin_or_owner"
  on public.survey_response_events;
create policy "survey_response_events_select_admin_or_owner"
  on public.survey_response_events for select to authenticated
  using (public.is_admin() or user_id = auth.uid());

drop policy if exists "survey_response_events_insert_owner"
  on public.survey_response_events;
create policy "survey_response_events_insert_owner"
  on public.survey_response_events for insert to authenticated
  with check (user_id = auth.uid());

drop policy if exists "survey_response_events_delete_admin"
  on public.survey_response_events;
create policy "survey_response_events_delete_admin"
  on public.survey_response_events for delete to authenticated
  using (public.is_admin());

create or replace function public.record_survey_opened(
  p_survey_id uuid,
  p_device_category text default null,
  p_platform_family text default null,
  p_browser_family text default null
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  rid uuid;
begin
  if uid is null then
    raise exception 'unauthenticated';
  end if;

  insert into public.survey_responses (
    survey_id,
    user_id,
    status,
    opened_at,
    device_category,
    platform_family,
    browser_family
  )
  values (
    p_survey_id,
    uid,
    'draft',
    now(),
    p_device_category,
    p_platform_family,
    p_browser_family
  )
  on conflict (survey_id, user_id) do update set
    opened_at = coalesce(public.survey_responses.opened_at, excluded.opened_at),
    device_category = coalesce(
      excluded.device_category,
      public.survey_responses.device_category
    ),
    platform_family = coalesce(
      excluded.platform_family,
      public.survey_responses.platform_family
    ),
    browser_family = coalesce(
      excluded.browser_family,
      public.survey_responses.browser_family
    ),
    updated_at = now()
  returning id into rid;

  if not exists (
    select 1
    from public.survey_response_events e
    where e.survey_id = p_survey_id
      and e.user_id = uid
      and e.event_type = 'opened'
  ) then
    insert into public.survey_response_events (
      survey_id,
      user_id,
      response_id,
      event_type,
      device_category,
      platform_family,
      browser_family
    )
    values (
      p_survey_id,
      uid,
      rid,
      'opened',
      p_device_category,
      p_platform_family,
      p_browser_family
    );
  end if;

  update public.survey_assignments
  set
    status = case
      when status = 'notStarted' then 'inProgress'
      else status
    end,
    updated_at = now()
  where survey_id = p_survey_id and user_id = uid;
end;
$$;

revoke all on function public.record_survey_opened(uuid, text, text, text)
  from public;
grant execute on function public.record_survey_opened(uuid, text, text, text)
  to authenticated;

commit;
