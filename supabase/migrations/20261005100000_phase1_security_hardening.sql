-- Phase 1: critical security hardening.
--   * Registration links a roster row only for a signed-in account whose email
--     Supabase Auth has confirmed, and only when the roster details match.
--   * public.users rows are created when an email is confirmed, not at sign-up.
--   * Roster rows are no longer readable anonymously or claimable by anyone;
--     owners may only touch mirror fields.
--   * Deactivating a roster row bans the linked login and ends its sessions.
--   * Chat images move to a private bucket.
--   * Anonymous callers keep EXECUTE only on the eligibility check and the two
--     helpers referenced by policies that apply to every role.

-- ---------------------------------------------------------------------------
-- Registration
-- ---------------------------------------------------------------------------

drop function if exists public.link_alumni_registration(text, text, text, text, text, text);

create or replace function public.link_alumni_registration(
  p_member_id text,
  p_full_name text,
  p_student_id text,
  p_course text,
  p_email text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  sid text := public.normalize_student_id(p_student_id);
  course_norm text := public.normalize_course(p_course);
  member public.alumni_members%rowtype;
  account_email text;
  confirmed_at timestamptz;
begin
  if uid is null then
    return jsonb_build_object(
      'ok', false,
      'code', 'unauthenticated',
      'message', 'You must be signed in to complete registration.'
    );
  end if;

  select lower(u.email), u.email_confirmed_at
  into account_email, confirmed_at
  from auth.users u
  where u.id = uid;

  if confirmed_at is null then
    return jsonb_build_object(
      'ok', false,
      'code', 'failed_precondition',
      'message', 'Verify your email address before completing registration.'
    );
  end if;

  if coalesce(p_member_id, '') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    return jsonb_build_object(
      'ok', false,
      'code', 'not_found',
      'message', 'Alumni roster record was not found.'
    );
  end if;

  select * into member
  from public.alumni_members m
  where m.id = p_member_id::uuid
  for update;

  if not found then
    return jsonb_build_object(
      'ok', false,
      'code', 'not_found',
      'message', 'Alumni roster record was not found.'
    );
  end if;

  if public.normalize_student_id(member.student_id) <> sid
     or public.normalize_course(member.course) is distinct from course_norm
     or public.normalize_person_name(member.full_name) <> public.normalize_person_name(p_full_name) then
    return jsonb_build_object(
      'ok', false,
      'code', 'failed_precondition',
      'message', 'Your details do not match the official alumni roster.'
    );
  end if;

  if member.is_deactivated then
    return jsonb_build_object(
      'ok', false,
      'code', 'failed_precondition',
      'message', 'This alumni record has been deactivated. Please contact the alumni office.'
    );
  end if;

  if member.auth_uid is not null and member.auth_uid <> uid then
    return jsonb_build_object(
      'ok', false,
      'code', 'already_exists',
      'message', 'This ID number is already registered. Try logging in instead.'
    );
  end if;

  if exists (
    select 1 from public.alumni_members m
    where m.auth_uid = uid and m.id <> member.id
  ) then
    return jsonb_build_object(
      'ok', false,
      'code', 'already_exists',
      'message', 'This account is already linked to another alumni record.'
    );
  end if;

  update public.alumni_members
  set
    is_registered_user = true,
    auth_uid = uid,
    registered_email = account_email,
    updated_at = now()
  where id = member.id;

  insert into public.users (
    id, role, display_name, email, student_id, program, batch_year, year_graduated, updated_at
  ) values (
    uid,
    'user',
    coalesce(nullif(trim(member.full_name), ''), trim(p_full_name)),
    coalesce(account_email, ''),
    sid,
    course_norm,
    trim(coalesce(member.batch_year, '')),
    trim(coalesce(member.year_graduated, '')),
    now()
  )
  on conflict (id) do update set
    display_name = excluded.display_name,
    email = excluded.email,
    student_id = excluded.student_id,
    program = excluded.program,
    batch_year = coalesce(nullif(public.users.batch_year, ''), excluded.batch_year),
    year_graduated = coalesce(nullif(public.users.year_graduated, ''), excluded.year_graduated),
    updated_at = now();

  return jsonb_build_object('ok', true, 'memberId', member.id::text);
end;
$$;

revoke execute on function public.link_alumni_registration(text, text, text, text, text) from public, anon;
grant execute on function public.link_alumni_registration(text, text, text, text, text) to authenticated, service_role;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.email_confirmed_at is null then
    return new;
  end if;
  if tg_op = 'UPDATE' and old.email_confirmed_at is not null then
    return new;
  end if;

  insert into public.users (id, email, display_name, role)
  values (
    new.id,
    coalesce(new.email, ''),
    coalesce(new.raw_user_meta_data->>'display_name', ''),
    'user'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert or update of email_confirmed_at on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- Alumni roster access
-- ---------------------------------------------------------------------------

drop policy if exists alumni_members_select_anon_unclaimed on public.alumni_members;
drop policy if exists alumni_members_select_auth_admin_or_owner_or_unclaimed on public.alumni_members;
drop policy if exists alumni_members_update_admin_or_owner on public.alumni_members;

create policy alumni_members_select_admin_or_owner
  on public.alumni_members for select to authenticated
  using ((select public.is_admin()) or auth_uid = (select auth.uid()));

create policy alumni_members_update_admin_or_owner
  on public.alumni_members for update to authenticated
  using ((select public.is_admin()) or auth_uid = (select auth.uid()))
  with check ((select public.is_admin()) or auth_uid = (select auth.uid()));

-- Invoker rights on purpose: inside SECURITY DEFINER functions (such as
-- link_alumni_registration) current_user is the owner, so they pass through.
create or replace function public.alumni_members_guard_owner_update()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if current_user not in ('authenticated', 'anon') or public.is_admin() then
    return new;
  end if;

  if new.id is distinct from old.id
     or new.full_name is distinct from old.full_name
     or new.course is distinct from old.course
     or new.student_id is distinct from old.student_id
     or new.auth_uid is distinct from old.auth_uid
     or new.registered_email is distinct from old.registered_email
     or new.is_registered_user is distinct from old.is_registered_user
     or new.is_deactivated is distinct from old.is_deactivated
     or new.admin_viewed_at is distinct from old.admin_viewed_at
     or new.batch_year is distinct from old.batch_year
     or new.year_graduated is distinct from old.year_graduated
     or new.created_at is distinct from old.created_at then
    raise exception 'Only the alumni office can change official roster details.'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_alumni_members_guard_owner_update on public.alumni_members;
create trigger trg_alumni_members_guard_owner_update
  before update on public.alumni_members
  for each row execute function public.alumni_members_guard_owner_update();

-- ---------------------------------------------------------------------------
-- Deactivation is enforced by Supabase Auth, not only by the app
-- ---------------------------------------------------------------------------

create or replace function public.alumni_members_sync_auth_ban()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.auth_uid is null
     or exists (select 1 from public.users u where u.id = new.auth_uid and u.role = 'admin') then
    return new;
  end if;

  if new.is_deactivated and not coalesce(old.is_deactivated, false) then
    update auth.users set banned_until = '2999-12-31 00:00:00+00' where id = new.auth_uid;
    delete from auth.sessions where user_id = new.auth_uid;
  elsif not new.is_deactivated and coalesce(old.is_deactivated, false) then
    update auth.users set banned_until = null where id = new.auth_uid;
  end if;
  return new;
end;
$$;

revoke execute on function public.alumni_members_sync_auth_ban() from public, anon;

drop trigger if exists trg_alumni_members_sync_auth_ban on public.alumni_members;
create trigger trg_alumni_members_sync_auth_ban
  after update of is_deactivated on public.alumni_members
  for each row execute function public.alumni_members_sync_auth_ban();

-- ---------------------------------------------------------------------------
-- Private chat attachments
-- ---------------------------------------------------------------------------

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('message-attachments', 'message-attachments', false, 2097152, array['image/jpeg'])
on conflict (id) do update set
  public = false,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists message_attachments_insert_own on storage.objects;
drop policy if exists message_attachments_update_own on storage.objects;
drop policy if exists message_attachments_delete_own_or_admin on storage.objects;
drop policy if exists message_attachments_select_participants on storage.objects;

create policy message_attachments_insert_own
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'message-attachments'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy message_attachments_update_own
  on storage.objects for update to authenticated
  using (
    bucket_id = 'message-attachments'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  )
  with check (
    bucket_id = 'message-attachments'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy message_attachments_delete_own_or_admin
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'message-attachments'
    and (
      (storage.foldername(name))[1] = (select auth.uid())::text
      or (select public.is_admin())
    )
  );

create policy message_attachments_select_participants
  on storage.objects for select to authenticated
  using (
    bucket_id = 'message-attachments'
    and (
      (storage.foldername(name))[1] = (select auth.uid())::text
      or (select public.is_admin())
      or exists (
        select 1 from public.messages m
        where m.image_base64 = 'message-attachments/' || storage.objects.name
          and m.recipient_id = (select auth.uid())
      )
    )
  );

-- The public images bucket keeps serving avatars, event covers and job logos
-- by public URL; listing it now needs a session, and chat images can no
-- longer be uploaded there.
drop policy if exists images_public_read on storage.objects;
create policy images_public_read
  on storage.objects for select to authenticated
  using (bucket_id = 'images');

drop policy if exists images_owner_insert on storage.objects;
create policy images_owner_insert
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'images'
    and (
      (select public.is_admin())
      or ((storage.foldername(name))[1] = 'avatars'
          and name like 'avatars/' || (select auth.uid())::text || '%')
    )
  );

drop policy if exists images_owner_update on storage.objects;
create policy images_owner_update
  on storage.objects for update to authenticated
  using (
    bucket_id = 'images'
    and (
      (select public.is_admin())
      or ((storage.foldername(name))[1] = 'avatars'
          and name like 'avatars/' || (select auth.uid())::text || '%')
    )
  )
  with check (
    bucket_id = 'images'
    and (
      (select public.is_admin())
      or ((storage.foldername(name))[1] = 'avatars'
          and name like 'avatars/' || (select auth.uid())::text || '%')
    )
  );

update storage.buckets
set file_size_limit = 2097152, allowed_mime_types = array['image/jpeg']
where id = 'images';

create or replace function public.enforce_message_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  jwt_role text := coalesce(auth.role(), '');
  uid uuid := auth.uid();
  max_body int := 4000;
begin
  if jwt_role in ('service_role', 'postgres') then
    return new;
  end if;
  if uid is null then
    raise exception 'not authenticated';
  end if;
  if new.sender_id is distinct from uid then
    raise exception 'sender_id must be the authenticated user';
  end if;
  if length(coalesce(new.body, '')) > max_body then
    raise exception 'message body too long';
  end if;
  if nullif(trim(coalesce(new.image_base64, '')), '') is not null
     and new.image_base64 !~ ('^message-attachments/' || uid::text || '/[A-Za-z0-9_-]{1,128}\.jpg$') then
    raise exception 'invalid message image reference';
  end if;
  if public.is_admin() then
    new.sender_role := 'admin';
  else
    new.sender_role := 'user';
  end if;
  return new;
end;
$$;

create or replace function public.enforce_message_update()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  jwt_role text := coalesce(auth.role(), '');
  max_body int := 4000;
begin
  if jwt_role in ('service_role', 'postgres') then
    return new;
  end if;
  if public.is_admin() then
    if length(coalesce(new.body, '')) > max_body then
      raise exception 'message body too long';
    end if;
    return new;
  end if;
  if uid is null then
    raise exception 'not authenticated';
  end if;
  if length(coalesce(new.body, '')) > max_body then
    raise exception 'message body too long';
  end if;
  if old.sender_id = uid then
    if new.sender_id is distinct from old.sender_id
       or new.recipient_id is distinct from old.recipient_id
       or new.created_at is distinct from old.created_at
       or new.sender_role is distinct from old.sender_role then
      raise exception 'sender cannot reassign message participants';
    end if;
    if nullif(trim(coalesce(new.image_base64, '')), '') is not null
       and new.image_base64 is distinct from old.image_base64
       and new.image_base64 !~ ('^message-attachments/' || uid::text || '/[A-Za-z0-9_-]{1,128}\.jpg$') then
      raise exception 'invalid message image reference';
    end if;
    return new;
  end if;
  if old.recipient_id = uid then
    if new.body is distinct from old.body
       or new.image_base64 is distinct from old.image_base64
       or new.sender_id is distinct from old.sender_id
       or new.recipient_id is distinct from old.recipient_id
       or new.created_at is distinct from old.created_at
       or new.sender_role is distinct from old.sender_role then
      raise exception 'recipient cannot modify message content';
    end if;
    if new.is_read = true or new.reactions is distinct from old.reactions then
      return new;
    end if;
    raise exception 'recipient update not allowed';
  end if;
  raise exception 'not a participant';
end;
$$;

-- ---------------------------------------------------------------------------
-- Function EXECUTE for anonymous callers
-- ---------------------------------------------------------------------------

do $$
declare
  f record;
begin
  for f in
    select
      p.oid::regprocedure as sig,
      has_function_privilege('authenticated', p.oid, 'EXECUTE') as auth_ok,
      has_function_privilege('service_role', p.oid, 'EXECUTE') as service_ok
    from pg_proc p
    where p.pronamespace = 'public'::regnamespace
      and p.prokind = 'f'
      and has_function_privilege('anon', p.oid, 'EXECUTE')
      and not exists (
        select 1 from pg_depend d where d.objid = p.oid and d.deptype = 'e'
      )
  loop
    if f.auth_ok then
      execute format('grant execute on function %s to authenticated', f.sig);
    end if;
    if f.service_ok then
      execute format('grant execute on function %s to service_role', f.sig);
    end if;
    execute format('revoke execute on function %s from public, anon', f.sig);
  end loop;
end;
$$;

grant execute on function public.validate_alumni_eligibility(text, text, text) to anon;
grant execute on function public.is_admin() to anon;
grant execute on function public.is_signed_in() to anon;

alter default privileges for role postgres in schema public
  revoke execute on functions from anon;

notify pgrst, 'reload schema';
