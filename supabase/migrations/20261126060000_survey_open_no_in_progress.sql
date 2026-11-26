-- Opening a survey must not mark the assignment inProgress.
-- inProgress is reserved for a real draft save (saveResponse / first_draft_at).
-- Also heal assignments that were bumped solely by record_survey_opened.

begin;

create or replace function public.record_survey_opened(
  p_survey_id uuid,
  p_device_category text default null,
  p_platform_family text default null,
  p_browser_family text default null
)
returns void
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
  if not public.caller_is_active() then
    raise exception 'not authorized' using errcode = '42501';
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

  -- Touch assignment updated_at only — do not promote notStarted → inProgress.
  update public.survey_assignments
  set updated_at = now()
  where survey_id = p_survey_id and user_id = uid;
end;
$$;

revoke all on function public.record_survey_opened(uuid, text, text, text)
  from public;
grant execute on function public.record_survey_opened(uuid, text, text, text)
  to authenticated;

-- Heal false inProgress: opened (or empty draft) but never actually drafted.
update public.survey_assignments a
set
  status = 'notStarted',
  updated_at = now()
where a.status = 'inProgress'
  and not exists (
    select 1
    from public.survey_responses r
    where r.survey_id = a.survey_id
      and r.user_id = a.user_id
      and (
        r.status = 'submitted'
        or r.first_draft_at is not null
        or exists (
          select 1
          from public.survey_response_events e
          where e.survey_id = a.survey_id
            and e.user_id = a.user_id
            and e.event_type in ('draft_saved', 'submitted')
        )
        or (
          r.answers is not null
          and jsonb_typeof(r.answers) = 'object'
          and r.answers <> '{}'::jsonb
        )
      )
  );

comment on function public.record_survey_opened(uuid, text, text, text) is
  'Records opened_at + opened event. Does not change assignment status; inProgress requires a draft save.';

commit;
