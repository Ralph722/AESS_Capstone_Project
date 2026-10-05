begin;
create function pg_temp.try_as(p_role text, p_uid text, p_sql text) returns text
language plpgsql as $$
declare r text;
begin
  perform set_config(
    'request.jwt.claims',
    case when p_uid is null then json_build_object('role', p_role)::text
         else json_build_object('role', p_role, 'sub', p_uid, 'email',
           (select email from auth.users where id = p_uid::uuid))::text end,
    true
  );
  execute format('set local role %I', p_role);
  begin
    if p_sql ~* '^\s*(insert|update|delete)' then execute p_sql; r := 'ok'; else execute p_sql into r; end if;
  exception when others then
    r := 'ERROR: ' || sqlerrm;
  end;
  reset role;
  perform set_config('request.jwt.claims', '', true);
  return coalesce(r, '(null)');
end $$;

create function pg_temp.try_raw(p_sql text) returns text
language plpgsql as $$
begin
  execute p_sql;
  return 'ok';
exception when others then
  return 'ERROR: ' || sqlerrm;
end $$;

create temp table t(n int, test text, expected text, actual text);
create temp table exp as
select
  (select count(*) from public.user_notifications where user_id = '6f6c569a-9ded-4c90-acab-19d78ab2a3f3') as a_notifs,
  (select count(*) from public.user_notifications where user_id = '8a845be5-5870-437f-95e6-7ea3b0ad7a06') as admin_notifs;

-- ===== Phase 6 tests =====
-- A = 6f6c569a-9ded-4c90-acab-19d78ab2a3f3, B = dfdf41bb-e201-4446-abee-e6b6ac67d82b, admin = 8a845be5-5870-437f-95e6-7ea3b0ad7a06
insert into t select 1, 'alumnus cannot create own notification', 'blocked',
  pg_temp.try_as('authenticated', '6f6c569a-9ded-4c90-acab-19d78ab2a3f3',
    $q$insert into public.user_notifications (user_id, title, body, type) values ('6f6c569a-9ded-4c90-acab-19d78ab2a3f3', 'x', 'x', 'system')$q$);
insert into t select 2, 'admin cannot insert notifications directly', 'blocked',
  pg_temp.try_as('authenticated', '8a845be5-5870-437f-95e6-7ea3b0ad7a06',
    $q$insert into public.user_notifications (user_id, title, body, type) values ('6f6c569a-9ded-4c90-acab-19d78ab2a3f3', 'x', 'x', 'system')$q$);
insert into t select 3, 'anon cannot read notifications', 'permission denied',
  pg_temp.try_as('anon', null, 'select count(*)::text from public.user_notifications');
insert into t select 4, 'alumnus still reads own notifications', 'all own rows',
  case when pg_temp.try_as('authenticated', '6f6c569a-9ded-4c90-acab-19d78ab2a3f3', 'select count(*)::text from public.user_notifications')
          = (select a_notifs::text from exp)
       then 'all own rows' else 'MISMATCH' end;
insert into t select 5, 'alumnus can mark own notifications read (as the app does)', 'ok, all read',
  pg_temp.try_as('authenticated', '6f6c569a-9ded-4c90-acab-19d78ab2a3f3',
    $q$update public.user_notifications set is_read = true, updated_at = now() where user_id = '6f6c569a-9ded-4c90-acab-19d78ab2a3f3'$q$);
update t set actual = actual
  || case when exists (select 1 from public.user_notifications where user_id = '6f6c569a-9ded-4c90-acab-19d78ab2a3f3' and not is_read)
       then ', NOT all read' else ', all read' end
where n = 5;
insert into t select 6, 'alumnus B cannot touch A''s notifications', '0 changed',
  (select pg_temp.try_as('authenticated', 'dfdf41bb-e201-4446-abee-e6b6ac67d82b',
     $q$delete from public.user_notifications where user_id = '6f6c569a-9ded-4c90-acab-19d78ab2a3f3'$q$)
   || '/' || (select count(*) from public.user_notifications where user_id = '6f6c569a-9ded-4c90-acab-19d78ab2a3f3'));
update t set actual = case when actual = 'ok/' || (select a_notifs from exp) then '0 changed' else actual end where n = 6;
insert into t select 7, 'server trigger still notifies (message A -> admin)', 'ok, +1 for admin',
  pg_temp.try_as('authenticated', '6f6c569a-9ded-4c90-acab-19d78ab2a3f3',
    $q$insert into public.messages (sender_id, recipient_id, body) values ('6f6c569a-9ded-4c90-acab-19d78ab2a3f3', '8a845be5-5870-437f-95e6-7ea3b0ad7a06', 'phase 6 test')$q$);
update t set actual = actual || ', +' || ((select count(*) from public.user_notifications where user_id = '8a845be5-5870-437f-95e6-7ea3b0ad7a06') - (select admin_notifs from exp)) || ' for admin' where n = 7;
insert into t select 8, 'notify_new_message dropped', 'gone',
  case when exists (select 1 from pg_proc where proname = 'notify_new_message') then 'still there' else 'gone' end;
insert into t select 9, 'delivery table renamed', 'notification_deliveries',
  case when to_regclass('public.notification_push_deliveries') is null then coalesce(to_regclass('public.notification_deliveries')::text, 'missing') else 'old name still there' end;

-- push pipeline on the renamed table
insert into public.push_tokens (id, user_id, provider, platform, token)
values ('00000000-0000-4000-8000-000000000601', '6f6c569a-9ded-4c90-acab-19d78ab2a3f3', 'fcm', 'android', 'phase6-test-token');
insert into public.user_notifications (id, user_id, title, body, type, priority)
values ('00000000-0000-4000-8000-000000000602', '6f6c569a-9ded-4c90-acab-19d78ab2a3f3', 'Phase 6', 'push test', 'system', 'urgent');
insert into t select 10, 'new notification queues push deliveries (one per device, incl. test token)', 'push only, test token included',
  (select case when bool_and(channel = 'push') and bool_or(token_id = '00000000-0000-4000-8000-000000000601')
     then 'push only, test token included' else coalesce(string_agg(channel, ','), 'none') end
   from public.notification_deliveries where notification_id = '00000000-0000-4000-8000-000000000602');
insert into public.notification_deliveries (id, channel, recipient, status, scheduled_at)
values ('00000000-0000-4000-8000-000000000603', 'email', 'someone@example.com', 'queued', now() - interval '1 minute');
set local role service_role;
create temp table claimed as select * from public.claim_push_deliveries(500);
reset role;
insert into t select 11, 'push claim returns the push row, never email rows', 'push claimed, email untouched',
  case when exists (select 1 from claimed c join public.notification_deliveries d on d.id = c.delivery_id where d.notification_id = '00000000-0000-4000-8000-000000000602')
        and not exists (select 1 from claimed where delivery_id = '00000000-0000-4000-8000-000000000603')
        and (select status from public.notification_deliveries where id = '00000000-0000-4000-8000-000000000603') = 'queued'
    then 'push claimed, email untouched' else 'WRONG' end;
set local role service_role;
select public.complete_push_deliveries(
  (select jsonb_agg(jsonb_build_object('id', delivery_id, 'ok', true)) from claimed)
  || jsonb_build_array(jsonb_build_object('id', '00000000-0000-4000-8000-000000000603', 'ok', true)));
reset role;
insert into t select 12, 'complete marks push sent, ignores email rows', 'sent/queued',
  (select string_agg(distinct status, ',') from public.notification_deliveries where notification_id = '00000000-0000-4000-8000-000000000602')
  || '/' || (select status from public.notification_deliveries where id = '00000000-0000-4000-8000-000000000603');

insert into t select 13, 'email row needs a recipient', 'check violation',
  pg_temp.try_raw($q$insert into public.notification_deliveries (channel, status) values ('email', 'sent')$q$);
insert into t select 14, 'push row needs a token', 'check violation',
  pg_temp.try_raw($q$insert into public.notification_deliveries (channel, user_id, notification_id) values ('push', '6f6c569a-9ded-4c90-acab-19d78ab2a3f3', '00000000-0000-4000-8000-000000000602')$q$);
insert into t select 15, 'unknown channel rejected', 'check violation',
  pg_temp.try_raw($q$insert into public.notification_deliveries (channel, recipient) values ('fax', 'x')$q$);
insert into t select 16, 'sms row accepted (reserved channel)', 'ok',
  pg_temp.try_raw($q$insert into public.notification_deliveries (channel, recipient, status) values ('sms', '+639000000000', 'skipped')$q$);

insert into t select 17, 'admin reads delivery log', '>= 3',
  (select case when r ~ '^\d+$' and r::int >= 3 then '>= 3' else r end
   from pg_temp.try_as('authenticated', '8a845be5-5870-437f-95e6-7ea3b0ad7a06', 'select count(*)::text from public.notification_deliveries') r);
insert into t select 18, 'alumnus sees no delivery rows', '0',
  pg_temp.try_as('authenticated', '6f6c569a-9ded-4c90-acab-19d78ab2a3f3', 'select count(*)::text from public.notification_deliveries');
insert into t select 19, 'admin cannot write delivery log', 'permission denied',
  pg_temp.try_as('authenticated', '8a845be5-5870-437f-95e6-7ea3b0ad7a06',
    $q$insert into public.notification_deliveries (channel, recipient) values ('email', 'x@example.com')$q$);
insert into t select 20, 'anon cannot read delivery log', 'permission denied',
  pg_temp.try_as('anon', null, 'select count(*)::text from public.notification_deliveries');
insert into t select 21, 'clients cannot run claim/complete', 'false/false',
  has_function_privilege('authenticated', 'public.claim_push_deliveries(integer)', 'execute')::text || '/' ||
  has_function_privilege('authenticated', 'public.complete_push_deliveries(jsonb)', 'execute')::text;
insert into t select 22, 'cleanup runs on the renamed table', 'ok',
  case when public.run_notification_cleanup() >= 0 then 'ok' else 'failed' end;
insert into t select 23, 'no function still references the old table name', '0',
  (select count(*)::text || coalesce(': ' || string_agg(proname, ', '), '') from pg_proc
   where pronamespace = 'public'::regnamespace and prosrc like '%notification_push_deliveries%');
insert into t select 24, 'no INSERT policy left on user_notifications', '0',
  (select count(*)::text from pg_policies where schemaname = 'public' and tablename = 'user_notifications' and cmd in ('INSERT', 'ALL') and permissive = 'PERMISSIVE');

select n, test, expected, actual from t order by n;

rollback;
