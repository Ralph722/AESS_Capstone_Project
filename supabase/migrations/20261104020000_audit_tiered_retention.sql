-- Tiered audit retention: keep the hot audit_logs table lean while preserving
-- older rows in audit_logs_archive (and applying longer keep for security).
--
-- Hot table (audit_logs):
--   LOGIN / LOGOUT ........ 90 days  (deleted; not archived — high volume)
--   activity (default) .... 1 year   (then archived)
--   security .............. 3 years  (then archived)
--
-- Archive table (audit_logs_archive):
--   activity .............. deleted 3 years after original created_at
--   security .............. deleted 5 years after original created_at
--
-- Does not change client RLS on audit_logs. Does not wipe existing rows.

-- ---------------------------------------------------------------------------
-- Cold archive (same shape as audit_logs + archived_at)
-- ---------------------------------------------------------------------------
create table if not exists public.audit_logs_archive (
  id uuid primary key,
  user_id uuid,
  action text not null default '',
  entity_type text not null default '',
  entity_id text not null default '',
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  archived_at timestamptz not null default now()
);

create index if not exists idx_audit_logs_archive_created_at
  on public.audit_logs_archive (created_at desc);

create index if not exists idx_audit_logs_archive_action_created_at
  on public.audit_logs_archive (action, created_at desc);

create index if not exists idx_audit_logs_archive_details_category
  on public.audit_logs_archive ((details->>'category'));

alter table public.audit_logs_archive enable row level security;

drop policy if exists audit_logs_archive_select_admin on public.audit_logs_archive;
create policy audit_logs_archive_select_admin
  on public.audit_logs_archive
  for select
  to authenticated
  using ((select public.is_admin()));

-- Clients must not write/update/delete archive rows directly.
revoke all on table public.audit_logs_archive from anon, authenticated;
grant select on table public.audit_logs_archive to authenticated;

-- ---------------------------------------------------------------------------
-- Tiered purge + archive
-- ---------------------------------------------------------------------------
create or replace function public.purge_expired_audit_logs()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_sessions integer := 0;
  v_activity integer := 0;
  v_security integer := 0;
  v_arch_activity integer := 0;
  v_arch_security integer := 0;
begin
  -- 1) Session noise: drop after 90 days (do not archive).
  delete from public.audit_logs
  where action in ('LOGIN', 'LOGOUT')
    and created_at < now() - interval '90 days';
  get diagnostics v_sessions = row_count;

  -- 2) Everyday activity: archive after 1 year, then remove from hot table.
  with doomed as (
    delete from public.audit_logs
    where action not in ('LOGIN', 'LOGOUT')
      and coalesce(details->>'category', 'activity') <> 'security'
      and created_at < now() - interval '1 year'
    returning
      id, user_id, action, entity_type, entity_id, details, created_at, updated_at
  ),
  moved as (
    insert into public.audit_logs_archive (
      id, user_id, action, entity_type, entity_id, details, created_at, updated_at, archived_at
    )
    select
      id, user_id, action, entity_type, entity_id, details, created_at, updated_at, now()
    from doomed
    on conflict (id) do nothing
    returning id
  )
  select count(*)::integer into v_activity from doomed;

  -- 3) Security events: archive after 3 years, then remove from hot table.
  with doomed as (
    delete from public.audit_logs
    where action not in ('LOGIN', 'LOGOUT')
      and coalesce(details->>'category', 'activity') = 'security'
      and created_at < now() - interval '3 years'
    returning
      id, user_id, action, entity_type, entity_id, details, created_at, updated_at
  ),
  moved as (
    insert into public.audit_logs_archive (
      id, user_id, action, entity_type, entity_id, details, created_at, updated_at, archived_at
    )
    select
      id, user_id, action, entity_type, entity_id, details, created_at, updated_at, now()
    from doomed
    on conflict (id) do nothing
    returning id
  )
  select count(*)::integer into v_security from doomed;

  -- 4) Cold archive cleanup (storage ceiling).
  delete from public.audit_logs_archive
  where coalesce(details->>'category', 'activity') <> 'security'
    and created_at < now() - interval '3 years';
  get diagnostics v_arch_activity = row_count;

  delete from public.audit_logs_archive
  where coalesce(details->>'category', 'activity') = 'security'
    and created_at < now() - interval '5 years';
  get diagnostics v_arch_security = row_count;

  -- Rows removed from the hot table (primary efficiency win).
  return v_sessions + v_activity + v_security;
end;
$$;

revoke all on function public.purge_expired_audit_logs() from public, anon, authenticated;

comment on table public.audit_logs_archive is
  'Cold store for aged audit_logs rows. Hot table is purged nightly into this archive.';

comment on function public.purge_expired_audit_logs() is
  'Tiered retention: sessions 90d deleted; activity 1y→archive (archive kept 3y); security 3y→archive (archive kept 5y).';
