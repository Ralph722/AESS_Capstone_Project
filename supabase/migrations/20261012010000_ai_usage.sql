-- Per-user daily request count for the ai-assist Edge Function, which holds
-- the Gemini key server-side. Only the count is stored; prompts and replies
-- are never persisted. The function (service role) is the only caller.
-- Additive: one new table and two functions.

create table if not exists public.ai_usage (
  user_id uuid not null references auth.users(id) on delete cascade,
  used_on date not null,
  count integer not null default 0 check (count >= 0),
  updated_at timestamptz not null default now(),
  primary key (user_id, used_on)
);

alter table public.ai_usage enable row level security;
-- No permissive policies: clients cannot read or write; the service role
-- bypasses RLS. The restrictive policy matches every other RLS table.
drop policy if exists active_caller_only on public.ai_usage;
create policy active_caller_only
  on public.ai_usage as restrictive
  for all to authenticated
  using ((select public.caller_is_active()))
  with check ((select public.caller_is_active()));

revoke all on public.ai_usage from public, anon, authenticated;
grant all on public.ai_usage to service_role;

-- Atomically uses one AI request for today (Manila).
-- Returns the requests left after this one, or -1 when the limit is reached.
create or replace function public.ai_usage_consume(
  p_user_id uuid,
  p_limit integer
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
  insert into public.ai_usage as u (user_id, used_on, count)
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
create or replace function public.ai_usage_refund(p_user_id uuid)
returns void
language sql
security definer
set search_path = public
as $$
  update public.ai_usage
     set count = greatest(count - 1, 0),
         updated_at = now()
   where user_id = p_user_id
     and used_on = public.notification_manila_today();
$$;

revoke all on function public.ai_usage_consume(uuid, integer)
  from public, anon, authenticated;
revoke all on function public.ai_usage_refund(uuid)
  from public, anon, authenticated;
grant execute on function public.ai_usage_consume(uuid, integer) to service_role;
grant execute on function public.ai_usage_refund(uuid) to service_role;

notify pgrst, 'reload schema';
