-- Fix verify_alumni_card: alumni_members has year_graduated, not batch_year.
-- Valid codes were throwing 42703 and the Flutter client mapped that to
-- "Expired / Not valid".

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
  delete from public.alumni_card_tokens where expires_at <= now();

  if raw = '' then
    return jsonb_build_object('ok', false, 'status', 'not_valid');
  end if;

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

  -- alumni_members stores graduation year as year_graduated (no batch_year column).
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
