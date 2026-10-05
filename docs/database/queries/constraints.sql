select conrelid::regclass::text tbl, conname, contype, pg_get_constraintdef(oid) def
from pg_constraint
where connamespace='public'::regnamespace and contype in ('p','f','u','c','x')
order by 1, contype, conname;
