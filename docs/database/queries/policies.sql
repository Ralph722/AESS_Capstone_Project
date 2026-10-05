select schemaname||'.'||tablename tbl, policyname, cmd, array_to_string(roles,',') roles, permissive,
  regexp_replace(coalesce(qual,''),'\s+',' ','g') using_expr,
  regexp_replace(coalesce(with_check,''),'\s+',' ','g') check_expr
from pg_policies where schemaname in ('public','storage') order by 1, cmd, policyname;
