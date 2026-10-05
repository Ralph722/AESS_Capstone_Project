-- Only admins and alumni linked to an active roster row may use the data API.
--
-- Anyone can create a Supabase Auth account with the public key and confirm
-- their own email, which also creates a public.users row. Until now policies
-- and functions that only asked "is the caller signed in?" let such accounts
-- read shared content, look up alumni profiles and post in the forum without
-- ever passing the roster link. The app's own login check did not stop direct
-- API calls.
--
-- 1. caller_is_active() now requires an admin, or a user linked to an active
--    roster row (and not deactivated). The restrictive policy
--    active_caller_only on every table and on storage.objects already uses it.
-- 2. SECURITY DEFINER functions bypass row level security, so the ones that
--    signed-in users call check it themselves. link_alumni_registration and
--    validate_alumni_eligibility stay open: registration needs them.
-- 3. The forum mention search no longer searches or returns email addresses
--    and skips deactivated, anonymized and unlinked accounts.

-- ---------------------------------------------------------------------------
-- 1. Who counts as an active caller
-- ---------------------------------------------------------------------------

create or replace function public.caller_is_active()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.users u
    where u.id = auth.uid()
      and u.deactivated_at is null
      and (
        u.role = 'admin'
        or exists (
          select 1
          from public.alumni_members m
          where m.auth_uid = u.id
            and m.is_registered_user
            and not m.is_deactivated
        )
      )
  );
$$;

-- ---------------------------------------------------------------------------
-- 2. SECURITY DEFINER functions called by signed-in users
-- ---------------------------------------------------------------------------

create or replace function public.get_public_profiles(p_ids uuid[])
returns table (
  id uuid,
  display_name text,
  profile_image_base64 text,
  program text,
  year_graduated text,
  role text,
  email text
)
language sql
stable
security definer
set search_path = public
as $$
  select
    u.id,
    case
      when u.anonymized_at is not null then 'Deleted alumni'
      when nullif(trim(u.display_name), '') is not null then u.display_name
      when u.role = 'admin' then 'Admin'
      else 'Alumnus'
    end,
    case when u.anonymized_at is null then u.profile_image_base64 end,
    u.program,
    u.year_graduated,
    u.role,
    case when public.is_admin() or u.id = auth.uid() then u.email else '' end
  from public.users u
  where public.caller_is_active()
    and u.id = any (p_ids[1:500]);
$$;

create or replace function public.increment_forum_topic_views(p_topic_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.caller_is_active() then
    return;
  end if;
  update public.forum_topics
  set view_count = view_count + 1
  where id = p_topic_id;
end;
$$;

create or replace function public.increment_job_views(p_job_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.caller_is_active() then
    return;
  end if;

  perform set_config('aess.job_views_bump', 'on', true);
  update public.jobs
  set views = views + 1
  where id = p_job_id;
  perform set_config('aess.job_views_bump', 'off', true);
end;
$$;

create or replace function public.edit_forum_post(p_post_id uuid, p_body text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  p public.forum_posts%rowtype;
begin
  if not public.caller_is_active() then
    raise exception 'not authorized' using errcode = '42501';
  end if;
  select * into p from public.forum_posts where id = p_post_id;
  if not found then
    raise exception 'post not found';
  end if;
  if not public.is_admin() and p.author_uid <> auth.uid() then
    raise exception 'not owner';
  end if;
  if not public.is_admin() and p.created_at < now() - interval '30 minutes' then
    raise exception 'edit window expired';
  end if;

  update public.forum_posts
  set body = trim(p_body), edited_at = now(), updated_at = now()
  where id = p_post_id;
end;
$$;

create or replace function public.edit_forum_topic(p_topic_id uuid, p_title text, p_body text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  t public.forum_topics%rowtype;
begin
  if not public.caller_is_active() then
    raise exception 'not authorized' using errcode = '42501';
  end if;
  select * into t from public.forum_topics where id = p_topic_id;
  if not found then
    raise exception 'topic not found';
  end if;
  if not public.is_admin() and t.author_uid <> auth.uid() then
    raise exception 'not owner';
  end if;
  if not public.is_admin() and t.created_at < now() - interval '30 minutes' then
    raise exception 'edit window expired';
  end if;

  update public.forum_topics
  set
    title = trim(p_title),
    body = trim(p_body),
    edited_at = now(),
    updated_at = now()
  where id = p_topic_id;
end;
$$;

create or replace function public.notify_forum_mentions(p_post_id uuid, p_mentioned_uids uuid[])
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
  if not public.caller_is_active() then
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

create or replace function public.record_survey_opened(
  p_survey_id uuid,
  p_device_category text default null,
  p_platform_family text default null,
  p_browser_family text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  rid uuid;
begin
  if uid is null then
    raise exception 'unauthenticated';
  end if;
  if not public.caller_is_active() then
    raise exception 'not authorized' using errcode = '42501';
  end if;

  insert into public.survey_responses (
    survey_id,
    user_id,
    status,
    opened_at,
    device_category,
    platform_family,
    browser_family
  )
  values (
    p_survey_id,
    uid,
    'draft',
    now(),
    p_device_category,
    p_platform_family,
    p_browser_family
  )
  on conflict (survey_id, user_id) do update set
    opened_at = coalesce(public.survey_responses.opened_at, excluded.opened_at),
    device_category = coalesce(
      excluded.device_category,
      public.survey_responses.device_category
    ),
    platform_family = coalesce(
      excluded.platform_family,
      public.survey_responses.platform_family
    ),
    browser_family = coalesce(
      excluded.browser_family,
      public.survey_responses.browser_family
    ),
    updated_at = now()
  returning id into rid;

  if not exists (
    select 1
    from public.survey_response_events e
    where e.survey_id = p_survey_id
      and e.user_id = uid
      and e.event_type = 'opened'
  ) then
    insert into public.survey_response_events (
      survey_id,
      user_id,
      response_id,
      event_type,
      device_category,
      platform_family,
      browser_family
    )
    values (
      p_survey_id,
      uid,
      rid,
      'opened',
      p_device_category,
      p_platform_family,
      p_browser_family
    );
  end if;

  update public.survey_assignments
  set
    status = case
      when status = 'notStarted' then 'inProgress'
      else status
    end,
    updated_at = now()
  where survey_id = p_survey_id and user_id = uid;
end;
$$;

create or replace function public.register_push_token(
  p_provider text,
  p_platform text,
  p_token text,
  p_subscription jsonb default null,
  p_device_label text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
  token_id uuid;
  clean_token text := trim(coalesce(p_token, ''));
begin
  if me is null then
    raise exception 'not authenticated';
  end if;
  if not public.caller_is_active() then
    raise exception 'not authorized' using errcode = '42501';
  end if;
  if p_provider not in ('webpush', 'fcm') or p_platform not in ('web', 'android', 'ios') then
    raise exception 'invalid provider or platform';
  end if;
  if length(clean_token) < 10 or length(clean_token) > 4096 then
    raise exception 'invalid token';
  end if;
  if p_provider = 'webpush' then
    if clean_token !~ '^https://'
       or p_subscription is null
       or p_subscription->>'endpoint' is distinct from clean_token
       or coalesce(p_subscription #>> '{keys,p256dh}', '') = ''
       or coalesce(p_subscription #>> '{keys,auth}', '') = '' then
      raise exception 'invalid web push subscription';
    end if;
  end if;

  insert into public.push_tokens as t (
    user_id, provider, platform, token, subscription, device_label
  ) values (
    me, p_provider, p_platform, clean_token,
    case when p_provider = 'webpush' then p_subscription else null end,
    left(nullif(trim(coalesce(p_device_label, '')), ''), 120)
  )
  on conflict (token) do update set
    user_id = excluded.user_id,
    provider = excluded.provider,
    platform = excluded.platform,
    subscription = excluded.subscription,
    device_label = coalesce(excluded.device_label, t.device_label),
    failure_count = 0,
    disabled_at = null,
    last_seen_at = now(),
    updated_at = now()
  returning id into token_id;

  -- Keep the 10 most recently seen devices per user.
  delete from public.push_tokens
  where user_id = me
    and id in (
      select id from public.push_tokens
      where user_id = me
      order by last_seen_at desc
      offset 10
    );

  return token_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- 3. Forum mention search: names only, linked alumni only
-- ---------------------------------------------------------------------------

create or replace function public.search_forum_mention_users(p_query text)
returns table (id uuid, display_name text, program text)
language plpgsql
security definer
set search_path = public
as $$
declare
  q text := lower(trim(coalesce(p_query, '')));
  pattern text;
begin
  if not public.caller_is_active() then
    raise exception 'not authenticated';
  end if;

  if length(q) < 1 then
    return;
  end if;
  pattern := '%' || replace(replace(replace(q, '\', '\\'), '%', '\%'), '_', '\_') || '%';

  return query
  select u.id, coalesce(nullif(trim(u.display_name), ''), 'Alumnus'), coalesce(u.program, '')
  from public.users u
  join public.alumni_members m
    on m.auth_uid = u.id
   and m.is_registered_user
   and not m.is_deactivated
  where coalesce(u.role, 'user') = 'user'
    and u.deactivated_at is null
    and u.anonymized_at is null
    and lower(coalesce(u.display_name, '')) like pattern
  order by u.display_name asc nulls last
  limit 12;
end;
$$;
