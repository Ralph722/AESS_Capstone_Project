-- Fix Supabase/PostgREST upsert support for events legacy Firestore IDs.
-- Partial unique indexes are not usable for `onConflict` in PostgREST.

begin;

drop index if exists public.idx_events_legacy_firestore_id;

alter table public.events
  add constraint events_legacy_firestore_id_key unique (legacy_firestore_id);

commit;
