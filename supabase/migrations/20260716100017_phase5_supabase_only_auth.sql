-- Phase 5: Supabase-only factory cutover helpers.
-- Auto-create public.users on auth signup; allow profile self-updates.

begin;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.users (
    id,
    email,
    display_name,
    role
  ) values (
    new.id,
    coalesce(new.email, ''),
    coalesce(new.raw_user_meta_data->>'display_name', ''),
    'user'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Allow authenticated users to update their own profile fields while keeping role.
drop policy if exists "users_update_self_user_role" on public.users;
create policy "users_update_self_user_role"
on public.users
for update
to authenticated
using (id = auth.uid() or public.is_admin())
with check (
  (id = auth.uid() and role = 'user')
  or public.is_admin()
);

-- Admins can insert/update any user row (e.g. promote admin after seed).
drop policy if exists "users_admin_write" on public.users;
create policy "users_admin_write"
on public.users
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

commit;
