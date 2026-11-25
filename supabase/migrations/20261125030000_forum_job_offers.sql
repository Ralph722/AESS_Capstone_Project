-- Community job offers: alumni submit for admin review before public feed.
-- Pending / declined / withdrawn offers are visible only to author + admin.
-- v1 is community-only (no Careers / jobs table sync).

begin;

-- ---------------------------------------------------------------------------
-- Columns
-- ---------------------------------------------------------------------------
alter table public.forum_topics
  add column if not exists post_kind text not null default 'discussion';

alter table public.forum_topics
  add column if not exists review_status text not null default 'none';

alter table public.forum_topics
  add column if not exists purpose_letter text not null default '';

alter table public.forum_topics
  add column if not exists cover_image_url text not null default '';

alter table public.forum_topics
  add column if not exists company_name text not null default '';

alter table public.forum_topics
  add column if not exists apply_url text not null default '';

alter table public.forum_topics
  add column if not exists decline_reason text not null default '';

alter table public.forum_topics
  add column if not exists reviewed_at timestamptz;

alter table public.forum_topics
  add column if not exists reviewed_by uuid references public.users (id) on delete set null;

alter table public.forum_topics
  drop constraint if exists forum_topics_post_kind_check;

alter table public.forum_topics
  add constraint forum_topics_post_kind_check
  check (post_kind in ('discussion', 'job_offer'));

alter table public.forum_topics
  drop constraint if exists forum_topics_review_status_check;

alter table public.forum_topics
  add constraint forum_topics_review_status_check
  check (review_status in ('none', 'pending', 'approved', 'declined', 'withdrawn'));

-- Discussions stay on review_status = none; job offers never use none.
alter table public.forum_topics
  drop constraint if exists forum_topics_kind_review_consistency;

alter table public.forum_topics
  add constraint forum_topics_kind_review_consistency
  check (
    (post_kind = 'discussion' and review_status = 'none')
    or (post_kind = 'job_offer' and review_status <> 'none')
  );

create index if not exists idx_forum_topics_job_offer_pending
  on public.forum_topics (created_at desc)
  where post_kind = 'job_offer' and review_status = 'pending';

create index if not exists idx_forum_topics_post_kind
  on public.forum_topics (post_kind)
  where post_kind <> 'discussion';

-- ---------------------------------------------------------------------------
-- Visibility: non-approved job offers only for author / admin
-- ---------------------------------------------------------------------------
create or replace function public.can_view_forum_job_offer(
  p_post_kind text,
  p_review_status text,
  p_author_uid uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    coalesce(p_post_kind, 'discussion') <> 'job_offer'
    or coalesce(p_review_status, 'none') = 'approved'
    or p_author_uid is not distinct from (select auth.uid())
    or (select public.is_admin());
$$;

revoke all on function public.can_view_forum_job_offer(text, text, uuid)
  from public, anon;
grant execute on function public.can_view_forum_job_offer(text, text, uuid)
  to authenticated, service_role;

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
    and public.can_view_forum_job_offer(
      post_kind,
      review_status,
      author_uid
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
        and public.can_view_forum_job_offer(
          t.post_kind,
          t.review_status,
          t.author_uid
        )
    )
  );

-- ---------------------------------------------------------------------------
-- Insert / author-update guards
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

  if coalesce(new.post_kind, 'discussion') not in ('discussion', 'job_offer') then
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
     or new.visibility is distinct from old.visibility
     or new.post_kind is distinct from old.post_kind
     or new.decline_reason is distinct from old.decline_reason
     or new.reviewed_at is distinct from old.reviewed_at
     or new.reviewed_by is distinct from old.reviewed_by
  then
    raise exception 'authors cannot change moderation fields';
  end if;

  if new.is_announcement and new.is_solved is distinct from old.is_solved and new.is_solved = true then
    raise exception 'announcements cannot be marked solved';
  end if;

  -- Job-offer authors may edit content while pending/declined, or withdraw.
  if old.post_kind = 'job_offer' then
    if old.review_status = 'approved' then
      if new.purpose_letter is distinct from old.purpose_letter
         or new.cover_image_url is distinct from old.cover_image_url
         or new.company_name is distinct from old.company_name
         or new.apply_url is distinct from old.apply_url
         or new.review_status is distinct from old.review_status
      then
        raise exception 'approved job offers cannot be edited by authors';
      end if;
    elsif old.review_status in ('pending', 'declined') then
      if new.review_status is distinct from old.review_status
         and new.review_status not in ('pending', 'withdrawn') then
        raise exception 'authors can only withdraw or keep pending';
      end if;
      if new.review_status = 'pending' and old.review_status = 'declined' then
        -- Resubmit after decline.
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
-- Admin review RPC
-- ---------------------------------------------------------------------------
create or replace function public.review_forum_job_offer(
  p_topic_id uuid,
  p_approve boolean,
  p_decline_reason text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  t public.forum_topics%rowtype;
  reason text := nullif(trim(coalesce(p_decline_reason, '')), '');
begin
  if not public.is_admin() then
    raise exception 'admin only';
  end if;

  select * into t from public.forum_topics where id = p_topic_id for update;
  if not found then
    raise exception 'topic not found';
  end if;
  if t.post_kind <> 'job_offer' then
    raise exception 'not a job offer';
  end if;
  if t.review_status not in ('pending', 'declined') then
    raise exception 'job offer is not awaiting review';
  end if;

  if p_approve then
    update public.forum_topics
    set
      review_status = 'approved',
      is_locked = false,
      decline_reason = '',
      reviewed_at = now(),
      reviewed_by = auth.uid(),
      updated_at = now()
    where id = p_topic_id;
  else
    if reason is null then
      raise exception 'decline reason is required';
    end if;
    if char_length(reason) > 500 then
      raise exception 'decline reason is too long';
    end if;
    update public.forum_topics
    set
      review_status = 'declined',
      is_locked = true,
      decline_reason = reason,
      reviewed_at = now(),
      reviewed_by = auth.uid(),
      updated_at = now()
    where id = p_topic_id;
  end if;

  insert into public.forum_moderation_events (topic_id, actor_uid, action, reason)
  values (
    p_topic_id,
    auth.uid(),
    case when p_approve then 'job_offer_approved' else 'job_offer_declined' end,
    case when p_approve then null else reason end
  );
end;
$$;

revoke all on function public.review_forum_job_offer(uuid, boolean, text)
  from public, anon;
grant execute on function public.review_forum_job_offer(uuid, boolean, text)
  to authenticated;

-- ---------------------------------------------------------------------------
-- Notifications: new pending offer → admins; review decision → author
-- ---------------------------------------------------------------------------
create or replace function public.notify_forum_job_offer_submitted()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  begin
    if new.post_kind = 'job_offer' and new.review_status = 'pending' then
      perform public.enqueue_notifications(
        array(
          select a
          from unnest(public.notification_admin_ids()) a
          where a is distinct from new.author_uid
        ),
        'forum',
        'Job offer awaiting review',
        coalesce(nullif(trim(new.author_name), ''), 'An alumnus')
          || ' submitted "'
          || left(coalesce(new.title, 'a job offer'), 80)
          || '" for community review.',
        jsonb_build_object(
          'relatedId', new.id::text,
          'topicId', new.id::text,
          'target', 'forum_job_offer'
        ),
        'normal',
        'forum_job_offer:' || new.id::text || ':submitted',
        'admin/forum',
        false
      );
    end if;
  exception when others then
    raise warning 'notify_forum_job_offer_submitted(%): %', new.id, sqlerrm;
  end;
  return new;
end;
$$;

drop trigger if exists trg_notify_forum_job_offer_submitted on public.forum_topics;
create trigger trg_notify_forum_job_offer_submitted
after insert on public.forum_topics
for each row execute function public.notify_forum_job_offer_submitted();

create or replace function public.notify_forum_job_offer_reviewed()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  payload jsonb := jsonb_build_object(
    'relatedId', new.id::text,
    'topicId', new.id::text,
    'target', 'forum_job_offer'
  );
  route text := 'forum/' || new.id::text;
  stamp text := to_char(now(), 'YYYYMMDDHH24MI');
  reason text := nullif(trim(coalesce(new.decline_reason, '')), '');
begin
  begin
    if new.post_kind <> 'job_offer' then
      return new;
    end if;
    if new.review_status is not distinct from old.review_status then
      return new;
    end if;

    if new.review_status = 'approved' and old.review_status in ('pending', 'declined') then
      perform public.enqueue_notifications(
        array[new.author_uid],
        'forum',
        'Your job offer was approved',
        '"' || left(coalesce(new.title, 'Your job offer'), 80)
          || '" is now visible in the community forum.',
        payload,
        'normal',
        'forum_job_offer:' || new.id::text || ':approved:' || stamp,
        route,
        false
      );
    elsif new.review_status = 'declined' and old.review_status = 'pending' then
      perform public.enqueue_notifications(
        array[new.author_uid],
        'forum',
        'Your job offer needs changes',
        '"' || left(coalesce(new.title, 'Your job offer'), 80)
          || '" was not approved.'
          || coalesce(' Reason: ' || reason, ''),
        payload,
        'normal',
        'forum_job_offer:' || new.id::text || ':declined:' || stamp,
        route,
        false
      );
    elsif new.review_status = 'pending' and old.review_status = 'declined' then
      -- Resubmit → notify admins again
      perform public.enqueue_notifications(
        array(
          select a
          from unnest(public.notification_admin_ids()) a
          where a is distinct from new.author_uid
        ),
        'forum',
        'Job offer resubmitted',
        coalesce(nullif(trim(new.author_name), ''), 'An alumnus')
          || ' resubmitted "'
          || left(coalesce(new.title, 'a job offer'), 80)
          || '" for review.',
        jsonb_build_object(
          'relatedId', new.id::text,
          'topicId', new.id::text,
          'target', 'forum_job_offer'
        ),
        'normal',
        'forum_job_offer:' || new.id::text || ':resubmitted:' || stamp,
        'admin/forum',
        false
      );
    end if;
  exception when others then
    raise warning 'notify_forum_job_offer_reviewed(%): %', new.id, sqlerrm;
  end;
  return new;
end;
$$;

drop trigger if exists trg_notify_forum_job_offer_reviewed on public.forum_topics;
create trigger trg_notify_forum_job_offer_reviewed
after update of review_status on public.forum_topics
for each row execute function public.notify_forum_job_offer_reviewed();

commit;
