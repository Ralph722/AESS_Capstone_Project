-- Phase 5: GTS analytics layer and employment_records retirement.
--   * gts_respondent_facts: one row per submitted CHED GTS response with
--     typed answers and the respondent's roster cohort
--   * gts_metric(): DSS metrics in SQL, same definitions as DssMetrics (Dart)
--   * gts_employment_records: employment rows derived from each alumnus'
--     latest submitted CHED GTS response (same shape as employment_records)
--   * dss_flag_checks + nightly dss_recheck_open_flags(): re-checks open DSS
--     flags and marks recovered ones for admin review (never auto-resolves)
--   * employment_records archived as archived_employment_records (no client
--     access); dropped in Phase 7

-- ---------------------------------------------------------------------------
-- Answer helpers
-- ---------------------------------------------------------------------------

-- First list element or trimmed text; null when blank (DssMetrics.single).
create or replace function public.gts_single(v jsonb)
returns text
language sql
immutable
parallel safe
set search_path = public
as $$
  select nullif(btrim(case jsonb_typeof(v)
    when 'array' then v ->> 0
    when 'null' then null
    else v #>> '{}'
  end), '');
$$;

-- Q30 job level: current job column first, then first job (DssMetrics.jobLevel).
create or replace function public.gts_job_level(v jsonb)
returns text
language sql
immutable
parallel safe
set search_path = public
as $$
  with cells as (
    select e.key, e.value
    from jsonb_each(case when jsonb_typeof(v) = 'object' then v else '{}'::jsonb end) e
  )
  select coalesce(
    (select key from cells where value -> '30.2. Current or Present Job' = 'true'::jsonb order by key limit 1),
    (select key from cells where value -> '30.1. First Job' = 'true'::jsonb order by key limit 1)
  );
$$;

-- Q31 bracket rank 0-5 (higher = better); null when unknown.
create or replace function public.gts_salary_rank(bracket text)
returns integer
language sql
immutable
parallel safe
set search_path = public
as $$
  select array_position(array[
    'Below P5,000.00',
    'P5,000.00 to less than P10,000.00',
    'P10,000.00 to less than P15,000.00',
    'P15,000.00 to less than P20,000.00',
    'P20,000.00 to less than P25,000.00',
    'P25,000.00 and above'
  ], btrim(bracket)) - 1;
$$;

create or replace function public.dss_crosses(op text, v numeric, t numeric)
returns boolean
language sql
immutable
parallel safe
set search_path = public
as $$
  select case op
    when 'gt' then v > t
    when 'lt' then v < t
    when 'lte' then v <= t
    else v >= t
  end;
$$;

revoke all on function public.gts_single(jsonb) from public, anon;
revoke all on function public.gts_job_level(jsonb) from public, anon;
revoke all on function public.gts_salary_rank(text) from public, anon;
revoke all on function public.dss_crosses(text, numeric, numeric) from public, anon;
grant execute on function public.gts_single(jsonb) to authenticated, service_role;
grant execute on function public.gts_job_level(jsonb) to authenticated, service_role;
grant execute on function public.gts_salary_rank(text) to authenticated, service_role;
grant execute on function public.dss_crosses(text, numeric, numeric) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Respondent facts (RLS of the caller applies: admins see all, alumni self)
-- ---------------------------------------------------------------------------
create or replace view public.gts_respondent_facts
with (security_invoker = true)
as
select
  r.id as response_id,
  r.survey_id,
  r.user_id,
  coalesce(r.submitted_at, r.updated_at) as submitted_at,
  m.id as member_id,
  (m.id is not null) as on_active_roster,
  coalesce(nullif(btrim(m.course), ''), 'Unknown') as course,
  coalesce(nullif(btrim(m.year_graduated), ''), 'Unknown') as year_graduated,
  public.gts_single(r.answers -> 'ched_16') as presently_employed,
  public.gts_single(r.answers -> 'ched_18') as employment_type,
  public.gts_single(r.answers -> 'ched_19') as occupation,
  case
    when public.gts_single(r.answers -> 'ched_20') like 'Others%'
      then coalesce(public.gts_single(r.answers -> 'ched_20_other'), public.gts_single(r.answers -> 'ched_20'))
    else public.gts_single(r.answers -> 'ched_20')
  end as industry,
  public.gts_single(r.answers -> 'ched_21') as place_of_work,
  public.gts_single(r.answers -> 'ched_24a') as first_job_related,
  public.gts_single(r.answers -> 'ched_29') as time_to_first_job,
  public.gts_job_level(r.answers -> 'ched_30') as job_level,
  public.gts_single(r.answers -> 'ched_31') as initial_salary,
  public.gts_salary_rank(public.gts_single(r.answers -> 'ched_31')) as salary_rank,
  public.gts_single(r.answers -> 'ched_32') as curriculum_relevant
from public.survey_responses r
join public.surveys s
  on s.id = r.survey_id
 and s.data ->> 'template_key' = 'ched_gts_builtin'
left join public.alumni_members m
  on m.auth_uid = r.user_id
 and not m.is_deactivated
where r.status = 'submitted';

revoke all on public.gts_respondent_facts from public, anon, authenticated;
grant select on public.gts_respondent_facts to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Metric function (admins and server jobs only)
--   cohort: course null = whole institution; year null = all batches
-- ---------------------------------------------------------------------------
create or replace function public.gts_metric(
  p_metric_key text,
  p_survey_id uuid,
  p_course text default null,
  p_year text default null,
  p_previous_survey_id uuid default null
)
returns table (
  metric_key text,
  hits integer,
  total integer,
  value numeric,
  sample_n integer,
  eligible_n integer,
  metric_version integer
)
language plpgsql
stable
set search_path = public
as $$
declare
  v_sample integer;
  v_eligible integer;
  v_unemp_hits integer;
  v_unemp_total integer;
  v_mismatch integer;
  v_related_total integer;
  v_clerical integer;
  v_level_total integer;
  v_long_wait integer;
  v_wait_total integer;
  v_cohort_median numeric;
  v_peer_median numeric;
  v_prev_hits integer;
  v_prev_total integer;
begin
  if current_user in ('authenticated', 'anon') and not public.is_admin() then
    raise exception 'Admin access required' using errcode = '42501';
  end if;

  select count(*)::integer into v_eligible
  from public.alumni_members m
  where not m.is_deactivated
    and (p_course is null or coalesce(nullif(btrim(m.course), ''), 'Unknown') = p_course)
    and (p_year is null or coalesce(nullif(btrim(m.year_graduated), ''), 'Unknown') = p_year);

  select
    count(*)::integer,
    count(*) filter (where f.presently_employed in ('No', 'Never Employed'))::integer,
    count(f.presently_employed)::integer,
    count(*) filter (where f.first_job_related = 'No' or f.curriculum_relevant = 'No')::integer,
    count(*) filter (where f.first_job_related is not null or f.curriculum_relevant is not null)::integer,
    count(*) filter (where f.presently_employed = 'Yes' and f.job_level = 'Rank or Clerical')::integer,
    count(*) filter (where f.presently_employed = 'Yes' and f.job_level is not null)::integer,
    count(*) filter (where f.time_to_first_job in (
      '1 year to less than 2 years',
      '2 years to less than 3 years',
      '3 years to less than 4 years'))::integer,
    count(f.time_to_first_job)::integer,
    (percentile_cont(0.5) within group (order by f.salary_rank))::numeric
  into v_sample, v_unemp_hits, v_unemp_total, v_mismatch, v_related_total,
       v_clerical, v_level_total, v_long_wait, v_wait_total, v_cohort_median
  from public.gts_respondent_facts f
  where f.survey_id = p_survey_id
    and f.on_active_roster
    and (p_course is null or f.course = p_course)
    and (p_year is null or f.year_graduated = p_year);

  metric_key := p_metric_key;
  sample_n := v_sample;
  eligible_n := v_eligible;
  metric_version := 1;

  case p_metric_key
    when 'unemployment_rate' then
      hits := v_unemp_hits; total := v_unemp_total;
    when 'unrelated_or_irrelevant_rate' then
      hits := v_mismatch; total := v_related_total;
    when 'related_and_relevant_rate' then
      hits := v_related_total - v_mismatch; total := v_related_total;
    when 'clerical_among_employed_rate' then
      hits := v_clerical; total := v_level_total;
    when 'long_time_to_first_job_rate' then
      hits := v_long_wait; total := v_wait_total;
    when 'response_rate' then
      hits := v_sample; total := v_eligible;
      value := case when v_eligible = 0 then 0 else v_sample::numeric / v_eligible end;
      return next;
      return;
    when 'salary_peer_gap' then
      -- Peers: every other course in the wave, including respondents who
      -- are not on the active roster ("Unknown").
      select (percentile_cont(0.5) within group (order by f.salary_rank))::numeric
      into v_peer_median
      from public.gts_respondent_facts f
      where f.survey_id = p_survey_id
        and f.course <> coalesce(p_course, '');
      value := v_peer_median - v_cohort_median;
      return next;
      return;
    when 'unemployment_change_pts' then
      hits := v_unemp_hits; total := v_unemp_total;
      if p_previous_survey_id is not null and v_unemp_total > 0 then
        select
          count(*) filter (where f.presently_employed in ('No', 'Never Employed'))::integer,
          count(f.presently_employed)::integer
        into v_prev_hits, v_prev_total
        from public.gts_respondent_facts f
        where f.survey_id = p_previous_survey_id
          and f.on_active_roster
          and (p_course is null or f.course = p_course)
          and (p_year is null or f.year_graduated = p_year);
        if v_prev_total > 0 then
          value := v_unemp_hits::numeric / v_unemp_total - v_prev_hits::numeric / v_prev_total;
        end if;
      end if;
      return next;
      return;
    else
      raise exception 'Unknown metric key: %', p_metric_key using errcode = '22023';
  end case;

  value := case when total > 0 then hits::numeric / total end;
  return next;
end;
$$;

revoke all on function public.gts_metric(text, uuid, text, text, uuid) from public, anon;
grant execute on function public.gts_metric(text, uuid, text, text, uuid) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Employment rows from the latest submitted CHED GTS response per alumnus
-- ---------------------------------------------------------------------------
create or replace view public.gts_employment_records
with (security_invoker = true)
as
select distinct on (f.user_id)
  f.response_id as id,
  f.user_id,
  case f.presently_employed
    when 'Yes' then 'Employed'
    when 'Never Employed' then 'Never Employed'
    else 'Unemployed'
  end as status,
  null::text as company,
  f.occupation as position,
  null::date as start_date,
  jsonb_strip_nulls(jsonb_build_object(
    'source', 'ched_gts',
    'surveyId', f.survey_id,
    'userName', coalesce(nullif(btrim(u.display_name), ''), m.full_name),
    'userEmail', coalesce(u.email, m.registered_email),
    'schoolId', coalesce(nullif(btrim(m.student_id), ''), u.student_id),
    'contactNumber', coalesce(nullif(btrim(u.mobile_number), ''), m.contact_number),
    'industry', f.industry,
    'employmentType', f.employment_type,
    'jobLevel', f.job_level,
    'salaryRange', f.initial_salary,
    'placeOfWork', f.place_of_work,
    'country', case f.place_of_work when 'Local' then 'Philippines' when 'Abroad' then 'Abroad' end
  )) as data,
  'Submitted'::text as verification_status,
  null::uuid as verified_by,
  null::timestamptz as verified_at,
  f.submitted_at as created_at,
  f.submitted_at as updated_at
from public.gts_respondent_facts f
left join public.users u on u.id = f.user_id
left join public.alumni_members m on m.auth_uid = f.user_id
where f.presently_employed is not null
order by f.user_id, f.submitted_at desc, f.response_id;

revoke all on public.gts_employment_records from public, anon, authenticated;
grant select on public.gts_employment_records to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Nightly DSS re-check
-- ---------------------------------------------------------------------------
create table if not exists public.dss_flag_checks (
  flag_id uuid primary key references public.dss_flags (id) on delete cascade,
  metric_key text not null,
  metric_version integer not null,
  checked_at timestamptz not null default now(),
  metric_value numeric,
  hits integer,
  total integer,
  sample_n integer not null default 0,
  eligible_n integer,
  state text not null check (state in ('still_triggered', 'recovered', 'no_data')),
  recovered_since timestamptz
);

alter table public.dss_flag_checks enable row level security;

drop policy if exists dss_flag_checks_select_admin on public.dss_flag_checks;
create policy dss_flag_checks_select_admin on public.dss_flag_checks
  for select to authenticated
  using ((select public.is_admin()));

revoke all on public.dss_flag_checks from public, anon, authenticated;
grant select on public.dss_flag_checks to authenticated;
grant all on public.dss_flag_checks to service_role;

create or replace function public.dss_recheck_open_flags()
returns integer
language plpgsql
set search_path = public
as $$
declare
  f record;
  m record;
  v_prev uuid;
  v_state text;
  v_still boolean;
  v_count integer := 0;
  uuid_re constant text := '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$';
begin
  for f in
    select fl.id, fl.rule_id, fl.cohort_level, fl.course, fl.batch_year,
           fl.survey_id, fl.evidence, r.metric_key, r.operator, r.threshold, r.min_n
    from public.dss_flags fl
    join public.dss_rules r on r.rule_id = fl.rule_id
    where fl.status in ('open', 'in_progress')
      and fl.survey_id ~ uuid_re
  loop
    v_prev := case
      when coalesce(f.evidence ->> 'previous_survey_id', '') ~ uuid_re
        then (f.evidence ->> 'previous_survey_id')::uuid
    end;

    begin
      select * into m
      from public.gts_metric(
        f.metric_key,
        f.survey_id::uuid,
        case when f.cohort_level = 'institution' then null else f.course end,
        case when f.cohort_level in ('institution', 'course') then null else f.batch_year end,
        v_prev
      );
    exception when others then
      continue;
    end;

    if f.metric_key = 'response_rate' then
      v_still := (m.value is not null and public.dss_crosses(f.operator, m.value, f.threshold))
        or (f.min_n > 0 and m.sample_n < f.min_n);
      v_state := case when v_still then 'still_triggered' else 'recovered' end;
    else
      v_state := case
        when m.value is null then 'no_data'
        when public.dss_crosses(f.operator, m.value, f.threshold) then 'still_triggered'
        else 'recovered'
      end;
    end if;

    insert into public.dss_flag_checks as c (
      flag_id, metric_key, metric_version, checked_at, metric_value,
      hits, total, sample_n, eligible_n, state, recovered_since
    ) values (
      f.id, f.metric_key, m.metric_version, now(), m.value,
      m.hits, m.total, m.sample_n, m.eligible_n, v_state,
      case when v_state = 'recovered' then now() end
    )
    on conflict (flag_id) do update set
      metric_key = excluded.metric_key,
      metric_version = excluded.metric_version,
      checked_at = excluded.checked_at,
      metric_value = excluded.metric_value,
      hits = excluded.hits,
      total = excluded.total,
      sample_n = excluded.sample_n,
      eligible_n = excluded.eligible_n,
      state = excluded.state,
      recovered_since = case
        when excluded.state <> 'recovered' then null
        when c.state = 'recovered' then c.recovered_since
        else excluded.recovered_since
      end;

    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$$;

revoke all on function public.dss_recheck_open_flags() from public, anon, authenticated;
grant execute on function public.dss_recheck_open_flags() to service_role;

do $$
begin
  if exists (select 1 from cron.job where jobname = 'aess-dss-recheck') then
    perform cron.unschedule('aess-dss-recheck');
  end if;
  -- 03:15 Asia/Manila
  perform cron.schedule(
    'aess-dss-recheck',
    '15 19 * * *',
    'select public.dss_recheck_open_flags();'
  );
end;
$$;

select public.dss_recheck_open_flags();

-- ---------------------------------------------------------------------------
-- Archive employment_records (dropped in Phase 7)
-- ---------------------------------------------------------------------------
drop trigger if exists trg_notify_employment_verification on public.employment_records;
drop trigger if exists trg_employment_owner_update on public.employment_records;
drop trigger if exists trg_employment_records_updated_at on public.employment_records;
drop function if exists public.notify_employment_verification();
drop function if exists public.enforce_employment_owner_update();

do $$
declare
  pol record;
begin
  for pol in
    select policyname from pg_policies
    where schemaname = 'public' and tablename = 'employment_records'
  loop
    execute format('drop policy %I on public.employment_records', pol.policyname);
  end loop;
end;
$$;

alter table public.employment_records rename to archived_employment_records;
revoke all on public.archived_employment_records from public, anon, authenticated;
comment on table public.archived_employment_records is
  'Retired in Phase 5; employment data now comes from CHED GTS answers (gts_employment_records). Dropped in Phase 7.';

notify pgrst, 'reload schema';
