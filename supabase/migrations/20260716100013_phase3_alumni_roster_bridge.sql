-- Phase 3: harden alumni_members bridge for upsert + Firebase UID mirror.

begin;

-- Replace partial unique index with a proper unique constraint for PostgREST upsert.
drop index if exists idx_alumni_members_legacy_firestore_id;

alter table public.alumni_members
  add column if not exists auth_legacy_firebase_uid text;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'alumni_members_legacy_firestore_id_key'
  ) then
    alter table public.alumni_members
      add constraint alumni_members_legacy_firestore_id_key unique (legacy_firestore_id);
  end if;
end $$;

commit;
