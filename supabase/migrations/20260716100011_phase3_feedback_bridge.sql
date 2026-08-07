-- Phase 3: bridge Firestore feedback IDs to Supabase feedback rows.

begin;

alter table public.feedback
  add column if not exists legacy_firestore_id text,
  add column if not exists data jsonb not null default '{}'::jsonb;

alter table public.feedback
  add constraint feedback_legacy_firestore_id_key unique (legacy_firestore_id);

commit;
