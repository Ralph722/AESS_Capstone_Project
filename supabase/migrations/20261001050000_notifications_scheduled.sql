-- Notifications Phase 3: scheduled notices (pg_cron).
--
-- Replaces the client-side job deadline check (which only ran when an
-- alumnus opened Home/Jobs) and adds time-based notices that no user action
-- triggers: survey windows opening/closing, event-day reminders, an admin
-- digest, and housekeeping.
--
-- Calendar days are Asia/Manila. cron runs in UTC:
--   every 15 min            -> 'frequent' (survey open_at reached)
--   23:00 UTC = 07:00 Manila -> 'events'   (event tomorrow / today)
--   00:00 UTC = 08:00 Manila -> 'morning'  (job deadlines, survey closing, admin digest)
--   19:30 UTC = 03:30 Manila -> 'cleanup'
--
-- Every notice has a dedupe key, so re-running a job is harmless.

create extension if not exists pg_cron with schema pg_catalog;
grant usage on schema cron to postgres;

begin;

create or replace function public.notification_manila_today()
returns date
language sql
stable
as $$
  select (now() at time zone 'Asia/Manila')::date;
$$;

create or replace function public.notification_try_timestamptz(p text)
returns timestamptz
language plpgsql
stable
as $$
begin
  if p is null or trim(p) = '' then
    return null;
  end if;
  return p::timestamptz;
exception when others then
  return null;
end;
$$;

-- ---------------------------------------------------------------------------
-- Job deadlines: 3 days / 1 day before the deadline day, to alumni who
-- favorited or are interested in the job, or whose program it targets.
-- ---------------------------------------------------------------------------
create or replace function public.run_job_deadline_reminders()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  today date := public.notification_manila_today();
  j record;
  targets text[];
  recipients uuid[];
  job_title text;
  company text;
  sent integer := 0;
begin
  for j in
    select x.*, (x.deadline at time zone 'Asia/Manila')::date - today as days_left
    from (
      select jb.id, jb.title, jb.company, jb.data,
             public.notification_try_timestamptz(jb.data->>'applicationDeadline') as deadline
      from public.jobs jb
      where lower(coalesce(jb.status, '')) = 'active'
    ) x
    where x.deadline is not null
      and (x.deadline at time zone 'Asia/Manila')::date - today in (1, 3)
  loop
    targets := array(
      select trim(t) from unnest(public.notification_jsonb_text_array(j.data->'targetPrograms')) t
      where trim(t) <> ''
    );

    recipients := array(
      select r.uid from (
        select f.user_id as uid from public.favorite_jobs f where f.job_id = j.id
        union
        select i.user_id from public.job_interests i where i.job_id = j.id
        union
        select u.id from public.users u
        where cardinality(targets) > 0
          and public.program_targets_include(targets, u.program)
        union
        select m.auth_uid from public.alumni_members m
        where cardinality(targets) > 0
          and m.auth_uid is not null
          and coalesce(m.is_registered_user, false)
          and public.program_targets_include(targets, m.course)
      ) r
      where public.notification_is_active_alumni(r.uid)
    );

    job_title := coalesce(nullif(trim(j.title), ''), nullif(trim(j.data->>'jobTitle'), ''), 'a role');
    company := coalesce(nullif(trim(j.company), ''), nullif(trim(j.data->>'companyName'), ''), 'An employer');

    sent := sent + public.enqueue_notifications(
      recipients,
      'job',
      case when j.days_left = 1 then 'Deadline tomorrow: ' else 'Deadline in 3 days: ' end || job_title,
      company || ' — application deadline approaching',
      jsonb_build_object(
        'relatedId', j.id::text,
        'jobId', j.id::text,
        'jobTitle', job_title,
        'companyName', company,
        'target', 'jobs',
        'kind', 'job_deadline_' || j.days_left || 'd',
        'daysLeft', j.days_left
      ),
      'high',
      'job:' || j.id::text || ':deadline:' || j.days_left || 'd',
      'job/' || j.id::text,
      true,
      ((j.deadline at time zone 'Asia/Manila')::date + 1)::timestamp at time zone 'Asia/Manila'
    );
  end loop;
  return sent;
end;
$$;

-- ---------------------------------------------------------------------------
-- Surveys closing in 3 days / 1 day -> alumni who have not completed them.
-- ---------------------------------------------------------------------------
create or replace function public.run_survey_closing_reminders()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  today date := public.notification_manila_today();
  s public.surveys%rowtype;
  days_left integer;
  is_ched boolean;
  label text;
  sent integer := 0;
begin
  for s in
    select * from public.surveys sv
    where sv.close_at is not null
      and public.notification_survey_accepting(sv)
      and (sv.close_at at time zone 'Asia/Manila')::date - today in (1, 3)
  loop
    days_left := (s.close_at at time zone 'Asia/Manila')::date - today;
    is_ched := coalesce(s.data->>'kind', '') = 'ched_gts_builtin'
      or coalesce(s.data->>'template_key', '') = 'ched_gts_builtin';
    label := case when days_left = 1 then 'tomorrow' else 'in 3 days' end;

    sent := sent + public.enqueue_notifications(
      array(
        select a.user_id from public.survey_assignments a
        where a.survey_id = s.id
          and a.status <> 'completed'
          and public.notification_is_active_alumni(a.user_id)
      ),
      'survey',
      'Survey closing ' || label || ': ' || coalesce(s.title, ''),
      case when is_ched
        then 'The graduate tracer survey closes ' || label || '. Please complete it before then.'
        else '"' || coalesce(s.title, 'This survey') || '" closes ' || label || '. Please complete it before then.' end,
      jsonb_build_object(
        'relatedId', s.id::text,
        'surveyId', s.id::text,
        'kind', 'closing_' || days_left || 'd'
      ),
      'high',
      'survey:' || s.id::text || ':closing:' || days_left || 'd',
      public.notification_survey_route(s.id),
      true,
      s.close_at
    );
  end loop;
  return sent;
end;
$$;

-- ---------------------------------------------------------------------------
-- Scheduled surveys whose open_at has arrived. Assignments made before the
-- window opened got no notice (the assignment trigger only fires while the
-- survey accepts responses); this sends it under the same "assigned" key.
-- ---------------------------------------------------------------------------
create or replace function public.run_survey_open_notifications()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  s public.surveys%rowtype;
  sent integer := 0;
begin
  for s in
    select * from public.surveys sv
    where sv.open_at is not null
      and sv.open_at > now() - interval '2 days'
      and public.notification_survey_accepting(sv)
  loop
    sent := sent + public.notification_survey_assigned(
      s,
      array(
        select a.user_id from public.survey_assignments a
        where a.survey_id = s.id and a.status <> 'completed'
      )
    );
  end loop;
  return sent;
end;
$$;

-- ---------------------------------------------------------------------------
-- Event reminders (in-app only; the phone also schedules local reminders)
-- for alumni who RSVP'd "going": the day before and the morning of.
-- ---------------------------------------------------------------------------
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
           (ev.date at time zone 'Asia/Manila')::date as event_day,
           (ev.date at time zone 'Asia/Manila')::date - today as days_left
    from public.events ev
    where coalesce(ev.status, 'Active') = 'Active'
      and not coalesce(ev.cancelled, false)
      and ev.date is not null
      and (ev.date at time zone 'Asia/Manila')::date - today in (0, 1)
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

-- ---------------------------------------------------------------------------
-- Admin digest: survey submissions received yesterday (Manila).
-- ---------------------------------------------------------------------------
create or replace function public.run_admin_survey_digest()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  yesterday date := public.notification_manila_today() - 1;
  responses integer;
  surveys_count integer;
begin
  select count(*), count(distinct r.survey_id)
  into responses, surveys_count
  from public.survey_responses r
  where r.status = 'submitted'
    and r.submitted_at is not null
    and (r.submitted_at at time zone 'Asia/Manila')::date = yesterday;

  if coalesce(responses, 0) = 0 then
    return 0;
  end if;

  return public.enqueue_notifications(
    public.notification_admin_ids(),
    'survey',
    'Survey responses yesterday',
    responses || case when responses = 1 then ' response was' else ' responses were' end
      || ' submitted across ' || surveys_count
      || case when surveys_count = 1 then ' survey.' else ' surveys.' end,
    jsonb_build_object(
      'kind', 'admin_digest',
      'date', yesterday::text,
      'responses', responses,
      'surveys', surveys_count
    ),
    'low',
    'digest:survey_submissions:' || yesterday::text,
    'admin/surveys',
    false
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Housekeeping: expired notices, read notices after 90 days, everything
-- after 180 days.
-- ---------------------------------------------------------------------------
create or replace function public.run_notification_cleanup()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  removed integer;
begin
  delete from public.user_notifications n
  where (n.expires_at is not null and n.expires_at < now() - interval '1 day')
     or (n.is_read and n.created_at < now() - interval '90 days')
     or n.created_at < now() - interval '180 days';
  get diagnostics removed = row_count;
  return removed;
end;
$$;

-- ---------------------------------------------------------------------------
-- Dispatcher called by pg_cron. One failing task does not stop the others.
-- ---------------------------------------------------------------------------
create or replace function public.run_scheduled_notifications(p_kind text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  result jsonb := jsonb_build_object('kind', p_kind, 'at', now());
  task text;
  tasks text[];
  n integer;
begin
  tasks := case p_kind
    when 'frequent' then array['survey_open']
    when 'events' then array['event_reminders']
    when 'morning' then array['job_deadlines', 'survey_closing', 'admin_digest']
    when 'cleanup' then array['cleanup']
    else array[]::text[]
  end;

  foreach task in array tasks loop
    begin
      n := case task
        when 'survey_open' then public.run_survey_open_notifications()
        when 'event_reminders' then public.run_event_reminders()
        when 'job_deadlines' then public.run_job_deadline_reminders()
        when 'survey_closing' then public.run_survey_closing_reminders()
        when 'admin_digest' then public.run_admin_survey_digest()
        when 'cleanup' then public.run_notification_cleanup()
      end;
      result := result || jsonb_build_object(task, n);
    exception when others then
      raise warning 'run_scheduled_notifications(%/%): %', p_kind, task, sqlerrm;
      result := result || jsonb_build_object(task, 'error: ' || sqlerrm);
    end;
  end loop;
  return result;
end;
$$;

revoke all on function public.run_job_deadline_reminders() from public, anon, authenticated;
revoke all on function public.run_survey_closing_reminders() from public, anon, authenticated;
revoke all on function public.run_survey_open_notifications() from public, anon, authenticated;
revoke all on function public.run_event_reminders() from public, anon, authenticated;
revoke all on function public.run_admin_survey_digest() from public, anon, authenticated;
revoke all on function public.run_notification_cleanup() from public, anon, authenticated;
revoke all on function public.run_scheduled_notifications(text) from public, anon, authenticated;

commit;

-- cron.schedule(name, ...) replaces an existing job with the same name.
select cron.schedule('aess-notify-frequent', '*/15 * * * *', $$select public.run_scheduled_notifications('frequent')$$);
select cron.schedule('aess-notify-events',   '0 23 * * *',   $$select public.run_scheduled_notifications('events')$$);
select cron.schedule('aess-notify-morning',  '0 0 * * *',    $$select public.run_scheduled_notifications('morning')$$);
select cron.schedule('aess-notify-cleanup',  '30 19 * * *',  $$select public.run_scheduled_notifications('cleanup')$$);
