-- Phase 8: fixes from the validation pass.
--
-- 1. Deactivated callers are denied everywhere. Deactivation bans the auth
--    user and revokes sessions, but an access token that was already issued
--    stays valid until it expires (up to an hour). A restrictive policy on
--    every public table and on storage.objects closes that window.
-- 2. Drop alumni_members.employment_status. Employment comes from CHED GTS
--    answers (gts_employment_records) and nothing writes the column.

-- ---------------------------------------------------------------------------
-- 1. Deactivated callers
-- ---------------------------------------------------------------------------

create or replace function public.caller_is_active()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select not exists (
    select 1
    from public.users u
    where u.id = auth.uid()
      and u.deactivated_at is not null
  );
$$;

revoke all on function public.caller_is_active() from public, anon;
grant execute on function public.caller_is_active() to authenticated, service_role;

-- New tables must add the same policy.
do $$
declare
  r record;
begin
  for r in
    select c.relname
    from pg_class c
    where c.relnamespace = 'public'::regnamespace
      and c.relkind = 'r'
      and c.relrowsecurity
  loop
    execute format('drop policy if exists active_caller_only on public.%I', r.relname);
    execute format(
      'create policy active_caller_only on public.%I as restrictive for all to authenticated '
      'using ((select public.caller_is_active())) with check ((select public.caller_is_active()))',
      r.relname);
  end loop;
end $$;

drop policy if exists active_caller_only on storage.objects;
create policy active_caller_only
  on storage.objects as restrictive for all to authenticated
  using ((select public.caller_is_active()))
  with check ((select public.caller_is_active()));

-- ---------------------------------------------------------------------------
-- 2. Roster employment mirror
-- ---------------------------------------------------------------------------

alter table public.alumni_members drop column if exists employment_status;
