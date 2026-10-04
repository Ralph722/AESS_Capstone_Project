-- Notifications hardening: drop default EXECUTE grants that clients never need.
--
-- Trigger functions cannot be called directly and PostgreSQL checks EXECUTE
-- only when a trigger is created, so revoking them does not affect firing.
-- notify_forum_mentions stays callable by signed-in users (it verifies the
-- caller is the post author); anonymous callers lose access.

begin;

do $$
declare
  fn record;
begin
  for fn in
    select p.oid::regprocedure as sig
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname like 'notify\_%'
      and p.prorettype = 'trigger'::regtype
  loop
    execute format('revoke execute on function %s from public, anon, authenticated', fn.sig);
  end loop;
end;
$$;

revoke execute on function public.notify_forum_mentions(uuid, uuid[]) from public, anon;
grant execute on function public.notify_forum_mentions(uuid, uuid[]) to authenticated;

commit;
