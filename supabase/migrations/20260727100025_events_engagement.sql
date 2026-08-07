-- Events engagement upgrade: cover, category, capacity, agenda, RSVP, views, cancel.

alter table public.events
  add column if not exists cover_image_url text not null default '',
  add column if not exists category text not null default 'Other',
  add column if not exists capacity integer,
  add column if not exists registration_deadline timestamptz,
  add column if not exists agenda jsonb not null default '[]'::jsonb,
  add column if not exists views_count integer not null default 0,
  add column if not exists cancelled boolean not null default false;

create table if not exists public.event_rsvps (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  status text not null check (status in ('going', 'interested', 'cant_attend')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (event_id, user_id)
);

create index if not exists event_rsvps_event_id_idx on public.event_rsvps (event_id);
create index if not exists event_rsvps_user_id_idx on public.event_rsvps (user_id);
create index if not exists event_rsvps_status_idx on public.event_rsvps (event_id, status);
create index if not exists events_category_idx on public.events (category);
create index if not exists events_date_status_idx on public.events (date, status);

alter table public.event_rsvps enable row level security;

create policy "event_rsvps_select_signed_in"
on public.event_rsvps
for select
to authenticated
using (public.is_signed_in());

create policy "event_rsvps_insert_own"
on public.event_rsvps
for insert
to authenticated
with check (user_id = auth.uid());

create policy "event_rsvps_update_own"
on public.event_rsvps
for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

create policy "event_rsvps_delete_own"
on public.event_rsvps
for delete
to authenticated
using (user_id = auth.uid());

create policy "event_rsvps_admin_all"
on public.event_rsvps
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());
