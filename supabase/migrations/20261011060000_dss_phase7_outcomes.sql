-- DSS Phase 7: intervention outcomes (docs/dss-capability-audit.md Part 10.4).
--   1. dss_interventions: one row per intervention on a finding, with its
--      success test, baseline, next-wave follow-up, outcome and decision
--   2. dss_evaluate_intervention(id): judges the outcome from the first CHED
--      wave published after the intervention started, with the Phase 3
--      server metrics. The outcome is stored only once that wave stops
--      accepting responses; while it is open the result is a preview.
--   3. dss_decide_intervention(...): resolve, continue, modify or escalate
--      after an outcome, with a required note
--   4. Note event type 'outcome'; recording, evaluating and deciding are
--      logged on the flag
-- Additive: no existing row changes. Older flags have no intervention rows
-- and show "Not evaluated (legacy)" in the app.

-- ---------------------------------------------------------------------------
-- 1. Interventions
-- ---------------------------------------------------------------------------
create table if not exists public.dss_interventions (
  id uuid primary key default gen_random_uuid(),
  flag_id uuid not null references public.dss_flags (id) on delete cascade,
  finding_key text not null,
  rule_id text not null,
  continues_id uuid references public.dss_interventions (id) on delete set null,
  intervention_type text not null
    check (btrim(intervention_type) <> '' and char_length(intervention_type) <= 120),
  description text not null default ''
    check (char_length(description) <= 2000),
  expected_outcome text not null default ''
    check (char_length(expected_outcome) <= 1000),
  success_metric text not null
    check (success_metric in (
      'response_rate', 'unemployment_rate', 'seeking_work_rate',
      'unrelated_or_irrelevant_rate', 'related_and_relevant_rate',
      'clerical_among_employed_rate', 'long_time_to_first_job_rate',
      'salary_peer_gap'
    )),
  success_operator text not null
    check (success_operator in ('lt', 'lte', 'gt', 'gte')),
  success_target numeric not null,
  started_on date not null,
  baseline_survey_id text,
  baseline_survey_title text not null default '',
  baseline_value numeric,
  baseline_n integer,
  followup_survey_id text,
  followup_survey_title text,
  followup_value numeric,
  followup_n integer,
  outcome_status text not null default 'not_evaluated'
    check (outcome_status in (
      'not_evaluated', 'pending_followup', 'successful',
      'partially_successful', 'unsuccessful', 'inconclusive',
      'no_comparable_data'
    )),
  evaluation_note text,
  evaluated_at timestamptz,
  decision text
    check (decision in ('resolve', 'continue', 'modify', 'escalate')),
  decision_note text,
  escalated_to text,
  decided_by uuid references auth.users (id) on delete set null,
  decided_by_name text,
  decided_at timestamptz,
  created_by uuid references auth.users (id) on delete set null,
  created_by_name text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint dss_interventions_target_check check (
    case when success_metric = 'salary_peer_gap'
      then success_target between -10 and 10
      else success_target between 0 and 1
    end
  ),
  constraint dss_interventions_decided_check check (
    (decision is null and decision_note is null and decided_at is null
      and escalated_to is null)
    or (decision is not null
      and btrim(coalesce(decision_note, '')) <> ''
      and char_length(decision_note) <= 2000
      and decided_at is not null
      and outcome_status not in ('not_evaluated', 'pending_followup')
      and (escalated_to is null
        or (decision = 'escalate' and btrim(escalated_to) <> ''
          and char_length(escalated_to) <= 120)))
  )
);

comment on table public.dss_interventions is
  'Interventions on a DSS finding and their next-wave outcome. Outcomes are '
  'written only by dss_evaluate_intervention; a decided row is final; rows '
  'are never deleted.';
comment on column public.dss_interventions.success_target is
  'Share 0-1, or salary brackets for salary_peer_gap. Defaults to the rule '
  'threshold (the previous wave''s rate for the trend rule).';

-- At most one intervention per finding is waiting for a decision.
create unique index if not exists uq_dss_interventions_undecided_finding
  on public.dss_interventions (finding_key)
  where decision is null;
create index if not exists idx_dss_interventions_flag
  on public.dss_interventions (flag_id, created_at desc);
create index if not exists idx_dss_interventions_finding
  on public.dss_interventions (finding_key, created_at desc);
create index if not exists idx_dss_interventions_continues
  on public.dss_interventions (continues_id);
create index if not exists idx_dss_interventions_created_by
  on public.dss_interventions (created_by);
create index if not exists idx_dss_interventions_decided_by
  on public.dss_interventions (decided_by);

-- Insert: finding, rule, success test and baseline come from the flag (or,
-- for a continued intervention, from the previous follow-up); the author is
-- the caller. Update: the plan can change only before an outcome is known,
-- and a decided row is final.
create or replace function public.dss_interventions_stamp()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_today date := (now() at time zone 'Asia/Manila')::date;
  f public.dss_flags%rowtype;
  r public.dss_rules%rowtype;
  p public.dss_interventions%rowtype;
  v_target numeric;
  v_base numeric;
  v_base_n integer;
begin
  if tg_op = 'INSERT' then
    select * into f from public.dss_flags where id = new.flag_id;
    if not found then
      raise exception 'DSS flag not found.' using errcode = '23503';
    end if;
    if f.status not in ('open', 'in_progress', 'resolved')
       and not (f.status = 'watch' and new.continues_id is not null) then
      raise exception 'Interventions can only be recorded on an open, in-progress or resolved finding.'
        using errcode = '23514';
    end if;
    select * into r from public.dss_rules where rule_id = f.rule_id;

    new.finding_key := f.finding_key;
    new.rule_id := f.rule_id;
    new.intervention_type := btrim(new.intervention_type);
    new.description := btrim(coalesce(new.description, ''));
    new.expected_outcome := btrim(coalesce(new.expected_outcome, ''));
    new.started_on := coalesce(new.started_on, f.start_date, v_today);
    if new.started_on > v_today then
      raise exception 'The start date cannot be in the future.' using errcode = '23514';
    end if;

    if f.rule_id = 'UNEMPLOYMENT_TREND_UP' then
      new.success_metric := 'unemployment_rate';
      new.success_operator := 'lte';
      v_target := (f.evidence ->> 'previous_rate')::numeric;
      v_base := (f.evidence ->> 'current_rate')::numeric;
      v_base_n := (f.evidence ->> 'current_answered')::integer;
    else
      new.success_metric := r.metric_key;
      new.success_operator := case
        when r.category = 'opportunity' then r.operator
        else case r.operator
          when 'gte' then 'lt'
          when 'gt' then 'lte'
          when 'lte' then 'gt'
          else 'gte'
        end
      end;
      v_target := f.threshold_snapshot;
      v_base := f.metric_value;
      v_base_n := f.sample_n;
    end if;
    new.success_target := coalesce(new.success_target, v_target);
    if new.success_target is null then
      raise exception 'This finding has no success target. Enter one.' using errcode = '23514';
    end if;

    if new.continues_id is not null then
      select * into p from public.dss_interventions where id = new.continues_id;
      if not found or p.finding_key <> f.finding_key then
        raise exception 'A continued intervention must belong to the same finding.'
          using errcode = '23514';
      end if;
      new.baseline_survey_id := p.followup_survey_id;
      new.baseline_survey_title := coalesce(p.followup_survey_title, '');
      new.baseline_value := p.followup_value;
      new.baseline_n := p.followup_n;
    else
      new.baseline_survey_id := f.survey_id;
      new.baseline_survey_title := coalesce(f.survey_title, '');
      new.baseline_value := v_base;
      new.baseline_n := v_base_n;
    end if;

    new.followup_survey_id := null;
    new.followup_survey_title := null;
    new.followup_value := null;
    new.followup_n := null;
    new.outcome_status := 'not_evaluated';
    new.evaluation_note := null;
    new.evaluated_at := null;
    new.decision := null;
    new.decision_note := null;
    new.escalated_to := null;
    new.decided_by := null;
    new.decided_by_name := null;
    new.decided_at := null;
    new.created_at := now();
    new.updated_at := now();
    new.created_by := v_uid;
    new.created_by_name := 'Admin';
    if v_uid is not null then
      select coalesce(nullif(btrim(u.display_name), ''), nullif(btrim(u.email), ''), 'Admin')
      into new.created_by_name
      from public.users u
      where u.id = v_uid;
      new.created_by_name := coalesce(new.created_by_name, 'Admin');
    end if;
    return new;
  end if;

  if old.decision is not null then
    raise exception 'A decided intervention is final.' using errcode = '23514';
  end if;
  if (new.intervention_type, new.description, new.expected_outcome,
      new.success_target, new.started_on)
     is distinct from
     (old.intervention_type, old.description, old.expected_outcome,
      old.success_target, old.started_on) then
    if old.outcome_status not in ('not_evaluated', 'pending_followup') then
      raise exception 'The plan cannot change after the outcome is known. Record a decision instead.'
        using errcode = '23514';
    end if;
    if new.started_on > v_today then
      raise exception 'The start date cannot be in the future.' using errcode = '23514';
    end if;
  end if;
  new.id := old.id;
  new.flag_id := old.flag_id;
  new.finding_key := old.finding_key;
  new.rule_id := old.rule_id;
  new.continues_id := old.continues_id;
  new.success_metric := old.success_metric;
  new.success_operator := old.success_operator;
  new.baseline_survey_id := old.baseline_survey_id;
  new.baseline_survey_title := old.baseline_survey_title;
  new.baseline_value := old.baseline_value;
  new.baseline_n := old.baseline_n;
  new.created_by := old.created_by;
  new.created_by_name := old.created_by_name;
  new.created_at := old.created_at;
  new.intervention_type := btrim(new.intervention_type);
  new.description := btrim(coalesce(new.description, ''));
  new.expected_outcome := btrim(coalesce(new.expected_outcome, ''));
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trg_dss_interventions_stamp on public.dss_interventions;
create trigger trg_dss_interventions_stamp
  before insert or update on public.dss_interventions
  for each row execute function public.dss_interventions_stamp();

alter table public.dss_interventions enable row level security;

drop policy if exists dss_interventions_admin_select on public.dss_interventions;
create policy dss_interventions_admin_select
  on public.dss_interventions
  for select to authenticated
  using ((select public.is_admin()));

drop policy if exists dss_interventions_admin_insert on public.dss_interventions;
create policy dss_interventions_admin_insert
  on public.dss_interventions
  for insert to authenticated
  with check ((select public.is_admin()));

drop policy if exists dss_interventions_admin_update on public.dss_interventions;
create policy dss_interventions_admin_update
  on public.dss_interventions
  for update to authenticated
  using ((select public.is_admin()))
  with check ((select public.is_admin()));

drop policy if exists active_caller_only on public.dss_interventions;
create policy active_caller_only
  on public.dss_interventions as restrictive
  for all to authenticated
  using ((select public.caller_is_active()))
  with check ((select public.caller_is_active()));

-- Outcome and decision columns are written only by the functions below.
revoke all on public.dss_interventions from public, anon, authenticated;
grant select on public.dss_interventions to authenticated;
grant insert (flag_id, intervention_type, description, expected_outcome,
  success_target, started_on) on public.dss_interventions to authenticated;
grant update (intervention_type, description, expected_outcome,
  success_target, started_on) on public.dss_interventions to authenticated;
grant all on public.dss_interventions to service_role;

-- ---------------------------------------------------------------------------
-- 2. Outcome notes in the action log
-- ---------------------------------------------------------------------------
alter table public.dss_flag_notes
  drop constraint if exists dss_flag_notes_event_type_check;
alter table public.dss_flag_notes
  add constraint dss_flag_notes_event_type_check
  check (
    event_type in (
      'note',
      'status',
      'assign',
      'impact',
      'announcement',
      'reopen',
      'action',
      'evidence',
      'outcome'
    )
  );

-- "31%" for a share, "1.5 brackets" for the salary gap.
create or replace function public.dss_outcome_value_text(p_metric text, p_value numeric)
returns text
language sql
immutable
set search_path = public
as $$
  select case
    when p_value is null then 'no value'
    when p_metric = 'salary_peer_gap' then to_char(p_value, 'FM990.0') || ' brackets'
    else to_char(round(p_value * 100), 'FM990') || '%'
  end;
$$;

create or replace function public.dss_interventions_log()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.dss_flag_notes (flag_id, note, event_type, metadata)
  values (
    new.flag_id,
    case when new.continues_id is null then 'Intervention recorded: '
         else 'Intervention continued: ' end
      || new.intervention_type || ' (started '
      || to_char(new.started_on, 'YYYY-MM-DD') || '). Success test: '
      || case new.success_operator
           when 'lt' then 'below '
           when 'lte' then 'at or below '
           when 'gt' then 'above '
           else 'at least '
         end
      || public.dss_outcome_value_text(new.success_metric, new.success_target)
      || ' in the next tracer wave.',
    'outcome',
    jsonb_strip_nulls(jsonb_build_object(
      'action', 'recorded',
      'intervention_id', new.id,
      'continues_id', new.continues_id,
      'intervention_type', new.intervention_type,
      'success_metric', new.success_metric,
      'success_operator', new.success_operator,
      'success_target', new.success_target,
      'baseline_value', new.baseline_value,
      'baseline_n', new.baseline_n
    ))
  );
  return null;
end;
$$;

drop trigger if exists trg_dss_interventions_log on public.dss_interventions;
create trigger trg_dss_interventions_log
  after insert on public.dss_interventions
  for each row execute function public.dss_interventions_log();

revoke all on function public.dss_interventions_stamp() from public, anon, authenticated;
revoke all on function public.dss_interventions_log() from public, anon, authenticated;
revoke all on function public.dss_outcome_value_text(text, numeric) from public, anon;
grant execute on function public.dss_outcome_value_text(text, numeric) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 3. Evaluate an intervention
--   Follow-up wave: the first CHED wave (published or closed) whose first
--   publish date is after the start date and after the baseline wave.
--   Group: the flag's level, course and batch in dss_cohort_metrics.
--   No comparable data: no group row, no value, fewer than 5 valid answers,
--   or no roster for a response rate. Inconclusive: below the rule minimum
--   (Watch). Otherwise Successful when the target is met, Partially
--   successful when the metric moved at least 5 points (0.5 salary
--   brackets) toward the target from the baseline, else Unsuccessful.
--   While the follow-up wave accepts responses nothing is stored except
--   Pending follow-up; the result is returned as a preview.
-- ---------------------------------------------------------------------------
create or replace function public.dss_evaluate_intervention(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  i public.dss_interventions%rowtype;
  f public.dss_flags%rowtype;
  w record;
  m record;
  v_base_at timestamptz;
  v_course text;
  v_batch text;
  v_open boolean;
  v_found boolean;
  v_status text;
  v_value numeric;
  v_n integer;
  v_gain numeric;
  v_met boolean;
  v_note text;
  v_label text;
begin
  if not public.is_admin() then
    raise exception 'Admin access required.' using errcode = '42501';
  end if;

  select * into i from public.dss_interventions where id = p_id for update;
  if not found then
    raise exception 'Intervention not found.' using errcode = 'P0002';
  end if;
  if i.decision is not null then
    return jsonb_build_object(
      'outcome_status', i.outcome_status, 'stored', true, 'provisional', false,
      'followup_survey_id', i.followup_survey_id,
      'followup_survey_title', i.followup_survey_title,
      'followup_value', i.followup_value, 'followup_n', i.followup_n,
      'note', i.evaluation_note);
  end if;
  select * into f from public.dss_flags where id = i.flag_id;

  select public.survey_first_published_at(s.data, s.open_at, s.created_at)
  into v_base_at
  from public.surveys s
  where s.id::text = i.baseline_survey_id;

  select s.id, s.title, s.status, s.close_at,
         public.survey_first_published_at(s.data, s.open_at, s.created_at) as wave_at
  into w
  from public.surveys s
  where s.data ->> 'template_key' = 'ched_gts_builtin'
    and s.status in ('published', 'closed')
    and coalesce(s.data ->> 'archived', '') <> 'true'
    and s.id::text is distinct from i.baseline_survey_id
    and (public.survey_first_published_at(s.data, s.open_at, s.created_at)
          at time zone 'Asia/Manila')::date > i.started_on
    and (v_base_at is null
      or public.survey_first_published_at(s.data, s.open_at, s.created_at) > v_base_at)
  order by 5, s.created_at, s.id
  limit 1;

  if not found then
    v_note := 'No CHED tracer wave has been published since the intervention started on '
      || to_char(i.started_on, 'YYYY-MM-DD') || '.';
    if i.outcome_status is distinct from 'pending_followup'
       or i.followup_survey_id is not null then
      update public.dss_interventions
      set outcome_status = 'pending_followup',
          followup_survey_id = null, followup_survey_title = null,
          followup_value = null, followup_n = null,
          evaluation_note = v_note, evaluated_at = now()
      where id = p_id;
    end if;
    return jsonb_build_object(
      'outcome_status', 'pending_followup', 'stored', true, 'provisional', false,
      'note', v_note);
  end if;

  v_open := not (w.status = 'closed' or (w.close_at is not null and w.close_at < now()));
  v_course := case when f.cohort_level = 'institution' then 'All' else f.course end;
  v_batch := case when f.cohort_level = 'batch' then f.batch_year else 'All' end;

  select x.value, x.total, x.respondents, x.eligible, x.evidence_strength
  into m
  from public.dss_cohort_metrics(w.id) x
  where x.level = f.cohort_level
    and x.course = v_course
    and x.batch_year = v_batch
    and x.metric_key = i.success_metric;
  v_found := found;

  v_value := case when v_found then m.value::numeric end;
  v_n := case when not v_found then null
              when i.success_metric = 'response_rate' then m.respondents
              else m.total end;

  if not v_found or v_value is null then
    v_status := 'no_comparable_data';
  elsif i.success_metric = 'response_rate' then
    v_status := case when coalesce(m.eligible, 0) = 0 then 'no_comparable_data' end;
  elsif m.evidence_strength = 'insufficient' then
    v_status := 'no_comparable_data';
  elsif m.evidence_strength = 'watch' then
    v_status := 'inconclusive';
  end if;

  -- Under 5 valid answers no rate is shown (Part 3 sample-size policy).
  if v_status = 'no_comparable_data' then
    v_value := null;
  end if;

  if v_status is null then
    v_met := case i.success_operator
      when 'lt' then v_value < i.success_target
      when 'lte' then v_value <= i.success_target
      when 'gt' then v_value > i.success_target
      else v_value >= i.success_target
    end;
    v_gain := case when i.success_operator in ('lt', 'lte')
      then i.baseline_value - v_value
      else v_value - i.baseline_value
    end;
    v_status := case
      when v_met then 'successful'
      when v_gain is not null
        and v_gain >= case when i.success_metric = 'salary_peer_gap' then 0.5 else 0.05 end - 0.000001
        then 'partially_successful'
      else 'unsuccessful'
    end;
  end if;

  v_note := w.title || ': '
    || case
         when v_status = 'no_comparable_data' then
           'fewer than 5 valid answers for this group, so there is no comparable result.'
         when v_status = 'inconclusive' then
           public.dss_outcome_value_text(i.success_metric, v_value) || ' from only '
           || v_n || ' valid answers, too few to judge.'
         else
           public.dss_outcome_value_text(i.success_metric, v_value) || ' from '
           || v_n || ' answers (target '
           || case i.success_operator
                when 'lt' then 'below '
                when 'lte' then 'at or below '
                when 'gt' then 'above '
                else 'at least '
              end
           || public.dss_outcome_value_text(i.success_metric, i.success_target)
           || coalesce('; baseline '
                || public.dss_outcome_value_text(i.success_metric, i.baseline_value), '')
           || '). This is an observed change, not proof that the intervention caused it.'
       end;

  if v_open then
    if i.outcome_status is distinct from 'pending_followup'
       or i.followup_survey_id is distinct from w.id::text
       or i.followup_value is not null then
      update public.dss_interventions
      set outcome_status = 'pending_followup',
          followup_survey_id = w.id::text, followup_survey_title = w.title,
          followup_value = null, followup_n = null,
          evaluation_note = 'Waiting for ' || w.title || ' to close.',
          evaluated_at = now()
      where id = p_id;
    end if;
  elsif (i.outcome_status, i.followup_survey_id, i.followup_value, i.followup_n)
        is distinct from (v_status, w.id::text, v_value, v_n) then
    update public.dss_interventions
    set outcome_status = v_status,
        followup_survey_id = w.id::text, followup_survey_title = w.title,
        followup_value = v_value, followup_n = v_n,
        evaluation_note = v_note, evaluated_at = now()
    where id = p_id;

    v_label := case v_status
      when 'successful' then 'Successful'
      when 'partially_successful' then 'Partially successful'
      when 'unsuccessful' then 'Unsuccessful'
      when 'inconclusive' then 'Inconclusive'
      else 'No comparable data'
    end;
    insert into public.dss_flag_notes (flag_id, note, event_type, metadata)
    values (
      i.flag_id,
      'Outcome: ' || v_label || '. ' || v_note,
      'outcome',
      jsonb_strip_nulls(jsonb_build_object(
        'action', 'evaluated',
        'intervention_id', i.id,
        'outcome_status', v_status,
        'followup_survey_id', w.id,
        'followup_value', v_value,
        'followup_n', v_n,
        'baseline_value', i.baseline_value,
        'success_target', i.success_target
      ))
    );
  end if;

  return jsonb_build_object(
    'outcome_status', case when v_open then 'pending_followup' else v_status end,
    'preview_status', case when v_open then v_status end,
    'stored', not v_open,
    'provisional', v_open,
    'followup_survey_id', w.id,
    'followup_survey_title', w.title,
    'followup_value', v_value,
    'followup_n', v_n,
    'evidence_strength', case when v_found then m.evidence_strength end,
    'note', v_note);
end;
$$;

revoke all on function public.dss_evaluate_intervention(uuid) from public, anon;
grant execute on function public.dss_evaluate_intervention(uuid) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 4. Decide after the outcome
--   resolve: the current flag of the finding is resolved if still active.
--   continue / modify: a new intervention starts today on the current flag,
--     with the follow-up as its baseline; modify takes the new plan. A
--     closed flag is reopened as in progress.
--   escalate: the office (optional) becomes the flag's owner office; a
--     closed flag is reopened as in progress.
--   Returns the new intervention id for continue / modify.
-- ---------------------------------------------------------------------------
create or replace function public.dss_decide_intervention(
  p_id uuid,
  p_decision text,
  p_note text,
  p_office text default null,
  p_intervention_type text default null,
  p_description text default null,
  p_expected_outcome text default null,
  p_success_target numeric default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  i public.dss_interventions%rowtype;
  f public.dss_flags%rowtype;
  v_note text := btrim(coalesce(p_note, ''));
  v_office text := nullif(btrim(coalesce(p_office, '')), '');
  v_uid uuid := auth.uid();
  v_name text;
  v_new uuid;
  v_label text;
begin
  if not public.is_admin() then
    raise exception 'Admin access required.' using errcode = '42501';
  end if;
  if p_decision is null or p_decision not in ('resolve', 'continue', 'modify', 'escalate') then
    raise exception 'Unknown decision: %', p_decision using errcode = '22023';
  end if;
  if v_note = '' then
    raise exception 'Add a note explaining the decision.' using errcode = '23514';
  end if;

  select * into i from public.dss_interventions where id = p_id for update;
  if not found then
    raise exception 'Intervention not found.' using errcode = 'P0002';
  end if;
  if i.decision is not null then
    raise exception 'A decision was already recorded for this intervention.'
      using errcode = '23514';
  end if;
  if i.outcome_status in ('not_evaluated', 'pending_followup') then
    raise exception 'Decide after the outcome is evaluated.' using errcode = '23514';
  end if;
  if p_decision <> 'escalate' then
    v_office := null;
  end if;

  select coalesce(nullif(btrim(u.display_name), ''), nullif(btrim(u.email), ''), 'Admin')
  into v_name
  from public.users u
  where u.id = v_uid;

  update public.dss_interventions
  set decision = p_decision,
      decision_note = v_note,
      escalated_to = v_office,
      decided_by = v_uid,
      decided_by_name = coalesce(v_name, 'Admin'),
      decided_at = now()
  where id = p_id;

  v_label := case p_decision
    when 'resolve' then 'Resolve'
    when 'continue' then 'Continue'
    when 'modify' then 'Modify'
    else 'Escalate'
  end;
  insert into public.dss_flag_notes (flag_id, note, event_type, metadata)
  values (
    i.flag_id,
    'Decision: ' || v_label
      || coalesce(' to ' || v_office, '') || '. ' || v_note,
    'outcome',
    jsonb_strip_nulls(jsonb_build_object(
      'action', 'decided',
      'intervention_id', i.id,
      'decision', p_decision,
      'escalated_to', v_office,
      'outcome_status', i.outcome_status
    ))
  );

  -- The finding's current flag: an active one first, then the newest.
  select * into f
  from public.dss_flags d
  where d.finding_key = i.finding_key
    and d.status <> 'superseded'
  order by (d.status in ('open', 'in_progress', 'watch')) desc, d.created_at desc
  limit 1;
  if not found then
    return null;
  end if;

  if p_decision = 'resolve' then
    if f.status in ('open', 'in_progress') then
      perform public.dss_update_flag_status(
        f.id, 'resolved', 'Resolved after the outcome check: ' || v_note);
    end if;
    return null;
  end if;

  if f.status in ('resolved', 'dismissed') then
    perform public.dss_update_flag_status(
      f.id, 'in_progress', 'Reopened after the outcome check (' || v_label || ').',
      p_clear_resolved_at => true);
    select * into f from public.dss_flags where id = f.id;
  end if;

  if p_decision = 'escalate' then
    if v_office is not null and f.status <> 'superseded' then
      update public.dss_flags
      set owner_office = v_office, updated_by = v_uid
      where id = f.id;
    end if;
    return null;
  end if;

  insert into public.dss_interventions (
    flag_id, continues_id, intervention_type, description, expected_outcome,
    success_target, started_on
  )
  values (
    f.id,
    i.id,
    case when p_decision = 'modify'
      then coalesce(nullif(btrim(p_intervention_type), ''), i.intervention_type)
      else i.intervention_type end,
    case when p_decision = 'modify'
      then coalesce(p_description, i.description)
      else i.description end,
    case when p_decision = 'modify'
      then coalesce(p_expected_outcome, i.expected_outcome)
      else i.expected_outcome end,
    case when p_decision = 'modify'
      then coalesce(p_success_target, i.success_target)
      else i.success_target end,
    (now() at time zone 'Asia/Manila')::date
  )
  returning id into v_new;
  return v_new;
end;
$$;

revoke all on function public.dss_decide_intervention(uuid, text, text, text, text, text, text, numeric) from public, anon;
grant execute on function public.dss_decide_intervention(uuid, text, text, text, text, text, text, numeric) to authenticated, service_role;

notify pgrst, 'reload schema';
