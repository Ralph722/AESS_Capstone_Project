-- Audit logging foundation: failed-auth RPC (no session required) + query indexes.
-- Does not alter RLS policies. Does not delete existing audit rows.

-- ---------------------------------------------------------------------------
-- record_failed_auth_attempt: SECURITY DEFINER insert for LOGIN/REGISTER failures
-- ---------------------------------------------------------------------------
create or replace function public.record_failed_auth_attempt(
  p_action text,
  p_email text,
  p_description text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_action text := upper(trim(coalesce(p_action, '')));
  v_email text := left(lower(trim(coalesce(p_email, ''))), 254);
  v_desc text := left(
    trim(coalesce(nullif(p_description, ''), 'Failed authentication attempt')),
    500
  );
  v_recent integer;
begin
  if v_action not in ('LOGIN', 'REGISTER') then
    raise exception 'unsupported failed-auth action';
  end if;

  -- Light abuse guard: max 30 failed-auth rows per email in 15 minutes.
  if v_email <> '' then
    select count(*)::integer into v_recent
    from public.audit_logs
    where action = v_action
      and created_at > now() - interval '15 minutes'
      and details->>'status' = 'FAILED'
      and lower(coalesce(details->>'attemptEmail', '')) = v_email;
    if v_recent >= 30 then
      return;
    end if;
  end if;

  insert into public.audit_logs (
    user_id,
    action,
    entity_type,
    entity_id,
    details
  ) values (
    null,
    v_action,
    'User',
    'unknown',
    jsonb_build_object(
      'userName', 'Unknown',
      'userEmail', '',
      'userRole', 'user',
      'actorType', 'alumni',
      'module', 'auth',
      'category', 'security',
      'status', 'FAILED',
      'description', v_desc,
      'attemptEmail', v_email
    )
  );
end;
$$;

revoke all on function public.record_failed_auth_attempt(text, text, text)
  from public;
grant execute on function public.record_failed_auth_attempt(text, text, text)
  to anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Indexes for Activity Logs filters / date sorts / retention scans
-- ---------------------------------------------------------------------------
create index if not exists idx_audit_logs_created_at
  on public.audit_logs (created_at desc);

create index if not exists idx_audit_logs_action_created_at
  on public.audit_logs (action, created_at desc);

create index if not exists idx_audit_logs_entity
  on public.audit_logs (entity_type, entity_id, created_at desc);

create index if not exists idx_audit_logs_details_status
  on public.audit_logs ((details->>'status'));

create index if not exists idx_audit_logs_details_module
  on public.audit_logs ((details->>'module'));

create index if not exists idx_audit_logs_details_category
  on public.audit_logs ((details->>'category'));
