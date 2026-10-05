select c.relname tbl, i.relname idx,
  case when x.indisprimary then 'PK' when x.indisunique then 'UNIQUE' else '' end kind,
  regexp_replace(pg_get_indexdef(x.indexrelid), '^CREATE (UNIQUE )?INDEX \S+ ON public\.\S+ USING ', '') def
from pg_index x
join pg_class i on i.oid = x.indexrelid
join pg_class c on c.oid = x.indrelid
where c.relnamespace = 'public'::regnamespace
order by 1, 2;
