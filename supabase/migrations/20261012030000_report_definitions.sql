-- Saved report builder settings (GtsReportConfig JSON). Settings only:
-- never results or personal data. One list shared by every admin.
-- Additive: one new table and one trigger function.

create table if not exists public.report_definitions (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(btrim(name)) between 1 and 120),
  description text not null default '' check (char_length(description) <= 500),
  config jsonb not null
    check (jsonb_typeof(config) = 'object' and pg_column_size(config) <= 32768),
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists report_definitions_name_key
  on public.report_definitions (lower(btrim(name)));

-- Who and when come from the session, never from the client.
create or replace function public.report_definitions_stamp()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    new.created_by := auth.uid();
    new.created_at := now();
  else
    new.created_by := old.created_by;
    new.created_at := old.created_at;
  end if;
  new.updated_by := auth.uid();
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trg_report_definitions_stamp on public.report_definitions;
create trigger trg_report_definitions_stamp
  before insert or update on public.report_definitions
  for each row execute function public.report_definitions_stamp();

alter table public.report_definitions enable row level security;

drop policy if exists report_definitions_admin_all on public.report_definitions;
create policy report_definitions_admin_all
  on public.report_definitions
  for all to authenticated
  using ((select public.is_admin()))
  with check ((select public.is_admin()));

drop policy if exists active_caller_only on public.report_definitions;
create policy active_caller_only
  on public.report_definitions as restrictive
  for all to authenticated
  using ((select public.caller_is_active()))
  with check ((select public.caller_is_active()));

revoke all on public.report_definitions from public, anon, authenticated;
grant select, insert, update, delete on public.report_definitions to authenticated;
grant all on public.report_definitions to service_role;

revoke all on function public.report_definitions_stamp() from public, anon, authenticated;

notify pgrst, 'reload schema';
