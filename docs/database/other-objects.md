# Other Database Objects

> Snapshot of the live schema in the linked Supabase project, taken 2026-10-05 with read-only queries. It contains structure only, no row data. Regenerate it from `queries/` instead of editing by hand; the migrations in `supabase/migrations` remain the source of truth.

Enums, views, storage buckets, Realtime publications, scheduled jobs and extensions. Scheduled job commands are left out because they can carry request headers.


## Views

| Name | Definition |
|---|---|
| gts_employment_records | `SELECT DISTINCT ON (f.user_id) f.response_id AS id, f.user_id, CASE f.presently_employed WHEN 'Yes'::text THEN 'Employed'::text WHEN 'Never Employed'::text THEN 'Never Employed'::text ELSE 'Unemployed'::text END AS status, NULL::text AS company, f.occupation AS "position", NULL::date AS start_date, jsonb_strip_nulls(jsonb_build_object('source', 'ched_gts', 'surveyId', f.survey_id, 'userName', COALESCE(NULLIF(btrim(u.display_name), ''::text), m.full_name), 'userEmail', COALESCE(u.email, m.registered_email), 'schoolId', COALESCE(NULLIF(btrim(m.student_id), ''::text), u.student_id), 'contactNumber', COALESCE(NULLIF(btrim(u.mobile_number), ''::text), m.contact_number), 'industry', f.industry, 'employmentType', f.employment_type, 'jobLevel', f.job_level, 'salaryRange', f.initial_salary, 'placeOfWork', f.place_of_work, 'country', CASE f.place_of_work WHEN 'Local'::text THEN 'Philippines'::text WHEN 'Abroad'::text THEN 'Abroad'::text ELSE NULL::text END)) AS data, 'Submitted'::text AS verification_status, NULL::uuid AS verified_by, NULL::timestamp with time zone AS verified_at, f.submitted_at AS created_at, f.submitted_at AS updated_at FROM ((gts_respondent_facts f LEFT JOIN users u ON ((u.id = f.user_id))) LEFT JOIN alumni_members m ON ((m.auth_uid = f.user_id))) WHERE (f.presently_employed IS NOT NULL) ORDER BY f.user_id, f.submitted_at DESC, f.response_id;` |
| gts_respondent_facts | `SELECT r.id AS response_id, r.survey_id, r.user_id, COALESCE(r.submitted_at, r.updated_at) AS submitted_at, m.id AS member_id, (m.id IS NOT NULL) AS on_active_roster, COALESCE(NULLIF(btrim(m.course), ''::text), 'Unknown'::text) AS course, COALESCE(NULLIF(btrim(m.year_graduated), ''::text), 'Unknown'::text) AS year_graduated, gts_single((r.answers -> 'ched_16'::text)) AS presently_employed, gts_single((r.answers -> 'ched_18'::text)) AS employment_type, gts_single((r.answers -> 'ched_19'::text)) AS occupation, CASE WHEN (gts_single((r.answers -> 'ched_20'::text)) ~~ 'Others%'::text) THEN COALESCE(gts_single((r.answers -> 'ched_20_other'::text)), gts_single((r.answers -> 'ched_20'::text))) ELSE gts_single((r.answers -> 'ched_20'::text)) END AS industry, gts_single((r.answers -> 'ched_21'::text)) AS place_of_work, gts_single((r.answers -> 'ched_24a'::text)) AS first_job_related, gts_single((r.answers -> 'ched_29'::text)) AS time_to_first_job, gts_job_level((r.answers -> 'ched_30'::text)) AS job_level, gts_single((r.answers -> 'ched_31'::text)) AS initial_salary, gts_salary_rank(gts_single((r.answers -> 'ched_31'::text))) AS salary_rank, gts_single((r.answers -> 'ched_32'::text)) AS curriculum_relevant FROM ((survey_responses r JOIN surveys s ON (((s.id = r.survey_id) AND ((s.data ->> 'template_key'::text) = 'ched_gts_builtin'::text)))) LEFT JOIN alumni_members m ON (((m.auth_uid = r.user_id) AND (NOT m.is_deactivated)))) WHERE (r.status = 'submitted'::text);` |

## Storage buckets

| Name | Settings |
|---|---|
| images | public=true, size_limit=2097152, mime=image/jpeg |
| message-attachments | public=false, size_limit=2097152, mime=image/jpeg |

## Tables published to Realtime

- `public.announcements`
- `public.event_comments`
- `public.event_replies`
- `public.event_rsvps`
- `public.events`
- `public.feedback`
- `public.forum_posts`
- `public.forum_topics`
- `public.messages`
- `public.survey_assignments`
- `public.user_notifications`

## Scheduled jobs (pg_cron)

| Name | Schedule (UTC) |
|---|---|
| aess-audit-retention | `45 19 * * *` |
| aess-dss-recheck | `15 19 * * *` |
| aess-notify-cleanup | `30 19 * * *` |
| aess-notify-events | `0 23 * * *` |
| aess-notify-frequent | `*/15 * * * *` |
| aess-notify-morning | `0 0 * * *` |
| aess-notify-tracer-reminders | `*/5 * * * *` |
| aess-push-dispatch | `* * * * *` |

## Extensions

| Name | Version |
|---|---|
| pg_cron | 1.6.4 |
| pg_net | 0.20.3 |
| pg_stat_statements | 1.11 |
| pgcrypto | 1.3 |
| plpgsql | 1.0 |
| supabase_vault | 0.3.1 |
| uuid-ossp | 1.1 |
