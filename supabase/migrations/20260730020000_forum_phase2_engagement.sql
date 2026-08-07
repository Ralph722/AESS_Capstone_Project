-- Forum Phase 2: reply/mention notifications, realtime, report helpers.

-- ---------------------------------------------------------------------------
-- Realtime publication
-- ---------------------------------------------------------------------------
alter table public.forum_posts replica identity full;
alter table public.forum_topics replica identity full;
alter table public.forum_reports replica identity full;
alter table public.forum_helpful_reactions replica identity full;

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'forum_posts'
  ) then
    alter publication supabase_realtime add table public.forum_posts;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'forum_topics'
  ) then
    alter publication supabase_realtime add table public.forum_topics;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'forum_reports'
  ) then
    alter publication supabase_realtime add table public.forum_reports;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'forum_helpful_reactions'
  ) then
    alter publication supabase_realtime add table public.forum_helpful_reactions;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- Notify topic author on reply
-- ---------------------------------------------------------------------------
create or replace function public.notify_forum_topic_author_on_reply()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  topic_record public.forum_topics%rowtype;
  actor text;
begin
  select * into topic_record
  from public.forum_topics
  where id = new.topic_id;

  if not found then
    return new;
  end if;

  if topic_record.author_uid = new.author_uid then
    return new;
  end if;

  actor := coalesce(nullif(trim(new.author_name), ''), 'An alumni');

  insert into public.user_notifications (
    user_id, title, body, type, is_read, data, created_at, updated_at
  ) values (
    topic_record.author_uid,
    'New reply to your discussion',
    actor || ' replied to "' || left(topic_record.title, 80) || '".',
    'forum',
    false,
    jsonb_build_object(
      'relatedId', new.topic_id::text,
      'topicId', new.topic_id::text,
      'postId', new.id::text,
      'target', 'forum_topic'
    ),
    now(),
    now()
  );

  -- If reply quotes someone else's post, notify that author too (not topic author again).
  if new.quoted_post_id is not null then
    declare
      quoted_author uuid;
      quoted_name text;
    begin
      select author_uid into quoted_author
      from public.forum_posts
      where id = new.quoted_post_id;

      if quoted_author is not null
         and quoted_author <> new.author_uid
         and quoted_author <> topic_record.author_uid then
        insert into public.user_notifications (
          user_id, title, body, type, is_read, data, created_at, updated_at
        ) values (
          quoted_author,
          'Your reply was quoted',
          actor || ' quoted your reply in "' || left(topic_record.title, 80) || '".',
          'forum',
          false,
          jsonb_build_object(
            'relatedId', new.topic_id::text,
            'topicId', new.topic_id::text,
            'postId', new.id::text,
            'target', 'forum_topic'
          ),
          now(),
          now()
        );
      end if;
    end;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_notify_forum_topic_author_on_reply on public.forum_posts;
create trigger trg_notify_forum_topic_author_on_reply
after insert on public.forum_posts
for each row execute function public.notify_forum_topic_author_on_reply();

-- ---------------------------------------------------------------------------
-- Mention search + notify RPCs (alumni cannot insert others' notifications)
-- ---------------------------------------------------------------------------
create or replace function public.search_forum_mention_users(p_query text)
returns table (
  id uuid,
  display_name text,
  program text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  q text := lower(trim(coalesce(p_query, '')));
begin
  if not public.is_signed_in() then
    raise exception 'not authenticated';
  end if;

  if length(q) < 1 then
    return;
  end if;

  return query
  select u.id, coalesce(nullif(trim(u.display_name), ''), u.email), coalesce(u.program, '')
  from public.users u
  where coalesce(u.role, 'user') = 'user'
    and (
      lower(coalesce(u.display_name, '')) like '%' || q || '%'
      or lower(coalesce(u.email, '')) like '%' || q || '%'
    )
  order by u.display_name asc nulls last
  limit 12;
end;
$$;

grant execute on function public.search_forum_mention_users(text) to authenticated;

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

  select title into topic_title from public.forum_topics where id = post_rec.topic_id;
  actor := coalesce(nullif(trim(post_rec.author_name), ''), 'An alumni');

  if p_mentioned_uids is null then
    return;
  end if;

  foreach uid in array p_mentioned_uids loop
    if uid is null or uid = post_rec.author_uid then
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
-- Admin notify helpers when reports are filed
-- ---------------------------------------------------------------------------
create or replace function public.notify_admins_forum_report()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  admin_rec record;
  actor text;
begin
  select coalesce(nullif(trim(display_name), ''), email, 'An alumni')
  into actor
  from public.users
  where id = new.reporter_uid;

  for admin_rec in
    select id from public.users where role = 'admin'
  loop
    insert into public.user_notifications (
      user_id, title, body, type, is_read, data, created_at, updated_at
    ) values (
      admin_rec.id,
      'Forum content reported',
      coalesce(actor, 'An alumni') || ' submitted a forum report.',
      'forum',
      false,
      jsonb_build_object(
        'relatedId', coalesce(new.topic_id::text, new.id::text),
        'topicId', new.topic_id::text,
        'postId', new.post_id::text,
        'reportId', new.id::text,
        'target', 'forum_report'
      ),
      now(),
      now()
    );
  end loop;

  return new;
end;
$$;

drop trigger if exists trg_notify_admins_forum_report on public.forum_reports;
create trigger trg_notify_admins_forum_report
after insert on public.forum_reports
for each row execute function public.notify_admins_forum_report();

-- Keep report updated_at fresh
drop trigger if exists trg_forum_reports_updated_at on public.forum_reports;
create trigger trg_forum_reports_updated_at
before update on public.forum_reports
for each row execute function public.set_updated_at();
