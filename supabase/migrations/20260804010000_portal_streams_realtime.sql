-- Enable Realtime for alumni portal watch streams that previously only
-- used .stream() without publication membership (announcements, feedback,
-- survey_assignments). Safe to re-run.

alter table public.announcements replica identity full;
alter table public.feedback replica identity full;
alter table public.survey_assignments replica identity full;

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'announcements'
  ) then
    alter publication supabase_realtime add table public.announcements;
  end if;

  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'feedback'
  ) then
    alter publication supabase_realtime add table public.feedback;
  end if;

  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'survey_assignments'
  ) then
    alter publication supabase_realtime add table public.survey_assignments;
  end if;
end $$;
