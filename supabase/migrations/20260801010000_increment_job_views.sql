-- Allow signed-in alumni to bump job view counts without full jobs UPDATE RLS.

create or replace function public.increment_job_views(p_job_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  current_views int;
begin
  if not public.is_signed_in() then
    return;
  end if;

  select coalesce((data->>'views')::int, 0)
  into current_views
  from public.jobs
  where id = p_job_id;

  if not found then
    return;
  end if;

  update public.jobs
  set
    data = jsonb_set(
      coalesce(data, '{}'::jsonb),
      '{views}',
      to_jsonb(current_views + 1),
      true
    ),
    updated_at = now()
  where id = p_job_id;
end;
$$;

grant execute on function public.increment_job_views(uuid) to authenticated;
