-- Instant decline for community job offers:
-- no required revision note; declined offers are final (withdraw only for authors).

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
    if t.review_status <> 'pending' then
      raise exception 'only pending job offers can be declined';
    end if;
    if reason is not null and char_length(reason) > 500 then
      raise exception 'decline reason is too long';
    end if;
    update public.forum_topics
    set
      review_status = 'declined',
      is_locked = true,
      decline_reason = coalesce(reason, ''),
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

  -- Service / system paths that only bump counters.
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

  -- Job-offer authors may edit content while pending, or withdraw pending/declined.
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
    elsif old.review_status = 'pending' then
      if new.review_status is distinct from old.review_status
         and new.review_status <> 'withdrawn' then
        raise exception 'authors can only withdraw or keep pending';
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
    elsif old.review_status = 'declined' then
      if new.review_status is distinct from old.review_status
         and new.review_status <> 'withdrawn' then
        raise exception 'declined job offers cannot be resubmitted';
      end if;
      if new.title is distinct from old.title
         or new.body is distinct from old.body
         or new.purpose_letter is distinct from old.purpose_letter
         or new.cover_image_url is distinct from old.cover_image_url
         or new.company_name is distinct from old.company_name
         or new.apply_url is distinct from old.apply_url
         or new.edited_at is distinct from old.edited_at
      then
        raise exception 'declined job offers cannot be edited';
      end if;
      if new.review_status = 'withdrawn' then
        new.is_locked := true;
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
        'Your job offer was declined',
        '"' || left(coalesce(new.title, 'Your job offer'), 80)
          || '" was not approved and will not appear in the community feed. '
          || 'A community admin may message you if you should submit a new offer.',
        payload,
        'normal',
        'forum_job_offer:' || new.id::text || ':declined:' || stamp,
        route,
        false
      );
    end if;
  exception when others then
    raise warning 'notify_forum_job_offer_reviewed(%): %', new.id, sqlerrm;
  end;
  return new;
end;
$$;
