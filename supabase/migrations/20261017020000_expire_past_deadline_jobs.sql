-- Phase 3 performance: expire past-deadline jobs on the server so alumni
-- clients never scan/write the jobs table on every Jobs/Home open.
-- Also runs during the morning scheduled-notification pass.

begin;

create or replace function public.expire_past_deadline_jobs()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  n integer := 0;
  jwt_role text := coalesce(auth.role(), '');
begin
  -- Cron / service role, or signed-in admin (admin management screens).
  if jwt_role not in ('service_role', 'postgres')
     and not public.is_admin() then
    raise exception 'not authorized';
  end if;

  with due as (
    select j.id
    from public.jobs j
    where j.status = 'active'
      and public.notification_try_timestamptz(j.data->>'applicationDeadline')
          is not null
      and (
        public.notification_try_timestamptz(j.data->>'applicationDeadline')
          at time zone 'Asia/Manila'
      )::date
        < (now() at time zone 'Asia/Manila')::date
  ),
  updated as (
    update public.jobs j
    set
      status = 'expired',
      data = coalesce(j.data, '{}'::jsonb)
        || jsonb_build_object(
          'status', 'expired',
          'isActive', false
        ),
      updated_at = now()
    from due
    where j.id = due.id
    returning j.id
  )
  select count(*)::integer into n from updated;
  return coalesce(n, 0);
end;
$$;

revoke all on function public.expire_past_deadline_jobs() from public, anon;
grant execute on function public.expire_past_deadline_jobs() to authenticated, service_role;

-- Fold into morning dispatcher (alongside job deadline reminders).
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
    when 'morning' then array[
      'expire_jobs', 'job_deadlines', 'survey_closing', 'admin_digest'
    ]
    when 'cleanup' then array['cleanup']
    else array[]::text[]
  end;

  foreach task in array tasks loop
    begin
      n := case task
        when 'expire_jobs' then public.expire_past_deadline_jobs()
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

commit;
