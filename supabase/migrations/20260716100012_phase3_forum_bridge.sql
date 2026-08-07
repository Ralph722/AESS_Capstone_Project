-- Phase 3: bridge Firestore forum IDs to Supabase forum tables.

begin;

alter table public.forum_topics
  add column if not exists legacy_firestore_id text,
  add column if not exists author_legacy_firebase_uid text;

alter table public.forum_topics
  add constraint forum_topics_legacy_firestore_id_key unique (legacy_firestore_id);

alter table public.forum_posts
  add column if not exists legacy_firestore_id text,
  add column if not exists author_legacy_firebase_uid text,
  add column if not exists topic_legacy_firestore_id text;

alter table public.forum_posts
  add constraint forum_posts_legacy_firestore_id_key unique (legacy_firestore_id);

commit;
