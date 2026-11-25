-- Allow alumni to upload/replace/delete their own community job-offer covers
-- under images/forum_jobs/{uid}/{topicId}/cover.jpg.
-- Admin uploads elsewhere (events/, jobs/) remain admin-only.

begin;

drop policy if exists images_owner_insert on storage.objects;
create policy images_owner_insert
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'images'
    and (
      (select public.is_admin())
      or (
        (storage.foldername(name))[1] = 'avatars'
        and name like 'avatars/' || (select auth.uid())::text || '%'
      )
      or (
        (storage.foldername(name))[1] = 'forum_jobs'
        and (storage.foldername(name))[2] = (select auth.uid())::text
      )
    )
  );

drop policy if exists images_owner_update on storage.objects;
create policy images_owner_update
  on storage.objects for update to authenticated
  using (
    bucket_id = 'images'
    and (
      (select public.is_admin())
      or (
        (storage.foldername(name))[1] = 'avatars'
        and name like 'avatars/' || (select auth.uid())::text || '%'
      )
      or (
        (storage.foldername(name))[1] = 'forum_jobs'
        and (storage.foldername(name))[2] = (select auth.uid())::text
      )
    )
  )
  with check (
    bucket_id = 'images'
    and (
      (select public.is_admin())
      or (
        (storage.foldername(name))[1] = 'avatars'
        and name like 'avatars/' || (select auth.uid())::text || '%'
      )
      or (
        (storage.foldername(name))[1] = 'forum_jobs'
        and (storage.foldername(name))[2] = (select auth.uid())::text
      )
    )
  );

drop policy if exists images_owner_delete on storage.objects;
create policy images_owner_delete
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'images'
    and (
      (select public.is_admin())
      or (
        (storage.foldername(name))[1] = 'messages'
        and (storage.foldername(name))[2] = (select auth.uid())::text
      )
      or (
        (storage.foldername(name))[1] = 'avatars'
        and name like 'avatars/' || (select auth.uid())::text || '%'
      )
      or (
        (storage.foldername(name))[1] = 'forum_jobs'
        and (storage.foldername(name))[2] = (select auth.uid())::text
      )
    )
  );

commit;
