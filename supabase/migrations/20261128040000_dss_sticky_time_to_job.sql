-- Sticky once-per-cohort for TIME_TO_JOB_LONG: do not re-raise / supersede the
-- same course×batch on later tracers (Q29 is a historical first-job fact).
-- Watch→Finding upgrades on a later wave still raise and may supersede Watch.

begin;

create or replace function public.dss_is_sticky_once_per_cohort_rule(p_rule_id text)
returns boolean
language sql
immutable
parallel safe
as $$
  select coalesce(p_rule_id, '') = 'TIME_TO_JOB_LONG';
$$;

comment on function public.dss_is_sticky_once_per_cohort_rule(text) is
  'Rules that raise at most once per finding key across tracer waves '
  '(except Watch→Finding upgrades). Currently TIME_TO_JOB_LONG only.';

revoke all on function public.dss_is_sticky_once_per_cohort_rule(text) from public, anon;
grant execute on function public.dss_is_sticky_once_per_cohort_rule(text) to authenticated, service_role;

alter table public.dss_evaluation_events
  drop constraint if exists dss_evaluation_events_reason_check;

alter table public.dss_evaluation_events
  add constraint dss_evaluation_events_reason_check
  check (reason in (
    'finding', 'watch', 'data_quality',
    'refreshed', 'became_finding', 'became_watch',
    'not_enough_data', 'closed_in_wave', 'superseded_in_wave', 'newer_wave',
    'newer_wave_raised', 'newer_wave_clear',
    'sticky_prior_finding'
  ));

CREATE OR REPLACE FUNCTION public.dss_evaluate_all(p_trigger text DEFAULT 'manual'::text, p_dry_run boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
 SET extra_float_digits TO '3'
AS $function$
declare
  c_bnr constant text := 'Batch not recorded';
  c_note_author constant text := 'DSS evaluation';
  v_uid uuid := auth.uid();
  v_trigger text := coalesce(nullif(btrim(p_trigger), ''), 'manual');
  v_now timestamptz := now();
  v_run uuid := gen_random_uuid();
  v_dq record;
  v_tr record;
  g record;
  r record;
  w record;
  pw record;
  p record;
  x record;
  v_have_prev boolean := false;
  v_key text;
  v_hits integer;
  v_total integer;
  v_n integer;
  v_metric double precision;
  v_rate double precision;
  v_strength text;
  v_spec jsonb;
  v_q17 jsonb;
  v_evidence jsonb;
  v_body text;
  v_low double precision;
  v_high double precision;
  v_cur_rate double precision;
  v_prev_rate double precision;
  v_prev_hits integer;
  v_prev_total integer;
  v_cur_low double precision;
  v_cur_high double precision;
  v_prev_low double precision;
  v_prev_high double precision;
  v_eligible integer;
  v_registered integer;
  v_group_n integer;
  v_label text;
  v_sparse boolean;
  v_low_rate boolean;
  v_reason text;
  v_pct text;
  v_peer double precision;
  v_fid uuid;
  v_fstatus text;
  v_snapshots integer := 0;
  v_result jsonb;
begin
  -- Admins run it from the app (always logged as manual); the cron job and
  -- the service role run it without a user.
  if v_uid is not null or coalesce(auth.role(), '') in ('anon', 'authenticated') then
    if not public.is_admin() then
      raise exception 'Admin access required.' using errcode = '42501';
    end if;
    v_trigger := 'manual';
  end if;
  if v_trigger not in ('manual', 'scheduled') then
    raise exception 'Unknown run trigger: %', v_trigger using errcode = '22023';
  end if;
  if not p_dry_run
     and not pg_try_advisory_xact_lock(hashtext('aess.dss_evaluate_all')) then
    raise exception 'Another DSS evaluation is running. Try again in a minute.'
      using errcode = '55P03';
  end if;

  drop table if exists pg_temp.ev_rules, pg_temp.ev_waves, pg_temp.ev_roster_now,
    pg_temp.ev_roster, pg_temp.ev_resp, pg_temp.ev_sizes, pg_temp.ev_plan,
    pg_temp.ev_groups, pg_temp.ev_member, pg_temp.ev_gm, pg_temp.ev_pairs,
    pg_temp.ev_rows, pg_temp.ev_checked, pg_temp.ev_suppressed, pg_temp.ev_stored,
    pg_temp.ev_latest, pg_temp.ev_actions;

  -- Rules ------------------------------------------------------------------
  create temp table ev_rules on commit drop as
  select
    d.rule_id,
    case d.rule_id when 'UNEMPLOYMENT_HIGH' then 'Not currently employed' else d.name end as display_name,
    d.category,
    coalesce(d.operator, 'gte') as operator,
    d.threshold::double precision as threshold,
    d.min_n,
    greatest(d.min_n, case when d.category = 'data_quality' then 1 else 10 end) as rule_min,
    coalesce(d.recommended_action, '') as recommended_action
  from public.dss_rules d
  where d.enabled;

  if not exists (select 1 from pg_temp.ev_rules) then
    return jsonb_build_object('dry_run', p_dry_run, 'trigger', v_trigger,
      'no_rules', true, 'message', 'No enabled DSS rules.');
  end if;

  -- Waves ------------------------------------------------------------------
  create temp table ev_waves on commit drop as
  select
    s.id as survey_id,
    s.id::text as sid,
    coalesce(s.title, '') as title,
    public.survey_first_published_at(s.data, s.open_at, s.created_at) as wave_date,
    (s.status = 'published'
      and (s.open_at is null or s.open_at <= v_now)
      and (s.close_at is null or s.close_at >= v_now)) as accepts,
    coalesce(s.target_programs, '{}'::text[]) as target_programs,
    coalesce(s.target_batch_years, '{}'::text[]) as target_batch_years,
    false as has_responses,
    false as is_newest,
    'current'::text as basis
  from public.surveys s
  where public.survey_is_ched_tracer(s.data)
    and coalesce(s.data ->> 'archived', '') <> 'true'
    and s.status in ('published', 'closed');

  update pg_temp.ev_waves wv
  set basis = case
    when wv.accepts then 'open_wave'
    when exists (select 1 from public.dss_wave_cohort_snapshots ws where ws.survey_id = wv.survey_id)
      then 'snapshot'
    else 'current'
  end
  where true;

  update pg_temp.ev_waves wv set is_newest = true
  where wv.survey_id = (
    select w2.survey_id from pg_temp.ev_waves w2 order by w2.wave_date desc, w2.sid limit 1);

  -- Roster -----------------------------------------------------------------
  create temp table ev_roster_now on commit drop as
  select
    btrim(m.course) as course,
    coalesce(nullif(btrim(m.year_graduated), ''), c_bnr) as batch,
    count(*)::integer as total,
    count(*) filter (
      where coalesce(m.is_registered_user, false)
         or nullif(btrim(m.auth_uid::text), '') is not null
    )::integer as registered
  from public.alumni_members m
  where not coalesce(m.is_deactivated, false)
    and nullif(btrim(m.course), '') is not null
  group by 1, 2;

  -- Responses (one per alumnus per wave) ------------------------------------
  create temp table ev_resp on commit drop as
  select
    q.*,
    case
      when q.q16 = 'Yes' then 'employed'
      when q.q16 in ('No', 'Never Employed') then case
        when cardinality(q.q17) = 0 then 'unknown'
        when 'Did not look for a job' = any (q.q17) then 'not_seeking'
        when q.q17 && array['No job opportunity', 'Lack of work experience'] then 'seeking'
        else 'not_seeking'
      end
    end as labour
  from (
    select
      sr.survey_id,
      sr.id as response_id,
      row_number() over (
        partition by sr.survey_id order by coalesce(sr.submitted_at, sr.updated_at), sr.id
      ) as ord,
      nullif(btrim(mb.course), '') as course,
      coalesce(nullif(btrim(mb.year_graduated), ''), c_bnr) as batch,
      nullif(btrim(mb.course), '') is not null as classified,
      public.gts_single(sr.answers -> 'ched_16') as q16,
      public.gts_multi(sr.answers -> 'ched_17') as q17,
      public.gts_single(sr.answers -> 'ched_24a') as q24,
      public.gts_single(sr.answers -> 'ched_32') as q32,
      public.gts_single(sr.answers -> 'ched_28') as q28,
      public.gts_single(sr.answers -> 'ched_29') as q29,
      public.gts_job_level(sr.answers -> 'ched_30') as q30,
      public.gts_job_level_first(sr.answers -> 'ched_30') as q30_first,
      public.gts_salary_rank(public.gts_single(sr.answers -> 'ched_31')) as salary_rank,
      btrim(coalesce(sr.answers ->> 'ched_34', '')) as q34
    from public.survey_responses sr
    join pg_temp.ev_waves wv on wv.survey_id = sr.survey_id
    left join lateral (
      select am.course, am.year_graduated
      from public.alumni_members am
      where not coalesce(am.is_deactivated, false)
        and nullif(btrim(am.auth_uid::text), '') = sr.user_id::text
      order by am.id
      limit 1
    ) mb on true
    where sr.status = 'submitted'
      and sr.user_id is not null
  ) q;

  alter table pg_temp.ev_resp add column bucket_ord bigint;
  update pg_temp.ev_resp x0 set bucket_ord = b.first_ord
  from (
    select survey_id, course, batch, min(ord) as first_ord
    from pg_temp.ev_resp where classified group by 1, 2, 3
  ) b
  where x0.classified and b.survey_id = x0.survey_id
    and b.course = x0.course and b.batch = x0.batch;

  update pg_temp.ev_waves wv set has_responses = true
  where exists (select 1 from pg_temp.ev_resp x0 where x0.survey_id = wv.survey_id);

  -- Roster used for each wave's rates: today's while the wave is open or
  -- when no snapshot was saved, otherwise the snapshot.
  create temp table ev_roster on commit drop as
  select wv.survey_id, ro.course, ro.batch, ro.total, ro.registered
  from pg_temp.ev_waves wv
  cross join lateral (
    select ws.course, ws.batch_year as batch, ws.roster_count as total, ws.registered_count as registered
    from public.dss_wave_cohort_snapshots ws
    where wv.basis = 'snapshot' and ws.survey_id = wv.survey_id
    union all
    select rn.course, rn.batch, rn.total, rn.registered
    from pg_temp.ev_roster_now rn
    where wv.basis <> 'snapshot'
  ) ro
  where wv.has_responses or wv.is_newest;

  create temp table ev_sizes on commit drop as
  select survey_id, course, batch, count(*)::integer as n
  from pg_temp.ev_resp
  where classified
  group by 1, 2, 3;

  -- Roll-up plan per outcome / opportunity rule ------------------------------
  create temp table ev_plan on commit drop as
  with cs as (
    select z.survey_id, z.course, rl.rule_id, rl.rule_min, sum(z.n) as total,
           bool_or(z.batch = c_bnr or z.n < rl.rule_min) as has_small
    from pg_temp.ev_sizes z
    cross join pg_temp.ev_rules rl
    where rl.category in ('outcome', 'opportunity')
    group by z.survey_id, z.course, rl.rule_id, rl.rule_min
  )
  select cs.survey_id, cs.rule_id, cs.course, false as inst
  from cs
  where cs.has_small and cs.total >= cs.rule_min
  union all
  select cs.survey_id, cs.rule_id, null::text, true
  from cs
  where cs.has_small and cs.total < cs.rule_min
  group by cs.survey_id, cs.rule_id, cs.rule_min
  having (select sum(z2.n) from pg_temp.ev_sizes z2 where z2.survey_id = cs.survey_id) >= cs.rule_min;

  -- Groups -------------------------------------------------------------------
  create temp table ev_groups (
    gid serial primary key,
    survey_id uuid not null,
    level text not null,
    course text not null,
    batch_year text not null,
    label text not null,
    eligible integer not null,
    registered integer not null,
    n integer not null,
    is_dq boolean not null,
    is_outcome boolean not null
  ) on commit drop;

  -- every course x batch with respondents
  insert into pg_temp.ev_groups (survey_id, level, course, batch_year, label, eligible, registered, n, is_dq, is_outcome)
  select z.survey_id, 'batch', z.course, z.batch, z.course || ' · Batch ' || z.batch,
         coalesce(ro.total, z.n), coalesce(ro.registered, 0), z.n, true, true
  from pg_temp.ev_sizes z
  left join pg_temp.ev_roster ro
    on ro.survey_id = z.survey_id and ro.course = z.course and ro.batch = z.batch
  where z.batch <> c_bnr
  order by z.survey_id, z.course, z.batch;

  -- newest wave: roster groups with no responses that the survey targets
  insert into pg_temp.ev_groups (survey_id, level, course, batch_year, label, eligible, registered, n, is_dq, is_outcome)
  select ro.survey_id, 'batch', ro.course, ro.batch, ro.course || ' · Batch ' || ro.batch,
         ro.total, ro.registered, 0, true, false
  from pg_temp.ev_roster ro
  join pg_temp.ev_waves wv on wv.survey_id = ro.survey_id and wv.is_newest
  where ro.batch <> c_bnr
    and ro.total >= 1
    and not exists (
      select 1 from pg_temp.ev_sizes z
      where z.survey_id = ro.survey_id and z.course = ro.course and z.batch = ro.batch)
    and substring(ro.batch from '\d{4}') is not null
    and substring(ro.batch from '\d{4}')::integer
        <= extract(year from wv.wave_date at time zone 'Asia/Manila')::integer
    and public.survey_audience_matches(wv.target_programs, wv.target_batch_years, ro.course, ro.batch)
  order by ro.course, ro.batch;

  -- whole courses that hold a rule's small batches
  insert into pg_temp.ev_groups (survey_id, level, course, batch_year, label, eligible, registered, n, is_dq, is_outcome)
  select c.survey_id, 'course', c.course, 'All', c.course || ' (all batches)',
         coalesce((select sum(ro.total) from pg_temp.ev_roster ro
                   where ro.survey_id = c.survey_id and ro.course = c.course), 0),
         coalesce((select sum(ro.registered) from pg_temp.ev_roster ro
                   where ro.survey_id = c.survey_id and ro.course = c.course), 0),
         (select sum(z.n) from pg_temp.ev_sizes z where z.survey_id = c.survey_id and z.course = c.course),
         false, true
  from (select distinct pl.survey_id, pl.course from pg_temp.ev_plan pl where not pl.inst) c
  order by c.survey_id, c.course;

  -- the whole institution, when a rule has courses that are still too small
  insert into pg_temp.ev_groups (survey_id, level, course, batch_year, label, eligible, registered, n, is_dq, is_outcome)
  select i.survey_id, 'institution', 'All', 'All', 'the whole institution',
         coalesce((select sum(ro.total) from pg_temp.ev_roster ro where ro.survey_id = i.survey_id), 0),
         coalesce((select sum(ro.registered) from pg_temp.ev_roster ro where ro.survey_id = i.survey_id), 0),
         (select sum(z.n) from pg_temp.ev_sizes z where z.survey_id = i.survey_id),
         false, true
  from (select distinct pl.survey_id from pg_temp.ev_plan pl where pl.inst) i;

  create temp table ev_member on commit drop as
  select gg.gid, x0.response_id
  from pg_temp.ev_groups gg
  join pg_temp.ev_resp x0
    on x0.survey_id = gg.survey_id
   and x0.classified
   and (gg.level = 'institution'
        or (x0.course = gg.course and (gg.level = 'course' or x0.batch = gg.batch_year)))
  where gg.is_outcome;

  create temp table ev_gm on commit drop as
  select
    mm.gid,
    count(*) filter (where x0.q16 in ('No', 'Never Employed'))::integer as unemp_hits,
    count(x0.q16)::integer as unemp_total,
    count(*) filter (where x0.labour = 'employed')::integer as employed,
    count(*) filter (where x0.labour = 'seeking')::integer as q17_seeking,
    count(*) filter (where x0.labour = 'not_seeking')::integer as q17_not_seeking,
    count(*) filter (where x0.labour = 'unknown')::integer as q17_unknown,
    count(*) filter (where x0.q24 = 'No' or x0.q32 = 'No')::integer as mismatch,
    count(*) filter (where x0.q24 is not null or x0.q32 is not null)::integer as related_total,
    array_agg(x0.q34 order by x0.bucket_ord, x0.ord)
      filter (where (x0.q24 = 'No' or x0.q32 = 'No') and x0.q34 <> '') as suggestions,
    count(*) filter (where x0.q16 = 'Yes' and x0.q30 = 'Rank or Clerical')::integer as clerical,
    count(*) filter (where x0.q16 = 'Yes' and x0.q30 is not null)::integer as level_total,
    count(*) filter (
      where x0.q24 = 'No' and x0.q30_first = 'Rank or Clerical'
    )::integer as qual_mismatch,
    count(*) filter (
      where x0.q24 is not null and x0.q30_first is not null
    )::integer as qual_total,
    count(*) filter (where x0.q29 in (
      '7 to 11 months',
      '1 year to less than 2 years',
      '2 years to less than 3 years',
      '3 years to less than 4 years'))::integer as long_wait,
    count(*) filter (where x0.q29 is not null and x0.q29 not like 'Others%')::integer as wait_total,
    count(*) filter (where x0.q29 like 'Others%')::integer as wait_others,
    count(*) filter (where x0.q28 in (
      'Arranged by school''s job placement officer',
      'Job Fair or Public Employment Service Office (PESO)'
    ))::integer as placement_hits,
    count(*) filter (where x0.q28 is not null and x0.q28 not like 'Others%')::integer as placement_total,
    count(*) filter (where x0.q28 like 'Others%')::integer as placement_others,
    count(*) filter (where x0.salary_rank is not null and x0.salary_rank <= 1)::integer as low_salary,
    count(x0.salary_rank)::integer as salary_n,
    percentile_cont(0.5) within group (order by x0.salary_rank) as salary_median
  from pg_temp.ev_member mm
  join pg_temp.ev_resp x0 on x0.response_id = mm.response_id
  group by mm.gid;

  create temp table ev_rows (
    row_id serial primary key,
    finding_key text not null,
    sid text not null,
    rule_id text not null,
    cohort_level text not null,
    course text not null,
    batch_year text not null,
    survey_title text not null,
    metric_value double precision not null,
    threshold double precision not null,
    sample_n integer not null,
    eligible_n integer,
    confidence text not null,
    title text not null,
    body text not null,
    recommended_action text not null,
    evidence jsonb not null,
    status text not null
  ) on commit drop;
  create temp table ev_checked (finding_key text not null, sid text not null) on commit drop;
  create temp table ev_suppressed (finding_key text not null, sid text not null, valid_answers integer not null) on commit drop;

  -- Data quality: response rate / too few responses per course x batch ------
  select * into v_dq from pg_temp.ev_rules where rule_id = 'DATA_QUALITY_LOW';
  if found then
    for g in
      select gg.gid, gg.survey_id, gg.course, gg.batch_year, gg.label, gg.eligible, gg.registered, gg.n,
             wv.sid, wv.title as wave_title, wv.basis
      from pg_temp.ev_groups gg
      join pg_temp.ev_waves wv on wv.survey_id = gg.survey_id
      where gg.is_dq
      order by gg.gid
    loop
      v_key := 'DATA_QUALITY_LOW|batch|' || g.course || '|' || g.batch_year;
      insert into pg_temp.ev_checked values (v_key, g.sid);
      v_rate := case when g.eligible > 0 then g.n::double precision / g.eligible else 0 end;
      v_low_rate := public.dss_crosses_float(v_dq.operator, v_rate, v_dq.threshold);
      v_sparse := g.n < v_dq.rule_min;
      continue when not v_low_rate and not v_sparse;

      v_reason := case when v_low_rate and v_sparse then 'both' when v_sparse then 'sparse' else 'low_rate' end;
      v_pct := public.dss_fixed(v_rate * 100, 0);
      insert into pg_temp.ev_rows (finding_key, sid, rule_id, cohort_level, course, batch_year,
        survey_title, metric_value, threshold, sample_n, eligible_n, confidence, title, body,
        recommended_action, evidence, status)
      values (
        v_key, g.sid, 'DATA_QUALITY_LOW', 'batch', g.course, g.batch_year, g.wave_title,
        v_rate, v_dq.threshold, g.n, g.eligible, 'ok',
        case v_reason
          when 'sparse' then 'Too few survey responses: '
          when 'low_rate' then 'Low survey response rate: '
          else 'Weak survey coverage: '
        end || g.label,
        case v_reason
          when 'sparse' then
            g.n || ' alumni in ' || g.label || ' answered "' || g.wave_title
            || '". That is below the minimum of ' || v_dq.rule_min
            || ' responses needed before outcome findings are reliable'
            || case when g.eligible > g.n then ' (roster in this group: ' || g.eligible || ')' else '' end
            || '.'
          when 'low_rate' then
            'Only ' || v_pct || '% of alumni on the roster for ' || g.label || ' answered "'
            || g.wave_title || '" (' || g.n || ' of ' || g.eligible || '). Coverage is below the '
            || public.dss_fixed(v_dq.threshold * 100, 0) || '% target.'
          else
            g.label || ' has weak coverage for "' || g.wave_title || '": ' || g.n || ' of '
            || g.eligible || ' on the roster answered (' || v_pct
            || '%). Raise participation before trusting employment outcome flags.'
        end,
        case v_reason
          when 'sparse' then 'Collect more tracer responses from this course/batch before acting on employment or curriculum findings.'
          when 'low_rate' then 'Send reminders to alumni who have not submitted the tracer survey, then refresh insights.'
          else 'Improve survey participation for this cohort, then refresh insights before using outcome flags.'
        end,
        jsonb_build_object(
          'response_rate', v_rate,
          'respondents', g.n,
          'eligible_roster', g.eligible,
          'registered_roster', g.registered,
          'roster_scope', 'whole_roster',
          'roster_basis', g.basis,
          'reason', v_reason,
          'min_responses_required', v_dq.rule_min)
        || case when v_sparse then '{"sparse_sample": true}'::jsonb else '{}'::jsonb end,
        'open'
      );
    end loop;
  end if;

  -- Outcome and opportunity rules per group ---------------------------------
  for g in
    select gg.gid, gg.survey_id, gg.level, gg.course, gg.batch_year, gg.label, gg.eligible,
           gg.registered, gg.n,
           case when gg.eligible > 0 then gg.n::double precision / gg.eligible end as rate,
           wv.sid, wv.title as wave_title, wv.basis,
           m.unemp_hits, m.unemp_total, m.employed, m.q17_seeking, m.q17_not_seeking,
           m.q17_unknown, m.mismatch, m.related_total, m.suggestions, m.clerical,
           m.level_total, m.qual_mismatch, m.qual_total, m.long_wait, m.wait_total,
           m.wait_others, m.placement_hits, m.placement_total, m.placement_others,
           m.low_salary, m.salary_n, m.salary_median
    from pg_temp.ev_groups gg
    join pg_temp.ev_waves wv on wv.survey_id = gg.survey_id
    join pg_temp.ev_gm m on m.gid = gg.gid
    where gg.is_outcome
    order by gg.gid
  loop
    for r in
      select * from pg_temp.ev_rules where category in ('outcome', 'opportunity') order by rule_id
    loop
      if g.level = 'course' and not exists (
           select 1 from pg_temp.ev_plan pl
           where pl.survey_id = g.survey_id and pl.rule_id = r.rule_id and pl.course = g.course) then
        continue;
      end if;
      if g.level = 'institution' and (r.rule_id = 'SALARY_STAGNATION' or not exists (
           select 1 from pg_temp.ev_plan pl
           where pl.survey_id = g.survey_id and pl.rule_id = r.rule_id and pl.inst)) then
        continue;
      end if;

      v_hits := null;
      v_total := null;
      v_metric := null;
      v_body := null;
      v_peer := null;
      case r.rule_id
        when 'UNEMPLOYMENT_HIGH' then
          if g.unemp_total > 0 then
            v_hits := g.unemp_hits;
            v_total := g.unemp_total;
            v_metric := v_hits::double precision / v_total;
            v_body := public.dss_fixed(v_metric * 100, 1) || '% of ' || v_total || ' respondents in '
              || g.label || ' are not currently employed'
              || case when v_hits > 0 then '; ' || g.q17_seeking || ' of them '
                   || case when g.q17_seeking = 1 then 'is' else 'are' end || ' looking for work'
                 else '' end
              || '.';
          end if;
        when 'SEEKING_WORK_HIGH' then
          if g.employed + g.q17_seeking > 0 then
            v_hits := g.q17_seeking;
            v_total := g.employed + g.q17_seeking;
            v_metric := v_hits::double precision / v_total;
            v_body := public.dss_fixed(v_metric * 100, 1) || '% of ' || v_total || ' respondents in '
              || g.label || ' who are employed or looking for work are looking for work '
              || '(no job opportunity or lack of work experience).';
          end if;
        when 'RELATEDNESS_LOW' then
          if g.related_total > 0 then
            v_hits := g.mismatch;
            v_total := g.related_total;
            v_metric := v_hits::double precision / v_total;
            v_body := public.dss_fixed(v_metric * 100, 1) || '% of ' || v_total
              || ' respondents report course/curriculum mismatch for ' || g.label || '.';
          end if;
        when 'RELATEDNESS_HIGH' then
          if g.related_total > 0 then
            v_hits := g.related_total - g.mismatch;
            v_total := g.related_total;
            v_metric := v_hits::double precision / v_total;
            v_body := public.dss_fixed(v_metric * 100, 1) || '% of ' || v_total
              || ' respondents report strong course/curriculum alignment for ' || g.label || '.';
          end if;
        when 'UNDEREMPLOYMENT' then
          if g.level_total > 0 then
            v_hits := g.clerical;
            v_total := g.level_total;
            v_metric := v_hits::double precision / v_total;
            v_body := public.dss_fixed(v_metric * 100, 1) || '% of ' || v_total
              || ' employed respondents report Rank/Clerical roles (' || g.label || ').';
          end if;
        when 'QUALIFICATION_MISMATCH' then
          if g.qual_total > 0 then
            v_hits := g.qual_mismatch;
            v_total := g.qual_total;
            v_metric := v_hits::double precision / v_total;
            v_body := public.dss_fixed(v_metric * 100, 1) || '% of ' || v_total
              || ' respondents report a first job unrelated to their course and at '
              || 'Rank/Clerical level (' || g.label || ').';
          end if;
        when 'TIME_TO_JOB_LONG' then
          if g.wait_total > 0 then
            v_hits := g.long_wait;
            v_total := g.wait_total;
            v_metric := v_hits::double precision / v_total;
            v_body := public.dss_fixed(v_metric * 100, 1) || '% of ' || v_total
              || ' respondents took longer than 6 months to land a first job ('
              || g.label || ').';
          end if;
        when 'PLACEMENT_CHANNEL_LOW' then
          if g.placement_total > 0 then
            v_hits := g.placement_hits;
            v_total := g.placement_total;
            v_metric := v_hits::double precision / v_total;
            v_body := public.dss_fixed(v_metric * 100, 1) || '% of ' || v_total
              || ' respondents found their first job through the school placement '
              || 'office or a Job Fair/PESO (' || g.label || ').';
          end if;
        when 'SALARY_LOW_ENTRY' then
          if g.salary_n > 0 then
            v_hits := g.low_salary;
            v_total := g.salary_n;
            v_metric := v_hits::double precision / v_total;
            v_body := public.dss_fixed(v_metric * 100, 1) || '% of ' || v_total
              || ' respondents started in the bottom two first-job salary brackets ('
              || g.label || ').';
          end if;
        when 'SALARY_STAGNATION' then
          if g.salary_n > 0 then
            select percentile_cont(0.5) within group (order by x0.salary_rank)
            into v_peer
            from pg_temp.ev_resp x0
            where x0.survey_id = g.survey_id and x0.classified
              and x0.course <> g.course and x0.salary_rank is not null;
            if v_peer is not null then
              v_metric := v_peer - g.salary_median;
              v_n := g.salary_n;
              v_body := 'First-job salary for ' || g.label || ' is ' || public.dss_fixed(v_metric, 1)
                || ' bracket(s) below the median of other courses in this wave.';
            end if;
          end if;
        else
          null;
      end case;
      continue when v_metric is null;
      if v_total is not null then
        v_n := v_total;
      end if;

      v_strength := case
        when v_n < 5 then 'insufficient'
        when v_n < greatest(r.min_n, 10) then 'watch'
        when v_n < 30 then 'limited'
        else 'strong'
      end;
      v_key := r.rule_id || '|' || g.level || '|' || g.course || '|' || g.batch_year;
      if v_strength = 'insufficient' then
        insert into pg_temp.ev_suppressed values (v_key, g.sid, v_n);
        continue;
      end if;
      insert into pg_temp.ev_checked values (v_key, g.sid);
      continue when not public.dss_crosses_float(r.operator, v_metric, r.threshold);

      if r.rule_id in ('UNEMPLOYMENT_HIGH', 'SEEKING_WORK_HIGH') then
        v_q17 := jsonb_build_object(
          'seeking', g.q17_seeking,
          'not_seeking', g.q17_not_seeking,
          'reason_unknown', g.q17_unknown,
          'reasons', (
            select coalesce(jsonb_object_agg(b.v, b.c), '{}'::jsonb)
            from (
              select u.v, count(*) as c
              from pg_temp.ev_member mm
              join pg_temp.ev_resp x0 on x0.response_id = mm.response_id
              cross join unnest(x0.q17) as u(v)
              where mm.gid = g.gid and x0.q16 in ('No', 'Never Employed')
              group by u.v
            ) b));
      end if;

      v_spec := case r.rule_id
        when 'UNEMPLOYMENT_HIGH' then jsonb_build_object(
          'question', 'ched_16',
          'not_employed', v_hits,
          'answered', v_total,
          'breakdown', (
            select coalesce(jsonb_object_agg(b.v, b.c), '{}'::jsonb)
            from (
              select x0.q16 as v, count(*) as c
              from pg_temp.ev_member mm
              join pg_temp.ev_resp x0 on x0.response_id = mm.response_id
              where mm.gid = g.gid and x0.q16 is not null
              group by x0.q16
            ) b),
          'q17', v_q17)
        when 'SEEKING_WORK_HIGH' then jsonb_build_object(
          'questions', jsonb_build_array('ched_16', 'ched_17'),
          'seeking', v_hits,
          'labour_force', v_total,
          'q17', v_q17)
        when 'RELATEDNESS_LOW' then jsonb_build_object(
          'questions', jsonb_build_array('ched_24a', 'ched_32'),
          'mismatch_count', v_hits,
          'answered', v_total,
          'suggestion_count', coalesce(cardinality(g.suggestions), 0),
          'suggestion_themes', public.dss_theme_hints(g.suggestions),
          'suggestion_samples', to_jsonb(coalesce(g.suggestions[1:5], '{}'::text[])))
        when 'RELATEDNESS_HIGH' then jsonb_build_object(
          'questions', jsonb_build_array('ched_24a', 'ched_32'),
          'aligned_count', v_hits,
          'answered', v_total)
        when 'UNDEREMPLOYMENT' then jsonb_build_object(
          'question', 'ched_30',
          'clerical', v_hits,
          'employed_with_level', v_total)
        when 'QUALIFICATION_MISMATCH' then jsonb_build_object(
          'questions', jsonb_build_array('ched_24a', 'ched_30'),
          'mismatch_clerical', v_hits,
          'answered', v_total,
          'first_job_column', '30.1. First Job',
          'note', 'Tracer proxy: Q24 No and Q30.1 Rank/Clerical. Not a CHED or '
                  || 'PSA certified underemployment definition.')
        when 'TIME_TO_JOB_LONG' then jsonb_build_object(
          'question', 'ched_29',
          'long_count', v_hits,
          'answered', v_total,
          'breakdown', (
            select coalesce(jsonb_object_agg(b.v, b.c), '{}'::jsonb)
            from (
              select x0.q29 as v, count(*) as c
              from pg_temp.ev_member mm
              join pg_temp.ev_resp x0 on x0.response_id = mm.response_id
              where mm.gid = g.gid and x0.q29 is not null and x0.q29 not like 'Others%'
              group by x0.q29
            ) b))
          || case when g.wait_others > 0
               then jsonb_build_object('others_excluded', g.wait_others) else '{}'::jsonb end
        when 'PLACEMENT_CHANNEL_LOW' then jsonb_build_object(
          'question', 'ched_28',
          'institutional_count', v_hits,
          'answered', v_total,
          'channels', jsonb_build_array(
            'Arranged by school''s job placement officer',
            'Job Fair or Public Employment Service Office (PESO)'),
          'breakdown', (
            select coalesce(jsonb_object_agg(b.v, b.c), '{}'::jsonb)
            from (
              select x0.q28 as v, count(*) as c
              from pg_temp.ev_member mm
              join pg_temp.ev_resp x0 on x0.response_id = mm.response_id
              where mm.gid = g.gid and x0.q28 is not null and x0.q28 not like 'Others%'
              group by x0.q28
            ) b))
          || case when g.placement_others > 0
               then jsonb_build_object('others_excluded', g.placement_others) else '{}'::jsonb end
        when 'SALARY_LOW_ENTRY' then jsonb_build_object(
          'question', 'ched_31',
          'low_count', v_hits,
          'answered', v_total,
          'brackets', jsonb_build_array(
            'Below P5,000.00',
            'P5,000.00 to less than P10,000.00'))
        when 'SALARY_STAGNATION' then jsonb_build_object(
          'question', 'ched_31',
          'cohort_median_rank', g.salary_median,
          'peer_median_rank', v_peer,
          'peer_scope', 'other_courses',
          'answered', g.salary_n,
          'note', 'Gap is the median salary rank of other courses in this wave minus the '
                  || 'cohort median; ≥1 means at least one bracket below.')
        else jsonb_build_object('question', 'unknown')
      end;

      v_evidence := v_spec
        || jsonb_build_object(
             'source', 'ched_gts',
             'valid_answers', v_n,
             'not_answered', greatest(0, g.n - v_n),
             'evidence_strength', v_strength,
             'registered_roster', g.registered,
             'roster_basis', g.basis)
        || case when g.rate is not null then jsonb_build_object('response_rate', g.rate) else '{}'::jsonb end
        || case when g.rate < 0.30 then '{"coverage_warning": true}'::jsonb else '{}'::jsonb end;

      if v_total is not null then
        select wl.low, wl.high into v_low, v_high from public.dss_wilson(v_hits, v_total) wl;
        v_evidence := v_evidence || jsonb_build_object(
          'ci_low', v_low,
          'ci_high', v_high,
          'ci_level', 0.95,
          'certainty', case
            when public.dss_crosses_float(r.operator,
                   case when r.operator in ('lt', 'lte') then v_high else v_low end, r.threshold)
              then 'confirmed' else 'possible' end);
      end if;

      if g.level = 'course' then
        v_evidence := v_evidence || jsonb_build_object(
          'rolled_up', true,
          'small_groups', (
            select coalesce(jsonb_object_agg(z.batch, z.n), '{}'::jsonb)
            from pg_temp.ev_sizes z
            where z.survey_id = g.survey_id and z.course = g.course
              and (z.batch = c_bnr or z.n < r.rule_min)),
          'min_responses_required', r.rule_min);
      elsif g.level = 'institution' then
        v_evidence := v_evidence || jsonb_build_object(
          'rolled_up', true,
          'small_groups', (
            select coalesce(jsonb_object_agg(c.course, c.total), '{}'::jsonb)
            from (
              select z.course, sum(z.n) as total
              from pg_temp.ev_sizes z
              where z.survey_id = g.survey_id
              group by z.course
              having sum(z.n) < r.rule_min
            ) c),
          'min_responses_required', r.rule_min);
      end if;

      insert into pg_temp.ev_rows (finding_key, sid, rule_id, cohort_level, course, batch_year,
        survey_title, metric_value, threshold, sample_n, eligible_n, confidence, title, body,
        recommended_action, evidence, status)
      values (
        v_key, g.sid, r.rule_id, g.level, g.course, g.batch_year, g.wave_title,
        v_metric, r.threshold, g.n, g.eligible,
        case when v_strength = 'strong' and not coalesce(g.rate < 0.30, false) then 'ok' else 'low' end,
        r.display_name || ': ' || g.label,
        case when v_strength = 'watch' then 'Watch (small sample): ' else '' end || v_body,
        r.recommended_action,
        v_evidence,
        case when v_strength = 'watch' then 'watch' else 'open' end
      );
    end loop;
  end loop;

  -- Trend: each wave against the wave before it ------------------------------
  create temp table ev_pairs (level text, course text, batch_year text) on commit drop;
  select * into v_tr from pg_temp.ev_rules where rule_id = 'UNEMPLOYMENT_TREND_UP';
  if found and (select count(*) from pg_temp.ev_waves where has_responses) > 1 then
    for w in
      select * from pg_temp.ev_waves where has_responses order by wave_date, sid
    loop
      if v_have_prev then
        delete from pg_temp.ev_pairs;

        -- course x batch groups surveyed in both waves
        insert into pg_temp.ev_pairs
        select 'batch', z.course, z.batch
        from pg_temp.ev_sizes z
        where z.survey_id = w.survey_id and z.batch <> c_bnr
          and exists (
            select 1 from pg_temp.ev_sizes z2
            where z2.survey_id = pw.survey_id and z2.course = z.course and z2.batch = z.batch);

        -- batches that cannot be compared are covered by the course, else
        -- by the institution
        with k as (
          select coalesce(a.course, b.course) as course,
                 coalesce(a.batch, b.batch) as batch,
                 coalesce(a.n, 0) as cn,
                 coalesce(b.n, 0) as pn
          from (select * from pg_temp.ev_sizes where survey_id = w.survey_id) a
          full join (select * from pg_temp.ev_sizes where survey_id = pw.survey_id) b
            on a.course = b.course and a.batch = b.batch
        ),
        cs as (
          select k.course, sum(k.cn) as ct, sum(k.pn) as pt,
                 bool_or(not (k.batch <> c_bnr and k.cn >= v_tr.rule_min and k.pn >= v_tr.rule_min)) as uncovered
          from k
          group by k.course
        )
        insert into pg_temp.ev_pairs
        select 'course', cs.course, 'All'
        from cs
        where cs.uncovered and cs.ct >= v_tr.rule_min and cs.pt >= v_tr.rule_min
        union all
        select 'institution', 'All', 'All'
        where exists (
            select 1 from cs
            where cs.uncovered and not (cs.ct >= v_tr.rule_min and cs.pt >= v_tr.rule_min))
          and (select coalesce(sum(n), 0) from pg_temp.ev_sizes where survey_id = w.survey_id) >= v_tr.rule_min
          and (select coalesce(sum(n), 0) from pg_temp.ev_sizes where survey_id = pw.survey_id) >= v_tr.rule_min;

        for p in select * from pg_temp.ev_pairs order by level, course, batch_year loop
          select count(*) filter (where x0.q16 in ('No', 'Never Employed'))::integer,
                 count(x0.q16)::integer,
                 count(*)::integer
          into v_hits, v_total, v_group_n
          from pg_temp.ev_resp x0
          where x0.survey_id = w.survey_id and x0.classified
            and (p.level = 'institution'
                 or (x0.course = p.course and (p.level = 'course' or x0.batch = p.batch_year)));
          select count(*) filter (where x0.q16 in ('No', 'Never Employed'))::integer,
                 count(x0.q16)::integer
          into v_prev_hits, v_prev_total
          from pg_temp.ev_resp x0
          where x0.survey_id = pw.survey_id and x0.classified
            and (p.level = 'institution'
                 or (x0.course = p.course and (p.level = 'course' or x0.batch = p.batch_year)));
          continue when v_total = 0 or v_prev_total = 0;

          if p.level = 'batch' then
            select ro.total, ro.registered into v_eligible, v_registered
            from pg_temp.ev_roster ro
            where ro.survey_id = w.survey_id and ro.course = p.course and ro.batch = p.batch_year;
            if not found then
              v_eligible := v_group_n;
              v_registered := 0;
            end if;
          else
            select coalesce(sum(ro.total), 0), coalesce(sum(ro.registered), 0)
            into v_eligible, v_registered
            from pg_temp.ev_roster ro
            where ro.survey_id = w.survey_id and (p.level = 'institution' or ro.course = p.course);
          end if;
          v_rate := case when v_eligible > 0 then v_group_n::double precision / v_eligible end;

          v_n := least(v_total, v_prev_total);
          v_strength := case
            when v_n < 5 then 'insufficient'
            when v_n < greatest(v_tr.min_n, 10) then 'watch'
            when v_n < 30 then 'limited'
            else 'strong'
          end;
          v_key := 'UNEMPLOYMENT_TREND_UP|' || p.level || '|' || p.course || '|' || p.batch_year;
          if v_strength = 'insufficient' then
            insert into pg_temp.ev_suppressed values (v_key, w.sid, v_n);
            continue;
          end if;
          insert into pg_temp.ev_checked values (v_key, w.sid);

          v_cur_rate := v_hits::double precision / v_total;
          v_prev_rate := v_prev_hits::double precision / v_prev_total;
          v_metric := v_cur_rate - v_prev_rate;
          continue when not public.dss_crosses_float(v_tr.operator, v_metric, v_tr.threshold);

          -- Newcombe interval for the change, from each wave's Wilson interval
          select wl.low, wl.high into v_cur_low, v_cur_high from public.dss_wilson(v_hits, v_total) wl;
          select wl.low, wl.high into v_prev_low, v_prev_high from public.dss_wilson(v_prev_hits, v_prev_total) wl;
          v_low := v_metric - sqrt(power(v_cur_rate - v_cur_low, 2) + power(v_prev_high - v_prev_rate, 2));
          v_high := v_metric + sqrt(power(v_cur_high - v_cur_rate, 2) + power(v_prev_rate - v_prev_low, 2));

          v_label := case p.level
            when 'batch' then p.course || ' · Batch ' || p.batch_year
            when 'course' then p.course || ' (all batches)'
            else 'the whole institution'
          end;

          v_evidence := jsonb_build_object(
              'question', 'ched_16',
              'previous_survey_id', pw.sid,
              'previous_survey_title', pw.title,
              'previous_rate', v_prev_rate,
              'previous_not_employed', v_prev_hits,
              'previous_answered', v_prev_total,
              'current_rate', v_cur_rate,
              'current_not_employed', v_hits,
              'current_answered', v_total,
              'source', 'ched_gts',
              'valid_answers', v_n,
              'not_answered', greatest(0, v_group_n - v_n),
              'evidence_strength', v_strength,
              'registered_roster', v_registered,
              'roster_basis', w.basis)
            || case when v_rate is not null then jsonb_build_object('response_rate', v_rate) else '{}'::jsonb end
            || case when v_rate < 0.30 then '{"coverage_warning": true}'::jsonb else '{}'::jsonb end
            || jsonb_build_object(
              'ci_low', v_low,
              'ci_high', v_high,
              'ci_level', 0.95,
              'certainty', case
                when public.dss_crosses_float(v_tr.operator,
                       case when v_tr.operator in ('lt', 'lte') then v_high else v_low end, v_tr.threshold)
                  then 'confirmed' else 'possible' end);

          if p.level = 'course' then
            v_evidence := v_evidence || jsonb_build_object(
              'rolled_up', true,
              'small_groups', (
                select coalesce(jsonb_object_agg(a.batch, least(a.n, b.n)), '{}'::jsonb)
                from pg_temp.ev_sizes a
                join pg_temp.ev_sizes b on b.course = a.course and b.batch = a.batch
                where a.survey_id = w.survey_id and b.survey_id = pw.survey_id
                  and a.course = p.course
                  and (least(a.n, b.n) < v_tr.rule_min or a.batch = c_bnr)),
              'min_responses_required', v_tr.rule_min);
          elsif p.level = 'institution' then
            v_evidence := v_evidence || jsonb_build_object(
              'rolled_up', true,
              'small_groups', (
                select coalesce(jsonb_object_agg(a.course, least(a.total, b.total)), '{}'::jsonb)
                from (select course, sum(n) as total from pg_temp.ev_sizes
                      where survey_id = w.survey_id group by course) a
                join (select course, sum(n) as total from pg_temp.ev_sizes
                      where survey_id = pw.survey_id group by course) b on b.course = a.course
                where least(a.total, b.total) < v_tr.rule_min),
              'min_responses_required', v_tr.rule_min);
          end if;

          insert into pg_temp.ev_rows (finding_key, sid, rule_id, cohort_level, course, batch_year,
            survey_title, metric_value, threshold, sample_n, eligible_n, confidence, title, body,
            recommended_action, evidence, status)
          values (
            v_key, w.sid, 'UNEMPLOYMENT_TREND_UP', p.level, p.course, p.batch_year, w.title,
            v_metric, v_tr.threshold, v_group_n, v_eligible,
            case when v_strength = 'strong' and not coalesce(v_rate < 0.30, false) then 'ok' else 'low' end,
            v_tr.display_name || ': ' || v_label,
            case when v_strength = 'watch' then 'Watch (small sample): ' else '' end
              || 'Not employed rose from ' || public.dss_fixed(v_prev_rate * 100, 0) || '% ('
              || v_prev_total || ' answers in "' || pw.title || '") to '
              || public.dss_fixed(v_cur_rate * 100, 0) || '% (' || v_total || ' answers in "'
              || w.title || '") for ' || v_label || ': ' || public.dss_points(v_metric) || '.',
            v_tr.recommended_action,
            v_evidence,
            case when v_strength = 'watch' then 'watch' else 'open' end
          );
        end loop;
      end if;
      pw := w;
      v_have_prev := true;
    end loop;
  end if;

  -- Finding sync ---------------------------------------------------------------
  create temp table ev_stored on commit drop as
  select f.id, f.finding_key, f.survey_id as sid, f.status
  from public.dss_flags f
  where f.survey_id in (select sid from pg_temp.ev_waves);

  -- the newest wave that checked each finding
  create temp table ev_latest on commit drop as
  select distinct on (k.finding_key) k.finding_key, k.sid, wv.wave_date
  from (
    select finding_key, sid from pg_temp.ev_checked
    union
    select finding_key, sid from pg_temp.ev_rows
  ) k
  join pg_temp.ev_waves wv on wv.sid = k.sid
  order by k.finding_key, wv.wave_date desc, k.sid;

  create temp table ev_actions (
    seq serial primary key,
    action text not null,
    finding_key text not null,
    sid text not null,
    row_id integer,
    flag_id uuid,
    status_from text,
    status_to text,
    reason text not null,
    valid_answers integer,
    newer_sid text,
    newer_flag uuid
  ) on commit drop;

  for x in
    select rw.row_id, rw.finding_key, rw.sid, rw.rule_id, rw.status, rw.sample_n,
           coalesce(lt.wave_date > wv.wave_date, false) as older
    from pg_temp.ev_rows rw
    join pg_temp.ev_waves wv on wv.sid = rw.sid
    left join pg_temp.ev_latest lt on lt.finding_key = rw.finding_key
    order by rw.row_id
  loop
    v_fid := null;
    v_fstatus := null;
    select s.id, s.status into v_fid, v_fstatus
    from pg_temp.ev_stored s
    where s.finding_key = x.finding_key and s.sid = x.sid
      and s.status in ('open', 'in_progress', 'watch')
    order by s.id
    limit 1;

    if v_fid is not null then
      if v_fstatus = 'in_progress' then
        insert into pg_temp.ev_actions (action, finding_key, sid, row_id, flag_id, status_from, reason, valid_answers)
        values ('update', x.finding_key, x.sid, x.row_id, v_fid, v_fstatus, 'refreshed', x.sample_n);
      elsif not x.older then
        insert into pg_temp.ev_actions (action, finding_key, sid, row_id, flag_id, status_from, status_to, reason, valid_answers)
        values ('update', x.finding_key, x.sid, x.row_id, v_fid, v_fstatus,
          case when v_fstatus <> x.status then x.status end,
          case when v_fstatus = x.status then 'refreshed'
               when x.status = 'watch' then 'became_watch'
               else 'became_finding' end,
          x.sample_n);
      end if;
    elsif x.older then
      insert into pg_temp.ev_actions (action, finding_key, sid, reason, valid_answers)
      values ('suppress', x.finding_key, x.sid, 'newer_wave', x.sample_n);
    elsif exists (select 1 from pg_temp.ev_stored s
                  where s.finding_key = x.finding_key and s.sid = x.sid and s.status = 'superseded') then
      insert into pg_temp.ev_actions (action, finding_key, sid, reason, valid_answers)
      values ('suppress', x.finding_key, x.sid, 'superseded_in_wave', x.sample_n);
    elsif exists (select 1 from pg_temp.ev_stored s
                  where s.finding_key = x.finding_key and s.sid = x.sid) then
      insert into pg_temp.ev_actions (action, finding_key, sid, reason, valid_answers)
      values ('suppress', x.finding_key, x.sid, 'closed_in_wave', x.sample_n);
    elsif public.dss_is_sticky_once_per_cohort_rule(x.rule_id)
          and exists (
            select 1 from pg_temp.ev_stored s
            where s.finding_key = x.finding_key
              and s.sid is distinct from x.sid
              and (
                s.status in ('open', 'in_progress', 'resolved', 'dismissed', 'superseded')
                or (s.status = 'watch' and x.status = 'watch')
              )
          ) then
      -- Sticky historical metrics (TIME_TO_JOB_LONG): do not re-raise the same
      -- course×batch on a later tracer. Watch→Finding upgrades still raise.
      insert into pg_temp.ev_actions (action, finding_key, sid, reason, valid_answers)
      values ('suppress', x.finding_key, x.sid, 'sticky_prior_finding', x.sample_n);
    else
      insert into pg_temp.ev_actions (action, finding_key, sid, row_id, status_to, reason, valid_answers)
      values ('insert', x.finding_key, x.sid, x.row_id, x.status,
        case when x.rule_id = 'DATA_QUALITY_LOW' then 'data_quality'
             when x.status = 'watch' then 'watch'
             else 'finding' end,
        x.sample_n);
    end if;
  end loop;

  insert into pg_temp.ev_actions (action, finding_key, sid, reason, valid_answers)
  select 'suppress', su.finding_key, su.sid, 'not_enough_data', su.valid_answers
  from pg_temp.ev_suppressed su;

  -- open and Watch flags of an older wave give way to the newest wave
  insert into pg_temp.ev_actions (action, finding_key, sid, flag_id, status_from, status_to, reason, newer_sid)
  select 'supersede', s.finding_key, s.sid, s.id, s.status, 'superseded',
    case when exists (
        select 1 from pg_temp.ev_stored s2
        where s2.finding_key = s.finding_key and s2.sid = lt.sid
          and s2.status in ('open', 'in_progress', 'watch'))
      or exists (
        select 1 from pg_temp.ev_actions a2
        where a2.action = 'insert' and a2.finding_key = s.finding_key and a2.sid = lt.sid)
      then 'newer_wave_raised' else 'newer_wave_clear' end,
    lt.sid
  from pg_temp.ev_stored s
  join pg_temp.ev_waves wv on wv.sid = s.sid
  join pg_temp.ev_latest lt on lt.finding_key = s.finding_key
  where s.status in ('open', 'watch')
    and lt.wave_date > wv.wave_date
    and not (
      public.dss_is_sticky_once_per_cohort_rule(split_part(s.finding_key, '|', 1))
      and (
        -- Newer wave suppressed as sticky: keep older Open/Watch.
        exists (
          select 1 from pg_temp.ev_actions a
          where a.action = 'suppress'
            and a.reason = 'sticky_prior_finding'
            and a.finding_key = s.finding_key
            and a.sid = lt.sid
        )
        -- Sticky Open with no newer insert: do not clear the active work item.
        or (
          s.status = 'open'
          and not exists (
            select 1 from pg_temp.ev_actions a2
            where a2.action = 'insert'
              and a2.finding_key = s.finding_key
              and a2.sid = lt.sid
          )
        )
      )
    )
  order by s.id;

  if not p_dry_run then
    with ins as (
      insert into public.dss_flags (rule_id, cohort_level, course, batch_year, survey_id,
        survey_title, metric_value, threshold_snapshot, sample_n, eligible_n, confidence, title,
        body, recommended_action, evidence, baseline_value, status, created_by, updated_by)
      select rw.rule_id, rw.cohort_level, rw.course, rw.batch_year, rw.sid, rw.survey_title,
        rw.metric_value::text::numeric, rw.threshold::text::numeric, rw.sample_n, rw.eligible_n,
        rw.confidence, rw.title, rw.body, rw.recommended_action, rw.evidence,
        rw.metric_value::text::numeric, rw.status, v_uid, v_uid
      from pg_temp.ev_actions a
      join pg_temp.ev_rows rw on rw.row_id = a.row_id
      where a.action = 'insert'
      order by a.seq
      returning id, finding_key, survey_id
    )
    update pg_temp.ev_actions a set flag_id = ins.id
    from ins
    where a.action = 'insert' and a.finding_key = ins.finding_key and a.sid = ins.survey_id;

    update public.dss_flags f set
      metric_value = rw.metric_value::text::numeric,
      threshold_snapshot = rw.threshold::text::numeric,
      sample_n = rw.sample_n,
      eligible_n = rw.eligible_n,
      confidence = rw.confidence,
      title = rw.title,
      body = rw.body,
      recommended_action = rw.recommended_action,
      evidence = rw.evidence,
      survey_title = rw.survey_title,
      baseline_value = rw.metric_value::text::numeric,
      status = coalesce(a.status_to, f.status),
      updated_by = v_uid
    from pg_temp.ev_actions a
    join pg_temp.ev_rows rw on rw.row_id = a.row_id
    where a.action = 'update' and f.id = a.flag_id;

    insert into public.dss_flag_notes (flag_id, note, status_from, status_to, event_type, author_name)
    select a.flag_id,
      case when a.status_to = 'watch'
        then 'Moved to Watch: the latest Refresh found too few valid answers for a finding.'
        else 'Now a finding: the latest Refresh found enough valid answers.' end,
      a.status_from, a.status_to, 'status', c_note_author
    from pg_temp.ev_actions a
    where a.action = 'update' and a.status_to is not null
    order by a.seq;

    update pg_temp.ev_actions a set newer_flag = (
      select f.id from public.dss_flags f
      where f.finding_key = a.finding_key and f.survey_id = a.newer_sid
        and f.status in ('open', 'in_progress', 'watch')
      order by f.id
      limit 1)
    where a.action = 'supersede';

    update public.dss_flags f set
      status = 'superseded',
      superseded_at = v_now,
      superseded_by = a.newer_flag,
      updated_by = v_uid
    from pg_temp.ev_actions a
    where a.action = 'supersede' and f.id = a.flag_id;

    insert into public.dss_flag_notes (flag_id, note, status_from, status_to, event_type, metadata, author_name)
    select a.flag_id,
      case when a.newer_flag is null
        then 'Superseded: a newer wave checked the same finding and has no active flag for it.'
        else 'Superseded by the newer wave''s flag for the same finding.' end,
      a.status_from, 'superseded', 'status',
      case when a.newer_flag is null then '{}'::jsonb
           else jsonb_build_object('superseded_by', a.newer_flag) end,
      c_note_author
    from pg_temp.ev_actions a
    where a.action = 'supersede'
    order by a.seq;

    insert into public.dss_evaluation_events (run_id, run_trigger, finding_key, survey_id,
      flag_id, outcome, reason, valid_answers, created_by)
    select v_run, v_trigger, a.finding_key,
      case when a.action = 'supersede' then a.newer_sid else a.sid end,
      a.flag_id,
      case a.action
        when 'insert' then 'raised'
        when 'update' then 'updated'
        when 'supersede' then 'superseded'
        else 'suppressed' end,
      a.reason, a.valid_answers, v_uid
    from pg_temp.ev_actions a
    order by a.seq;

    -- roster counts of open waves, for later response rates
    insert into public.dss_wave_cohort_snapshots (survey_id, course, batch_year,
      roster_count, registered_count, captured_at)
    select wv.survey_id, rn.course, rn.batch, rn.total, rn.registered, v_now
    from pg_temp.ev_waves wv
    cross join pg_temp.ev_roster_now rn
    where wv.accepts and (wv.has_responses or wv.is_newest)
    on conflict (survey_id, course, batch_year) do update set
      roster_count = excluded.roster_count,
      registered_count = excluded.registered_count,
      captured_at = excluded.captured_at;
    get diagnostics v_snapshots = row_count;

    with pr as (
      select f.id, public.dss_flag_priority(f, v_now) as pv
      from public.dss_flags f
      where f.status in ('open', 'in_progress', 'watch')
    )
    update public.dss_flags f set
      priority = pr.pv ->> 'level',
      priority_score = (pr.pv ->> 'score')::integer,
      priority_reasons = pr.pv -> 'reasons',
      priority_at = v_now
    from pr
    where f.id = pr.id
      and (f.priority, f.priority_score, f.priority_reasons)
          is distinct from (pr.pv ->> 'level', (pr.pv ->> 'score')::integer, pr.pv -> 'reasons');
  end if;

  v_result := jsonb_build_object(
    'dry_run', p_dry_run,
    'trigger', v_trigger,
    'run_id', case when p_dry_run then null else v_run end,
    'evaluated_at', v_now,
    'ched_waves', (select count(*) from pg_temp.ev_waves),
    'waves_with_responses', (select count(*) from pg_temp.ev_waves where has_responses),
    'responses_scanned', (select count(*) from pg_temp.ev_resp),
    'unclassified', (select count(*) from pg_temp.ev_resp where not classified),
    'cohorts_evaluated', (select count(*) from pg_temp.ev_groups where is_dq),
    'rolled_up_groups', (select count(*) from pg_temp.ev_groups where is_outcome and level <> 'batch'),
    'flag_rows', (select count(*) from pg_temp.ev_rows),
    'watch', (select count(*) from pg_temp.ev_rows where status = 'watch'),
    'not_enough_data', (select count(*) from pg_temp.ev_suppressed),
    'raised', (select count(*) from pg_temp.ev_actions where action = 'insert'),
    'updated', (select count(*) from pg_temp.ev_actions where action = 'update'),
    'superseded', (select count(*) from pg_temp.ev_actions where action = 'supersede'),
    'skipped_newer_wave', (select count(*) from pg_temp.ev_actions
                           where action = 'suppress' and reason = 'newer_wave'),
    'skipped_closed', (select count(*) from pg_temp.ev_actions
                       where action = 'suppress' and reason in ('closed_in_wave', 'superseded_in_wave')),
    'snapshots_saved', v_snapshots
  );

  if p_dry_run then
    v_result := v_result || jsonb_build_object(
      'rows', (
        select coalesce(jsonb_agg(
          jsonb_build_object(
            'finding_key', rw.finding_key,
            'rule_id', rw.rule_id,
            'cohort_level', rw.cohort_level,
            'course', rw.course,
            'batch_year', rw.batch_year,
            'survey_id', rw.sid,
            'survey_title', rw.survey_title,
            'metric_value', rw.metric_value::text::numeric,
            'threshold_snapshot', rw.threshold::text::numeric,
            'sample_n', rw.sample_n,
            'eligible_n', rw.eligible_n,
            'confidence', rw.confidence,
            'title', rw.title,
            'body', rw.body,
            'recommended_action', rw.recommended_action,
            'evidence', rw.evidence,
            'baseline_value', rw.metric_value::text::numeric,
            'status', rw.status)
          order by rw.finding_key, rw.sid), '[]'::jsonb)
        from pg_temp.ev_rows rw),
      'checked', (
        select coalesce(jsonb_object_agg(c.finding_key, c.sids), '{}'::jsonb)
        from (
          select ck.finding_key, jsonb_agg(distinct ck.sid) as sids
          from pg_temp.ev_checked ck
          group by ck.finding_key
        ) c),
      'suppressed', (
        select coalesce(jsonb_agg(jsonb_build_object(
          'finding_key', su.finding_key, 'survey_id', su.sid, 'valid_answers', su.valid_answers)
          order by su.finding_key, su.sid), '[]'::jsonb)
        from pg_temp.ev_suppressed su),
      'actions', (
        select coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
          'action', a.action, 'finding_key', a.finding_key, 'survey_id', a.sid,
          'flag_id', a.flag_id, 'status_from', a.status_from, 'status_to', a.status_to,
          'reason', a.reason, 'valid_answers', a.valid_answers, 'newer_survey_id', a.newer_sid))
          order by a.seq), '[]'::jsonb)
        from pg_temp.ev_actions a)
    );
  end if;

  return v_result;
end;
$function$;

commit;
