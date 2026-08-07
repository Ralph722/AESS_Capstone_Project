-- Phase 4: allow service_role backfill/upserts to pass message update guardrails.

begin;

create or replace function public.enforce_message_update()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  jwt_role text := coalesce(auth.role(), '');
begin
  -- Migration / service-role scripts bypass participant checks.
  if jwt_role in ('service_role', 'postgres') then
    return new;
  end if;

  if public.is_admin() then
    return new;
  end if;

  if uid is null then
    raise exception 'not authenticated';
  end if;

  if old.sender_id = uid then
    return new;
  end if;

  if old.recipient_id = uid then
    if new.body is distinct from old.body
       or new.image_base64 is distinct from old.image_base64
       or new.sender_id is distinct from old.sender_id
       or new.recipient_id is distinct from old.recipient_id
       or new.created_at is distinct from old.created_at then
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

create or replace function public.enforce_assignment_owner_update()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if coalesce(auth.role(), '') in ('service_role', 'postgres') then
    return new;
  end if;

  if public.is_admin() then
    return new;
  end if;

  if old.user_id <> auth.uid() then
    raise exception 'not owner';
  end if;

  if new.survey_id is distinct from old.survey_id
     or new.user_id is distinct from old.user_id
     or new.survey_title is distinct from old.survey_title
     or new.assigned_at is distinct from old.assigned_at
     or new.last_reminder_at is distinct from old.last_reminder_at
     or new.reminder_count is distinct from old.reminder_count
     or new.created_at is distinct from old.created_at then
    raise exception 'owner may only update status';
  end if;

  return new;
end;
$$;

commit;
