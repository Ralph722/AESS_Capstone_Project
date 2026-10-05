select table_name tbl, grantee,
  string_agg(privilege_type, ', ' order by privilege_type) privileges
from information_schema.role_table_grants
where table_schema = 'public' and grantee in ('anon', 'authenticated')
group by table_name, grantee
order by 1, 2;
