-- Phase 1 security: stop alumni SELECT of every admin users row (emails, etc.).
-- Messaging still works via SECURITY DEFINER helpers + insert policy that does
-- not rely on being able to read admin rows under RLS.
-- Profile/avatar enrichment continues to use existing get_public_profiles().

begin;

-- True when p_id is an admin account (bypasses users RLS for policy checks).
create or replace function public.is_admin_user(p_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.users u
    where u.id = p_id
      and u.role = 'admin'
  );
$$;

revoke all on function public.is_admin_user(uuid) from public;
grant execute on function public.is_admin_user(uuid) to authenticated;

-- Lean admin directory for alumni support routing (no email).
create or replace function public.list_support_admins()
returns table (
  id uuid,
  display_name text,
  profile_image_base64 text
)
language sql
stable
security definer
set search_path = public
as $$
  select
    u.id,
    coalesce(nullif(trim(u.display_name), ''), 'Admin') as display_name,
    u.profile_image_base64
  from public.users u
  where u.role = 'admin'
  order by u.created_at nulls last, u.id
  limit 50;
$$;

revoke all on function public.list_support_admins() from public;
grant execute on function public.list_support_admins() to authenticated;

-- Alumni message inserts must not depend on SELECT-ing admin rows.
alter policy messages_insert_participant on public.messages
  with check (
    (sender_id = (select auth.uid()))
    and (
      (select public.is_admin())
      or public.is_admin_user(recipient_id)
    )
  );

-- Own row or admin reader only — no more "any admin row is public to alumni".
alter policy users_select_owner_admin_or_admin_target on public.users
  using (
    (select public.is_signed_in())
    and (
      id = (select auth.uid())
      or (select public.is_admin())
    )
  );

commit;
