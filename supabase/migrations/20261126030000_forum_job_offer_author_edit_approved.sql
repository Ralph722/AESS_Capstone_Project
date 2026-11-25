-- Allow job-offer authors to edit approved posts (content + visibility).

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
     or new.post_kind is distinct from old.post_kind
     or new.decline_reason is distinct from old.decline_reason
     or new.reviewed_at is distinct from old.reviewed_at
     or new.reviewed_by is distinct from old.reviewed_by
  then
    raise exception 'authors cannot change moderation fields';
  end if;

  -- Job-offer authors may change visibility; discussion authors may not.
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
      if new.title is distinct from old.title
         or new.body is distinct from old.body
         or new.purpose_letter is distinct from old.purpose_letter
         or new.cover_image_url is distinct from old.cover_image_url
         or new.company_name is distinct from old.company_name
         or new.apply_url is distinct from old.apply_url
         or new.visibility is distinct from old.visibility
      then
        new.edited_at := now();
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
         or new.visibility is distinct from old.visibility
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
