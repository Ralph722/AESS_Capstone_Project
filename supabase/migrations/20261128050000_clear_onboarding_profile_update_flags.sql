-- Clear false-positive directory Updates flags caused by onboarding finish
-- always calling flagProfileUpdatedForAuthUid. Keep flags only when a
-- review-eligible PROFILE_UPDATE exists (profile / tracer / survey).

update public.alumni_members am
   set has_profile_updates = false,
       profile_updated_at = null
 where am.has_profile_updates = true
   and am.auth_uid is not null
   and not exists (
     select 1
       from public.audit_logs al
      where al.action = 'PROFILE_UPDATE'
        and al.entity_id = am.auth_uid::text
        and coalesce(al.details -> 'changes' ->> 'source', '')
            in ('profile', 'tracer', 'survey')
   );

-- Also clear flagged rows with no linked auth user (cannot have live-profile
-- review-eligible updates).
update public.alumni_members
   set has_profile_updates = false,
       profile_updated_at = null
 where has_profile_updates = true
   and auth_uid is null;
