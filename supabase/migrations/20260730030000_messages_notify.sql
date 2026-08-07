-- Part 5: notify recipient when a support message is inserted.
-- Alumni cannot insert user_notifications for admins (RLS), so use SECURITY DEFINER.

begin;

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
  notif_title text;
  notif_body text;
begin
  -- Never notify the sender.
  if new.recipient_id is null or new.recipient_id = new.sender_id then
    return new;
  end if;

  -- Dedupe by message id for this recipient.
  if exists (
    select 1
    from public.user_notifications un
    where un.user_id = new.recipient_id
      and un.type = 'message'
      and (un.data->>'messageId') = new.id::text
  ) then
    return new;
  end if;

  actor := coalesce(nullif(trim(new.sender_name), ''), 'Someone');
  preview := nullif(trim(new.body), '');
  if preview is null and coalesce(new.image_base64, '') <> '' then
    preview := 'Sent an image';
  end if;
  if preview is null then
    preview := 'You have received a new message';
  else
    preview := left(preview, 120);
  end if;

  -- Alumni thread id for admin deep-link (always the non-admin participant).
  if lower(coalesce(new.sender_role, '')) = 'admin' then
    conversation_user := new.recipient_id;
    notif_title := 'New message from Alumni Office';
    notif_body := preview;
  else
    conversation_user := new.sender_id;
    notif_title := 'New message from ' || actor;
    notif_body := preview;
  end if;

  insert into public.user_notifications (
    user_id,
    title,
    body,
    type,
    is_read,
    data,
    created_at,
    updated_at
  ) values (
    new.recipient_id,
    notif_title,
    notif_body,
    'message',
    false,
    jsonb_build_object(
      'relatedId', new.id::text,
      'messageId', new.id::text,
      'senderId', new.sender_id::text,
      'senderName', actor,
      'senderRole', coalesce(new.sender_role, ''),
      'conversationUserId', conversation_user::text,
      'target', 'messages'
    ),
    now(),
    now()
  );

  return new;
end;
$$;

drop trigger if exists trg_notify_message_recipient on public.messages;
create trigger trg_notify_message_recipient
after insert on public.messages
for each row execute function public.notify_message_recipient();

-- Optional RPC for clients that still call NotificationService.notifyNewMessage.
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
  actor text := coalesce(nullif(trim(p_sender_name), ''), 'Someone');
  preview text := coalesce(nullif(trim(p_preview), ''), 'You have received a new message');
  conversation_user uuid;
  notif_title text;
begin
  if p_recipient_id is null or p_message_id is null then
    return;
  end if;

  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  -- Only sender (or admin) may notify about a message.
  if not public.is_admin() and auth.uid() is distinct from p_sender_id then
    raise exception 'not allowed';
  end if;

  if exists (
    select 1
    from public.user_notifications un
    where un.user_id = p_recipient_id
      and un.type = 'message'
      and (un.data->>'messageId') = p_message_id::text
  ) then
    return;
  end if;

  if lower(coalesce(p_sender_role, '')) = 'admin' then
    conversation_user := p_recipient_id;
    notif_title := 'New message from Alumni Office';
  else
    conversation_user := coalesce(p_sender_id, p_recipient_id);
    notif_title := 'New message from ' || actor;
  end if;

  insert into public.user_notifications (
    user_id, title, body, type, is_read, data, created_at, updated_at
  ) values (
    p_recipient_id,
    notif_title,
    left(preview, 120),
    'message',
    false,
    jsonb_build_object(
      'relatedId', p_message_id::text,
      'messageId', p_message_id::text,
      'senderId', coalesce(p_sender_id::text, ''),
      'senderName', actor,
      'senderRole', coalesce(p_sender_role, ''),
      'conversationUserId', conversation_user::text,
      'target', 'messages'
    ),
    now(),
    now()
  );
end;
$$;

revoke all on function public.notify_new_message(uuid, uuid, text, uuid, text, text) from public;
grant execute on function public.notify_new_message(uuid, uuid, text, uuid, text, text) to authenticated;

commit;
