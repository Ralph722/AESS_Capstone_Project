-- Phase 5: image storage bucket for profile + message images.
-- Public bucket so images render via simple public URLs (Image.network).

insert into storage.buckets (id, name, public)
values ('images', 'images', true)
on conflict (id) do update set public = true;

-- Public read of images in this bucket.
drop policy if exists "images_public_read" on storage.objects;
create policy "images_public_read"
on storage.objects
for select
to public
using (bucket_id = 'images');

-- Authenticated users can upload.
drop policy if exists "images_authenticated_insert" on storage.objects;
create policy "images_authenticated_insert"
on storage.objects
for insert
to authenticated
with check (bucket_id = 'images');

-- Authenticated users can overwrite / update objects in this bucket.
drop policy if exists "images_authenticated_update" on storage.objects;
create policy "images_authenticated_update"
on storage.objects
for update
to authenticated
using (bucket_id = 'images')
with check (bucket_id = 'images');

-- Authenticated users can delete objects in this bucket.
drop policy if exists "images_authenticated_delete" on storage.objects;
create policy "images_authenticated_delete"
on storage.objects
for delete
to authenticated
using (bucket_id = 'images');
