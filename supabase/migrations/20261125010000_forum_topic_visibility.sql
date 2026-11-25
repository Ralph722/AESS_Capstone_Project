-- Forum topic audience: everyone | program | program_batch.
-- Restricted posts are visible to matching alumni (and always to author/admin).

begin;

alter table public.forum_topics
  add column if not exists visibility text not null default 'everyone';

alter table public.forum_topics
  drop constraint if exists forum_topics_visibility_check;

alter table public.forum_topics
  add constraint forum_topics_visibility_check
  check (visibility in ('everyone', 'program', 'program_batch'));

create index if not exists idx_forum_topics_visibility
  on public.forum_topics (visibility)
  where visibility <> 'everyone';

-- ---------------------------------------------------------------------------
-- Viewer helpers (program / batch from public.users)
-- ---------------------------------------------------------------------------
create or replace function public.forum_viewer_program()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(nullif(trim(u.program), ''), '')
  from public.users u
  where u.id = (select auth.uid());
$$;

create or replace function public.forum_viewer_batch()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(nullif(trim(u.year_graduated), ''), '')
  from public.users u
  where u.id = (select auth.uid());
$$;

revoke all on function public.forum_viewer_program() from public, anon;
revoke all on function public.forum_viewer_batch() from public, anon;
grant execute on function public.forum_viewer_program() to authenticated, service_role;
grant execute on function public.forum_viewer_batch() to authenticated, service_role;

create or replace function public.can_view_forum_topic(
  p_visibility text,
  p_author_uid uuid,
  p_author_program text,
  p_author_batch text,
  p_is_announcement boolean
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    (select public.is_admin())
    or p_author_uid is not distinct from (select auth.uid())
    or coalesce(p_is_announcement, false) = true
    or coalesce(p_visibility, 'everyone') = 'everyone'
    or (
      coalesce(p_visibility, 'everyone') = 'program'
      and nullif(trim(coalesce(p_author_program, '')), '') is not null
      and lower(trim(p_author_program)) = lower(trim(coalesce((select public.forum_viewer_program()), '')))
    )
    or (
      coalesce(p_visibility, 'everyone') = 'program_batch'
      and nullif(trim(coalesce(p_author_program, '')), '') is not null
      and nullif(trim(coalesce(p_author_batch, '')), '') is not null
      and lower(trim(p_author_program)) = lower(trim(coalesce((select public.forum_viewer_program()), '')))
      and lower(trim(p_author_batch)) = lower(trim(coalesce((select public.forum_viewer_batch()), '')))
    );
$$;

revoke all on function public.can_view_forum_topic(text, uuid, text, text, boolean)
  from public, anon;
grant execute on function public.can_view_forum_topic(text, uuid, text, text, boolean)
  to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Insert / update guards
-- ---------------------------------------------------------------------------
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
    new.visibility := 'everyone';
  end if;

  if new.visibility is null or new.visibility not in ('everyone', 'program', 'program_batch') then
    new.visibility := 'everyone';
  end if;

  if new.visibility in ('program', 'program_batch')
     and nullif(trim(coalesce(new.author_program, '')), '') is null then
    new.visibility := 'everyone';
  end if;

  if new.visibility = 'program_batch'
     and nullif(trim(coalesce(new.author_batch, '')), '') is null then
    new.visibility := 'program';
  end if;

  return new;
end;
$$;

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

  -- Allow reply-count / activity maintenance from forum_posts triggers.
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
     and new.visibility is not distinct from old.visibility
  then
    return new;
  end if;

  if old.author_uid <> auth.uid() then
    raise exception 'not owner';
  end if;

  if new.is_locked is distinct from old.is_locked
     or new.is_pinned is distinct from old.is_pinned
     or new.is_announcement is distinct from old.is_announcement
     or new.is_featured is distinct from old.is_featured
     or new.moderation_reason is distinct from old.moderation_reason
     or new.view_count is distinct from old.view_count
     or new.author_uid is distinct from old.author_uid
     or new.visibility is distinct from old.visibility
  then
    raise exception 'authors cannot change moderation fields';
  end if;

  if new.is_announcement and new.is_solved is distinct from old.is_solved and new.is_solved = true then
    raise exception 'announcements cannot be marked solved';
  end if;

  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- RLS: topics + posts respect audience
-- ---------------------------------------------------------------------------
alter policy forum_topics_select_signed_in on public.forum_topics
  using (
    (select public.is_signed_in())
    and (
      (select public.is_admin())
      or not public.user_is_anonymized(author_uid)
    )
    and public.can_view_forum_topic(
      visibility,
      author_uid,
      author_program,
      author_batch,
      is_announcement
    )
  );

alter policy forum_posts_select_signed_in on public.forum_posts
  using (
    (select public.is_signed_in())
    and (
      (select public.is_admin())
      or not public.user_is_anonymized(author_uid)
    )
    and exists (
      select 1
      from public.forum_topics t
      where t.id = topic_id
        and public.can_view_forum_topic(
          t.visibility,
          t.author_uid,
          t.author_program,
          t.author_batch,
          t.is_announcement
        )
    )
  );

commit;
