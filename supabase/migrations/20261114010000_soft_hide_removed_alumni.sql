-- Soft-hide removed alumni from the alumni app.
-- Interaction rows stay in the database; non-admins no longer see forum /
-- event content authored by users with users.anonymized_at set. Admins retain
-- full visibility and can resolve roster legal names via former_auth_uid.

begin;

-- ---------------------------------------------------------------------------
-- Helper: anonymized portal user?
-- ---------------------------------------------------------------------------
create or replace function public.user_is_anonymized(p_uid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select p_uid is not null
    and exists (
      select 1
      from public.users u
      where u.id = p_uid
        and u.anonymized_at is not null
    );
$$;

revoke all on function public.user_is_anonymized(uuid) from public, anon;
grant execute on function public.user_is_anonymized(uuid) to authenticated, service_role;

comment on function public.user_is_anonymized(uuid) is
  'True when the portal user row has anonymized_at (Remove account).';

-- ---------------------------------------------------------------------------
-- Preserve auth link for admin name resolution after unlink
-- ---------------------------------------------------------------------------
alter table public.alumni_members
  add column if not exists former_auth_uid uuid;

create index if not exists alumni_members_former_auth_uid_idx
  on public.alumni_members (former_auth_uid)
  where former_auth_uid is not null;

comment on column public.alumni_members.former_auth_uid is
  'Last linked auth user id after Remove account (auth_uid cleared). Admin display only.';

-- ---------------------------------------------------------------------------
-- Audience RLS: hide anonymized authors from non-admins
-- ---------------------------------------------------------------------------
alter policy forum_topics_select_signed_in on public.forum_topics
  using (
    (select public.is_signed_in())
    and (
      (select public.is_admin())
      or not public.user_is_anonymized(author_uid)
    )
  );

alter policy forum_posts_select_signed_in on public.forum_posts
  using (
    (select public.is_signed_in())
    and (
      (select public.is_admin())
      or not public.user_is_anonymized(author_uid)
    )
  );

alter policy event_comments_select_signed_in on public.event_comments
  using (
    (select public.is_signed_in())
    and (
      (select public.is_admin())
      or not public.user_is_anonymized(user_id)
    )
  );

alter policy event_replies_select_signed_in on public.event_replies
  using (
    (select public.is_signed_in())
    and (
      (select public.is_admin())
      or not public.user_is_anonymized(user_id)
    )
  );

-- ---------------------------------------------------------------------------
-- Admin-facing profile names for removed users (roster legal name)
-- ---------------------------------------------------------------------------
create or replace function public.get_public_profiles(p_ids uuid[])
returns table (
  id uuid,
  display_name text,
  profile_image_base64 text,
  program text,
  year_graduated text,
  role text,
  email text
)
language sql
stable
security definer
set search_path = public
as $$
  select
    u.id,
    case
      when u.anonymized_at is not null and public.is_admin() then
        coalesce(
          (
            select nullif(btrim(m.full_name), '')
            from public.alumni_members m
            where m.former_auth_uid = u.id
            order by m.updated_at desc nulls last
            limit 1
          ),
          (
            select nullif(btrim(m.full_name), '')
            from public.alumni_members m
            where m.auth_uid = u.id
            order by m.updated_at desc nulls last
            limit 1
          ),
          'Removed alumni'
        )
      when u.anonymized_at is not null then 'Deleted alumni'
      when nullif(trim(u.display_name), '') is not null then u.display_name
      when u.role = 'admin' then 'Admin'
      else 'Alumnus'
    end,
    case when u.anonymized_at is null then u.profile_image_base64 end,
    u.program,
    u.year_graduated,
    u.role,
    case when public.is_admin() or u.id = auth.uid() then u.email else '' end
  from public.users u
  where public.caller_is_active()
    and u.id = any (p_ids[1:500]);
$$;

revoke all on function public.get_public_profiles(uuid[]) from public, anon;
grant execute on function public.get_public_profiles(uuid[]) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Remove account: hide-based peer visibility; keep interaction rows
-- ---------------------------------------------------------------------------
create or replace function public.admin_remove_alumni_account(p_member_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin uuid := auth.uid();
  v_member public.alumni_members%rowtype;
  v_uid uuid;
  v_avatar text;
  v_placeholder text;
  v_anon_name constant text := 'Deleted alumni';
  v_roster_name text;
begin
  if v_admin is null or not public.is_admin() then
    raise exception 'Admin access required.' using errcode = '42501';
  end if;
  select * into v_member from public.alumni_members where id = p_member_id for update;
  if not found then
    raise exception 'Roster entry not found.';
  end if;
  v_uid := v_member.auth_uid;
  if v_uid is null then
    raise exception 'This roster entry has no linked portal account.';
  end if;
  if v_uid = v_admin then
    raise exception 'You cannot remove your own account.' using errcode = '42501';
  end if;
  if exists (select 1 from public.users where id = v_uid and role = 'admin') then
    raise exception 'Admin accounts cannot be removed here.' using errcode = '42501';
  end if;

  v_roster_name := nullif(btrim(v_member.full_name), '');
  select profile_image_base64 into v_avatar from public.users where id = v_uid;
  v_placeholder := 'removed+' || v_uid::text || '@removed.invalid';

  update auth.users
  set email = v_placeholder,
      phone = null,
      raw_user_meta_data = jsonb_build_object(
        'display_name', coalesce(v_roster_name, v_anon_name)
      ),
      banned_until = '2999-12-31 00:00:00+00',
      updated_at = now()
  where id = v_uid;

  update auth.identities
  set identity_data = coalesce(identity_data, '{}'::jsonb)
        || jsonb_build_object('email', v_placeholder, 'email_verified', false),
      updated_at = now()
  where user_id = v_uid;

  delete from auth.sessions where user_id = v_uid;

  update public.users
  set display_name = v_anon_name,
      email = '',
      student_id = '',
      address = '',
      birth_date = null,
      telephone_number = '',
      mobile_number = '',
      honors_awards = '',
      profile_image_base64 = null,
      deactivated_at = coalesce(deactivated_at, now()),
      anonymized_at = now(),
      updated_at = now()
  where id = v_uid;

  update public.survey_responses
  set answers = answers - array['ched_1', 'ched_2', 'ched_3', 'ched_4', 'ched_5', 'ched_8']
  where user_id = v_uid;

  -- Admin message threads keep the roster name; email cleared. Rows are not deleted.
  update public.messages
  set sender_name = coalesce(v_roster_name, sender_name),
      sender_email = ''
  where sender_id = v_uid;

  -- Soft-hide alumni notifications that would resurface this person's forum /
  -- event activity (client already drops expired rows). Do not delete rows.
  update public.user_notifications n
  set expires_at = now(),
      updated_at = now()
  where (n.expires_at is null or n.expires_at > now())
    and (
      (
        n.type = 'forum'
        and (
          (
            nullif(n.data->>'postId', '') is not null
            and exists (
              select 1
              from public.forum_posts p
              where p.id::text = n.data->>'postId'
                and p.author_uid = v_uid
            )
          )
          or (
            nullif(n.data->>'topicId', '') is not null
            and nullif(n.data->>'postId', '') is null
            and exists (
              select 1
              from public.forum_topics t
              where t.id::text = n.data->>'topicId'
                and t.author_uid = v_uid
            )
          )
        )
      )
      or (
        coalesce(n.data->>'target', '') = 'event_comments'
        and (
          exists (
            select 1
            from public.event_comments c
            where c.user_id = v_uid
              and (
                c.id::text = coalesce(n.data->>'relatedId', '')
                or c.event_id::text = coalesce(n.data->>'relatedId', '')
              )
          )
          or exists (
            select 1
            from public.event_replies r
            where r.user_id = v_uid
              and (
                r.id::text = coalesce(n.data->>'relatedId', '')
                or r.event_id::text = coalesce(n.data->>'relatedId', '')
                or r.comment_id::text = coalesce(n.data->>'relatedId', '')
              )
          )
        )
      )
    );

  -- Forum / event author labels are left intact for admin; peers cannot select
  -- those rows once anonymized_at is set (RLS above).

  update public.audit_logs
  set details = details || jsonb_build_object('userName', v_anon_name, 'userEmail', '')
  where user_id = v_uid;

  delete from public.push_tokens where user_id = v_uid;
  delete from public.notification_preferences where user_id = v_uid;
  delete from public.tracer_draft_reminders where user_id = v_uid;

  update public.alumni_members
  set former_auth_uid = v_uid,
      auth_uid = null,
      is_registered_user = false,
      registered_email = null,
      is_deactivated = true,
      contact_number = '',
      email_address = '',
      address = null,
      birth_date = null,
      gender = null,
      civil_status = null,
      profile_image_url = null,
      tracer_profile_complete = false,
      has_profile_updates = false,
      updated_at = now()
  where id = p_member_id;

  insert into public.audit_logs (user_id, action, entity_type, entity_id, details)
  values (
    v_admin,
    'REMOVE_ALUMNI_ACCOUNT',
    'AlumniMember',
    p_member_id::text,
    jsonb_build_object(
      'description', 'Removed portal account for ' || coalesce(v_roster_name, 'alumni')
        || ' (deactivated and anonymized; peer activity soft-hidden; tracer answers kept)',
      'status', 'SUCCESS',
      'changes', jsonb_build_object('authUid', v_uid::text)
    )
  );

  return jsonb_build_object(
    'ok', true,
    'userId', v_uid,
    'avatarUrl', v_avatar
  );
end;
$$;

revoke all on function public.admin_remove_alumni_account(uuid) from public, anon;
grant execute on function public.admin_remove_alumni_account(uuid) to authenticated, service_role;

commit;
