select p.proname fn, pg_get_function_identity_arguments(p.oid) args, pg_get_function_result(p.oid) ret,
  case when p.prosecdef then 'definer' else 'invoker' end sec,
  coalesce(array_to_string(p.proconfig,'; '),'') cfg,
  has_function_privilege('anon', p.oid, 'EXECUTE') anon_exec,
  has_function_privilege('authenticated', p.oid, 'EXECUTE') auth_exec,
  l.lanname lang
from pg_proc p join pg_language l on l.oid=p.prolang
where p.pronamespace='public'::regnamespace and p.prokind='f'
order by 1, 2;
