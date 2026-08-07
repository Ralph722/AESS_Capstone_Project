-- Part 8: admin inbox summaries without full-table client aggregation.
-- Returns one row per alumni conversation; never returns image blobs.

begin;

create or replace function public.admin_conversation_inbox()
returns table (
  messaging_id text,
  last_message text,
  last_message_time timestamptz,
  last_message_from_role text,
  sender_name text,
  sender_email text,
  has_unread boolean,
  waiting_since timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'admin_conversation_inbox: admin only';
  end if;

  return query
  with admin_ids as (
    select u.id::text as id
    from public.users u
    where u.role = 'admin'
  ),
  tagged as (
    select
      m.sender_id::text as sender_id,
      m.recipient_id::text as recipient_id,
      lower(coalesce(m.sender_role, '')) as sender_role,
      coalesce(m.sender_name, '') as sender_name,
      coalesce(m.sender_email, '') as sender_email,
      coalesce(m.body, '') as body,
      coalesce(m.image_base64, '') as image_ref,
      m.is_read,
      m.created_at,
      case
        when lower(coalesce(m.sender_role, '')) = 'user'
          then m.sender_id::text
        when lower(coalesce(m.sender_role, '')) = 'admin'
             and m.recipient_id::text not in (select a.id from admin_ids a)
          then m.recipient_id::text
        else null
      end as peer_id
    from public.messages m
  ),
  peers as (
    select *
    from tagged
    where peer_id is not null and peer_id <> ''
  ),
  latest as (
    select distinct on (p.peer_id)
      p.peer_id,
      case
        when nullif(trim(p.body), '') is not null then left(trim(p.body), 200)
        when nullif(trim(p.image_ref), '') is not null then 'Sent an image'
        else ''
      end as preview,
      p.created_at as msg_time,
      p.sender_role as from_role,
      p.sender_name as from_name,
      p.sender_email as from_email
    from peers p
    order by p.peer_id, p.created_at desc
  ),
  unread as (
    select
      m.sender_id::text as peer_id,
      true as unread,
      min(m.created_at) as first_unread_at
    from public.messages m
    where lower(coalesce(m.sender_role, '')) = 'user'
      and m.is_read = false
    group by m.sender_id
  )
  select
    l.peer_id,
    l.preview,
    l.msg_time,
    l.from_role,
    l.from_name,
    l.from_email,
    coalesce(u.unread, false),
    u.first_unread_at
  from latest l
  left join unread u on u.peer_id = l.peer_id
  order by l.msg_time desc nulls last;
end;
$$;

revoke all on function public.admin_conversation_inbox() from public;
grant execute on function public.admin_conversation_inbox() to authenticated;

commit;
