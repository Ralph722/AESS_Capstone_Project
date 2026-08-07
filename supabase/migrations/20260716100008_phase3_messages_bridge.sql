-- Phase 3: bridge Firestore message IDs and metadata to Supabase messages rows.

begin;

alter table public.messages
  add column if not exists legacy_firestore_id text,
  add column if not exists sender_doc_id text,
  add column if not exists recipient_doc_id text,
  add column if not exists sender_role text not null default '',
  add column if not exists sender_name text not null default '',
  add column if not exists sender_email text not null default '',
  add column if not exists sender_legacy_firebase_uid text,
  add column if not exists recipient_legacy_firebase_uid text;

alter table public.messages
  add constraint messages_legacy_firestore_id_key unique (legacy_firestore_id);

commit;
