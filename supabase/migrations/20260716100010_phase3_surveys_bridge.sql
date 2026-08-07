-- Phase 3: bridge Firestore survey IDs to Supabase survey tables.

begin;

alter table public.survey_templates
  add column if not exists legacy_firestore_id text;

alter table public.survey_templates
  add constraint survey_templates_legacy_firestore_id_key unique (legacy_firestore_id);

alter table public.survey_template_questions
  add column if not exists legacy_firestore_id text;

alter table public.survey_template_questions
  add constraint survey_template_questions_legacy_firestore_id_key unique (legacy_firestore_id);

alter table public.surveys
  add column if not exists legacy_firestore_id text,
  add column if not exists template_legacy_firestore_id text,
  add column if not exists created_by_legacy_firebase_uid text,
  add column if not exists data jsonb not null default '{}'::jsonb;

alter table public.surveys
  add constraint surveys_legacy_firestore_id_key unique (legacy_firestore_id);

alter table public.survey_questions
  add column if not exists legacy_firestore_id text;

alter table public.survey_questions
  add constraint survey_questions_legacy_firestore_id_key unique (legacy_firestore_id);

alter table public.survey_assignments
  add column if not exists legacy_firestore_id text,
  add column if not exists legacy_firebase_user_id text;

alter table public.survey_assignments
  add constraint survey_assignments_legacy_firestore_id_key unique (legacy_firestore_id);

create unique index if not exists idx_survey_assignments_survey_user
  on public.survey_assignments (survey_id, user_id);

alter table public.survey_responses
  add column if not exists legacy_firebase_user_id text;

commit;
