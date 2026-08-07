-- Enable Realtime for admin/alumni live Events updates.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'events'
  ) then
    alter publication supabase_realtime add table public.events;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'event_rsvps'
  ) then
    alter publication supabase_realtime add table public.event_rsvps;
  end if;
end $$;

alter table public.events replica identity full;
alter table public.event_rsvps replica identity full;
