-- Forum Redesign Phase 1: columns, tags, bookmarks, moderation events, stubs, RLS hardening.

-- ---------------------------------------------------------------------------
-- Extend forum_topics
-- ---------------------------------------------------------------------------
alter table public.forum_topics
  add column if not exists author_batch text not null default '',
  add column if not exists is_solved boolean not null default false,
  add column if not exists is_announcement boolean not null default false,
  add column if not exists is_featured boolean not null default false,
  add column if not exists edited_at timestamptz,
  add column if not exists moderation_reason text,
  add column if not exists view_count integer not null default 0;

-- ---------------------------------------------------------------------------
-- Extend forum_posts
-- ---------------------------------------------------------------------------
alter table public.forum_posts
  add column if not exists edited_at timestamptz,
  add column if not exists parent_post_id uuid references public.forum_posts(id) on delete set null,
  add column if not exists quoted_post_id uuid references public.forum_posts(id) on delete set null,
  add column if not exists quoted_excerpt text;

-- ---------------------------------------------------------------------------
-- Tags
-- ---------------------------------------------------------------------------
create table if not exists public.forum_tags (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  label text not null,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.forum_topic_tags (
  topic_id uuid not null references public.forum_topics(id) on delete cascade,
  tag_id uuid not null references public.forum_tags(id) on delete cascade,
  primary key (topic_id, tag_id)
);

create index if not exists idx_forum_topic_tags_tag on public.forum_topic_tags(tag_id);

insert into public.forum_tags (slug, label, sort_order) values
  ('career', 'Career', 10),
  ('employment', 'Employment', 20),
  ('internship', 'Internship', 30),
  ('scholarship', 'Scholarship', 40),
  ('business', 'Business', 50),
  ('networking', 'Networking', 60),
  ('events', 'Events', 70),
  ('question', 'Question', 80),
  ('advice', 'Advice', 90),
  ('technology', 'Technology', 100),
  ('entrepreneurship', 'Entrepreneurship', 110),
  ('further-study', 'Further Study', 120)
on conflict (slug) do nothing;

alter table public.forum_tags enable row level security;
alter table public.forum_topic_tags enable row level security;

drop policy if exists "forum_tags_select_signed_in" on public.forum_tags;
create policy "forum_tags_select_signed_in"
on public.forum_tags for select to authenticated
using (public.is_signed_in());

drop policy if exists "forum_tags_admin_write" on public.forum_tags;
create policy "forum_tags_admin_write"
on public.forum_tags for all to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "forum_topic_tags_select_signed_in" on public.forum_topic_tags;
create policy "forum_topic_tags_select_signed_in"
on public.forum_topic_tags for select to authenticated
using (public.is_signed_in());

drop policy if exists "forum_topic_tags_insert_author_or_admin" on public.forum_topic_tags;
create policy "forum_topic_tags_insert_author_or_admin"
on public.forum_topic_tags for insert to authenticated
with check (
  public.is_admin()
  or exists (
    select 1 from public.forum_topics t
    where t.id = topic_id and t.author_uid = auth.uid()
  )
);

drop policy if exists "forum_topic_tags_delete_author_or_admin" on public.forum_topic_tags;
create policy "forum_topic_tags_delete_author_or_admin"
on public.forum_topic_tags for delete to authenticated
using (
  public.is_admin()
  or exists (
    select 1 from public.forum_topics t
    where t.id = topic_id and t.author_uid = auth.uid()
  )
);

-- ---------------------------------------------------------------------------
-- Bookmarks
-- ---------------------------------------------------------------------------
create table if not exists public.forum_bookmarks (
  user_id uuid not null references auth.users(id) on delete cascade,
  topic_id uuid not null references public.forum_topics(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, topic_id)
);

create index if not exists idx_forum_bookmarks_topic on public.forum_bookmarks(topic_id);

alter table public.forum_bookmarks enable row level security;

drop policy if exists "forum_bookmarks_select_own" on public.forum_bookmarks;
create policy "forum_bookmarks_select_own"
on public.forum_bookmarks for select to authenticated
using (user_id = auth.uid());

drop policy if exists "forum_bookmarks_insert_own" on public.forum_bookmarks;
create policy "forum_bookmarks_insert_own"
on public.forum_bookmarks for insert to authenticated
with check (user_id = auth.uid());

drop policy if exists "forum_bookmarks_delete_own" on public.forum_bookmarks;
create policy "forum_bookmarks_delete_own"
on public.forum_bookmarks for delete to authenticated
using (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- Helpful reactions (schema only — no Phase 1 UI)
-- ---------------------------------------------------------------------------
create table if not exists public.forum_helpful_reactions (
  user_id uuid not null references auth.users(id) on delete cascade,
  post_id uuid not null references public.forum_posts(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, post_id)
);

alter table public.forum_helpful_reactions enable row level security;

drop policy if exists "forum_helpful_select_signed_in" on public.forum_helpful_reactions;
create policy "forum_helpful_select_signed_in"
on public.forum_helpful_reactions for select to authenticated
using (public.is_signed_in());

drop policy if exists "forum_helpful_insert_own" on public.forum_helpful_reactions;
create policy "forum_helpful_insert_own"
on public.forum_helpful_reactions for insert to authenticated
with check (user_id = auth.uid());

drop policy if exists "forum_helpful_delete_own" on public.forum_helpful_reactions;
create policy "forum_helpful_delete_own"
on public.forum_helpful_reactions for delete to authenticated
using (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- Moderation events
-- ---------------------------------------------------------------------------
create table if not exists public.forum_moderation_events (
  id uuid primary key default gen_random_uuid(),
  topic_id uuid references public.forum_topics(id) on delete set null,
  actor_uid uuid not null references auth.users(id) on delete cascade,
  action text not null,
  reason text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_forum_moderation_topic
  on public.forum_moderation_events(topic_id, created_at desc);

alter table public.forum_moderation_events enable row level security;

drop policy if exists "forum_moderation_select_admin" on public.forum_moderation_events;
create policy "forum_moderation_select_admin"
on public.forum_moderation_events for select to authenticated
using (public.is_admin());

drop policy if exists "forum_moderation_insert_admin" on public.forum_moderation_events;
create policy "forum_moderation_insert_admin"
on public.forum_moderation_events for insert to authenticated
with check (public.is_admin() and actor_uid = auth.uid());

-- ---------------------------------------------------------------------------
-- Reports stub (future)
-- ---------------------------------------------------------------------------
create table if not exists public.forum_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_uid uuid not null references auth.users(id) on delete cascade,
  topic_id uuid references public.forum_topics(id) on delete set null,
  post_id uuid references public.forum_posts(id) on delete set null,
  reason text not null default '',
  status text not null default 'open',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.forum_reports enable row level security;

drop policy if exists "forum_reports_select_admin_or_reporter" on public.forum_reports;
create policy "forum_reports_select_admin_or_reporter"
on public.forum_reports for select to authenticated
using (public.is_admin() or reporter_uid = auth.uid());

drop policy if exists "forum_reports_insert_own" on public.forum_reports;
create policy "forum_reports_insert_own"
on public.forum_reports for insert to authenticated
with check (reporter_uid = auth.uid());

drop policy if exists "forum_reports_admin_update" on public.forum_reports;
create policy "forum_reports_admin_update"
on public.forum_reports for update to authenticated
using (public.is_admin())
with check (public.is_admin());

-- ---------------------------------------------------------------------------
-- Indexes for list/search/sort
-- ---------------------------------------------------------------------------
create index if not exists idx_forum_topics_list
  on public.forum_topics (is_pinned desc, last_reply_at desc nulls last, created_at desc);

create index if not exists idx_forum_topics_announcement
  on public.forum_topics (is_announcement) where is_announcement = true;

create index if not exists idx_forum_topics_solved
  on public.forum_topics (is_solved) where is_solved = true;

create index if not exists idx_forum_topics_reply_count
  on public.forum_topics (reply_count desc);

create index if not exists idx_forum_topics_author_name
  on public.forum_topics using gin (to_tsvector('english', coalesce(title, '') || ' ' || coalesce(body, '') || ' ' || coalesce(author_name, '') || ' ' || coalesce(author_program, '')));

-- ---------------------------------------------------------------------------
-- RLS: harden topic updates — authors cannot flip moderation flags via raw update
-- ---------------------------------------------------------------------------
create or replace function public.forum_topics_guard_author_update()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.is_admin() then
    return new;
  end if;

  -- Allow reply-count maintenance from forum_posts triggers (any authenticated poster).
  if new.title is not distinct from old.title
     and new.body is not distinct from old.body
     and new.author_uid is not distinct from old.author_uid
     and new.author_name is not distinct from old.author_name
     and new.author_program is not distinct from old.author_program
     and new.author_batch is not distinct from old.author_batch
     and new.is_locked is not distinct from old.is_locked
     and new.is_pinned is not distinct from old.is_pinned
     and new.is_solved is not distinct from old.is_solved
     and new.is_announcement is not distinct from old.is_announcement
     and new.is_featured is not distinct from old.is_featured
     and new.moderation_reason is not distinct from old.moderation_reason
     and new.edited_at is not distinct from old.edited_at
     and new.view_count is not distinct from old.view_count
     and new.created_at is not distinct from old.created_at
  then
    return new;
  end if;

  if old.author_uid <> auth.uid() then
    raise exception 'not owner';
  end if;

  -- Authors may only change content + solved (not announcements)
  if new.is_locked is distinct from old.is_locked
     or new.is_pinned is distinct from old.is_pinned
     or new.is_announcement is distinct from old.is_announcement
     or new.is_featured is distinct from old.is_featured
     or new.moderation_reason is distinct from old.moderation_reason
     or new.view_count is distinct from old.view_count
     or new.author_uid is distinct from old.author_uid
  then
    raise exception 'authors cannot change moderation fields';
  end if;

  if new.is_announcement and new.is_solved is distinct from old.is_solved and new.is_solved = true then
    raise exception 'announcements cannot be marked solved';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_forum_topics_guard_author_update on public.forum_topics;
create trigger trg_forum_topics_guard_author_update
before update on public.forum_topics
for each row execute function public.forum_topics_guard_author_update();

-- Allow announcement insert only for admins
create or replace function public.forum_topics_guard_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.is_announcement = true and not public.is_admin() then
    raise exception 'only admins can create announcements';
  end if;
  if new.is_announcement = true then
    new.is_pinned := true;
    new.is_solved := false;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_forum_topics_guard_insert on public.forum_topics;
create trigger trg_forum_topics_guard_insert
before insert on public.forum_topics
for each row execute function public.forum_topics_guard_insert();

-- Posts: allow author edit of body within 30 minutes via RPC; replace never-update policy
drop policy if exists "forum_posts_update_never" on public.forum_posts;
drop policy if exists "forum_posts_update_admin_or_author" on public.forum_posts;

create policy "forum_posts_update_admin_or_author"
on public.forum_posts for update to authenticated
using (public.is_admin() or author_uid = auth.uid())
with check (public.is_admin() or author_uid = auth.uid());

create or replace function public.forum_posts_guard_author_update()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.is_admin() then
    return new;
  end if;

  if old.author_uid <> auth.uid() then
    raise exception 'not owner';
  end if;

  if new.topic_id is distinct from old.topic_id
     or new.author_uid is distinct from old.author_uid
     or new.parent_post_id is distinct from old.parent_post_id
  then
    raise exception 'invalid post update';
  end if;

  if new.body is distinct from old.body then
    if old.created_at < now() - interval '30 minutes' then
      raise exception 'edit window expired';
    end if;
    new.edited_at := now();
  end if;

  return new;
end;
$$;

drop trigger if exists trg_forum_posts_guard_author_update on public.forum_posts;
create trigger trg_forum_posts_guard_author_update
before update on public.forum_posts
for each row execute function public.forum_posts_guard_author_update();

-- ---------------------------------------------------------------------------
-- RPCs: edit topic/post within 30 minutes
-- ---------------------------------------------------------------------------
create or replace function public.edit_forum_topic(
  p_topic_id uuid,
  p_title text,
  p_body text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  t public.forum_topics%rowtype;
begin
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

create or replace function public.edit_forum_post(
  p_post_id uuid,
  p_body text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  p public.forum_posts%rowtype;
begin
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

grant execute on function public.edit_forum_topic(uuid, text, text) to authenticated;
grant execute on function public.edit_forum_post(uuid, text) to authenticated;

-- Optional view count bump (future analytics)
create or replace function public.increment_forum_topic_views(p_topic_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_signed_in() then
    return;
  end if;
  update public.forum_topics
  set view_count = view_count + 1
  where id = p_topic_id;
end;
$$;

grant execute on function public.increment_forum_topic_views(uuid) to authenticated;

-- Maintain reply_count / last_reply_at from posts (security definer bypasses author guard intent)
create or replace function public.forum_posts_maintain_topic_counts()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    update public.forum_topics
    set
      reply_count = reply_count + 1,
      last_reply_at = new.created_at,
      updated_at = now()
    where id = new.topic_id;
    return new;
  elsif tg_op = 'DELETE' then
    update public.forum_topics
    set
      reply_count = greatest(reply_count - 1, 0),
      updated_at = now()
    where id = old.topic_id;
    return old;
  end if;
  return null;
end;
$$;

drop trigger if exists trg_forum_posts_maintain_counts_ins on public.forum_posts;
create trigger trg_forum_posts_maintain_counts_ins
after insert on public.forum_posts
for each row execute function public.forum_posts_maintain_topic_counts();

drop trigger if exists trg_forum_posts_maintain_counts_del on public.forum_posts;
create trigger trg_forum_posts_maintain_counts_del
after delete on public.forum_posts
for each row execute function public.forum_posts_maintain_topic_counts();
