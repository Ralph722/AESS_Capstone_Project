-- Notifications Phase 0: critical fixes.
--  * Indexes for the per-user list / unread count.
--  * Publish user_notifications to Realtime (list + badge were never live).
--  * notify_new_message: derive everything from the real message row so a
--    caller can no longer forge "New message from Alumni Office" notices.
--  * notify_forum_mentions: cap recipients and skip people already notified
--    about the same post (reply / quote / earlier mention).
--  * Owners may only change the read flag on their notifications.

begin;

-- ---------------------------------------------------------------------------
-- Indexes
-- ---------------------------------------------------------------------------
create index if not exists user_notifications_user_created_idx
  on public.user_notifications (user_id, created_at desc);

create index if not exists user_notifications_user_unread_idx
  on public.user_notifications (user_id)
  where is_read = false;

-- ---------------------------------------------------------------------------
-- Realtime
-- ---------------------------------------------------------------------------
alter table public.user_notifications replica identity full;

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'user_notifications'
  ) then
    alter publication supabase_realtime add table public.user_notifications;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- notify_new_message: validate against the stored message
-- ---------------------------------------------------------------------------
create or replace function public.notify_new_message(
  p_recipient_id uuid,
  p_message_id uuid,
  p_sender_name text,
  p_sender_id uuid default null,
  p_sender_role text default '',
  p_preview text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  msg public.messages%rowtype;
  actor text;
  preview text;
  conversation_user uuid;
  notif_title text;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  if p_message_id is null then
    return;
  end if;

  select * into msg from public.messages where id = p_message_id;
  if not found then
    return;
  end if;

  -- Only the real sender (or an admin) may ask for this notice, and only for
  -- the real recipient. Client-supplied name / role / preview are ignored.
  if msg.sender_id is distinct from auth.uid() and not public.is_admin() then
    return;
  end if;
  if msg.recipient_id is null
     or msg.recipient_id = msg.sender_id
     or (p_recipient_id is not null and p_recipient_id <> msg.recipient_id) then
    return;
  end if;

  if exists (
    select 1
    from public.user_notifications un
    where un.user_id = msg.recipient_id
      and un.type = 'message'
      and (un.data->>'messageId') = msg.id::text
  ) then
    return;
  end if;

  actor := coalesce(nullif(trim(msg.sender_name), ''), 'Someone');
  preview := nullif(trim(msg.body), '');
  if preview is null and coalesce(msg.image_base64, '') <> '' then
    preview := 'Sent an image';
  end if;
  preview := left(coalesce(preview, 'You have received a new message'), 120);

  if lower(coalesce(msg.sender_role, '')) = 'admin' then
    conversation_user := msg.recipient_id;
    notif_title := 'New message from Alumni Office';
  else
    conversation_user := msg.sender_id;
    notif_title := 'New message from ' || actor;
  end if;

  insert into public.user_notifications (
    user_id, title, body, type, is_read, data, created_at, updated_at
  ) values (
    msg.recipient_id,
    notif_title,
    preview,
    'message',
    false,
    jsonb_build_object(
      'relatedId', msg.id::text,
      'messageId', msg.id::text,
      'senderId', msg.sender_id::text,
      'senderName', actor,
      'senderRole', coalesce(msg.sender_role, ''),
      'conversationUserId', conversation_user::text,
      'target', 'messages'
    ),
    now(),
    now()
  );
end;
$$;

revoke all on function public.notify_new_message(uuid, uuid, text, uuid, text, text) from public, anon;
grant execute on function public.notify_new_message(uuid, uuid, text, uuid, text, text) to authenticated;

-- ---------------------------------------------------------------------------
-- notify_forum_mentions: cap + per-post dedupe
-- ---------------------------------------------------------------------------
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
  uid uuid;
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

  for uid in
    select distinct m.uid
    from unnest(p_mentioned_uids) as m(uid)
    join public.users u on u.id = m.uid
    where m.uid is not null
      and m.uid <> post_rec.author_uid
    limit 10
  loop
    -- One notice per person per post (reply / quote / mention).
    if exists (
      select 1 from public.user_notifications un
      where un.user_id = uid
        and un.type = 'forum'
        and (un.data->>'postId') = post_rec.id::text
    ) then
      continue;
    end if;

    insert into public.user_notifications (
      user_id, title, body, type, is_read, data, created_at, updated_at
    ) values (
      uid,
      'You were mentioned in the forum',
      actor || ' mentioned you in "' || left(coalesce(topic_title, 'a discussion'), 80) || '".',
      'forum',
      false,
      jsonb_build_object(
        'relatedId', post_rec.topic_id::text,
        'topicId', post_rec.topic_id::text,
        'postId', post_rec.id::text,
        'target', 'forum_topic'
      ),
      now(),
      now()
    );
  end loop;
end;
$$;

grant execute on function public.notify_forum_mentions(uuid, uuid[]) to authenticated;

-- ---------------------------------------------------------------------------
-- Owners may only flip the read flag (RLS already limits rows to the owner).
-- ---------------------------------------------------------------------------
revoke update on public.user_notifications from authenticated, anon;
grant update (is_read, updated_at) on public.user_notifications to authenticated;

commit;
