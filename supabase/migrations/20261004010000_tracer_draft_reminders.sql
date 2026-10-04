-- Tracer draft reminders.
--
-- An alumnus who leaves the CHED GTS with a saved draft can pick when to be
-- reminded to finish it, optionally with hourly follow-ups on that day.
--
-- * One row per (user, survey). The app replaces the row (delete + insert)
--   when a new reminder is set, so each reminder gets a fresh id and fresh
--   dedupe keys.
-- * Follow-ups (max 3) only on the reminder's Manila calendar day, before
--   21:00, and only while the tracer has not been opened since the last
--   reminder. Opening the tracer (record_survey_opened) or saving a draft
--   bumps survey_responses.updated_at, which is what "opened" means here.
-- * No follow-ups on days the "survey closing in 1/3 days" notice goes out.
-- * Submitted or closed tracers never get reminders; submitted rows are
--   cancelled.
-- * Sent through enqueue_notifications (in-app + push, respects the user's
--   notification preferences and quiet hours).

begin;

create table if not exists public.tracer_draft_reminders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  survey_id uuid not null references public.surveys (id) on delete cascade,
  remind_at timestamptz not null,
  repeat_hourly boolean not null default false,
  followups_sent integer not null default 0,
  last_sent_at timestamptz,
  cancelled_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint tracer_draft_reminders_user_survey_key unique (user_id, survey_id),
  constraint tracer_draft_reminders_followups_check
    check (followups_sent between 0 and 3)
);

create index if not exists tracer_draft_reminders_due_idx
  on public.tracer_draft_reminders (remind_at)
  where cancelled_at is null;

alter table public.tracer_draft_reminders enable row level security;

drop policy if exists tracer_draft_reminders_select_own on public.tracer_draft_reminders;
create policy tracer_draft_reminders_select_own
on public.tracer_draft_reminders for select
using (user_id = auth.uid());

drop policy if exists tracer_draft_reminders_insert_own on public.tracer_draft_reminders;
create policy tracer_draft_reminders_insert_own
on public.tracer_draft_reminders for insert
with check (user_id = auth.uid());

drop policy if exists tracer_draft_reminders_update_own on public.tracer_draft_reminders;
create policy tracer_draft_reminders_update_own
on public.tracer_draft_reminders for update
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists tracer_draft_reminders_delete_own on public.tracer_draft_reminders;
create policy tracer_draft_reminders_delete_own
on public.tracer_draft_reminders for delete
using (user_id = auth.uid());

drop trigger if exists trg_tracer_draft_reminders_updated_at on public.tracer_draft_reminders;
create trigger trg_tracer_draft_reminders_updated_at
before update on public.tracer_draft_reminders
for each row execute function public.set_updated_at();

create or replace function public.run_tracer_draft_reminders()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  today date := public.notification_manila_today();
  manila_now timestamp := now() at time zone 'Asia/Manila';
  r record;
  resp record;
  has_resp boolean;
  close_days integer;
  n integer;
  sent integer := 0;
begin
  for r in
    select d.*, s.close_at
    from public.tracer_draft_reminders d
    join public.surveys s on s.id = d.survey_id
    where d.cancelled_at is null
      and d.remind_at <= now()
      and public.notification_survey_accepting(s)
      and (
        (d.last_sent_at is null and d.remind_at > now() - interval '1 day')
        or (
          d.last_sent_at is not null
          and d.repeat_hourly
          and d.followups_sent < 3
          and (d.remind_at at time zone 'Asia/Manila')::date = today
        )
      )
    for update of d skip locked
  loop
    select sr.status, sr.submitted_at, sr.updated_at
    into resp
    from public.survey_responses sr
    where sr.survey_id = r.survey_id and sr.user_id = r.user_id;
    has_resp := found;

    if has_resp and (resp.status = 'submitted' or resp.submitted_at is not null) then
      update public.tracer_draft_reminders
      set cancelled_at = now()
      where id = r.id;
      continue;
    end if;

    if not public.notification_is_active_alumni(r.user_id) then
      continue;
    end if;

    if r.last_sent_at is null then
      n := public.enqueue_notifications(
        array[r.user_id],
        'survey',
        'Time to finish your tracer',
        'You saved a draft of the CHED Graduate Tracer Survey. '
          || 'Pick up where you left off, it only takes a few minutes.',
        jsonb_build_object(
          'relatedId', r.survey_id::text,
          'surveyId', r.survey_id::text,
          'kind', 'tracer_draft_reminder'
        ),
        'high',
        'tracer_reminder:' || r.id::text || ':0',
        'tracer',
        true,
        r.close_at
      );
      update public.tracer_draft_reminders
      set last_sent_at = now()
      where id = r.id;
      sent := sent + n;
      continue;
    end if;

    -- Follow-up checks.
    if now() < r.last_sent_at + interval '1 hour' then
      continue;
    end if;
    if manila_now::time >= time '21:00' then
      continue;
    end if;
    if has_resp and resp.updated_at is not null and resp.updated_at > r.last_sent_at then
      continue;
    end if;
    if r.close_at is not null then
      close_days := (r.close_at at time zone 'Asia/Manila')::date - today;
      if close_days in (1, 3) then
        continue;
      end if;
    end if;

    n := public.enqueue_notifications(
      array[r.user_id],
      'survey',
      'Your tracer is still waiting',
      'You haven''t opened your saved CHED GTS draft yet. '
        || 'Finish it when you have a few minutes.',
      jsonb_build_object(
        'relatedId', r.survey_id::text,
        'surveyId', r.survey_id::text,
        'kind', 'tracer_draft_followup',
        'followup', r.followups_sent + 1
      ),
      'normal',
      'tracer_reminder:' || r.id::text || ':' || (r.followups_sent + 1)::text,
      'tracer',
      true,
      r.close_at
    );
    update public.tracer_draft_reminders
    set followups_sent = followups_sent + 1,
        last_sent_at = now()
    where id = r.id;
    sent := sent + n;
  end loop;

  return sent;
end;
$$;

revoke all on function public.run_tracer_draft_reminders() from public, anon, authenticated;

commit;

select cron.schedule(
  'aess-notify-tracer-reminders',
  '*/5 * * * *',
  $$select public.run_tracer_draft_reminders()$$
);
