-- DSS Phase 1: sample-size and group-mapping guardrails
-- (docs/dss-capability-audit.md Part 3 and Part 10.4).
--   1. dss_flags.evidence_strength: generated from evidence->>'evidence_strength'
--   2. dss_wave_cohort_snapshots: roster counts saved while a wave is open
--   3. dss_rules min_n floors (data quality >= 1, others >= 10); raises
--      existing rules below the floor, then validates the constraint
--   4. gts_metric version 2: Q29 "Others" leaves the denominator; respondents
--      without a roster course never count; "Unknown" never matches a group
--   5. dss_recheck_open_flags: "no_data" below the evidence floor; trends use
--      the smaller wave
-- Additive: no table, column or row is dropped. Existing flags keep their
-- stored values.

-- ---------------------------------------------------------------------------
-- 1. Evidence strength on each flag
-- ---------------------------------------------------------------------------
alter table public.dss_flags
  add column if not exists evidence_strength text
  generated always as (nullif(btrim(evidence ->> 'evidence_strength'), '')) stored;

alter table public.dss_flags
  drop constraint if exists dss_flags_evidence_strength_check;
alter table public.dss_flags
  add constraint dss_flags_evidence_strength_check
  check (evidence_strength in ('insufficient', 'watch', 'limited', 'strong'));

comment on column public.dss_flags.evidence_strength is
  'Sample-size level of the metric (insufficient < 5, watch 5-9 or below the '
  'rule minimum, limited 10-29, strong 30+). Null for data-quality checks and '
  'flags saved before DSS Phase 1.';

-- ---------------------------------------------------------------------------
-- 2. Roster counts per wave (counts only, no personal data)
-- ---------------------------------------------------------------------------
create table if not exists public.dss_wave_cohort_snapshots (
  survey_id uuid not null references public.surveys (id) on delete cascade,
  course text not null check (btrim(course) <> ''),
  batch_year text not null check (btrim(batch_year) <> ''),
  roster_count integer not null check (roster_count >= 0),
  registered_count integer not null
    check (registered_count >= 0 and registered_count <= roster_count),
  captured_at timestamptz not null default now(),
  primary key (survey_id, course, batch_year)
);

comment on table public.dss_wave_cohort_snapshots is
  'Active roster size per course x batch, saved by Refresh insights while a '
  'CHED GTS wave accepts responses. Response rates of closed waves use it '
  'instead of today''s roster.';

alter table public.dss_wave_cohort_snapshots enable row level security;

drop policy if exists dss_wave_cohort_snapshots_admin_all
  on public.dss_wave_cohort_snapshots;
create policy dss_wave_cohort_snapshots_admin_all
  on public.dss_wave_cohort_snapshots
  for all to authenticated
  using ((select public.is_admin()))
  with check ((select public.is_admin()));

drop policy if exists active_caller_only on public.dss_wave_cohort_snapshots;
create policy active_caller_only
  on public.dss_wave_cohort_snapshots as restrictive
  for all to authenticated
  using ((select public.caller_is_active()))
  with check ((select public.caller_is_active()));

revoke all on public.dss_wave_cohort_snapshots from public, anon, authenticated;
grant select, insert, update on public.dss_wave_cohort_snapshots to authenticated;
grant all on public.dss_wave_cohort_snapshots to service_role;

-- ---------------------------------------------------------------------------
-- 3. Rule minimums (added NOT VALID, existing rows raised, then validated)
-- ---------------------------------------------------------------------------
alter table public.dss_rules
  drop constraint if exists dss_rules_min_n_policy;
alter table public.dss_rules
  add constraint dss_rules_min_n_policy
  check (min_n >= case when category = 'data_quality' then 1 else 10 end)
  not valid;

-- Data update: rules saved below the floor are raised to it.
update public.dss_rules
set min_n = case when category = 'data_quality' then 1 else 10 end
where min_n < case when category = 'data_quality' then 1 else 10 end;

alter table public.dss_rules
  validate constraint dss_rules_min_n_policy;

-- ---------------------------------------------------------------------------
-- 4. gts_metric version 2 (same signature and columns)
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
  v_salary_total integer;
  v_cohort_median numeric;
  v_peer_median numeric;
  v_prev_hits integer;
  v_prev_total integer;
begin
  if current_user in ('authenticated', 'anon') and not public.is_admin() then
    raise exception 'Admin access required' using errcode = '42501';
  end if;

  -- Roster members without a course are never counted; a missing batch
  -- counts at course level only.
  select count(*)::integer into v_eligible
  from public.alumni_members m
  where not m.is_deactivated
    and nullif(btrim(m.course), '') is not null
    and (p_course is null or btrim(m.course) = p_course)
    and (p_year is null or nullif(btrim(m.year_graduated), '') = p_year);

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
    count(*) filter (where f.time_to_first_job is not null
                       and f.time_to_first_job not like 'Others%')::integer,
    count(f.salary_rank)::integer,
    (percentile_cont(0.5) within group (order by f.salary_rank))::numeric
  into v_sample, v_unemp_hits, v_unemp_total, v_mismatch, v_related_total,
       v_clerical, v_level_total, v_long_wait, v_wait_total, v_salary_total,
       v_cohort_median
  from public.gts_respondent_facts f
  where f.survey_id = p_survey_id
    and f.on_active_roster
    and f.course <> 'Unknown'
    and (p_course is null or f.course = p_course)
    and (p_year is null or (p_year <> 'Unknown' and f.year_graduated = p_year));

  metric_key := p_metric_key;
  sample_n := v_sample;
  eligible_n := v_eligible;
  metric_version := 2;

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
      -- Peers: the other roster courses in the same wave.
      select (percentile_cont(0.5) within group (order by f.salary_rank))::numeric
      into v_peer_median
      from public.gts_respondent_facts f
      where f.survey_id = p_survey_id
        and f.on_active_roster
        and f.course <> 'Unknown'
        and f.course <> coalesce(p_course, '');
      total := v_salary_total;
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
          and f.course <> 'Unknown'
          and (p_course is null or f.course = p_course)
          and (p_year is null or (p_year <> 'Unknown' and f.year_graduated = p_year));
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
-- 5. Nightly re-check with the evidence floor
-- ---------------------------------------------------------------------------
create or replace function public.dss_recheck_open_flags()
returns integer
language plpgsql
set search_path = public
as $$
declare
  f record;
  m record;
  v_prev uuid;
  v_prev_total integer;
  v_n integer;
  v_floor integer;
  v_state text;
  v_still boolean;
  v_count integer := 0;
  uuid_re constant text := '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$';
begin
  for f in
    select fl.id, fl.rule_id, fl.cohort_level, fl.course, fl.batch_year,
           fl.survey_id, fl.evidence, fl.evidence_strength,
           r.metric_key, r.operator, r.threshold, r.min_n
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
      -- Watch items need 5 valid answers; findings need the rule minimum
      -- (never below 10). Trends need it in both waves.
      v_floor := case when f.evidence_strength = 'watch' then 5
                      else greatest(f.min_n, 10) end;
      v_n := coalesce(m.total, 0);
      if f.metric_key = 'unemployment_change_pts' then
        v_prev_total := 0;
        if v_prev is not null then
          begin
            select p.total into v_prev_total
            from public.gts_metric(
              'unemployment_rate',
              v_prev,
              case when f.cohort_level = 'institution' then null else f.course end,
              case when f.cohort_level in ('institution', 'course') then null else f.batch_year end
            ) p;
          exception when others then
            v_prev_total := 0;
          end;
        end if;
        v_n := least(v_n, coalesce(v_prev_total, 0));
      end if;
      v_state := case
        when m.value is null or v_n < v_floor then 'no_data'
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

notify pgrst, 'reload schema';
