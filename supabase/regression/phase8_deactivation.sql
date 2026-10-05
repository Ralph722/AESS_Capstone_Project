begin;
-- A = 6f6c569a-9ded-4c90-acab-19d78ab2a3f3, B = dfdf41bb-e201-4446-abee-e6b6ac67d82b, admin = 8a845be5-5870-437f-95e6-7ea3b0ad7a06
-- Returns "select/update/delete/foreign": rows visible, rows updatable, rows
-- deletable (both rolled back), and visible rows not owned by the caller.
create function pg_temp.probe(p_role text, p_uid text, p_rel regclass) returns text
language plpgsql as $$
declare
  n_sel bigint; n_upd text; n_del text; n_for text := '-';
  v_col text; v_owner text; n bigint; v_kind char;
begin
  select relkind into v_kind from pg_class where oid = p_rel;
  select string_agg(format('%I::text is distinct from %L', attname, coalesce(p_uid, '')), ' and ')
  into v_owner
  from pg_attribute
  where attrelid = p_rel and attnum > 0 and not attisdropped
    and attname in ('user_id', 'author_uid', 'auth_uid', 'sender_id', 'recipient_id', 'reporter_uid', 'created_by');
  if p_rel = 'public.users'::regclass then v_owner := format('id::text is distinct from %L', coalesce(p_uid, '')); end if;
  select attname into v_col from pg_attribute
  where attrelid = p_rel and attnum > 0 and not attisdropped
    and has_column_privilege(p_role, p_rel, attnum, 'UPDATE')
  order by (attname = 'updated_at') desc, attnum limit 1;

  perform set_config('request.jwt.claims',
    case when p_uid is null then json_build_object('role', p_role)::text
         else json_build_object('role', p_role, 'sub', p_uid, 'email',
           (select email from auth.users where id = p_uid::uuid))::text end, true);
  execute format('set local role %I', p_role);

  begin
    execute format('select count(*) from %s', p_rel) into n_sel;
    if v_owner is not null then
      execute format('select count(*) from %s where %s', p_rel, v_owner) into n;
      n_for := n::text;
    end if;
  exception when others then
    n_sel := null;
    n_for := '-';
  end;

  if v_kind <> 'r' then
    n_upd := 'view'; n_del := 'view';
  else
    if v_col is null then
      n_upd := 'x';
    else
      begin
        execute format('with u as (update %s set %I = %I returning 1) select count(*) from u', p_rel, v_col, v_col) into n;
        raise exception using message = '__rollback__';
      exception when others then
        n_upd := case when sqlerrm = '__rollback__' then n::text
                      when sqlerrm like 'permission denied%' then 'x'
                      else 'E:' || left(sqlerrm, 40) end;
      end;
    end if;
    begin
      execute format('with d as (delete from %s returning 1) select count(*) from d', p_rel) into n;
      raise exception using message = '__rollback__';
    exception when others then
      n_del := case when sqlerrm = '__rollback__' then n::text
                    when sqlerrm like 'permission denied%' then 'x'
                    else 'E:' || left(sqlerrm, 40) end;
    end;
  end if;

  reset role;
  perform set_config('request.jwt.claims', '', true);
  return coalesce(n_sel::text, 'x') || '/' || n_upd || '/' || n_del || '/' || n_for;
end $$;

create temp table rels as
select c.oid::regclass as rel, c.relname
from pg_class c
where c.relnamespace = 'public'::regnamespace and c.relkind in ('r', 'v')
union all select 'storage.objects'::regclass, 'storage.objects';

create temp table m as
select relname,
  (select count(*) from pg_class where false) as total,
  pg_temp.probe('anon', null, rel) as anon,
  pg_temp.probe('authenticated', '6f6c569a-9ded-4c90-acab-19d78ab2a3f3', rel) as alum_a,
  pg_temp.probe('authenticated', 'dfdf41bb-e201-4446-abee-e6b6ac67d82b', rel) as alum_b,
  ''::text as deact_b,
  ''::text as react_b,
  pg_temp.probe('authenticated', '8a845be5-5870-437f-95e6-7ea3b0ad7a06', rel) as admin,
  rel
from rels;

update public.users set deactivated_at = now() where id = 'dfdf41bb-e201-4446-abee-e6b6ac67d82b';
update public.alumni_members set is_deactivated = true where auth_uid = 'dfdf41bb-e201-4446-abee-e6b6ac67d82b';
update m set deact_b = pg_temp.probe('authenticated', 'dfdf41bb-e201-4446-abee-e6b6ac67d82b', rel);

create function pg_temp.cnt(p_rel regclass) returns bigint language plpgsql as $$
declare n bigint; begin execute format('select count(*) from %s', p_rel) into n; return n; end $$;
update m set total = pg_temp.cnt(rel);
update public.users set deactivated_at = null where id = 'dfdf41bb-e201-4446-abee-e6b6ac67d82b';
update public.alumni_members set is_deactivated = false where auth_uid = 'dfdf41bb-e201-4446-abee-e6b6ac67d82b';
update m set react_b = pg_temp.probe('authenticated', 'dfdf41bb-e201-4446-abee-e6b6ac67d82b', rel);

-- Pass/fail only, so the output does not change as live row counts grow.
-- Storage rejects direct deletes with its own error, which also counts as blocked.
select relname as rel,
  case when split_part(deact_b, '/', 1) in ('0', 'x')
        and split_part(deact_b, '/', 2) in ('0', 'x', 'view')
        and (split_part(deact_b, '/', 3) in ('0', 'x', 'view') or split_part(deact_b, '/', 3) like 'E:Direct deletion%')
       then 'blocked' else 'OPEN: ' || deact_b end as deactivated_user,
  case when react_b = alum_b then 'same as before' else 'DIFF: ' || react_b || ' vs ' || alum_b end as after_reactivation
from m
union all select '~ policies named active_caller_only',
  case when (select count(*) from pg_policy where polname = 'active_caller_only')
          = (select count(*) from pg_class c where c.relnamespace = 'public'::regnamespace and c.relkind = 'r' and c.relrowsecurity) + 1
       then 'one per RLS table + storage' else 'MISSING' end, ''
union all select '~ roster employment_status column',
  (select case when count(*) = 0 then 'dropped' else 'STILL PRESENT' end from information_schema.columns
   where table_schema = 'public' and table_name = 'alumni_members' and column_name = 'employment_status'), ''
union all select '~ anon can execute caller_is_active',
  case when has_function_privilege('anon', 'public.caller_is_active()', 'execute') then 'YES' else 'no' end, ''
order by 1;
rollback;
