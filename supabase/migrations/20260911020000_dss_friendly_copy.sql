-- Friendlier DSS rule labels for admins (copy only; logic unchanged).

begin;

update public.dss_rules
set
  name = 'Survey data quality',
  description =
    'Checks whether enough alumni answered the tracer survey. Can flag a low response rate and/or too few responses to trust outcome findings.',
  recommended_action =
    'Improve survey participation for this cohort before relying on employment or curriculum outcome flags.',
  playbook = '[
    {"step": "Check how many alumni in this course/batch still need to submit."},
    {"step": "Send reminders (announcement or message) to non-respondents."},
    {"step": "Refresh DSS insights after more responses arrive."}
  ]'::jsonb,
  updated_at = now()
where rule_id = 'DATA_QUALITY_LOW';

update public.dss_rules
set
  name = 'High unemployment',
  description = 'A large share of respondents are not presently employed.',
  updated_at = now()
where rule_id = 'UNEMPLOYMENT_HIGH';

update public.dss_rules
set
  name = 'Jobs not aligned with course',
  description =
    'Many alumni say their first job was not related to their course, or the curriculum was not relevant.',
  updated_at = now()
where rule_id = 'RELATEDNESS_LOW';

update public.dss_rules
set
  name = 'Strong course alignment',
  description =
    'Many alumni report jobs and curriculum that align well with their course — a positive signal to share.',
  updated_at = now()
where rule_id = 'RELATEDNESS_HIGH';

update public.dss_rules
set
  name = 'Underemployment (job level)',
  description =
    'Many employed alumni report Rank/Clerical roles — different from unemployment.',
  updated_at = now()
where rule_id = 'UNDEREMPLOYMENT';

update public.dss_rules
set
  name = 'Long time to first job',
  description = 'Many alumni took one year or longer to land their first job.',
  updated_at = now()
where rule_id = 'TIME_TO_JOB_LONG';

update public.dss_rules
set
  name = 'Salary below peer programs',
  description =
    'First-job salary brackets for this program lag other programs in the same survey wave.',
  updated_at = now()
where rule_id = 'SALARY_STAGNATION';

commit;
