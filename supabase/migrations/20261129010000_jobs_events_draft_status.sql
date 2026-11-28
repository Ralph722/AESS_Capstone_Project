-- Allow draft status for jobs and events (archive = history bin; Duplicate
-- creates a new draft template without restoring the archived row).

alter table public.jobs drop constraint if exists jobs_status_check;
alter table public.jobs add constraint jobs_status_check
  check (status in ('draft', 'active', 'expired', 'closed', 'archived'));

alter table public.events drop constraint if exists events_status_check;
alter table public.events add constraint events_status_check
  check (status in ('Draft', 'Active', 'Archived'));

-- When a draft job is posted (draft → active), notify alumni the same way
-- as a brand-new active insert.
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

    -- draft/expired/archived → active: treat as a fresh publish.
    if lower(coalesce(old.status, '')) <> 'active' then
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

    followers := array(
      select f.user_id from public.favorite_jobs f where f.job_id = new.id
      union
      select i.user_id from public.job_interests i where i.job_id = new.id
    );

    if public.notification_job_fingerprint(new) <> public.notification_job_fingerprint(old) then
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

-- When a draft event is published (Draft → Active), notify alumni the same way
-- as a brand-new Active insert.
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

    -- Draft → Active publish (or any non-Active → Active).
    if coalesce(old.status, '') <> 'Active'
       and coalesce(new.status, '') = 'Active'
       and not coalesce(new.cancelled, false) then
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
