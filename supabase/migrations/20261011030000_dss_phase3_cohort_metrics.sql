-- DSS Phase 3: one server metric layer
-- (docs/dss-capability-audit.md Part 10, Phase 3).
--   1. dss_wilson(): 95% Wilson interval (DssMetrics.wilson)
--   2. dss_cohort_metrics(p_survey_id): every group and metric of one CHED
--      GTS wave with counts, sample-size state and roster basis, applying
--      the Part 3 policies exactly like the Dart reference
--      (lib/features/admin/dss/application/dss_cohort_metrics.dart)
-- Read-only functions: no table, column or row changes. Nothing calls them
-- yet; server evaluation (Phase 8) switches over after parity checks.

-- ---------------------------------------------------------------------------
-- 1. Wilson interval; null when there are no answers
-- ---------------------------------------------------------------------------
create or replace function public.dss_wilson(
  p_hits integer,
  p_total integer,
  out low double precision,
  out high double precision
)
language sql
immutable
parallel safe
set search_path = public
as $$
  with c as (
    select
      p_hits::double precision / p_total as p,
      p_total::double precision as n,
      1.959964::double precision as z,
      1.959964::double precision * 1.959964::double precision as z2
    where p_total > 0
  ),
  w as (
    select
      (c.p + c.z2 / (2 * c.n)) / (1 + c.z2 / c.n) as centre,
      c.z * sqrt(c.p * (1 - c.p) / c.n + c.z2 / (4 * c.n * c.n)) / (1 + c.z2 / c.n) as half
    from c
  )
  select
    case when p_hits <= 0 then 0::double precision else greatest(0::double precision, w.centre - w.half) end,
    case when p_hits >= p_total then 1::double precision else least(1::double precision, w.centre + w.half) end
  from w;
$$;

revoke all on function public.dss_wilson(integer, integer) from public, anon;
grant execute on function public.dss_wilson(integer, integer) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 2. Cohort metrics of one wave
--   Groups: the institution, every course and every recorded batch that has
--   respondents or active roster members. Respondents count only through an
--   active roster record with a course; a missing batch counts at course
--   level only. Groups without respondents get the response rate only.
--   Roster: today's roster while the wave accepts responses or when no
--   snapshot was saved, otherwise the saved snapshot.
--   Evidence strength (not for the response rate): insufficient below 5
--   valid answers, watch below the rule minimum (never below 10), limited
--   below 30, strong from 30.
-- ---------------------------------------------------------------------------
create or replace function public.dss_cohort_metrics(p_survey_id uuid)
returns table (
  level text,
  course text,
  batch_year text,
  metric_key text,
  hits integer,
  total integer,
  value double precision,
  respondents integer,
  non_response integer,
  eligible integer,
  registered integer,
  roster_basis text,
  evidence_strength text,
  coverage_warning boolean,
  ci_low double precision,
  ci_high double precision,
  metric_version integer
)
language plpgsql
stable
set search_path = public
as $$
#variable_conflict use_column
declare
  v_basis text;
begin
  if current_user in ('authenticated', 'anon') and not public.is_admin() then
    raise exception 'Admin access required' using errcode = '42501';
  end if;

  select case
    when s.status = 'published'
     and coalesce(s.data ->> 'archived', '') <> 'true'
     and (s.open_at is null or s.open_at <= now())
     and (s.close_at is null or s.close_at >= now())
      then 'open_wave'
    when exists (
      select 1 from public.dss_wave_cohort_snapshots ws where ws.survey_id = s.id
    ) then 'snapshot'
    else 'current'
  end
  into v_basis
  from public.surveys s
  where s.id = p_survey_id
    and s.data ->> 'template_key' = 'ched_gts_builtin';

  if v_basis is null then
    return;
  end if;

  return query
  with roster as (
    select
      btrim(m.course) as r_course,
      coalesce(nullif(btrim(m.year_graduated), ''), 'Batch not recorded') as r_batch,
      count(*)::integer as r_total,
      count(*) filter (
        where coalesce(m.is_registered_user, false)
           or nullif(btrim(m.auth_uid::text), '') is not null
      )::integer as r_registered
    from public.alumni_members m
    where v_basis <> 'snapshot'
      and not m.is_deactivated
      and nullif(btrim(m.course), '') is not null
    group by 1, 2
    union all
    select ws.course, ws.batch_year, ws.roster_count, ws.registered_count
    from public.dss_wave_cohort_snapshots ws
    where v_basis = 'snapshot'
      and ws.survey_id = p_survey_id
  ),
  facts as (
    select
      f.course as f_course,
      case when f.year_graduated = 'Unknown' then 'Batch not recorded' else f.year_graduated end as f_batch,
      f.presently_employed as q16,
      f.first_job_related as q24,
      f.curriculum_relevant as q32,
      f.job_level as q30,
      f.time_to_first_job as q29,
      f.salary_rank,
      (f.presently_employed in ('No', 'Never Employed')
        and not ('Did not look for a job' = any (f.not_employed_reasons))
        and f.not_employed_reasons && array['No job opportunity', 'Lack of work experience']
      ) as seeking
    from public.gts_respondent_facts f
    where f.survey_id = p_survey_id
      and f.on_active_roster
      and f.course <> 'Unknown'
  ),
  groups as (
    select
      'institution'::text as g_level, 0 as g_order, 'All'::text as g_course, 'All'::text as g_batch,
      (select coalesce(sum(r.r_total), 0) from roster r)::integer as g_eligible,
      (select coalesce(sum(r.r_registered), 0) from roster r)::integer as g_registered
    union all
    select
      'course', 1, c.c_course, 'All',
      (select coalesce(sum(r.r_total), 0) from roster r where r.r_course = c.c_course)::integer,
      (select coalesce(sum(r.r_registered), 0) from roster r where r.r_course = c.c_course)::integer
    from (
      select fc.f_course as c_course from facts fc
      union
      select r.r_course from roster r where r.r_total > 0
    ) c
    union all
    select 'batch', 2, b.b_course, b.b_batch, r.r_total, coalesce(r.r_registered, 0)
    from (
      select fb.f_course as b_course, fb.f_batch as b_batch
      from facts fb where fb.f_batch <> 'Batch not recorded'
      union
      select r.r_course, r.r_batch
      from roster r where r.r_batch <> 'Batch not recorded' and r.r_total > 0
    ) b
    left join roster r on r.r_course = b.b_course and r.r_batch = b.b_batch
  ),
  agg as (
    select
      g.g_level, g.g_order, g.g_course, g.g_batch,
      coalesce(g.g_eligible, a.n) as eligible_n,
      g.g_registered as registered_n,
      a.*,
      case when g.g_level <> 'institution' then (
        select percentile_cont(0.5) within group (order by fp.salary_rank)
        from facts fp
        where fp.f_course <> g.g_course
      ) end as peer_median
    from groups g
    cross join lateral (
      select
        count(*)::integer as n,
        count(*) filter (where f.q16 in ('No', 'Never Employed'))::integer as unemp_hits,
        count(f.q16)::integer as unemp_total,
        count(*) filter (where f.seeking)::integer as seek_hits,
        count(*) filter (where f.q16 = 'Yes' or f.seeking)::integer as labour_total,
        count(*) filter (where f.q24 = 'No' or f.q32 = 'No')::integer as mismatch,
        count(*) filter (where f.q24 is not null or f.q32 is not null)::integer as related_total,
        count(*) filter (where f.q16 = 'Yes' and f.q30 = 'Rank or Clerical')::integer as clerical,
        count(*) filter (where f.q16 = 'Yes' and f.q30 is not null)::integer as level_total,
        count(*) filter (where f.q29 in (
          '1 year to less than 2 years',
          '2 years to less than 3 years',
          '3 years to less than 4 years'))::integer as long_wait,
        count(*) filter (where f.q29 is not null and f.q29 not like 'Others%')::integer as wait_total,
        count(f.salary_rank)::integer as salary_n,
        percentile_cont(0.5) within group (order by f.salary_rank) as salary_median
      from facts f
      where g.g_level = 'institution'
         or (f.f_course = g.g_course and (g.g_level = 'course' or f.f_batch = g.g_batch))
    ) a
  ),
  metric_rows as (
    select x.*, mr.*
    from agg x
    cross join lateral (values
      ('response_rate', 1, x.n, x.eligible_n, 'rate'),
      ('unemployment_rate', 2, x.unemp_hits, x.unemp_total, 'share'),
      ('seeking_work_rate', 3, x.seek_hits, x.labour_total, 'share'),
      ('unrelated_or_irrelevant_rate', 4, x.mismatch, x.related_total, 'share'),
      ('related_and_relevant_rate', 5, x.related_total - x.mismatch, x.related_total, 'share'),
      ('clerical_among_employed_rate', 6, x.clerical, x.level_total, 'share'),
      ('long_time_to_first_job_rate', 7, x.long_wait, x.wait_total, 'share'),
      ('salary_peer_gap', 8, null::integer, x.salary_n, 'gap')
    ) as mr(m_key, m_order, m_hits, m_total, m_kind)
    where mr.m_key = 'response_rate'
       or (x.n > 0 and not (mr.m_key = 'salary_peer_gap' and x.g_level = 'institution'))
  )
  select
    mr.g_level,
    mr.g_course,
    mr.g_batch,
    mr.m_key,
    mr.m_hits,
    mr.m_total,
    case mr.m_kind
      when 'gap' then mr.peer_median - mr.salary_median
      else case when mr.m_total > 0 then mr.m_hits::double precision / mr.m_total end
    end,
    mr.n,
    case when mr.m_kind = 'rate' then null else mr.n - mr.m_total end,
    mr.eligible_n,
    mr.registered_n,
    v_basis,
    case
      when mr.m_kind = 'rate' then null
      when mr.m_total < 5 then 'insufficient'
      when mr.m_total < greatest(coalesce((
        select max(d.min_n) from public.dss_rules d where d.metric_key = mr.m_key
      ), 10), 10) then 'watch'
      when mr.m_total < 30 then 'limited'
      else 'strong'
    end,
    mr.eligible_n > 0 and mr.n::double precision / mr.eligible_n < 0.30,
    w.low,
    w.high,
    2
  from metric_rows mr
  left join lateral public.dss_wilson(mr.m_hits, mr.m_total) w
    on mr.m_kind = 'share' and mr.m_total > 0
  order by mr.g_order, mr.g_course collate "C", mr.g_batch collate "C", mr.m_order;
end;
$$;

revoke all on function public.dss_cohort_metrics(uuid) from public, anon;
grant execute on function public.dss_cohort_metrics(uuid) to authenticated, service_role;

notify pgrst, 'reload schema';
