-- Phase 3: bridge Firestore announcement IDs to Supabase announcements rows.

begin;

alter table public.announcements
  add column if not exists legacy_firestore_id text;

alter table public.announcements
  add constraint announcements_legacy_firestore_id_key unique (legacy_firestore_id);

commit;
