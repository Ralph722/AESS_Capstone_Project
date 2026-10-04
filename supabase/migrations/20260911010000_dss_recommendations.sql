-- DSS Recommendations: threshold flags, action log, rule config (admin-only).

begin;

create table if not exists public.dss_rules (
  rule_id text primary key,
  name text not null,
  description text not null default '',
  metric_key text not null,
  operator text not null default 'gte'
    check (operator in ('gte', 'lte', 'gt', 'lt')),
  threshold numeric not null,
  min_n integer not null default 20,
  enabled boolean not null default true,
  severity text not null default 'warning'
    check (severity in ('info', 'warning', 'critical')),
  recommended_action text not null default '',
  playbook jsonb not null default '[]'::jsonb,
  category text not null default 'outcome'
    check (category in ('outcome', 'data_quality', 'opportunity')),
  sort_order integer not null default 100,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.dss_flags (
  id uuid primary key default gen_random_uuid(),
  rule_id text not null references public.dss_rules(rule_id) on delete restrict,
  course text not null default '',
  batch_year text not null default '',
  survey_id text not null default '',
  survey_title text not null default '',
  metric_value numeric not null,
  threshold_snapshot numeric not null,
  sample_n integer not null default 0,
  eligible_n integer,
  confidence text not null default 'ok'
    check (confidence in ('ok', 'low')),
  status text not null default 'open'
    check (status in ('open', 'in_progress', 'resolved', 'dismissed')),
  title text not null,
  body text not null default '',
  recommended_action text not null default '',
  evidence jsonb not null default '{}'::jsonb,
  baseline_value numeric,
  followup_value numeric,
  followup_at timestamptz,
  intervention_type text,
  assigned_to uuid references auth.users(id) on delete set null,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  resolved_at timestamptz
);

-- One active (open/in_progress) flag per rule × cohort.
create unique index if not exists uq_dss_flags_active_cohort
  on public.dss_flags (rule_id, course, batch_year, survey_id)
  where status in ('open', 'in_progress');

create index if not exists idx_dss_flags_status_created
  on public.dss_flags (status, created_at desc);

create index if not exists idx_dss_flags_rule
  on public.dss_flags (rule_id, created_at desc);

create table if not exists public.dss_flag_notes (
  id uuid primary key default gen_random_uuid(),
  flag_id uuid not null references public.dss_flags(id) on delete cascade,
  author_id uuid references auth.users(id) on delete set null,
  author_name text not null default '',
  note text not null default '',
  status_from text,
  status_to text,
  created_at timestamptz not null default now()
);

create index if not exists idx_dss_flag_notes_flag
  on public.dss_flag_notes (flag_id, created_at desc);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_dss_rules_updated_at on public.dss_rules;
create trigger trg_dss_rules_updated_at
before update on public.dss_rules
for each row execute function public.set_updated_at();

drop trigger if exists trg_dss_flags_updated_at on public.dss_flags;
create trigger trg_dss_flags_updated_at
before update on public.dss_flags
for each row execute function public.set_updated_at();

alter table public.dss_rules enable row level security;
alter table public.dss_flags enable row level security;
alter table public.dss_flag_notes enable row level security;

drop policy if exists "dss_rules_admin_all" on public.dss_rules;
create policy "dss_rules_admin_all"
on public.dss_rules
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "dss_flags_admin_all" on public.dss_flags;
create policy "dss_flags_admin_all"
on public.dss_flags
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "dss_flag_notes_admin_all" on public.dss_flag_notes;
create policy "dss_flag_notes_admin_all"
on public.dss_flag_notes
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

-- Seed core rules (Phase 1 + Phase 2 keys; Phase 1 engine evaluates subset).
insert into public.dss_rules (
  rule_id, name, description, metric_key, operator, threshold, min_n,
  enabled, severity, recommended_action, playbook, category, sort_order
) values
(
  'DATA_QUALITY_LOW',
  'Low survey response rate',
  'Too few alumni in this cohort submitted the tracer survey for outcome flags to be reliable.',
  'response_rate',
  'lt',
  0.40,
  0,
  true,
  'warning',
  'Run a reminder campaign for incomplete respondents before acting on employment metrics.',
  '[
    {"step": "Open Surveys and review assignment completion for this course/batch."},
    {"step": "Send targeted announcements or messages to non-respondents."},
    {"step": "Re-run DSS evaluation after response rate improves."}
  ]'::jsonb,
  'data_quality',
  10
),
(
  'UNEMPLOYMENT_HIGH',
  'High unemployment',
  'Share of respondents not presently employed exceeds the configured threshold.',
  'unemployment_rate',
  'gte',
  0.25,
  20,
  true,
  'critical',
  'Coordinate with the Career Center for targeted job fairs, counseling, and job-board outreach.',
  '[
    {"step": "Review unemployed respondents in Reports (filtered by course/batch/wave)."},
    {"step": "Coordinate with Career Center on a job fair or coaching session."},
    {"step": "Publish relevant job postings and announce them to the cohort."},
    {"step": "Record actions taken in the flag notes, then mark Resolved."}
  ]'::jsonb,
  'outcome',
  20
),
(
  'RELATEDNESS_LOW',
  'Low course-relatedness / curriculum relevance',
  'Many alumni report first jobs not related to their course, or curriculum not relevant.',
  'unrelated_or_irrelevant_rate',
  'gte',
  0.40,
  20,
  true,
  'warning',
  'Flag for curriculum committee review; use alumni curriculum suggestions as supporting evidence.',
  '[
    {"step": "Inspect relatedness (ched_24a) and curriculum relevance (ched_32) breakdowns."},
    {"step": "Review curriculum suggestion themes (ched_34) attached as evidence."},
    {"step": "Schedule curriculum committee discussion with the evidence pack."},
    {"step": "Document committee outcome in the flag notes."}
  ]'::jsonb,
  'outcome',
  30
),
(
  'UNDEREMPLOYMENT',
  'Job-level mismatch (underemployment)',
  'Employed alumni reporting Rank/Clerical roles despite a bachelor''s pathway.',
  'clerical_among_employed_rate',
  'gte',
  0.35,
  20,
  true,
  'warning',
  'Review career-path alignment and curriculum pathways separately from unemployment interventions.',
  '[
    {"step": "Confirm job-level matrix answers (ched_30) for First/Current job."},
    {"step": "Discuss underemployment with curriculum and career counseling leads."},
    {"step": "Consider upskilling workshops or industry mentoring for the cohort."},
    {"step": "Keep this flag distinct from unemployment actions in notes."}
  ]'::jsonb,
  'outcome',
  40
),
(
  'TIME_TO_JOB_LONG',
  'Long time-to-first-job',
  'A large share of alumni took one year or longer to land a first job.',
  'long_time_to_first_job_rate',
  'gte',
  0.40,
  20,
  true,
  'warning',
  'Strengthen OJT/internship partnerships and earlier career counseling.',
  '[
    {"step": "Review time-to-first-job brackets (ched_29) for the cohort."},
    {"step": "Meet with OJT coordinators and industry partners."},
    {"step": "Plan earlier career counseling for current students in the same program."}
  ]'::jsonb,
  'outcome',
  50
),
(
  'SALARY_STAGNATION',
  'Salary bracket below peer programs',
  'Modal/median first-job salary bracket lags other programs in the same survey wave.',
  'salary_peer_gap',
  'gte',
  1.0,
  20,
  true,
  'info',
  'Review industry alignment and employer partnerships for the program.',
  '[
    {"step": "Compare salary brackets (ched_31) against other courses in the same wave."},
    {"step": "Identify target employers and partnership gaps."},
    {"step": "Document partnership or curriculum salary-alignment actions."}
  ]'::jsonb,
  'outcome',
  60
),
(
  'RELATEDNESS_HIGH',
  'Strong course-related employment',
  'A high share of alumni report course-related / curriculum-relevant first jobs.',
  'related_and_relevant_rate',
  'gte',
  0.75,
  20,
  true,
  'info',
  'Document and share successful practices with other departments.',
  '[
    {"step": "Capture practices that support strong relatedness outcomes."},
    {"step": "Share findings with other program chairs."},
    {"step": "Optional: invite alumni mentors from this cohort."}
  ]'::jsonb,
  'opportunity',
  70
)
on conflict (rule_id) do update set
  name = excluded.name,
  description = excluded.description,
  metric_key = excluded.metric_key,
  operator = excluded.operator,
  threshold = excluded.threshold,
  min_n = excluded.min_n,
  severity = excluded.severity,
  recommended_action = excluded.recommended_action,
  playbook = excluded.playbook,
  category = excluded.category,
  sort_order = excluded.sort_order,
  updated_at = now();

commit;
