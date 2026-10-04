-- Notifications Phase 2: server-side creation.
--
-- Every notice is created here (triggers / admin RPC) through
-- enqueue_notifications(), with a dedupe key and a deep-link route.
-- The Flutter app no longer inserts notifications for other users.
--
-- Trigger bodies never raise: a notification problem must not block the
-- underlying save (event, job, message, ...).

begin;

-- ---------------------------------------------------------------------------
-- Recipients
-- ---------------------------------------------------------------------------
create or replace function public.notification_active_alumni_ids()
returns uuid[]
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(array_agg(u.id), '{}'::uuid[])
  from public.users u
  where coalesce(u.role, 'user') <> 'admin'
    and not exists (
      select 1 from public.alumni_members m
      where m.auth_uid = u.id and coalesce(m.is_deactivated, false)
    );
$$;

revoke all on function public.notification_active_alumni_ids() from public, anon, authenticated;

create or replace function public.notification_jsonb_text_array(p jsonb)
returns text[]
language sql
immutable
as $$
  select case
    when jsonb_typeof(p) = 'array'
      then array(select jsonb_array_elements_text(p))
    else '{}'::text[]
  end;
$$;

-- ---------------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------------
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
        payload || jsonb_build_object('eventDate', date_label),
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

drop trigger if exists trg_notify_event_changes on public.events;
create trigger trg_notify_event_changes
after insert or update on public.events
for each row execute function public.notify_event_changes();

-- Replies to event comments -> original commenter.
create or replace function public.notify_event_comment_reply()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  author uuid;
  theme text;
  replier_is_admin boolean;
  replier_name text;
  title text;
begin
  begin
    select c.user_id into author from public.event_comments c where c.id = new.comment_id;
    if author is null or author = new.user_id then
      return new;
    end if;

    select coalesce(nullif(trim(e.theme), ''), 'Event') into theme
    from public.events e where e.id = new.event_id;

    select coalesce(u.role, 'user') = 'admin',
           coalesce(nullif(trim(u.display_name), ''), 'Someone')
    into replier_is_admin, replier_name
    from public.users u where u.id = new.user_id;

    title := case when coalesce(replier_is_admin, false)
      then 'Admin replied to your comment'
      else coalesce(replier_name, 'Someone') || ' replied to your comment' end;

    perform public.enqueue_notifications(
      array[author],
      'event',
      title,
      left(title || ' on "' || coalesce(theme, 'Event') || '": ' || coalesce(new.body, ''), 300),
      jsonb_build_object(
        'relatedId', new.event_id::text,
        'eventId', new.event_id::text,
        'commentId', new.comment_id::text,
        'replyId', new.id::text,
        'target', 'event_comments'
      ),
      'normal',
      'event_reply:' || new.id::text,
      'event/' || new.event_id::text || '/comments'
    );
  exception when others then
    raise warning 'notify_event_comment_reply(%): %', new.id, sqlerrm;
  end;
  return new;
end;
$$;

drop trigger if exists trg_notify_event_comment_reply on public.event_replies;
create trigger trg_notify_event_comment_reply
after insert on public.event_replies
for each row execute function public.notify_event_comment_reply();

-- New event comment -> admins (rewritten on enqueue_notifications).
create or replace function public.notify_admins_new_event_comment()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  theme text;
  commenter text;
begin
  begin
    select coalesce(nullif(trim(e.theme), ''), 'Event') into theme
    from public.events e where e.id = new.event_id;
    select coalesce(nullif(trim(u.display_name), ''), 'A user') into commenter
    from public.users u where u.id = new.user_id;

    perform public.enqueue_notifications(
      array(select a from unnest(public.notification_admin_ids()) a where a <> new.user_id),
      'event',
      'New event comment',
      coalesce(commenter, 'A user') || ' commented on "' || coalesce(theme, 'Event') || '".',
      jsonb_build_object(
        'relatedId', new.event_id::text,
        'eventId', new.event_id::text,
        'commentId', new.id::text,
        'target', 'event_comments'
      ),
      'normal',
      'event_comment:' || new.id::text,
      'admin/events/' || new.event_id::text
    );
  exception when others then
    raise warning 'notify_admins_new_event_comment(%): %', new.id, sqlerrm;
  end;
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- Jobs
-- ---------------------------------------------------------------------------
create or replace function public.notification_job_fingerprint(j public.jobs)
returns text
language sql
immutable
as $$
  select md5(concat_ws('|',
    j.title, j.company, j.location, j.description,
    j.data->>'applicationDeadline', j.data->>'salaryRange', j.data->>'jobType',
    j.data->>'experienceLevel', j.data->>'isRemote', j.data->>'applicationUrl',
    j.data->>'contactEmail', (j.data->'requirements')::text, (j.data->'benefits')::text
  ));
$$;

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
      end if;

      perform public.enqueue_notifications(
        recipients,
        'job',
        'New Job Opportunity: ' || job_title,
        company || ' is looking for ' || job_title,
        payload,
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
      -- Restored / unarchived.
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

drop trigger if exists trg_notify_job_changes on public.jobs;
create trigger trg_notify_job_changes
after insert or update on public.jobs
for each row execute function public.notify_job_changes();

-- ---------------------------------------------------------------------------
-- Announcements
-- ---------------------------------------------------------------------------
create or replace function public.notify_announcement_published()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  recipients uuid[];
  excerpt text;
  is_urgent boolean;
begin
  begin
    if coalesce(new.status, '') <> 'published' then
      return new;
    end if;
    if tg_op = 'UPDATE' and old.status = 'published' then
      return new;
    end if;
    if lower(coalesce(new.data->>'notifyInApp', 'true')) = 'false' then
      return new;
    end if;

    recipients := array(
      select u.id
      from public.users u
      where u.id = any (public.notification_active_alumni_ids())
        and public.survey_audience_matches(
          public.notification_jsonb_text_array(new.data->'targetPrograms'),
          public.notification_jsonb_text_array(new.data->'targetBatchYears'),
          u.program, u.batch_year, u.year_graduated
        )
    );

    excerpt := case when length(coalesce(new.body, '')) > 200
      then left(new.body, 200) || '…' else coalesce(new.body, '') end;
    is_urgent := lower(coalesce(new.data->>'urgent', 'false')) = 'true';

    perform public.enqueue_notifications(
      recipients,
      'announcement',
      new.title,
      excerpt,
      jsonb_build_object('relatedId', new.id::text, 'announcementId', new.id::text),
      case when is_urgent then 'urgent' else 'normal' end,
      'announcement:' || new.id::text || ':published',
      'announcement/' || new.id::text,
      lower(coalesce(new.data->>'notifyPush', 'true')) <> 'false'
    );
  exception when others then
    raise warning 'notify_announcement_published(%): %', new.id, sqlerrm;
  end;
  return new;
end;
$$;

drop trigger if exists trg_notify_announcement_published on public.announcements;
create trigger trg_notify_announcement_published
after insert or update of status on public.announcements
for each row execute function public.notify_announcement_published();

-- ---------------------------------------------------------------------------
-- Surveys
-- ---------------------------------------------------------------------------
create or replace function public.notification_survey_accepting(s public.surveys)
returns boolean
language sql
stable
as $$
  select s.status = 'published'
    and coalesce(s.data->>'archived', 'false') <> 'true'
    and (s.open_at is null or s.open_at <= now())
    and (s.close_at is null or s.close_at > now());
$$;

create or replace function public.notification_survey_assigned(
  p_survey public.surveys,
  p_user_ids uuid[]
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  is_ched boolean := coalesce(p_survey.data->>'kind', '') = 'ched_gts_builtin'
    or coalesce(p_survey.data->>'template_key', '') = 'ched_gts_builtin';
begin
  return public.enqueue_notifications(
    array(
      select a from unnest(p_user_ids) a
      where public.notification_is_active_alumni(a)
    ),
    'survey',
    'New survey: ' || coalesce(p_survey.title, ''),
    case when is_ched then 'Please complete the graduate tracer survey.'
      else 'Please complete "' || coalesce(p_survey.title, 'this survey') || '".' end,
    jsonb_build_object('relatedId', p_survey.id::text, 'surveyId', p_survey.id::text),
    'high',
    'survey:' || p_survey.id::text || ':assigned',
    case when is_ched then 'tracer' else 'survey/' || p_survey.id::text end
  );
end;
$$;

revoke all on function public.notification_survey_assigned(public.surveys, uuid[]) from public, anon, authenticated;

create or replace function public.notify_survey_assignment_created()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  s public.surveys%rowtype;
begin
  begin
    select * into s from public.surveys where id = new.survey_id;
    if found and public.notification_survey_accepting(s) then
      perform public.notification_survey_assigned(s, array[new.user_id]);
    end if;
  exception when others then
    raise warning 'notify_survey_assignment_created(%): %', new.id, sqlerrm;
  end;
  return new;
end;
$$;

drop trigger if exists trg_notify_survey_assignment_created on public.survey_assignments;
create trigger trg_notify_survey_assignment_created
after insert on public.survey_assignments
for each row execute function public.notify_survey_assignment_created();

-- First publish sets status after the assignment rows exist.
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
    end if;
  exception when others then
    raise warning 'notify_survey_published(%): %', new.id, sqlerrm;
  end;
  return new;
end;
$$;

drop trigger if exists trg_notify_survey_published on public.surveys;
create trigger trg_notify_survey_published
after update of status on public.surveys
for each row execute function public.notify_survey_published();

-- Submission receipt for the alumnus.
create or replace function public.notify_survey_submitted()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  s public.surveys%rowtype;
begin
  begin
    if coalesce(new.status, '') <> 'submitted' then
      return new;
    end if;
    if tg_op = 'UPDATE' and old.status = 'submitted' then
      return new;
    end if;
    select * into s from public.surveys where id = new.survey_id;
    if not found then
      return new;
    end if;
    perform public.enqueue_notifications(
      array[new.user_id],
      'survey',
      'Survey submitted',
      'Thank you for completing "' || coalesce(s.title, 'the survey') || '".',
      jsonb_build_object('relatedId', s.id::text, 'surveyId', s.id::text),
      'low',
      'survey:' || s.id::text || ':submitted',
      public.notification_survey_route(s.id),
      false
    );
  exception when others then
    raise warning 'notify_survey_submitted(%): %', new.id, sqlerrm;
  end;
  return new;
end;
$$;

drop trigger if exists trg_notify_survey_submitted on public.survey_responses;
create trigger trg_notify_survey_submitted
after insert or update of status on public.survey_responses
for each row execute function public.notify_survey_submitted();

-- Auto-assign: the assignment trigger now sends the notice.
create or replace function public.auto_assign_open_surveys(p_user_id uuid)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  u public.users%rowtype;
  s record;
  inserted_id uuid;
  assigned integer := 0;
begin
  select * into u from public.users where id = p_user_id;
  if not found or coalesce(u.role, 'user') = 'admin' then
    return 0;
  end if;

  for s in
    select sv.id, sv.title, sv.target_programs, sv.target_batch_years
    from public.surveys sv
    where sv.status = 'published'
      and coalesce(sv.data->>'archived', 'false') <> 'true'
      and coalesce(sv.data->>'autoAssignNewAlumni', 'true') <> 'false'
      and (sv.close_at is null or sv.close_at > now())
  loop
    if not public.survey_audience_matches(
      s.target_programs, s.target_batch_years,
      u.program, u.batch_year, u.year_graduated
    ) then
      continue;
    end if;

    inserted_id := null;
    insert into public.survey_assignments (
      survey_id, user_id, survey_title, status, assigned_at
    ) values (
      s.id, p_user_id, coalesce(s.title, ''), 'notStarted', now()
    )
    on conflict (survey_id, user_id) do nothing
    returning id into inserted_id;

    if inserted_id is null then
      continue;
    end if;

    assigned := assigned + 1;
    update public.surveys
    set assignment_count = assignment_count + 1
    where id = s.id;
  end loop;

  return assigned;
end;
$$;

revoke all on function public.auto_assign_open_surveys(uuid) from public, anon, authenticated;

-- Admin reminders: at most one in-app reminder per alumnus per survey per day.
create or replace function public.admin_send_survey_reminders(
  p_survey_id uuid,
  p_user_ids uuid[]
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  s public.surveys%rowtype;
begin
  if not public.is_admin() then
    raise exception 'not allowed';
  end if;

  select * into s from public.surveys where id = p_survey_id;
  if not found then
    raise exception 'survey not found';
  end if;

  return public.enqueue_notifications(
    array(
      select a.user_id from public.survey_assignments a
      where a.survey_id = p_survey_id
        and a.user_id = any (coalesce(p_user_ids, '{}'::uuid[]))
        and a.status <> 'completed'
    ),
    'survey',
    'Reminder: ' || coalesce(s.title, ''),
    'Please complete "' || coalesce(s.title, '') || '" in the Alumni System app.',
    jsonb_build_object('relatedId', s.id::text, 'surveyId', s.id::text, 'kind', 'reminder'),
    'high',
    'survey:' || s.id::text || ':reminder:' || to_char(now() at time zone 'Asia/Manila', 'YYYY-MM-DD'),
    public.notification_survey_route(s.id)
  );
end;
$$;

revoke all on function public.admin_send_survey_reminders(uuid, uuid[]) from public, anon;
grant execute on function public.admin_send_survey_reminders(uuid, uuid[]) to authenticated;

-- ---------------------------------------------------------------------------
-- Feedback
-- ---------------------------------------------------------------------------
create or replace function public.notify_feedback_changes()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  submitter uuid := new.user_id;
  reply text := nullif(trim(coalesce(new.admin_reply, '')), '');
  payload jsonb := jsonb_build_object('relatedId', new.id::text, 'feedbackId', new.id::text);
  route text := 'feedback/' || new.id::text;
  who text;
begin
  begin
    if tg_op = 'INSERT' then
      who := coalesce(nullif(trim(new.data->>'userName'), ''), 'An alumni');
      perform public.enqueue_notifications(
        array(select a from unnest(public.notification_admin_ids()) a where a <> new.user_id),
        'feedback',
        'New feedback',
        who || ' submitted feedback'
          || coalesce(': ' || nullif(trim(new.data->>'subject'), ''), '') || '.',
        payload,
        'normal',
        'feedback:' || new.id::text || ':submitted',
        'admin/feedback/' || new.id::text
      );
      return new;
    end if;

    if submitter is null then
      return new;
    end if;

    if reply is not null and reply is distinct from nullif(trim(coalesce(old.admin_reply, '')), '') then
      perform public.enqueue_notifications(
        array[submitter],
        'feedback',
        'Response to your feedback',
        case when length(reply) > 120 then left(reply, 120) || '…' else reply end,
        payload,
        'normal',
        'feedback:' || new.id::text || ':reply:' || md5(reply),
        route
      );
    elsif new.status is distinct from old.status and new.status in ('resolved', 'closed') then
      perform public.enqueue_notifications(
        array[submitter],
        'feedback',
        'Feedback update',
        'Your feedback is now marked as ' || new.status || '.',
        payload,
        'low',
        'feedback:' || new.id::text || ':status:' || new.status,
        route,
        false
      );
    end if;
  exception when others then
    raise warning 'notify_feedback_changes(%): %', new.id, sqlerrm;
  end;
  return new;
end;
$$;

drop trigger if exists trg_notify_feedback_changes on public.feedback;
create trigger trg_notify_feedback_changes
after insert or update on public.feedback
for each row execute function public.notify_feedback_changes();

-- ---------------------------------------------------------------------------
-- Messages (rewritten on enqueue_notifications; same text as before)
-- ---------------------------------------------------------------------------
create or replace function public.notify_message_recipient()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  actor text;
  preview text;
  conversation_user uuid;
  from_admin boolean := lower(coalesce(new.sender_role, '')) = 'admin';
begin
  begin
    if new.recipient_id is null or new.recipient_id = new.sender_id then
      return new;
    end if;

    actor := coalesce(nullif(trim(new.sender_name), ''), 'Someone');
    preview := nullif(trim(new.body), '');
    if preview is null and coalesce(new.image_base64, '') <> '' then
      preview := 'Sent an image';
    end if;
    preview := left(coalesce(preview, 'You have received a new message'), 120);
    conversation_user := case when from_admin then new.recipient_id else new.sender_id end;

    perform public.enqueue_notifications(
      array[new.recipient_id],
      'message',
      case when from_admin then 'New message from Alumni Office' else 'New message from ' || actor end,
      preview,
      jsonb_build_object(
        'relatedId', new.id::text,
        'messageId', new.id::text,
        'senderId', new.sender_id::text,
        'senderName', actor,
        'senderRole', coalesce(new.sender_role, ''),
        'conversationUserId', conversation_user::text,
        'target', 'messages'
      ),
      'high',
      'msg:' || new.id::text,
      case when from_admin then 'messages' else 'messages/' || conversation_user::text end
    );
  exception when others then
    raise warning 'notify_message_recipient(%): %', new.id, sqlerrm;
  end;
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- Forum
-- ---------------------------------------------------------------------------
-- One notice per person per post: reply, quote and mention share the key.
create or replace function public.notify_forum_topic_author_on_reply()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  topic_record public.forum_topics%rowtype;
  actor text;
  quoted_author uuid;
  payload jsonb;
  key text := 'forum_post:' || new.id::text;
  route text := 'forum/' || new.topic_id::text;
begin
  begin
    select * into topic_record from public.forum_topics where id = new.topic_id;
    if not found then
      return new;
    end if;

    actor := coalesce(nullif(trim(new.author_name), ''), 'An alumni');
    payload := jsonb_build_object(
      'relatedId', new.topic_id::text,
      'topicId', new.topic_id::text,
      'postId', new.id::text,
      'target', 'forum_topic'
    );

    if topic_record.author_uid <> new.author_uid then
      perform public.enqueue_notifications(
        array[topic_record.author_uid],
        'forum',
        'New reply to your discussion',
        actor || ' replied to "' || left(topic_record.title, 80) || '".',
        payload, 'normal', key, route
      );
    end if;

    if new.quoted_post_id is not null then
      select author_uid into quoted_author from public.forum_posts where id = new.quoted_post_id;
      if quoted_author is not null and quoted_author <> new.author_uid then
        perform public.enqueue_notifications(
          array[quoted_author],
          'forum',
          'Your reply was quoted',
          actor || ' quoted your reply in "' || left(topic_record.title, 80) || '".',
          payload, 'normal', key, route
        );
      end if;
    end if;
  exception when others then
    raise warning 'notify_forum_topic_author_on_reply(%): %', new.id, sqlerrm;
  end;
  return new;
end;
$$;

create or replace function public.notify_forum_mentions(
  p_post_id uuid,
  p_mentioned_uids uuid[]
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  post_rec public.forum_posts%rowtype;
  topic_title text;
  actor text;
begin
  if not public.is_signed_in() then
    raise exception 'not authenticated';
  end if;

  select * into post_rec from public.forum_posts where id = p_post_id;
  if not found then
    raise exception 'post not found';
  end if;

  if post_rec.author_uid <> auth.uid() and not public.is_admin() then
    raise exception 'not post author';
  end if;

  if p_mentioned_uids is null then
    return;
  end if;

  select title into topic_title from public.forum_topics where id = post_rec.topic_id;
  actor := coalesce(nullif(trim(post_rec.author_name), ''), 'An alumni');

  perform public.enqueue_notifications(
    array(
      select distinct m.uid
      from unnest(p_mentioned_uids) as m(uid)
      join public.users u on u.id = m.uid
      where m.uid <> post_rec.author_uid
      limit 10
    ),
    'forum',
    'You were mentioned in the forum',
    actor || ' mentioned you in "' || left(coalesce(topic_title, 'a discussion'), 80) || '".',
    jsonb_build_object(
      'relatedId', post_rec.topic_id::text,
      'topicId', post_rec.topic_id::text,
      'postId', post_rec.id::text,
      'target', 'forum_topic'
    ),
    'normal',
    'forum_post:' || post_rec.id::text,
    'forum/' || post_rec.topic_id::text
  );
end;
$$;

grant execute on function public.notify_forum_mentions(uuid, uuid[]) to authenticated;

create or replace function public.notify_admins_forum_report()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  actor text;
begin
  begin
    select coalesce(nullif(trim(display_name), ''), email, 'An alumni') into actor
    from public.users where id = new.reporter_uid;

    perform public.enqueue_notifications(
      public.notification_admin_ids(),
      'forum',
      'Forum content reported',
      coalesce(actor, 'An alumni') || ' submitted a forum report.',
      jsonb_build_object(
        'relatedId', coalesce(new.topic_id::text, new.id::text),
        'topicId', new.topic_id::text,
        'postId', new.post_id::text,
        'reportId', new.id::text,
        'target', 'forum_report'
      ),
      'normal',
      'forum_report:' || new.id::text,
      'admin/forum'
    );
  exception when others then
    raise warning 'notify_admins_forum_report(%): %', new.id, sqlerrm;
  end;
  return new;
end;
$$;

-- Moderation: lock / unlock / pin -> topic author (not when acting on own topic).
create or replace function public.notify_forum_topic_moderation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  actor uuid := auth.uid();
  payload jsonb := jsonb_build_object(
    'relatedId', new.id::text,
    'topicId', new.id::text,
    'target', 'forum_topic'
  );
  route text := 'forum/' || new.id::text;
  stamp text := to_char(now(), 'YYYYMMDDHH24MI');
  reason text := nullif(trim(coalesce(new.moderation_reason, '')), '');
begin
  begin
    if actor is null or actor = new.author_uid then
      return new;
    end if;

    if new.is_locked is distinct from old.is_locked then
      perform public.enqueue_notifications(
        array[new.author_uid],
        'forum',
        case when new.is_locked then 'Your discussion was locked' else 'Your discussion was unlocked' end,
        case when new.is_locked
          then 'Moderators locked "' || new.title || '".' || coalesce(' Reason: ' || reason, '')
          else 'Moderators unlocked "' || new.title || '". You can receive replies again.' end,
        payload,
        'low',
        'forum_topic:' || new.id::text || ':lock:' || new.is_locked::text || ':' || stamp,
        route,
        false
      );
    end if;

    if coalesce(new.is_pinned, false) and not coalesce(old.is_pinned, false) then
      perform public.enqueue_notifications(
        array[new.author_uid],
        'forum',
        'Your discussion was pinned',
        'Moderators pinned "' || new.title || '" in the alumni forum.',
        payload,
        'low',
        'forum_topic:' || new.id::text || ':pinned:' || stamp,
        route,
        false
      );
    end if;
  exception when others then
    raise warning 'notify_forum_topic_moderation(%): %', new.id, sqlerrm;
  end;
  return new;
end;
$$;

drop trigger if exists trg_notify_forum_topic_moderation on public.forum_topics;
create trigger trg_notify_forum_topic_moderation
after update of is_locked, is_pinned on public.forum_topics
for each row execute function public.notify_forum_topic_moderation();

create or replace function public.notify_forum_topic_removed()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  begin
    if auth.uid() is not null and auth.uid() <> old.author_uid then
      perform public.enqueue_notifications(
        array[old.author_uid],
        'forum',
        'Your discussion was removed',
        'Moderators removed "' || left(coalesce(old.title, 'your discussion'), 80) || '".',
        '{}'::jsonb,
        'low',
        'forum_topic:' || old.id::text || ':removed',
        null,
        false
      );
    end if;
  exception when others then
    raise warning 'notify_forum_topic_removed(%): %', old.id, sqlerrm;
  end;
  return old;
end;
$$;

drop trigger if exists trg_notify_forum_topic_removed on public.forum_topics;
create trigger trg_notify_forum_topic_removed
after delete on public.forum_topics
for each row execute function public.notify_forum_topic_removed();

-- ---------------------------------------------------------------------------
-- Accounts
-- ---------------------------------------------------------------------------
create or replace function public.notify_admins_new_registration()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  begin
    if coalesce(new.role, 'user') = 'admin' then
      return new;
    end if;
    perform public.enqueue_notifications(
      public.notification_admin_ids(),
      'system',
      'New alumni registration',
      coalesce(nullif(trim(new.display_name), ''), nullif(trim(new.email), ''), 'An alumnus')
        || ' registered' || coalesce(' (' || nullif(trim(new.program), '') || ')', '') || '.',
      jsonb_build_object('relatedId', new.id::text, 'userId', new.id::text, 'target', 'registrations'),
      'normal',
      'user:' || new.id::text || ':registered',
      'admin/alumni',
      false
    );
  exception when others then
    raise warning 'notify_admins_new_registration(%): %', new.id, sqlerrm;
  end;
  return new;
end;
$$;

drop trigger if exists trg_notify_admins_new_registration on public.users;
create trigger trg_notify_admins_new_registration
after insert on public.users
for each row execute function public.notify_admins_new_registration();

create or replace function public.notify_employment_verification()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  company text := coalesce(nullif(trim(new.company), ''), 'your employer');
begin
  begin
    if new.verification_status is not distinct from old.verification_status
       or new.verification_status not in ('Verified', 'Rejected') then
      return new;
    end if;
    perform public.enqueue_notifications(
      array[new.user_id],
      'system',
      case when new.verification_status = 'Verified'
        then 'Employment record verified'
        else 'Employment record needs attention' end,
      case when new.verification_status = 'Verified'
        then 'Your employment record at ' || company || ' was verified.'
        else 'Your employment record at ' || company || ' was not approved. Please review and update it.' end,
      jsonb_build_object('relatedId', new.id::text, 'recordId', new.id::text),
      'normal',
      'employment:' || new.id::text || ':' || lower(new.verification_status)
        || ':' || coalesce(to_char(new.verified_at, 'YYYYMMDDHH24MISS'), ''),
      'profile'
    );
  exception when others then
    raise warning 'notify_employment_verification(%): %', new.id, sqlerrm;
  end;
  return new;
end;
$$;

drop trigger if exists trg_notify_employment_verification on public.employment_records;
create trigger trg_notify_employment_verification
after update of verification_status on public.employment_records
for each row execute function public.notify_employment_verification();

commit;
