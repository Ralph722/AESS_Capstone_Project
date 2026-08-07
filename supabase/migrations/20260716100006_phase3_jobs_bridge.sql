-- Phase 3: bridge Firestore job IDs to Supabase jobs rows.

begin;

alter table public.jobs
  add column if not exists legacy_firestore_id text;

alter table public.jobs
  add constraint jobs_legacy_firestore_id_key unique (legacy_firestore_id);

commit;
