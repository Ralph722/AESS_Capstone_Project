-- Late registrants get only the current CHED tracer.
--
-- Each tracer cycle is its own survey, and an older one is sometimes left open
-- by mistake. Alumni who registered (or changed program / graduation year)
-- while several tracers were open used to be assigned all of them. Now only
-- the newest tracer that matches the alumnus counts: it is assigned when it
-- still accepts responses and has auto-assign on; older tracers are skipped,
-- even when the newest one is closed or opted out. Other surveys are unchanged.
--
-- "Newest" is the first publish time (data.publishedAt, set by the app), then
-- open_at, then created_at. Publishing a tracer still assigns every matching
-- alumnus regardless of graduation year. Existing assignments are untouched.

begin;

create or replace function public.survey_is_ched_tracer(p_data jsonb)
returns boolean
language sql
immutable
set search_path = public
as $$
  select coalesce(p_data->>'kind', '') = 'ched_gts_builtin'
    or coalesce(p_data->>'template_key', '') = 'ched_gts_builtin';
$$;

create or replace function public.survey_first_published_at(
  p_data jsonb,
  p_open_at timestamptz,
  p_created_at timestamptz
)
returns timestamptz
language plpgsql
stable
set search_path = public
as $$
begin
  return coalesce((p_data->>'publishedAt')::timestamptz, p_open_at, p_created_at);
exception when others then
  return coalesce(p_open_at, p_created_at);
end;
$$;

revoke all on function public.survey_is_ched_tracer(jsonb) from public, anon;
revoke all on function public.survey_first_published_at(jsonb, timestamptz, timestamptz)
  from public, anon;
grant execute on function public.survey_is_ched_tracer(jsonb) to authenticated, service_role;
grant execute on function public.survey_first_published_at(jsonb, timestamptz, timestamptz)
  to authenticated, service_role;

create or replace function public.auto_assign_open_surveys(p_user_id uuid)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  u public.users%rowtype;
  s record;
  inserted_id uuid;
  assigned integer := 0;
  current_tracer uuid;
begin
  select * into u from public.users where id = p_user_id;
  if not found or coalesce(u.role, 'user') = 'admin' then
    return 0;
  end if;

  select sv.id into current_tracer
  from public.surveys sv
  where public.survey_is_ched_tracer(sv.data)
    and sv.status in ('published', 'closed')
    and coalesce(sv.data->>'archived', 'false') <> 'true'
    and public.survey_audience_matches(
      sv.target_programs, sv.target_batch_years,
      u.program, u.year_graduated
    )
  order by
    public.survey_first_published_at(sv.data, sv.open_at, sv.created_at) desc,
    sv.created_at desc
  limit 1;

  for s in
    select sv.id, sv.title, sv.target_programs, sv.target_batch_years, sv.data
    from public.surveys sv
    where sv.status = 'published'
      and coalesce(sv.data->>'archived', 'false') <> 'true'
      and coalesce(sv.data->>'autoAssignNewAlumni', 'true') <> 'false'
      and (sv.close_at is null or sv.close_at > now())
  loop
    if public.survey_is_ched_tracer(s.data)
       and s.id is distinct from current_tracer then
      continue;
    end if;
    if not public.survey_audience_matches(
      s.target_programs, s.target_batch_years,
      u.program, u.year_graduated
    ) then
      continue;
    end if;
    -- assignment_count is kept in sync by trg_survey_assignments_recount_ins.
    inserted_id := null;
    insert into public.survey_assignments (
      survey_id, user_id, survey_title, status, assigned_at
    ) values (
      s.id, p_user_id, coalesce(s.title, ''), 'notStarted', now()
    )
    on conflict (survey_id, user_id) do nothing
    returning id into inserted_id;
    if inserted_id is not null then
      assigned := assigned + 1;
    end if;
  end loop;
  return assigned;
end;
$$;

revoke all on function public.auto_assign_open_surveys(uuid)
  from public, anon, authenticated;

commit;
