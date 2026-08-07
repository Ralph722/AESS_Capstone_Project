-- Jobs redesign: interest roster + (logos use existing admin storage policies).

create table if not exists public.job_interests (
  user_id uuid not null references auth.users(id) on delete cascade,
  job_id uuid not null references public.jobs(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, job_id)
);

create index if not exists idx_job_interests_job_id
  on public.job_interests(job_id, created_at desc);

alter table public.job_interests enable row level security;

drop policy if exists "job_interests_select_own_or_admin" on public.job_interests;
create policy "job_interests_select_own_or_admin"
on public.job_interests
for select
to authenticated
using (public.is_admin() or user_id = auth.uid());

drop policy if exists "job_interests_insert_own" on public.job_interests;
create policy "job_interests_insert_own"
on public.job_interests
for insert
to authenticated
with check (user_id = auth.uid());

drop policy if exists "job_interests_delete_own" on public.job_interests;
create policy "job_interests_delete_own"
on public.job_interests
for delete
to authenticated
using (user_id = auth.uid());

drop policy if exists "job_interests_admin_delete" on public.job_interests;
create policy "job_interests_admin_delete"
on public.job_interests
for delete
to authenticated
using (public.is_admin());
