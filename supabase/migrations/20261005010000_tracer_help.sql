-- Tracer AI helper ("Help me answer" on CHED GTS Q19/Q20).
--
-- Only a per-day request count is stored; the alumnus's description is never
-- persisted. The tracer-help Edge Function (service role) is the only caller.

create table if not exists public.tracer_help_usage (
  user_id uuid not null references auth.users(id) on delete cascade,
  used_on date not null,
  count integer not null default 0 check (count >= 0),
  updated_at timestamptz not null default now(),
  primary key (user_id, used_on)
);

alter table public.tracer_help_usage enable row level security;
-- No policies: clients cannot read or write; the service role bypasses RLS.

revoke all on public.tracer_help_usage from anon, authenticated;

-- Atomically uses one help request for today (Manila).
-- Returns the requests left after this one, or -1 when the limit is reached.
create or replace function public.tracer_help_consume(
  p_user_id uuid,
  p_limit integer default 20
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  today date := public.notification_manila_today();
  new_count integer;
begin
  insert into public.tracer_help_usage as u (user_id, used_on, count)
  values (p_user_id, today, 1)
  on conflict (user_id, used_on) do update
    set count = u.count + 1,
        updated_at = now()
    where u.count < p_limit
  returning u.count into new_count;

  if new_count is null then
    return -1;
  end if;
  return greatest(p_limit - new_count, 0);
end;
$$;

-- Gives back a request when the AI call itself failed.
create or replace function public.tracer_help_refund(p_user_id uuid)
returns void
language sql
security definer
set search_path = public
as $$
  update public.tracer_help_usage
     set count = greatest(count - 1, 0),
         updated_at = now()
   where user_id = p_user_id
     and used_on = public.notification_manila_today();
$$;

revoke all on function public.tracer_help_consume(uuid, integer)
  from public, anon, authenticated;
revoke all on function public.tracer_help_refund(uuid)
  from public, anon, authenticated;
grant execute on function public.tracer_help_consume(uuid, integer) to service_role;
grant execute on function public.tracer_help_refund(uuid) to service_role;
