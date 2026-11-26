-- Community light polls (YouTube-style): post_kind=poll, options, changeable votes.
-- Separate from system Surveys. No admin review; publishes like discussions.

begin;

-- ---------------------------------------------------------------------------
-- Allow post_kind = poll (review_status stays none, like discussion)
-- ---------------------------------------------------------------------------
alter table public.forum_topics
  drop constraint if exists forum_topics_post_kind_check;

alter table public.forum_topics
  add constraint forum_topics_post_kind_check
  check (post_kind in ('discussion', 'job_offer', 'poll'));

alter table public.forum_topics
  drop constraint if exists forum_topics_kind_review_consistency;

alter table public.forum_topics
  add constraint forum_topics_kind_review_consistency
  check (
    (post_kind in ('discussion', 'poll') and review_status = 'none')
    or (post_kind = 'job_offer' and review_status <> 'none')
  );

-- ---------------------------------------------------------------------------
-- Options + votes
-- ---------------------------------------------------------------------------
create table if not exists public.forum_poll_options (
  id uuid primary key default gen_random_uuid(),
  topic_id uuid not null references public.forum_topics (id) on delete cascade,
  label text not null,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  constraint forum_poll_options_label_len
    check (char_length(trim(label)) between 1 and 120)
);

create index if not exists idx_forum_poll_options_topic
  on public.forum_poll_options (topic_id, sort_order);

create table if not exists public.forum_poll_votes (
  topic_id uuid not null references public.forum_topics (id) on delete cascade,
  option_id uuid not null references public.forum_poll_options (id) on delete cascade,
  user_id uuid not null references public.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (topic_id, user_id)
);

create index if not exists idx_forum_poll_votes_option
  on public.forum_poll_votes (option_id);

create index if not exists idx_forum_poll_votes_topic
  on public.forum_poll_votes (topic_id);

-- ---------------------------------------------------------------------------
-- Insert guard: keep polls as poll (do not force to discussion)
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
    new.post_kind := 'discussion';
    new.review_status := 'none';
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

  if coalesce(new.post_kind, 'discussion') not in ('discussion', 'job_offer', 'poll') then
    new.post_kind := 'discussion';
  end if;

  if new.post_kind = 'job_offer' then
    if new.is_announcement = true then
      raise exception 'job offers cannot be announcements';
    end if;
    if nullif(trim(coalesce(new.purpose_letter, '')), '') is null then
      raise exception 'purpose letter is required for job offers';
    end if;
    if char_length(trim(new.purpose_letter)) > 2000 then
      raise exception 'purpose letter is too long';
    end if;
    new.review_status := 'pending';
    new.is_locked := true;
    new.is_solved := false;
    new.is_pinned := false;
    new.is_featured := false;
    new.decline_reason := '';
    new.reviewed_at := null;
    new.reviewed_by := null;
  elsif new.post_kind = 'poll' then
    if new.is_announcement = true then
      raise exception 'polls cannot be announcements';
    end if;
    new.review_status := 'none';
    new.is_solved := false;
    new.purpose_letter := coalesce(new.purpose_letter, '');
    new.cover_image_url := coalesce(new.cover_image_url, '');
    new.company_name := coalesce(new.company_name, '');
    new.apply_url := coalesce(new.apply_url, '');
    new.decline_reason := '';
    new.reviewed_at := null;
    new.reviewed_by := null;
  else
    new.post_kind := 'discussion';
    new.review_status := 'none';
    new.purpose_letter := coalesce(new.purpose_letter, '');
    new.cover_image_url := coalesce(new.cover_image_url, '');
    new.company_name := coalesce(new.company_name, '');
    new.apply_url := coalesce(new.apply_url, '');
    new.decline_reason := '';
    new.reviewed_at := null;
    new.reviewed_by := null;
  end if;

  return new;
end;
$$;

-- Author update: polls may edit title/body like discussions (job-offer fields blocked).
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
     and new.post_kind is not distinct from old.post_kind
     and new.review_status is not distinct from old.review_status
     and new.purpose_letter is not distinct from old.purpose_letter
     and new.cover_image_url is not distinct from old.cover_image_url
     and new.company_name is not distinct from old.company_name
     and new.apply_url is not distinct from old.apply_url
     and new.decline_reason is not distinct from old.decline_reason
     and new.reviewed_at is not distinct from old.reviewed_at
     and new.reviewed_by is not distinct from old.reviewed_by
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
     or new.post_kind is distinct from old.post_kind
     or new.decline_reason is distinct from old.decline_reason
     or new.reviewed_at is distinct from old.reviewed_at
     or new.reviewed_by is distinct from old.reviewed_by
  then
    raise exception 'authors cannot change moderation fields';
  end if;

  if old.post_kind <> 'job_offer'
     and new.visibility is distinct from old.visibility
  then
    raise exception 'authors cannot change moderation fields';
  end if;

  if new.is_announcement and new.is_solved is distinct from old.is_solved and new.is_solved = true then
    raise exception 'announcements cannot be marked solved';
  end if;

  if old.post_kind = 'job_offer' then
    if new.visibility is null
       or new.visibility not in ('everyone', 'program', 'program_batch')
    then
      new.visibility := 'everyone';
    end if;
    if new.visibility in ('program', 'program_batch')
       and nullif(trim(coalesce(new.author_program, '')), '') is null
    then
      new.visibility := 'everyone';
    end if;
    if new.visibility = 'program_batch'
       and nullif(trim(coalesce(new.author_batch, '')), '') is null
    then
      new.visibility := 'program';
    end if;

    if old.review_status = 'approved' then
      if new.review_status is distinct from old.review_status then
        raise exception 'approved job offers cannot change review status';
      end if;
      if nullif(trim(coalesce(new.purpose_letter, '')), '') is null then
        raise exception 'purpose letter is required for job offers';
      end if;
      if char_length(trim(new.purpose_letter)) > 2000 then
        raise exception 'purpose letter is too long';
      end if;
    elsif old.review_status in ('pending', 'declined') then
      if new.review_status is distinct from old.review_status
         and new.review_status not in ('pending', 'withdrawn') then
        raise exception 'authors can only withdraw or keep pending';
      end if;
      if new.review_status = 'pending' and old.review_status = 'declined' then
        new.is_locked := true;
        new.decline_reason := '';
        new.reviewed_at := null;
        new.reviewed_by := null;
      end if;
      if new.review_status = 'withdrawn' then
        new.is_locked := true;
      end if;
      if nullif(trim(coalesce(new.purpose_letter, '')), '') is null then
        raise exception 'purpose letter is required for job offers';
      end if;
      if char_length(trim(new.purpose_letter)) > 2000 then
        raise exception 'purpose letter is too long';
      end if;
    elsif old.review_status = 'withdrawn' then
      raise exception 'withdrawn job offers cannot be edited';
    end if;
  else
    if new.review_status is distinct from old.review_status
       or new.purpose_letter is distinct from old.purpose_letter
       or new.cover_image_url is distinct from old.cover_image_url
       or new.company_name is distinct from old.company_name
       or new.apply_url is distinct from old.apply_url
    then
      raise exception 'discussion topics cannot change job-offer fields';
    end if;
  end if;

  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
alter table public.forum_poll_options enable row level security;
alter table public.forum_poll_votes enable row level security;

drop policy if exists forum_poll_options_select on public.forum_poll_options;
create policy forum_poll_options_select on public.forum_poll_options
  for select to authenticated
  using (
    exists (
      select 1 from public.forum_topics t
      where t.id = topic_id
    )
  );

drop policy if exists forum_poll_options_insert on public.forum_poll_options;
create policy forum_poll_options_insert on public.forum_poll_options
  for insert to authenticated
  with check (
    exists (
      select 1 from public.forum_topics t
      where t.id = topic_id
        and t.post_kind = 'poll'
        and (t.author_uid = auth.uid() or public.is_admin())
    )
  );

drop policy if exists forum_poll_options_delete on public.forum_poll_options;
create policy forum_poll_options_delete on public.forum_poll_options
  for delete to authenticated
  using (
    public.is_admin()
    or exists (
      select 1 from public.forum_topics t
      where t.id = topic_id and t.author_uid = auth.uid()
    )
  );

drop policy if exists forum_poll_votes_select on public.forum_poll_votes;
create policy forum_poll_votes_select on public.forum_poll_votes
  for select to authenticated
  using (
    exists (
      select 1 from public.forum_topics t
      where t.id = topic_id
    )
  );

-- Votes only via RPC (security definer); block direct writes.
drop policy if exists forum_poll_votes_insert on public.forum_poll_votes;
drop policy if exists forum_poll_votes_update on public.forum_poll_votes;
drop policy if exists forum_poll_votes_delete on public.forum_poll_votes;

revoke all on table public.forum_poll_options from anon;
revoke all on table public.forum_poll_votes from anon;
grant select, insert, delete on table public.forum_poll_options to authenticated;
grant select on table public.forum_poll_votes to authenticated;

-- ---------------------------------------------------------------------------
-- Create poll (atomic topic + 2–4 options)
-- ---------------------------------------------------------------------------
create or replace function public.create_forum_poll(
  p_title text,
  p_body text,
  p_options text[],
  p_visibility text default 'everyone',
  p_topic_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_id uuid;
  v_name text;
  v_program text := '';
  v_batch text := '';
  v_vis text := coalesce(nullif(trim(p_visibility), ''), 'everyone');
  v_opt text;
  v_count integer := 0;
  v_ord integer := 0;
  cleaned text[];
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  if nullif(trim(coalesce(p_title, '')), '') is null then
    raise exception 'Question is required';
  end if;
  if char_length(trim(p_title)) > 120 then
    raise exception 'Question is too long';
  end if;
  if char_length(trim(coalesce(p_body, ''))) > 10000 then
    raise exception 'Details are too long';
  end if;

  cleaned := array[]::text[];
  if p_options is not null then
    foreach v_opt in array p_options loop
      v_opt := trim(coalesce(v_opt, ''));
      if v_opt <> '' then
        if char_length(v_opt) > 120 then
          raise exception 'Option is too long';
        end if;
        cleaned := array_append(cleaned, v_opt);
      end if;
    end loop;
  end if;
  v_count := coalesce(array_length(cleaned, 1), 0);
  if v_count < 2 or v_count > 4 then
    raise exception 'Polls need 2 to 4 options';
  end if;

  select
    coalesce(nullif(trim(u.display_name), ''), 'Alumni'),
    coalesce(nullif(trim(u.program), ''), ''),
    coalesce(nullif(trim(u.year_graduated), ''), '')
  into v_name, v_program, v_batch
  from public.users u
  where u.id = v_uid;

  if v_vis not in ('everyone', 'program', 'program_batch') then
    v_vis := 'everyone';
  end if;
  if v_vis in ('program', 'program_batch') and v_program = '' then
    v_vis := 'everyone';
  end if;
  if v_vis = 'program_batch' and v_batch = '' then
    v_vis := 'program';
  end if;

  v_id := coalesce(p_topic_id, gen_random_uuid());

  insert into public.forum_topics (
    id, title, body, author_uid, author_name, author_program, author_batch,
    post_kind, review_status, visibility, is_announcement, is_pinned, is_solved,
    is_locked, is_featured
  ) values (
    v_id,
    trim(p_title),
    trim(coalesce(p_body, '')),
    v_uid,
    coalesce(v_name, 'Alumni'),
    v_program,
    v_batch,
    'poll',
    'none',
    v_vis,
    false,
    false,
    false,
    false,
    false
  );

  for v_ord in 1 .. v_count loop
    insert into public.forum_poll_options (topic_id, label, sort_order)
    values (v_id, cleaned[v_ord], v_ord - 1);
  end loop;

  return v_id;
end;
$$;

revoke all on function public.create_forum_poll(text, text, text[], text, uuid)
  from public, anon;
grant execute on function public.create_forum_poll(text, text, text[], text, uuid)
  to authenticated;

-- ---------------------------------------------------------------------------
-- Vote (changeable single choice) + summary helper
-- ---------------------------------------------------------------------------
create or replace function public.forum_poll_summary(p_topic_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_kind text;
  v_total integer;
  v_mine uuid;
  v_counts jsonb;
  v_options jsonb;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  select t.post_kind into v_kind
  from public.forum_topics t
  where t.id = p_topic_id;

  if v_kind is null then
    raise exception 'Poll not found';
  end if;
  if v_kind <> 'poll' then
    raise exception 'Not a poll';
  end if;

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'id', o.id,
      'label', o.label,
      'sort_order', o.sort_order,
      'votes', coalesce(c.cnt, 0)
    )
    order by o.sort_order, o.created_at
  ), '[]'::jsonb)
  into v_options
  from public.forum_poll_options o
  left join lateral (
    select count(*)::integer as cnt
    from public.forum_poll_votes v
    where v.option_id = o.id
  ) c on true
  where o.topic_id = p_topic_id;

  select count(*)::integer into v_total
  from public.forum_poll_votes
  where topic_id = p_topic_id;

  select option_id into v_mine
  from public.forum_poll_votes
  where topic_id = p_topic_id and user_id = v_uid;

  select coalesce(jsonb_agg(
    jsonb_build_object('option_id', x.option_id, 'votes', x.votes)
  ), '[]'::jsonb)
  into v_counts
  from (
    select option_id, count(*)::integer as votes
    from public.forum_poll_votes
    where topic_id = p_topic_id
    group by option_id
  ) x;

  return jsonb_build_object(
    'topic_id', p_topic_id,
    'total', coalesce(v_total, 0),
    'my_option_id', v_mine,
    'options', v_options,
    'counts', v_counts
  );
end;
$$;

revoke all on function public.forum_poll_summary(uuid) from public, anon;
grant execute on function public.forum_poll_summary(uuid) to authenticated;

create or replace function public.vote_forum_poll(
  p_topic_id uuid,
  p_option_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_kind text;
  v_locked boolean;
  v_opt_topic uuid;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  select t.post_kind, t.is_locked into v_kind, v_locked
  from public.forum_topics t
  where t.id = p_topic_id;

  if v_kind is null then
    raise exception 'Poll not found';
  end if;
  if v_kind <> 'poll' then
    raise exception 'Not a poll';
  end if;
  if v_locked then
    raise exception 'This poll is locked';
  end if;

  select o.topic_id into v_opt_topic
  from public.forum_poll_options o
  where o.id = p_option_id;

  if v_opt_topic is null or v_opt_topic <> p_topic_id then
    raise exception 'Invalid poll option';
  end if;

  insert into public.forum_poll_votes (topic_id, option_id, user_id, updated_at)
  values (p_topic_id, p_option_id, v_uid, now())
  on conflict (topic_id, user_id) do update
    set option_id = excluded.option_id,
        updated_at = now();

  return public.forum_poll_summary(p_topic_id);
end;
$$;

revoke all on function public.vote_forum_poll(uuid, uuid) from public, anon;
grant execute on function public.vote_forum_poll(uuid, uuid) to authenticated;

-- Batch summaries for feed hydration
create or replace function public.forum_poll_summaries(p_topic_ids uuid[])
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  tid uuid;
  out jsonb := '{}'::jsonb;
  one jsonb;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  if p_topic_ids is null then
    return out;
  end if;
  foreach tid in array p_topic_ids loop
    begin
      one := public.forum_poll_summary(tid);
      out := out || jsonb_build_object(tid::text, one);
    exception when others then
      -- skip non-poll / missing
      null;
    end;
  end loop;
  return out;
end;
$$;

revoke all on function public.forum_poll_summaries(uuid[]) from public, anon;
grant execute on function public.forum_poll_summaries(uuid[]) to authenticated;

commit;
