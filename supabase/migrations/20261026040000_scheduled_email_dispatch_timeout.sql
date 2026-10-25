-- Automated survey email claim worked after the user_id fix, but
-- scheduled_email_dispatch used a 10s pg_net timeout. Claiming inserts up to
-- 40 'sending' rows then SMTP-sends them sequentially; the HTTP call timed
-- out before complete_scheduled_survey_emails ran, leaving stuck deliveries.
-- Raise the timeout and keep SMS dispatch in sync.

begin;

create or replace function public.scheduled_email_dispatch()
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  push_url text;
  url text;
  secret text;
begin
  select decrypted_secret into push_url from vault.decrypted_secrets where name = 'push_dispatch_url';
  select decrypted_secret into secret from vault.decrypted_secrets where name = 'push_dispatch_secret';
  if coalesce(push_url, '') = '' or coalesce(secret, '') = '' then
    return false;
  end if;

  url := replace(push_url, '/send-push', '/send-scheduled-emails');
  if url = push_url then
    return false;
  end if;

  perform net.http_post(
    url := url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-dispatch-secret', secret
    ),
    body := '{}'::jsonb,
    timeout_milliseconds := 55000
  );
  return true;
exception when others then
  raise warning 'scheduled_email_dispatch: %', sqlerrm;
  return false;
end;
$$;

create or replace function public.scheduled_sms_dispatch()
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  push_url text;
  url text;
  secret text;
begin
  select decrypted_secret into push_url from vault.decrypted_secrets where name = 'push_dispatch_url';
  select decrypted_secret into secret from vault.decrypted_secrets where name = 'push_dispatch_secret';
  if coalesce(push_url, '') = '' or coalesce(secret, '') = '' then
    return false;
  end if;

  url := replace(push_url, '/send-push', '/send-scheduled-sms');
  if url = push_url then
    return false;
  end if;

  perform net.http_post(
    url := url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-dispatch-secret', secret
    ),
    body := '{}'::jsonb,
    timeout_milliseconds := 55000
  );
  return true;
exception when others then
  raise warning 'scheduled_sms_dispatch: %', sqlerrm;
  return false;
end;
$$;

revoke all on function public.scheduled_email_dispatch() from public, anon, authenticated;
revoke all on function public.scheduled_sms_dispatch() from public, anon, authenticated;

-- Clear deliveries left mid-flight by the 10s timeout so they can be reclaimed.
update public.notification_deliveries
set status = 'failed',
    last_error = left(
      coalesce(nullif(last_error, ''), '') ||
      case when coalesce(last_error, '') = '' then '' else '; ' end ||
      'pg_net timeout before complete (reclaimed)',
      500
    )
where channel = 'email'
  and status = 'sending'
  and coalesce(data->>'automated', '') = 'true'
  and created_at > now() - interval '2 hours';

commit;
