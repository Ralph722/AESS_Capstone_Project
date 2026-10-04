-- DSS trends: compare the same group across consecutive CHED GTS waves.

begin;

alter table public.dss_rules
  drop constraint if exists dss_rules_category_check;

alter table public.dss_rules
  add constraint dss_rules_category_check
  check (category in ('outcome', 'data_quality', 'opportunity', 'trend'));

insert into public.dss_rules (
  rule_id, name, description, metric_key, operator, threshold, min_n,
  enabled, severity, recommended_action, playbook, category, sort_order
) values (
  'UNEMPLOYMENT_TREND_UP',
  'Unemployment rising between waves',
  'The share of respondents not presently employed rose by at least the threshold (in percentage points) compared with the previous tracer wave for the same group.',
  'unemployment_change_pts',
  'gte',
  0.10,
  10,
  true,
  'warning',
  'Find out what changed since the previous wave (job market, employer partners, batch profile) and start employment support before the next wave.',
  '[
    {"step": "Compare both waves for this group in Reports (CHED wave comparison)."},
    {"step": "Check whether employer partners or local hiring changed since the previous wave."},
    {"step": "Send matching job postings or arrange career counseling for the group."},
    {"step": "Record what you did in the flag notes, then recheck after the next wave."}
  ]'::jsonb,
  'trend',
  80
)
on conflict (rule_id) do update set
  name = excluded.name,
  description = excluded.description,
  metric_key = excluded.metric_key,
  operator = excluded.operator,
  recommended_action = excluded.recommended_action,
  playbook = excluded.playbook,
  category = excluded.category,
  sort_order = excluded.sort_order,
  updated_at = now();

commit;
