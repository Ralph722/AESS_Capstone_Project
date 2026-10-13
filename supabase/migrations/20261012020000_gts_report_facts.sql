-- Report builder data source: one row per submitted CHED GTS response with
-- the roster cohort (same join as gts_respondent_facts) and the answers
-- minus personal items (1-5 name/address/email/phones, 8 birthday).
-- Caller's RLS applies: admins see all responses, alumni only their own.

create or replace view public.gts_report_facts
with (security_invoker = true)
as
select
  r.id as response_id,
  r.survey_id,
  r.user_id,
  coalesce(r.submitted_at, r.updated_at) as submitted_at,
  (m.id is not null) as on_active_roster,
  coalesce(btrim(m.course), '') as course,
  coalesce(btrim(m.year_graduated), '') as year_graduated,
  r.answers - array['ched_1', 'ched_2', 'ched_3', 'ched_4', 'ched_5', 'ched_8'] as answers
from public.survey_responses r
join public.surveys s
  on s.id = r.survey_id
 and s.data ->> 'template_key' = 'ched_gts_builtin'
left join public.alumni_members m
  on m.auth_uid = r.user_id
 and not m.is_deactivated
where r.status = 'submitted';

revoke all on public.gts_report_facts from public, anon, authenticated;
grant select on public.gts_report_facts to authenticated, service_role;

notify pgrst, 'reload schema';
