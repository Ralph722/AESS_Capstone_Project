-- DSS one-click actions: send tracer reminders to a flagged group's
-- non-respondents, or matching job postings to its unemployed respondents.
-- Notifications are inserted server-side; the action is logged on the flag
-- and the flag moves to in_progress so the impact check can follow up.

begin;

alter table public.dss_flag_notes
  drop constraint if exists dss_flag_notes_event_type_check;

alter table public.dss_flag_notes
  add constraint dss_flag_notes_event_type_check
  check (
    event_type in (
      'note',
      'status',
      'assign',
      'impact',
      'announcement',
      'reopen',
      'action'
    )
  );

-- Q16 answer as text (stored as a string or a one-item array).
create or replace function public.dss_ched_single(p_answers jsonb, p_key text)
returns text
language sql
immutable
as $$
  select nullif(trim(
    case jsonb_typeof(p_answers -> p_key)
      when 'array' then p_answers -> p_key ->> 0
      else p_answers ->> p_key
    end
  ), '');
$$;

create or replace function public.dss_run_flag_action(
  p_flag_id uuid,
  p_action text,
  p_user_ids uuid[],
  p_job_ids uuid[] default '{}'::uuid[]
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  f public.dss_flags%rowtype;
  s public.surveys%rowtype;
  v_survey_id uuid;
  v_actor uuid := auth.uid();
  v_actor_name text;
  v_today text := to_char(now() at time zone 'Asia/Manila', 'YYYY-MM-DD');
  v_selected integer := cardinality(coalesce(p_user_ids, '{}'::uuid[]));
  v_recipients uuid[];
  v_sent integer := 0;
  v_jobs jsonb := '[]'::jsonb;
  v_job_count integer := 0;
  v_first_job jsonb;
  v_note text;
  v_intervention text;
  v_cohort text;
begin
  if not public.is_admin() then
    raise exception 'not allowed';
  end if;

  select * into f from public.dss_flags where id = p_flag_id for update;
  if not found then
    raise exception 'flag not found';
  end if;
  if f.status not in ('open', 'in_progress') then
    raise exception 'flag is already closed';
  end if;

  begin
    v_survey_id := nullif(f.survey_id, '')::uuid;
  exception when invalid_text_representation then
    v_survey_id := null;
  end;
  select * into s from public.surveys where id = v_survey_id;
  if not found then
    raise exception 'survey for this flag was not found';
  end if;

  v_cohort := case f.cohort_level
    when 'institution' then 'whole institution'
    when 'course' then f.course || ' (all batches)'
    else f.course || ' · Batch ' || f.batch_year
  end;

  -- Active alumni only.
  select coalesce(array_agg(distinct u), '{}'::uuid[]) into v_recipients
  from unnest(coalesce(p_user_ids, '{}'::uuid[])) as t(u)
  where public.notification_is_active_alumni(u);

  if p_action = 'survey_reminder' then
    if f.rule_id <> 'DATA_QUALITY_LOW' then
      raise exception 'reminders are only available on response-rate flags';
    end if;

    -- Never remind someone who already submitted.
    select coalesce(array_agg(u), '{}'::uuid[]) into v_recipients
    from unnest(v_recipients) as t(u)
    where not exists (
      select 1 from public.survey_responses r
      where r.survey_id = s.id and r.user_id = u and r.status = 'submitted'
    );

    v_sent := public.enqueue_notifications(
      v_recipients,
      'survey',
      'Reminder: ' || coalesce(s.title, ''),
      'Please complete "' || coalesce(s.title, '') || '" in the Alumni System app.',
      jsonb_build_object(
        'relatedId', s.id::text,
        'surveyId', s.id::text,
        'kind', 'reminder',
        'source', 'dss'
      ),
      'high',
      'survey:' || s.id::text || ':reminder:' || v_today,
      public.notification_survey_route(s.id)
    );

    update public.survey_assignments a
    set last_reminder_at = now(), reminder_count = a.reminder_count + 1
    where a.survey_id = s.id
      and a.user_id = any (v_recipients)
      and exists (
        select 1 from public.user_notifications n
        where n.user_id = a.user_id
          and n.dedupe_key = 'survey:' || s.id::text || ':reminder:' || v_today
          and n.created_at >= now() - interval '1 minute'
      );

    v_intervention := 'Survey reminder campaign';
    v_note := format(
      'Sent a tracer reminder for "%s" to %s alumni in %s (%s selected; already reminded today or already submitted are skipped).',
      s.title, v_sent, v_cohort, v_selected
    );

  elsif p_action = 'job_matches' then
    if f.rule_id <> 'UNEMPLOYMENT_HIGH' then
      raise exception 'job matches are only available on unemployment flags';
    end if;

    select
      count(*),
      coalesce(
        jsonb_agg(
          jsonb_build_object(
            'id', j.id::text,
            'title', coalesce(nullif(trim(j.title), ''), nullif(trim(j.data ->> 'jobTitle'), ''), 'Job opening'),
            'company', coalesce(nullif(trim(j.company), ''), nullif(trim(j.data ->> 'companyName'), ''), '')
          )
          order by j.created_at desc
        ),
        '[]'::jsonb
      )
    into v_job_count, v_jobs
    from public.jobs j
    where j.id = any (coalesce(p_job_ids, '{}'::uuid[]))
      and lower(coalesce(j.status, '')) = 'active';

    if v_job_count = 0 then
      raise exception 'pick at least one active job posting';
    end if;

    -- Only respondents of this wave who reported not being employed.
    select coalesce(array_agg(u), '{}'::uuid[]) into v_recipients
    from unnest(v_recipients) as t(u)
    where exists (
      select 1 from public.survey_responses r
      where r.survey_id = s.id
        and r.user_id = u
        and r.status = 'submitted'
        and public.dss_ched_single(r.answers, 'ched_16') in ('No', 'Never Employed')
    );

    v_first_job := v_jobs -> 0;
    v_sent := public.enqueue_notifications(
      v_recipients,
      'job',
      case when v_job_count = 1
        then 'Job opening for you: ' || (v_first_job ->> 'title')
        else v_job_count || ' job openings picked for you'
      end,
      case when v_job_count = 1
        then coalesce(nullif(v_first_job ->> 'company', ''), 'An employer')
          || ' is hiring. Open the Jobs tab to view and apply.'
        else 'Your alumni office picked ' || v_job_count
          || ' openings that match your program. Open the Jobs tab to view and apply.'
      end,
      jsonb_build_object(
        'kind', 'dss_job_matches',
        'source', 'dss',
        'jobIds', (select jsonb_agg(x ->> 'id') from jsonb_array_elements(v_jobs) x),
        'target', 'jobs'
      ) || case when v_job_count = 1
        then jsonb_build_object('jobId', v_first_job ->> 'id', 'relatedId', v_first_job ->> 'id')
        else '{}'::jsonb
      end,
      'high',
      'dss:' || f.id::text || ':jobs:' || v_today,
      case when v_job_count = 1 then 'job/' || (v_first_job ->> 'id') else 'job' end
    );

    v_intervention := 'Job board / posting push';
    v_note := format(
      'Sent %s matching job posting(s) to %s unemployed respondents in %s (%s selected; already sent today is skipped).',
      v_job_count, v_sent, v_cohort, v_selected
    );

  else
    raise exception 'unknown action %', p_action;
  end if;

  select coalesce(nullif(trim(u.display_name), ''), nullif(trim(u.email), ''), 'Admin')
  into v_actor_name
  from public.users u where u.id = v_actor;

  insert into public.dss_flag_notes (
    flag_id, author_id, author_name, note, status_from, status_to,
    event_type, metadata
  ) values (
    f.id,
    v_actor,
    coalesce(v_actor_name, 'Admin'),
    v_note,
    case when f.status = 'open' then 'open' end,
    case when f.status = 'open' then 'in_progress' end,
    'action',
    jsonb_build_object(
      'action', p_action,
      'selected', v_selected,
      'eligible', cardinality(v_recipients),
      'sent', v_sent,
      'jobs', v_jobs
    )
  );

  update public.dss_flags
  set status = 'in_progress',
      intervention_type = coalesce(intervention_type, v_intervention),
      updated_by = v_actor
  where id = f.id;

  return jsonb_build_object(
    'selected', v_selected,
    'eligible', cardinality(v_recipients),
    'sent', v_sent,
    'jobs', v_job_count
  );
end;
$$;

revoke all on function public.dss_run_flag_action(uuid, text, uuid[], uuid[]) from public, anon;
grant execute on function public.dss_run_flag_action(uuid, text, uuid[], uuid[]) to authenticated;

commit;
