-- Fix issue_alumni_card_token: gen_random_bytes lives in the extensions schema
-- on Supabase. Functions used search_path = public only, so the call failed
-- with "function gen_random_bytes(integer) does not exist".

create extension if not exists pgcrypto with schema extensions;

create or replace function public.alumni_card_new_short_code()
returns text
language plpgsql
volatile
set search_path = public, extensions
as $$
declare
  v text;
  i int;
begin
  for i in 1..12 loop
    v := upper(substr(encode(extensions.gen_random_bytes(4), 'hex'), 1, 6));
    if not exists (
      select 1 from public.alumni_card_tokens t where t.short_code = v
    ) then
      return v;
    end if;
  end loop;
  raise exception 'Could not allocate a unique short code';
end;
$$;

revoke all on function public.alumni_card_new_short_code() from public;

create or replace function public.issue_alumni_card_token()
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  uid uuid := auth.uid();
  member public.alumni_members%rowtype;
  v_token text;
  v_short text;
  v_expires timestamptz;
begin
  if uid is null then
    return jsonb_build_object(
      'ok', false,
      'error', 'unauthenticated',
      'message', 'You must be signed in to show your alumni card.'
    );
  end if;

  if not public.caller_is_active() then
    return jsonb_build_object(
      'ok', false,
      'error', 'inactive',
      'message', 'This account cannot issue a card code right now.'
    );
  end if;

  select * into member
  from public.alumni_members m
  where m.auth_uid = uid
  limit 1;

  if not found then
    return jsonb_build_object(
      'ok', false,
      'error', 'unmatched',
      'message', 'Your card will be available once the Alumni Office confirms your record.'
    );
  end if;

  if member.is_deactivated then
    return jsonb_build_object(
      'ok', false,
      'error', 'deactivated',
      'message', 'This alumni account is deactivated.'
    );
  end if;

  perform public.alumni_card_tokens_cleanup(member.id);

  v_token := encode(extensions.gen_random_bytes(24), 'hex');
  v_short := public.alumni_card_new_short_code();
  v_expires := now() + interval '60 seconds';

  insert into public.alumni_card_tokens (member_id, token, short_code, expires_at)
  values (member.id, v_token, v_short, v_expires);

  return jsonb_build_object(
    'ok', true,
    'token', v_token,
    'shortCode', v_short,
    'expiresAt', v_expires
  );
end;
$$;

revoke all on function public.issue_alumni_card_token() from public;
grant execute on function public.issue_alumni_card_token()
  to authenticated, service_role;
