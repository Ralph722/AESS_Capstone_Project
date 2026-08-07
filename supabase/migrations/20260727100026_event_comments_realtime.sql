-- Enable Realtime for event comments and replies (alumni comments UI).
alter table public.event_comments replica identity full;
alter table public.event_replies replica identity full;

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'event_comments'
  ) then
    alter publication supabase_realtime add table public.event_comments;
  end if;

  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'event_replies'
  ) then
    alter publication supabase_realtime add table public.event_replies;
  end if;
end $$;
