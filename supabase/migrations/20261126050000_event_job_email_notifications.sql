-- Event + job email notifications.
-- Queues email deliveries when in-app notices are created for:
--   * event published / T-1 & day-of reminders (RSVP going)
--   * job published (open) / recommended (program-targeted) / deadline 3d & 1d
-- Dispatched by Edge Function send-queued-notification-emails (cron).

begin;

-- ---------------------------------------------------------------------------
-- Job publish copy: open vs recommended-for-you
-- ---------------------------------------------------------------------------
create or replace function public.notify_job_changes()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  targets text[];
  recipients uuid[];
  followers uuid[];
  company text := coalesce(nullif(trim(new.company), ''), nullif(trim(new.data->>'companyName'), ''), 'An employer');
  job_title text := coalesce(nullif(trim(new.title), ''), nullif(trim(new.data->>'jobTitle'), ''), 'a role');
  payload jsonb;
  route text := 'job/' || new.id::text;
  title text;
  body text;
  kind text;
begin
  begin
    payload := jsonb_build_object(
      'relatedId', new.id::text,
      'jobId', new.id::text,
      'jobTitle', job_title,
      'companyName', company,
      'target', 'jobs'
    );

    if tg_op = 'INSERT' then
      if lower(coalesce(new.status, '')) <> 'active' then
        return new;
      end if;

      targets := array(
        select trim(t) from unnest(public.notification_jsonb_text_array(new.data->'targetPrograms')) t
        where trim(t) <> ''
      );

      if cardinality(targets) = 0 then
        recipients := public.notification_active_alumni_ids();
        title := 'New Job Opportunity: ' || job_title;
        body := company || ' is looking for ' || job_title;
        kind := 'job_published';
      else
        recipients := array(
          select a.uid from unnest(public.notification_active_alumni_ids()) a(uid)
          join public.users u on u.id = a.uid
          where public.program_targets_include(targets, u.program)
          union
          select m.auth_uid from public.alumni_members m
          where m.auth_uid is not null
            and coalesce(m.is_registered_user, false)
            and not coalesce(m.is_deactivated, false)
            and public.program_targets_include(targets, m.course)
        );
        title := 'Recommended for you: ' || job_title;
        body := company || ' is hiring for ' || job_title
          || ' — this role matches your program.';
        kind := 'job_recommended';
      end if;

      perform public.enqueue_notifications(
        recipients,
        'job',
        title,
        body,
        payload || jsonb_build_object('kind', kind),
        'normal',
        'job:' || new.id::text || ':created',
        route
      );
      return new;
    end if;

    if lower(coalesce(new.status, '')) <> 'active' then
      return new;
    end if;

    followers := array(
      select f.user_id from public.favorite_jobs f where f.job_id = new.id
      union
      select i.user_id from public.job_interests i where i.job_id = new.id
    );

    if lower(coalesce(old.status, '')) <> 'active' then
      perform public.enqueue_notifications(
        followers,
        'job',
        'Job updated: ' || job_title,
        company || ' updated "' || job_title || '"',
        payload || jsonb_build_object('kind', 'job_restored'),
        'low',
        'job:' || new.id::text || ':restored:' || to_char(now(), 'YYYYMMDDHH24MI'),
        route,
        false
      );
    elsif public.notification_job_fingerprint(new) <> public.notification_job_fingerprint(old) then
      perform public.enqueue_notifications(
        followers,
        'job',
        'Job updated: ' || job_title,
        company || ' updated "' || job_title || '"',
        payload || jsonb_build_object('kind', 'job_updated'),
        'low',
        'job:' || new.id::text || ':updated:' || public.notification_job_fingerprint(new),
        route,
        false
      );
    end if;
  exception when others then
    raise warning 'notify_job_changes(%): %', new.id, sqlerrm;
  end;
  return new;
end;
$$;

-- Tag event publish notices with an explicit kind for the email queue.
create or replace function public.notify_event_changes()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  everyone uuid[];
  rsvp uuid[];
  date_label text;
  payload jsonb;
  route text := 'event/' || new.id::text;
  title text;
  body text;
  key text;
begin
  begin
    payload := jsonb_build_object(
      'relatedId', new.id::text,
      'eventId', new.id::text,
      'eventTitle', new.theme
    );

    if tg_op = 'INSERT' then
      if coalesce(new.status, 'Active') <> 'Active' or coalesce(new.cancelled, false) then
        return new;
      end if;
      date_label := to_char(new.date at time zone 'Asia/Manila', 'Mon FMDD, YYYY');
      perform public.enqueue_notifications(
        public.notification_active_alumni_ids(),
        'event',
        'New Event: ' || new.theme,
        'A new event has been scheduled on ' || date_label,
        payload || jsonb_build_object(
          'eventDate', date_label,
          'kind', 'event_published'
        ),
        'normal',
        'event:' || new.id::text || ':created',
        route
      );
      return new;
    end if;

    if coalesce(new.status, '') = 'Archived' then
      return new;
    end if;

    everyone := public.notification_active_alumni_ids();
    rsvp := array(
      select r.user_id from public.event_rsvps r
      where r.event_id = new.id and r.status in ('going', 'interested')
    );

    if coalesce(new.cancelled, false) and not coalesce(old.cancelled, false) then
      title := 'Event cancelled: ' || new.theme;
      body := 'The event "' || new.theme || '" has been cancelled.';
      key := 'event:' || new.id::text || ':cancelled';
      perform public.enqueue_notifications(rsvp, 'event', title, body, payload, 'high', key, route, true);
      perform public.enqueue_notifications(everyone, 'event', title, body, payload, 'normal', key, route, false);
      return new;
    end if;

    if coalesce(new.cancelled, false) then
      return new;
    end if;

    if new.venue is distinct from old.venue
       or new.venue_latitude is distinct from old.venue_latitude
       or new.venue_longitude is distinct from old.venue_longitude then
      title := new.theme;
      body := 'Venue updated to ' || coalesce(new.venue, '') || '.';
      key := 'event:' || new.id::text || ':venue:'
        || md5(coalesce(new.venue, '') || '|' || coalesce(new.venue_latitude::text, '')
               || '|' || coalesce(new.venue_longitude::text, ''));
    elsif new.date is distinct from old.date
       or new.start_time is distinct from old.start_time
       or new.end_time is distinct from old.end_time then
      title := new.theme;
      body := 'Schedule updated for ' || new.theme || '.';
      key := 'event:' || new.id::text || ':schedule:'
        || md5(coalesce(new.date::text, '') || '|' || coalesce(new.start_time, '')
               || '|' || coalesce(new.end_time, ''));
    else
      return new;
    end if;

    perform public.enqueue_notifications(rsvp, 'event', title, body, payload, 'high', key, route, true);
    perform public.enqueue_notifications(everyone, 'event', title, body, payload, 'normal', key, route, false);
  exception when others then
    raise warning 'notify_event_changes(%): %', new.id, sqlerrm;
  end;
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- Queue email when an eligible event/job notice is inserted
-- ---------------------------------------------------------------------------
create or replace function public.notification_email_kind_allowed(
  p_type text,
  p_kind text
)
returns boolean
language sql
immutable
as $$
  select case
    when p_type = 'event' and p_kind in ('event_published', 'reminder_0d', 'reminder_1d')
      then true
    when p_type = 'job' and p_kind in (
      'job_published', 'job_recommended', 'job_deadline_3d', 'job_deadline_1d'
    ) then true
    else false
  end;
$$;

create or replace function public.queue_notification_email()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  kind text := coalesce(nullif(trim(new.data->>'kind'), ''), '');
  addr text;
  display text;
begin
  begin
    if new.type not in ('event', 'job') then
      return new;
    end if;
    -- Back-compat: older event-created rows may lack kind.
    if kind = '' and new.type = 'event'
       and coalesce(new.dedupe_key, '') like '%:created' then
      kind := 'event_published';
    end if;
    if kind = '' and new.type = 'job'
       and coalesce(new.dedupe_key, '') like '%:created' then
      kind := 'job_published';
    end if;
    if not public.notification_email_kind_allowed(new.type, kind) then
      return new;
    end if;
    if new.expires_at is not null and new.expires_at <= now() then
      return new;
    end if;
    if not public.notification_channel_allowed(
      new.user_id, new.type, 'email', coalesce(new.priority, 'normal')
    ) then
      return new;
    end if;

    select
      lower(nullif(trim(u.email), '')),
      coalesce(nullif(trim(u.display_name), ''), 'Alumni')
    into addr, display
    from public.users u
    where u.id = new.user_id;

    if addr is null or position('@' in addr) = 0 then
      return new;
    end if;

    if exists (
      select 1 from public.notification_deliveries d
      where d.channel = 'email' and d.notification_id = new.id
    ) then
      return new;
    end if;

    insert into public.notification_deliveries (
      channel, notification_id, user_id, recipient, status, scheduled_at, data
    ) values (
      'email',
      new.id,
      new.user_id,
      addr,
      'queued',
      now(),
      jsonb_build_object(
        'kind', kind,
        'preference_type', new.type,
        'title', new.title,
        'message', new.body,
        'display_name', display,
        'action_path', coalesce(nullif(trim(new.route), ''), ''),
        'action_label', case new.type
          when 'event' then 'View event'
          when 'job' then 'View job'
          else 'Open AESS-USTP'
        end
      )
    );
  exception when others then
    raise warning 'queue_notification_email(%): %', new.id, sqlerrm;
  end;
  return new;
end;
$$;

drop trigger if exists trg_queue_notification_email on public.user_notifications;
create trigger trg_queue_notification_email
after insert on public.user_notifications
for each row execute function public.queue_notification_email();

-- One queued email per notification (idempotent).
create unique index if not exists notification_deliveries_email_notification_uidx
  on public.notification_deliveries (notification_id)
  where channel = 'email' and notification_id is not null;

create index if not exists notification_deliveries_email_due_idx
  on public.notification_deliveries (scheduled_at)
  where channel = 'email' and status in ('queued', 'sending');

-- ---------------------------------------------------------------------------
-- Claim / complete for Edge Function
-- ---------------------------------------------------------------------------
create or replace function public.claim_queued_notification_emails(
  p_limit integer default 20
)
returns table (
  delivery_id uuid,
  user_id uuid,
  email text,
  display_name text,
  title text,
  message text,
  action_path text,
  action_label text,
  preference_type text,
  kind text
)
language plpgsql
security definer
set search_path = public
as $$
begin
  return query
  with due as (
    select d.id
    from public.notification_deliveries d
    where d.channel = 'email'
      and (
        (d.status = 'queued' and d.scheduled_at <= now())
        or (d.status = 'sending' and d.claimed_at < now() - interval '5 minutes')
      )
    order by d.scheduled_at
    limit greatest(1, least(coalesce(p_limit, 20), 50))
    for update skip locked
  ),
  claimed as (
    update public.notification_deliveries d
    set status = 'sending',
        claimed_at = now(),
        attempts = coalesce(d.attempts, 0) + 1
    from due
    where d.id = due.id
    returning d.*
  )
  select
    c.id,
    c.user_id,
    c.recipient,
    coalesce(c.data->>'display_name', 'Alumni'),
    coalesce(c.data->>'title', 'AESS-USTP update'),
    coalesce(c.data->>'message', ''),
    coalesce(c.data->>'action_path', ''),
    coalesce(c.data->>'action_label', 'Open AESS-USTP'),
    coalesce(c.data->>'preference_type', 'system'),
    coalesce(c.data->>'kind', '')
  from claimed c;
end;
$$;

create or replace function public.complete_queued_notification_emails(
  p_results jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  r jsonb;
  rid uuid;
  ok boolean;
  err text;
begin
  if p_results is null or jsonb_typeof(p_results) <> 'array' then
    return;
  end if;
  for r in select * from jsonb_array_elements(p_results)
  loop
    begin
      rid := (r->>'id')::uuid;
    exception when others then
      continue;
    end;
    ok := coalesce((r->>'ok')::boolean, false);
    err := nullif(trim(coalesce(r->>'error', '')), '');
    if ok then
      update public.notification_deliveries
      set status = 'sent',
          sent_at = now(),
          last_error = null
      where id = rid and channel = 'email';
    else
      update public.notification_deliveries
      set status = case when coalesce(attempts, 0) >= 4 then 'failed' else 'queued' end,
          scheduled_at = case
            when coalesce(attempts, 0) >= 4 then scheduled_at
            else now() + (interval '5 minutes' * least(coalesce(attempts, 1), 4))
          end,
          last_error = left(coalesce(err, 'send failed'), 500),
          claimed_at = null
      where id = rid and channel = 'email';
    end if;
  end loop;
end;
$$;

revoke all on function public.claim_queued_notification_emails(integer)
  from public, anon, authenticated;
revoke all on function public.complete_queued_notification_emails(jsonb)
  from public, anon, authenticated;
grant execute on function public.claim_queued_notification_emails(integer) to service_role;
grant execute on function public.complete_queued_notification_emails(jsonb) to service_role;

-- ---------------------------------------------------------------------------
-- Dispatch (same Vault secrets as send-push / send-scheduled-emails)
-- ---------------------------------------------------------------------------
create or replace function public.queued_notification_email_dispatch()
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
  if not exists (
    select 1 from public.notification_deliveries
    where channel = 'email'
      and (
        (status = 'queued' and scheduled_at <= now())
        or (status = 'sending' and claimed_at < now() - interval '5 minutes')
      )
  ) then
    return false;
  end if;

  select decrypted_secret into push_url from vault.decrypted_secrets where name = 'push_dispatch_url';
  select decrypted_secret into secret from vault.decrypted_secrets where name = 'push_dispatch_secret';
  if coalesce(push_url, '') = '' or coalesce(secret, '') = '' then
    return false;
  end if;

  url := replace(push_url, '/send-push', '/send-queued-notification-emails');
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
  raise warning 'queued_notification_email_dispatch: %', sqlerrm;
  return false;
end;
$$;

revoke all on function public.queued_notification_email_dispatch()
  from public, anon, authenticated;
grant execute on function public.queued_notification_email_dispatch() to service_role;

comment on function public.queue_notification_email() is
  'Queues event/job emails (publish, reminders, deadlines, recommended) into notification_deliveries.';

commit;

-- Hourly at :10. cron.schedule replaces an existing job with the same name.
select cron.schedule(
  'aess-email-event-job',
  '10 * * * *',
  $$select public.queued_notification_email_dispatch()$$
);
