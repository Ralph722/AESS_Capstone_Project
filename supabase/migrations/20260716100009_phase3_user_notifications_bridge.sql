-- Phase 3: bridge Firestore notification IDs to Supabase user_notifications rows.

begin;

alter table public.user_notifications
  add column if not exists legacy_firestore_id text;

alter table public.user_notifications
  add constraint user_notifications_legacy_firestore_id_key unique (legacy_firestore_id);

commit;
