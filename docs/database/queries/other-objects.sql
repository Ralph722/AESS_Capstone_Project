select 'enum' kind, t.typname name, string_agg(e.enumlabel, ', ' order by e.enumsortorder) detail
from pg_type t join pg_enum e on e.enumtypid=t.oid where t.typnamespace='public'::regnamespace group by t.typname
union all
select case c.relkind when 'v' then 'view' else 'matview' end, c.relname, regexp_replace(pg_get_viewdef(c.oid),'\s+',' ','g')
from pg_class c where c.relnamespace='public'::regnamespace and c.relkind in ('v','m')
union all
select 'rls', c.relname, 'enabled=' || c.relrowsecurity || ', forced=' || c.relforcerowsecurity
from pg_class c where c.relnamespace='public'::regnamespace and c.relkind='r'
union all
select 'realtime', schemaname||'.'||tablename, '' from pg_publication_tables where pubname='supabase_realtime'
union all
select 'bucket', id, 'public=' || public || ', size_limit=' || coalesce(file_size_limit::text,'none') || ', mime=' || coalesce(array_to_string(allowed_mime_types,' '),'any') from storage.buckets
union all
select 'extension', extname, extversion from pg_extension
union all
select 'cron', jobname, schedule || case when active then '' else ' (inactive)' end from cron.job
order by 1, 2;
