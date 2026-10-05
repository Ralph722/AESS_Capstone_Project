begin;
create temp table r as
select (select count(*) from public.audit_logs) as before_logs, 0::bigint as purged, 0::bigint as rechecked;
update r set purged = (select public.purge_expired_audit_logs())::text::bigint;
update r set rechecked = (select public.dss_recheck_open_flags())::text::bigint;
select before_logs, purged, (select count(*) from public.audit_logs) after_logs, rechecked,
  (select string_agg(state || '=' || n, ' ') from (select state, count(*) n from public.dss_flag_checks group by 1) s) states from r;
rollback;
