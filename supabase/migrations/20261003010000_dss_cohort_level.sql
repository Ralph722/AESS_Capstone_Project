-- DSS roll-up: flags can be raised for a course × batch, a whole course
-- (batch_year = 'All') or the whole institution (course = batch_year = 'All')
-- when smaller groups are below a rule's minimum responses.

begin;

alter table public.dss_flags
  add column if not exists cohort_level text not null default 'batch';

alter table public.dss_flags
  drop constraint if exists dss_flags_cohort_level_check;

alter table public.dss_flags
  add constraint dss_flags_cohort_level_check
  check (cohort_level in ('batch', 'course', 'institution'));

-- One active (open/in_progress) flag per rule × cohort × level × wave.
drop index if exists public.uq_dss_flags_active_cohort;

create unique index uq_dss_flags_active_cohort
  on public.dss_flags (rule_id, cohort_level, course, batch_year, survey_id)
  where status in ('open', 'in_progress');

commit;
