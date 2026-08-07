-- Phase 2 auth bridge:
-- Keep a link from Supabase auth users to legacy Firebase-auth-backed records
-- while the app migrates service by service.

begin;

alter table public.users
  add column if not exists legacy_firebase_uid text;

create unique index if not exists idx_users_legacy_firebase_uid
  on public.users (legacy_firebase_uid)
  where legacy_firebase_uid is not null;

commit;
