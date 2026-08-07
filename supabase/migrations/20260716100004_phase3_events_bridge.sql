-- Phase 3: bridge Firestore event IDs to Supabase events rows.

begin;

alter table public.events
  add column if not exists legacy_firestore_id text;

create unique index if not exists idx_events_legacy_firestore_id
  on public.events (legacy_firestore_id)
  where legacy_firestore_id is not null;

commit;
