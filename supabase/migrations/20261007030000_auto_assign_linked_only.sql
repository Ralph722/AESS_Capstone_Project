-- Auto-assign surveys only once the account is linked to the alumni roster.
--
-- Confirming the email code creates an empty profile (handle_new_user), and
-- auto-assignment used to run right then. Untargeted surveys matched that
-- empty profile, so a late registrant could get an old open tracer before
-- their graduation year was known, and the newest tracer for their batch
-- again at the roster link. Now nothing is assigned until the account is
-- linked to an active roster row; link_alumni_registration fills program and
-- graduation year after linking, which runs this once with the real profile.
-- Deactivated accounts and alumni are skipped too.

begin;

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
  if not found
     or coalesce(u.role, 'user') = 'admin'
     or u.deactivated_at is not null
     or not exists (
       select 1 from public.alumni_members m
       where m.auth_uid = u.id
         and m.is_registered_user
         and not m.is_deactivated
     ) then
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
