-- Phase 2 roster bridge: map Firestore alumni_members doc IDs to Supabase rows.

begin;

alter table public.alumni_members
  add column if not exists legacy_firestore_id text;

create unique index if not exists idx_alumni_members_legacy_firestore_id
  on public.alumni_members (legacy_firestore_id)
  where legacy_firestore_id is not null;

commit;
