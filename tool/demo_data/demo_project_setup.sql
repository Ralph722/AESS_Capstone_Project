-- Demo project only. Run after `supabase db push --db-url <DEMO_DB_URL>`:
--   supabase db query --db-url "<DEMO_DB_URL>" -f tool/demo_data/demo_project_setup.sql
-- Refuses to run when any account outside @demo.aess.test or any roster row
-- without a DEMO- student ID exists, so it can never change the live project.
-- Everything runs in one block: a refusal changes nothing. Check the result
-- with: select jobname, schedule from cron.job order by jobname;
do $$
begin
  if exists (
    select 1 from auth.users
    where lower(coalesce(email, '')) not like '%@demo.aess.test'
  ) or exists (
    select 1 from public.alumni_members
    where student_id not like 'DEMO-%'
  ) then
    raise exception 'Not a demo-only database. Nothing was changed.';
  end if;

  -- No reminders, scheduled notifications or push dispatch in the demo.
  -- The nightly DSS re-check (aess-dss-recheck) stays scheduled.
  perform cron.unschedule(jobname)
  from cron.job
  where jobname in (
    'aess-notify-frequent',
    'aess-notify-events',
    'aess-notify-morning',
    'aess-notify-tracer-reminders',
    'aess-push-dispatch'
  );
end;
$$;
