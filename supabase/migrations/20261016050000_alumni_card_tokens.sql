-- Digital alumni card verification tokens (Phase 2).
--
-- Short-lived codes (60s) for the QR on the back of the digital card.
-- issue_alumni_card_token(): signed-in, active, roster-matched alumni only.
-- verify_alumni_card(code): callable without login; returns limited identity
-- fields when the code is still valid.
--
-- Clients cannot read or write alumni_card_tokens directly (RLS on, no
-- permissive policies). Only the SECURITY DEFINER functions below touch it.

-- ---------------------------------------------------------------------------
-- 1. Table
-- ---------------------------------------------------------------------------

create table if not exists public.alumni_card_tokens (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references public.alumni_members(id) on delete cascade,
  token text not null,
  short_code text not null,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  constraint alumni_card_tokens_token_len check (char_length(token) between 24 and 128),
  constraint alumni_card_tokens_short_len check (char_length(short_code) = 6),
  constraint alumni_card_tokens_expires_after_created check (expires_at > created_at)
);

create unique index if not exists idx_alumni_card_tokens_token
  on public.alumni_card_tokens (token);

create unique index if not exists idx_alumni_card_tokens_short_code
  on public.alumni_card_tokens (short_code);

create index if not exists idx_alumni_card_tokens_member_expires
  on public.alumni_card_tokens (member_id, expires_at desc);

create index if not exists idx_alumni_card_tokens_expires
  on public.alumni_card_tokens (expires_at);

comment on table public.alumni_card_tokens is
  'Short-lived digital alumni card verification codes (QR token + 6-char backup).';

alter table public.alumni_card_tokens enable row level security;

drop policy if exists active_caller_only on public.alumni_card_tokens;
create policy active_caller_only
  on public.alumni_card_tokens as restrictive for all to authenticated
  using ((select public.caller_is_active()))
  with check ((select public.caller_is_active()));

revoke all on public.alumni_card_tokens from anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2. Helpers
-- ---------------------------------------------------------------------------

-- Delete expired rows (and optionally all rows for one member before re-issue).
create or replace function public.alumni_card_tokens_cleanup(
  p_member_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.alumni_card_tokens
  where expires_at <= now()
     or (p_member_id is not null and member_id = p_member_id);
end;
$$;

revoke all on function public.alumni_card_tokens_cleanup(uuid) from public;
grant execute on function public.alumni_card_tokens_cleanup(uuid) to service_role;

-- Six uppercase hex characters for the staff backup code (shown as XXX-XXX).
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

-- ---------------------------------------------------------------------------
-- 3. Issue (authenticated alumnus)
-- ---------------------------------------------------------------------------

-- Returns {ok, token, shortCode, expiresAt} or {ok:false, error, message}.
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

-- ---------------------------------------------------------------------------
-- 4. Verify (anon + authenticated; no login required)
-- ---------------------------------------------------------------------------

-- p_code may be the long QR token or the 6-char backup (with or without dash).
-- Returns {ok:true, status:'verified', fullName, program, batchYear, profileImageUrl}
-- or {ok:false, status:'not_valid'}.
create or replace function public.verify_alumni_card(p_code text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  raw text := btrim(coalesce(p_code, ''));
  v_token text;
  v_short text;
  row_tok public.alumni_card_tokens%rowtype;
  member public.alumni_members%rowtype;
  photo text;
  batch text;
begin
  -- Drop expired rows opportunistically.
  delete from public.alumni_card_tokens where expires_at <= now();

  if raw = '' then
    return jsonb_build_object('ok', false, 'status', 'not_valid');
  end if;

  -- Long QR tokens are lowercase hex; backup codes are 6 hex chars (optional dash).
  v_token := lower(raw);
  v_short := replace(upper(raw), '-', '');

  select * into row_tok
  from public.alumni_card_tokens t
  where t.token = v_token
     or (char_length(v_short) = 6 and t.short_code = v_short)
  limit 1;

  if not found then
    return jsonb_build_object('ok', false, 'status', 'not_valid');
  end if;

  if row_tok.expires_at <= now() then
    delete from public.alumni_card_tokens where id = row_tok.id;
    return jsonb_build_object('ok', false, 'status', 'not_valid');
  end if;

  select * into member
  from public.alumni_members m
  where m.id = row_tok.member_id;

  if not found or member.is_deactivated then
    return jsonb_build_object('ok', false, 'status', 'not_valid');
  end if;

  -- Prefer the user profile photo when the account is linked.
  photo := nullif(btrim(coalesce(member.profile_image_url, '')), '');
  if member.auth_uid is not null then
    select nullif(btrim(coalesce(u.profile_image_base64, '')), '')
      into photo
    from public.users u
    where u.id = member.auth_uid
      and u.anonymized_at is null;
    if photo is null then
      photo := nullif(btrim(coalesce(member.profile_image_url, '')), '');
    end if;
  end if;

  -- year_graduated is the batch/graduation year column (no batch_year).
  batch := nullif(btrim(coalesce(member.year_graduated, '')), '');

  return jsonb_build_object(
    'ok', true,
    'status', 'verified',
    'fullName', coalesce(nullif(btrim(member.full_name), ''), 'Alumni'),
    'program', coalesce(btrim(member.course), ''),
    'batchYear', coalesce(batch, ''),
    'profileImageUrl', photo
  );
end;
$$;

revoke all on function public.verify_alumni_card(text) from public;
grant execute on function public.verify_alumni_card(text)
  to anon, authenticated, service_role;
