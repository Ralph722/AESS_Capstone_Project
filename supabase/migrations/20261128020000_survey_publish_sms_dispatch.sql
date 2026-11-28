-- Kick assigned survey SMS immediately on publish (custom + CHED GTS).
-- Reuses scheduled_sms_dispatch() → send-scheduled-sms (same path as cron).
-- Hourly aess-sms-scheduled remains for week1 / closing_3d and leftover batches.

begin;

create or replace function public.notify_survey_published()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  begin
    if new.status = 'published'
       and old.status is distinct from 'published'
       and public.notification_survey_accepting(new) then
      perform public.notification_survey_assigned(
        new,
        array(
          select a.user_id from public.survey_assignments a
          where a.survey_id = new.id and a.status <> 'completed'
        )
      );

      -- Best-effort immediate assigned SMS (cron still drains leftovers / reminders).
      begin
        perform public.scheduled_sms_dispatch();
      exception when others then
        raise warning 'notify_survey_published sms dispatch(%): %', new.id, sqlerrm;
      end;
    end if;
  exception when others then
    raise warning 'notify_survey_published(%): %', new.id, sqlerrm;
  end;
  return new;
end;
$$;

comment on function public.notify_survey_published() is
  'On draft→published (accepting): enqueue in-app/push survey assigned notices, '
  'then kick scheduled_sms_dispatch for near-publish assigned SMS. '
  'Cron aess-sms-scheduled still handles week1/closing_3d and leftover batches.';

commit;
