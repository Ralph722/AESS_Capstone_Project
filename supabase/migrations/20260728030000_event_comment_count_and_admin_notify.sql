-- Keep events.comments_count accurate even when alumni post/delete comments.
-- Alumni cannot UPDATE events (admin-only RLS), so maintain the count in a
-- security-definer trigger instead of from the Flutter client.

create or replace function public.sync_event_comments_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  target_event_id uuid;
begin
  target_event_id := coalesce(new.event_id, old.event_id);
  update public.events
  set
    comments_count = (
      select count(*)::integer
      from public.event_comments
      where event_id = target_event_id
    ),
    updated_at = now()
  where id = target_event_id;
  return coalesce(new, old);
end;
$$;

drop trigger if exists trg_sync_event_comments_count on public.event_comments;
create trigger trg_sync_event_comments_count
after insert or delete on public.event_comments
for each row execute function public.sync_event_comments_count();

-- Backfill existing rows that were stuck at 0.
update public.events e
set comments_count = coalesce(c.cnt, 0)
from (
  select event_id, count(*)::integer as cnt
  from public.event_comments
  group by event_id
) c
where e.id = c.event_id;

update public.events e
set comments_count = 0
where not exists (
  select 1 from public.event_comments c where c.event_id = e.id
)
and e.comments_count <> 0;

-- Notify all admins when an alumni posts a new event comment.
-- Regular users cannot insert user_notifications for other users (RLS).
create or replace function public.notify_admins_new_event_comment()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  event_theme text;
  commenter_name text;
  admin_id uuid;
begin
  select coalesce(nullif(trim(theme), ''), 'Event')
  into event_theme
  from public.events
  where id = new.event_id;

  select coalesce(nullif(trim(display_name), ''), 'A user')
  into commenter_name
  from public.users
  where id = new.user_id;

  for admin_id in
    select id from public.users where role = 'admin'
  loop
    -- Skip notifying the comment author if they are somehow an admin posting.
    if admin_id = new.user_id then
      continue;
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
      admin_id,
      'New event comment',
      commenter_name || ' commented on "' || event_theme || '".',
      'event',
      false,
      jsonb_build_object(
        'relatedId', new.event_id::text,
        'eventId', new.event_id::text,
        'commentId', new.id::text,
        'target', 'event_comments'
      ),
      now(),
      now()
    );
  end loop;

  return new;
end;
$$;

drop trigger if exists trg_notify_admins_new_event_comment on public.event_comments;
create trigger trg_notify_admins_new_event_comment
after insert on public.event_comments
for each row execute function public.notify_admins_new_event_comment();
