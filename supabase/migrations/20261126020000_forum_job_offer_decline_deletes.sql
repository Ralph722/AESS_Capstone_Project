-- Decline permanently removes the job offer (no declined status / revision loop).

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
  stamp text := to_char(now(), 'YYYYMMDDHH24MI');
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

  if p_approve then
    if t.review_status <> 'pending' then
      raise exception 'only pending job offers can be approved';
    end if;
    update public.forum_topics
    set
      review_status = 'approved',
      is_locked = false,
      decline_reason = '',
      reviewed_at = now(),
      reviewed_by = auth.uid(),
      updated_at = now()
    where id = p_topic_id;

    insert into public.forum_moderation_events (topic_id, actor_uid, action, reason)
    values (p_topic_id, auth.uid(), 'job_offer_approved', null);
  else
    if t.review_status <> 'pending' then
      raise exception 'only pending job offers can be declined';
    end if;
    if reason is not null and char_length(reason) > 500 then
      raise exception 'decline reason is too long';
    end if;

    -- Notify author before delete so the row still exists for context.
    begin
      perform public.enqueue_notifications(
        array[t.author_uid],
        'forum',
        'Your job offer was declined',
        '"' || left(coalesce(t.title, 'Your job offer'), 80)
          || '" was not approved and has been removed. '
          || 'A community admin may message you if you should submit a new offer.',
        jsonb_build_object(
          'relatedId', t.id::text,
          'topicId', t.id::text,
          'target', 'forum_job_offer'
        ),
        'normal',
        'forum_job_offer:' || t.id::text || ':declined:' || stamp,
        'forum',
        false
      );
    exception when others then
      raise warning 'review_forum_job_offer notify(%): %', t.id, sqlerrm;
    end;

    insert into public.forum_moderation_events (topic_id, actor_uid, action, reason)
    values (p_topic_id, auth.uid(), 'job_offer_declined', reason);

    delete from public.forum_topics where id = p_topic_id;
  end if;
end;
$$;

revoke all on function public.review_forum_job_offer(uuid, boolean, text)
  from public, anon;
grant execute on function public.review_forum_job_offer(uuid, boolean, text)
  to authenticated;

-- Remove leftover declined offers from the old revision flow.
delete from public.forum_topics
where post_kind = 'job_offer'
  and review_status = 'declined';
