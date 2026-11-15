-- Soft-trim Program Insights to five non-overlapping core rules.
-- Keep evaluator / rule rows intact; only flip enabled defaults and dismiss
-- stale active findings for rules that are turned off.

-- 1) Enable the five keepers.
update public.dss_rules
set enabled = true,
    updated_at = now()
where rule_id in (
  'DATA_QUALITY_LOW',
  'UNEMPLOYMENT_HIGH',
  'RELATEDNESS_LOW',
  'UNDEREMPLOYMENT',
  'TIME_TO_JOB_LONG'
);

-- 2) Disable every other rule.
update public.dss_rules
set enabled = false,
    updated_at = now()
where rule_id not in (
  'DATA_QUALITY_LOW',
  'UNEMPLOYMENT_HIGH',
  'RELATEDNESS_LOW',
  'UNDEREMPLOYMENT',
  'TIME_TO_JOB_LONG'
);

-- 3) One-time Findings cleanup: dismiss open / in-progress / watch flags for
-- disabled rules so the queue is not crowded by non-core leftovers.
-- Do not delete flag history rows.
with to_dismiss as (
  select id, status as status_from
  from public.dss_flags
  where status in ('open', 'in_progress', 'watch')
    and rule_id not in (
      'DATA_QUALITY_LOW',
      'UNEMPLOYMENT_HIGH',
      'RELATEDNESS_LOW',
      'UNDEREMPLOYMENT',
      'TIME_TO_JOB_LONG'
    )
),
dismissed as (
  update public.dss_flags f
  set status = 'dismissed',
      resolved_at = coalesce(f.resolved_at, now()),
      updated_at = now()
  from to_dismiss d
  where f.id = d.id
  returning f.id, d.status_from
)
insert into public.dss_flag_notes (
  flag_id,
  author_name,
  note,
  status_from,
  status_to,
  event_type
)
select
  d.id,
  'system',
  'Disabled in lean rule set',
  d.status_from,
  'dismissed',
  'status'
from dismissed d;
