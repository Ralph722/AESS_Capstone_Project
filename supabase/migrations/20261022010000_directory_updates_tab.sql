-- Directory "Updates" tab + profile-change timeline support.
--
-- alumni_members.has_profile_updates already flags members whose live profile
-- changed since an admin last reviewed them. Until now the directory could
-- only surface that as a conditional KPI card, and opening the member detail
-- cleared the flag (view = reviewed). This adds when the latest unreviewed
-- update happened so the Updates tab can sort newest-first, and backfills it
-- for members already flagged.

alter table public.alumni_members
  add column if not exists profile_updated_at timestamptz;

update public.alumni_members
   set profile_updated_at = coalesce(updated_at, created_at, now())
 where has_profile_updates
   and profile_updated_at is null;

create index if not exists alumni_members_profile_updates_idx
  on public.alumni_members (profile_updated_at desc nulls last)
  where has_profile_updates;
