select c.relnamespace::regnamespace::text sch, c.relname::text tbl, t.tgname::text trg,
  regexp_replace(pg_get_triggerdef(t.oid), '^CREATE (CONSTRAINT )?TRIGGER \S+ ', '') def
from pg_trigger t join pg_class c on c.oid=t.tgrelid
where not t.tgisinternal and c.relnamespace in ('public'::regnamespace, 'auth'::regnamespace)
order by 1, 2, 3;
