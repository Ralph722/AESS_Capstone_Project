-- DSS Phase 4: finding identity across waves
-- (docs/dss-capability-audit.md Part 10.4).
--   1. dss_flags.finding_key: rule x level x course x batch (generated)
--   2. Two flag statuses set only by Refresh insights:
--        watch       5 to (rule minimum - 1) valid answers; monitored, not a
--                    finding
--        superseded  a newer wave checked the same finding; final
--      with superseded_by / superseded_at
--   3. Status guard and dss_update_flag_status know both statuses
--   4. One active flag per finding and wave now includes Watch
--   5. dss_recheck_open_flags re-checks Watch items too
--   6. dss_evaluation_events: what each Refresh raised, updated, skipped or
--      superseded, and why
-- Additive: no row is deleted. The status check and the active-flag index
-- are replaced with wider versions of themselves.

-- ---------------------------------------------------------------------------
-- 1. Finding identity
-- ---------------------------------------------------------------------------
alter table public.dss_flags
  add column if not exists finding_key text
  generated always as (
    rule_id || '|' || cohort_level || '|' || course || '|' || batch_year
  ) stored;

comment on column public.dss_flags.finding_key is
  'Identity of a finding across CHED GTS waves: rule|level|course|batch.';

create index if not exists idx_dss_flags_finding_key
  on public.dss_flags (finding_key, survey_id);

-- ---------------------------------------------------------------------------
-- 2. Watch and Superseded
-- ---------------------------------------------------------------------------
alter table public.dss_flags
  add column if not exists superseded_by uuid
    references public.dss_flags (id) on delete set null,
  add column if not exists superseded_at timestamptz;

comment on column public.dss_flags.superseded_by is
  'The newer wave''s flag for the same finding; null when that wave did not '
  'raise it.';

-- The table was created with an unnamed inline check; replace it by
-- definition rather than by name.
do $$
declare
  c record;
begin
  for c in
    select conname
    from pg_constraint
    where conrelid = 'public.dss_flags'::regclass
      and contype = 'c'
      and pg_get_constraintdef(oid) ~ '\mstatus\M'
      and pg_get_constraintdef(oid) ~ 'in_progress'
  loop
    execute format('alter table public.dss_flags drop constraint %I', c.conname);
  end loop;
end $$;

alter table public.dss_flags
  add constraint dss_flags_status_check
  check (status in ('open', 'in_progress', 'resolved', 'dismissed', 'watch', 'superseded'));

alter table public.dss_flags
  drop constraint if exists dss_flags_superseded_check;
alter table public.dss_flags
  add constraint dss_flags_superseded_check
  check ((status = 'superseded') = (superseded_at is not null));

-- ---------------------------------------------------------------------------
-- 3. Status rules
-- ---------------------------------------------------------------------------
create or replace function public.dss_flags_guard_status_transition()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.status is not distinct from old.status then
    return new;
  end if;
  if old.status = 'superseded' then
    raise exception 'A superseded flag is final.' using errcode = '23514';
  end if;
  if old.status in ('resolved', 'dismissed')
     and new.status in ('resolved', 'dismissed') then
    raise exception 'Reopen this flag before marking it %.', new.status
      using errcode = '23514';
  end if;
  if new.status = 'superseded' and old.status not in ('open', 'watch') then
    raise exception 'Only open or Watch flags can be superseded.'
      using errcode = '23514';
  end if;
  if old.status = 'watch' and new.status not in ('open', 'dismissed', 'superseded') then
    raise exception 'A Watch item can only become a finding, be dismissed or be superseded.'
      using errcode = '23514';
  end if;
  if new.status = 'watch' and old.status not in ('open', 'dismissed') then
    raise exception 'Only open or dismissed flags can go back to Watch.'
      using errcode = '23514';
  end if;
  return new;
end;
$$;

create or replace function public.dss_update_flag_status(
  p_flag_id uuid,
  p_status text,
  p_note text default '',
  p_intervention_type text default null,
  p_intervention_detail text default null,
  p_followup_value numeric default null,
  p_followup_sample_n integer default null,
  p_impact_verdict text default null,
  p_verify_due_at timestamptz default null,
  p_clear_resolved_at boolean default false
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  f public.dss_flags%rowtype;
  v_note text := trim(coalesce(p_note, ''));
  v_status text := p_status;
  v_was_closed boolean;
  v_reopening boolean;
  v_label text;
begin
  if not public.is_admin() then
    raise exception 'Admin access required.' using errcode = '42501';
  end if;
  if p_status not in ('open', 'in_progress', 'resolved', 'dismissed', 'watch', 'superseded') then
    raise exception 'Unknown flag status: %', p_status;
  end if;

  select * into f from public.dss_flags where id = p_flag_id for update;
  if not found then
    raise exception 'DSS flag not found.';
  end if;

  if f.status = 'superseded' then
    raise exception 'This flag was superseded by a newer wave and can no longer change.'
      using errcode = '23514';
  end if;
  if p_status in ('watch', 'superseded') and p_status <> f.status then
    raise exception 'Watch and Superseded are set by Refresh insights.'
      using errcode = '23514';
  end if;
  if f.status = 'watch' and p_status not in ('watch', 'dismissed') then
    raise exception 'A Watch item can only be dismissed. It becomes a finding when a Refresh finds enough answers.'
      using errcode = '23514';
  end if;

  -- A dismissed Watch item reopens as Watch, not as a finding.
  if f.status = 'dismissed' and p_status in ('open', 'in_progress')
     and f.evidence_strength = 'watch' then
    v_status := 'watch';
  end if;

  v_was_closed := f.status in ('resolved', 'dismissed');
  v_reopening := v_was_closed and v_status in ('open', 'in_progress', 'watch');

  update public.dss_flags
  set status = v_status,
      updated_by = auth.uid(),
      resolved_at = case
        when v_status in ('resolved', 'dismissed') then now()
        when v_was_closed and (p_clear_resolved_at or v_reopening) then null
        else resolved_at
      end,
      verify_due_at = case
        when p_verify_due_at is not null then p_verify_due_at
        when v_was_closed and (p_clear_resolved_at or v_reopening) then null
        else verify_due_at
      end,
      intervention_type = coalesce(p_intervention_type, intervention_type),
      intervention_detail = coalesce(p_intervention_detail, intervention_detail),
      followup_value = coalesce(p_followup_value, followup_value),
      followup_at = case when p_followup_value is not null then now() else followup_at end,
      followup_sample_n = coalesce(p_followup_sample_n, followup_sample_n),
      impact_verdict = coalesce(p_impact_verdict, impact_verdict)
  where id = p_flag_id;

  if v_note <> '' or v_status <> f.status then
    v_label := case v_status
      when 'open' then 'Open'
      when 'in_progress' then 'In Progress'
      when 'resolved' then 'Resolved'
      when 'watch' then 'Watch'
      else 'Dismissed'
    end;
    insert into public.dss_flag_notes (
      flag_id, note, status_from, status_to, event_type, metadata
    )
    values (
      p_flag_id,
      case when v_note = '' then 'Status changed to ' || v_label else v_note end,
      f.status,
      v_status,
      case when v_reopening then 'reopen' else 'status' end,
      jsonb_strip_nulls(jsonb_build_object(
        'intervention', p_intervention_type,
        'intervention_detail', nullif(p_intervention_detail, ''),
        'impact_verdict', p_impact_verdict,
        'followup_value', p_followup_value,
        'followup_sample_n', p_followup_sample_n
      ))
    );
  end if;
end;
$$;

revoke all on function public.dss_update_flag_status(uuid, text, text, text, text, numeric, integer, text, timestamptz, boolean) from public, anon;
grant execute on function public.dss_update_flag_status(uuid, text, text, text, text, numeric, integer, text, timestamptz, boolean) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 4. One active flag per finding and wave (Watch included)
-- ---------------------------------------------------------------------------
drop index if exists public.uq_dss_flags_active_cohort;
create unique index uq_dss_flags_active_cohort
  on public.dss_flags (rule_id, cohort_level, course, batch_year, survey_id)
  where status in ('open', 'in_progress', 'watch');

-- ---------------------------------------------------------------------------
-- 5. Nightly re-check (same as Phase 1, Watch items included)
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
    where fl.status in ('open', 'in_progress', 'watch')
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

-- ---------------------------------------------------------------------------
-- 6. Evaluation log (counts and keys only, no personal data)
-- ---------------------------------------------------------------------------
create table if not exists public.dss_evaluation_events (
  id bigint generated always as identity primary key,
  run_id uuid not null,
  run_trigger text not null default 'manual'
    check (run_trigger in ('manual', 'scheduled')),
  finding_key text not null check (btrim(finding_key) <> ''),
  survey_id text not null,
  flag_id uuid references public.dss_flags (id) on delete set null,
  outcome text not null
    check (outcome in ('raised', 'updated', 'suppressed', 'superseded')),
  reason text not null
    check (reason in (
      'finding', 'watch', 'data_quality',
      'refreshed', 'became_finding', 'became_watch',
      'not_enough_data', 'closed_in_wave', 'superseded_in_wave', 'newer_wave',
      'newer_wave_raised', 'newer_wave_clear'
    )),
  valid_answers integer check (valid_answers >= 0),
  created_by uuid default auth.uid() references auth.users (id) on delete set null,
  created_at timestamptz not null default now()
);

comment on table public.dss_evaluation_events is
  'One row per finding per wave per Refresh insights run: raised, updated, '
  'suppressed (with the reason) or superseded. Append-only.';

create index if not exists idx_dss_evaluation_events_run
  on public.dss_evaluation_events (run_id);
create index if not exists idx_dss_evaluation_events_finding
  on public.dss_evaluation_events (finding_key, survey_id, created_at desc);
create index if not exists idx_dss_evaluation_events_flag
  on public.dss_evaluation_events (flag_id);

alter table public.dss_evaluation_events enable row level security;

drop policy if exists dss_evaluation_events_admin_select on public.dss_evaluation_events;
create policy dss_evaluation_events_admin_select
  on public.dss_evaluation_events
  for select to authenticated
  using ((select public.is_admin()));

drop policy if exists dss_evaluation_events_admin_insert on public.dss_evaluation_events;
create policy dss_evaluation_events_admin_insert
  on public.dss_evaluation_events
  for insert to authenticated
  with check ((select public.is_admin()) and created_by is not distinct from (select auth.uid()));

drop policy if exists active_caller_only on public.dss_evaluation_events;
create policy active_caller_only
  on public.dss_evaluation_events as restrictive
  for all to authenticated
  using ((select public.caller_is_active()))
  with check ((select public.caller_is_active()));

revoke all on public.dss_evaluation_events from public, anon, authenticated;
grant select, insert on public.dss_evaluation_events to authenticated;
grant all on public.dss_evaluation_events to service_role;

notify pgrst, 'reload schema';
