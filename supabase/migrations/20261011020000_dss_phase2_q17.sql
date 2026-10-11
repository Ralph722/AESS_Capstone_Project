-- DSS Phase 2: Q17 reasons for not being employed
-- (docs/dss-capability-audit.md Part 10, Phase 2).
--   1. gts_multi(): multi-select answer as a trimmed text array
--   2. gts_respondent_facts: new last column not_employed_reasons (Q17)
--   3. gts_metric: new key seeking_work_rate (looking for work among
--      employed + looking); every existing key is unchanged
--   4. dss_rules: SEEKING_WORK_HIGH inserted switched off
-- Additive: UNEMPLOYMENT_HIGH keeps its name and meaning; no row is updated
-- or deleted.

-- ---------------------------------------------------------------------------
-- 1. Multi-select helper (DssMetrics.notEmployedReasons)
-- ---------------------------------------------------------------------------
create or replace function public.gts_multi(v jsonb)
returns text[]
language sql
immutable
parallel safe
set search_path = public
as $$
  select coalesce(
    (select array_agg(btrim(e) order by o)
     from jsonb_array_elements_text(
            case jsonb_typeof(v)
              when 'array' then v
              when 'string' then jsonb_build_array(v)
              else '[]'::jsonb
            end
          ) with ordinality as t(e, o)
     where btrim(e) <> ''),
    '{}'::text[]
  );
$$;

revoke all on function public.gts_multi(jsonb) from public, anon;
grant execute on function public.gts_multi(jsonb) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 2. Respondent facts: Q17 reasons appended as the last column
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
  public.gts_single(r.answers -> 'ched_32') as curriculum_relevant,
  public.gts_multi(r.answers -> 'ched_17') as not_employed_reasons
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
-- 3. gts_metric: seeking_work_rate (same signature, columns and version)
--   Looking = Q16 No / Never Employed, a Q17 reason "No job opportunity" or
--   "Lack of work experience", and not "Did not look for a job".
--   Total = Q16 Yes + looking (the labour force).
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
  v_seek_hits integer;
  v_labour_total integer;
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

  with facts as (
    select
      f.*,
      (f.presently_employed in ('No', 'Never Employed')
        and not ('Did not look for a job' = any (f.not_employed_reasons))
        and f.not_employed_reasons && array['No job opportunity', 'Lack of work experience']
      ) as seeking
    from public.gts_respondent_facts f
    where f.survey_id = p_survey_id
      and f.on_active_roster
      and f.course <> 'Unknown'
      and (p_course is null or f.course = p_course)
      and (p_year is null or (p_year <> 'Unknown' and f.year_graduated = p_year))
  )
  select
    count(*)::integer,
    count(*) filter (where f.presently_employed in ('No', 'Never Employed'))::integer,
    count(f.presently_employed)::integer,
    count(*) filter (where f.seeking)::integer,
    count(*) filter (where f.presently_employed = 'Yes' or f.seeking)::integer,
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
  into v_sample, v_unemp_hits, v_unemp_total, v_seek_hits, v_labour_total,
       v_mismatch, v_related_total, v_clerical, v_level_total, v_long_wait,
       v_wait_total, v_salary_total, v_cohort_median
  from facts f;

  metric_key := p_metric_key;
  sample_n := v_sample;
  eligible_n := v_eligible;
  metric_version := 2;

  case p_metric_key
    when 'unemployment_rate' then
      hits := v_unemp_hits; total := v_unemp_total;
    when 'seeking_work_rate' then
      hits := v_seek_hits; total := v_labour_total;
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
-- 4. New rule, switched off until an admin turns it on in DSS settings
-- ---------------------------------------------------------------------------
insert into public.dss_rules (
  rule_id, name, description, metric_key, operator, threshold, min_n,
  enabled, severity, recommended_action, playbook, category, sort_order
) values (
  'SEEKING_WORK_HIGH',
  'Many alumni looking for work',
  'Share of alumni looking for work (Q17: no job opportunity or lack of work experience) among those employed or looking for work. Alumni in further study, with family or health reasons, or not looking are left out.',
  'seeking_work_rate',
  'gte',
  0.15,
  10,
  false,
  'warning',
  'Connect the group with job postings, employer partners and work-readiness support from the Career Center.',
  '[
    {"step": "Check the Q17 reasons on this flag: no job opportunity points to job supply, lack of work experience to readiness."},
    {"step": "Publish matching job postings and announce them to the group."},
    {"step": "Coordinate with the Career Center on a job fair, OJT or work-readiness session."},
    {"step": "Record what you did in the flag notes, then recheck after the next wave."}
  ]'::jsonb,
  'outcome',
  25
)
on conflict (rule_id) do nothing;

notify pgrst, 'reload schema';
