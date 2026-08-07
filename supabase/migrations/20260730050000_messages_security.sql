-- Part 10: Messages security — tighten RLS, insert/update guardrails, Storage path ownership.

begin;

-- ---------------------------------------------------------------------------
-- Messages INSERT: must be the authenticated sender; alumni only → admin.
-- ---------------------------------------------------------------------------
drop policy if exists "messages_insert_signed_in" on public.messages;
drop policy if exists "messages_insert_participant" on public.messages;

create policy "messages_insert_participant"
on public.messages
for insert
to authenticated
with check (
  sender_id = auth.uid()
  and (
    public.is_admin()
    or exists (
      select 1
      from public.users u
      where u.id = recipient_id
        and u.role = 'admin'
    )
  )
);

-- ---------------------------------------------------------------------------
-- INSERT guardrails: body length, attachment URL shape, role spoofing.
-- ---------------------------------------------------------------------------
create or replace function public.enforce_message_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  jwt_role text := coalesce(auth.role(), '');
  uid uuid := auth.uid();
  max_body int := 4000;
  max_image_ref int := 2048;
begin
  if jwt_role in ('service_role', 'postgres') then
    return new;
  end if;

  if uid is null then
    raise exception 'not authenticated';
  end if;

  if new.sender_id is distinct from uid then
    raise exception 'sender_id must be the authenticated user';
  end if;

  if length(coalesce(new.body, '')) > max_body then
    raise exception 'message body too long';
  end if;

  if new.image_base64 is not null and length(new.image_base64) > max_image_ref then
    raise exception 'image reference too long';
  end if;

  -- Disallow embedding raw base64 payloads; Storage URLs only.
  if new.image_base64 is not null
     and nullif(trim(new.image_base64), '') is not null
     and (
       left(trim(new.image_base64), 5) = 'data:'
       or (
         position('/object/public/images/messages/' in new.image_base64) = 0
         and position('/storage/v1/object/public/images/messages/' in new.image_base64) = 0
       )
     ) then
    raise exception 'invalid message image reference';
  end if;

  -- sender_role must match real role (admin cannot be spoofed by alumni).
  if public.is_admin() then
    new.sender_role := 'admin';
  else
    new.sender_role := 'user';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_messages_enforce_insert on public.messages;
create trigger trg_messages_enforce_insert
before insert on public.messages
for each row execute function public.enforce_message_insert();

-- ---------------------------------------------------------------------------
-- UPDATE guardrails: senders cannot reassign participants; length checks.
-- ---------------------------------------------------------------------------
create or replace function public.enforce_message_update()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  jwt_role text := coalesce(auth.role(), '');
  max_body int := 4000;
  max_image_ref int := 2048;
begin
  if jwt_role in ('service_role', 'postgres') then
    return new;
  end if;

  if public.is_admin() then
    if length(coalesce(new.body, '')) > max_body then
      raise exception 'message body too long';
    end if;
    return new;
  end if;

  if uid is null then
    raise exception 'not authenticated';
  end if;

  if length(coalesce(new.body, '')) > max_body then
    raise exception 'message body too long';
  end if;

  if new.image_base64 is not null and length(new.image_base64) > max_image_ref then
    raise exception 'image reference too long';
  end if;

  if old.sender_id = uid then
    -- Sender may edit content/reactions, not reassign the thread.
    if new.sender_id is distinct from old.sender_id
       or new.recipient_id is distinct from old.recipient_id
       or new.created_at is distinct from old.created_at
       or new.sender_role is distinct from old.sender_role then
      raise exception 'sender cannot reassign message participants';
    end if;

    if new.image_base64 is not null
       and nullif(trim(new.image_base64), '') is not null
       and new.image_base64 is distinct from old.image_base64
       and (
         left(trim(new.image_base64), 5) = 'data:'
         or (
           position('/object/public/images/messages/' in new.image_base64) = 0
           and position('/storage/v1/object/public/images/messages/' in new.image_base64) = 0
         )
       ) then
      raise exception 'invalid message image reference';
    end if;

    return new;
  end if;

  if old.recipient_id = uid then
    if new.body is distinct from old.body
       or new.image_base64 is distinct from old.image_base64
       or new.sender_id is distinct from old.sender_id
       or new.recipient_id is distinct from old.recipient_id
       or new.created_at is distinct from old.created_at
       or new.sender_role is distinct from old.sender_role then
      raise exception 'recipient cannot modify message content';
    end if;

    if new.is_read = true or new.reactions is distinct from old.reactions then
      return new;
    end if;

    raise exception 'recipient update not allowed';
  end if;

  raise exception 'not a participant';
end;
$$;

-- ---------------------------------------------------------------------------
-- Storage: own folder only (messages/avatars); admins may manage events + all.
-- ---------------------------------------------------------------------------
drop policy if exists "images_authenticated_insert" on storage.objects;
drop policy if exists "images_authenticated_update" on storage.objects;
drop policy if exists "images_authenticated_delete" on storage.objects;
drop policy if exists "images_owner_insert" on storage.objects;
drop policy if exists "images_owner_update" on storage.objects;
drop policy if exists "images_owner_delete" on storage.objects;

create policy "images_owner_insert"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'images'
  and (
    public.is_admin()
    or (
      (storage.foldername(name))[1] = 'messages'
      and (storage.foldername(name))[2] = auth.uid()::text
    )
    or (
      (storage.foldername(name))[1] = 'avatars'
      and name like ('avatars/' || auth.uid()::text || '%')
    )
  )
);

create policy "images_owner_update"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'images'
  and (
    public.is_admin()
    or (
      (storage.foldername(name))[1] = 'messages'
      and (storage.foldername(name))[2] = auth.uid()::text
    )
    or (
      (storage.foldername(name))[1] = 'avatars'
      and name like ('avatars/' || auth.uid()::text || '%')
    )
  )
)
with check (
  bucket_id = 'images'
  and (
    public.is_admin()
    or (
      (storage.foldername(name))[1] = 'messages'
      and (storage.foldername(name))[2] = auth.uid()::text
    )
    or (
      (storage.foldername(name))[1] = 'avatars'
      and name like ('avatars/' || auth.uid()::text || '%')
    )
  )
);

create policy "images_owner_delete"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'images'
  and (
    public.is_admin()
    or (
      (storage.foldername(name))[1] = 'messages'
      and (storage.foldername(name))[2] = auth.uid()::text
    )
    or (
      (storage.foldername(name))[1] = 'avatars'
      and name like ('avatars/' || auth.uid()::text || '%')
    )
  )
);

commit;
