-- Email opt-out preference (follows 20261021020000 daily cap).
--
-- notification_preferences gains an `email` channel map next to `in_app`
-- and `push`, keyed by notification type; a missing key means "on".
-- Only account (`system`) mail is locked on — and Supabase Auth codes
-- (registration, password reset) plus contact-verification codes are
-- transactional and never governed by this preference at all.
--
-- Enforcement points:
--   * automated survey email: claim_scheduled_survey_emails only claims
--     alumni whose survey email preference is on;
--   * manual admin email: the send-email Edge Function checks the same
--     preference server-side and logs a 'skipped' delivery instead.
-- In-app and push delivery are unchanged.

begin;

alter table public.notification_preferences
  add column if not exists email jsonb not null default '{}'::jsonb;

-- Channel switch now understands 'email'. Account notices and urgent
-- notices still always arrive; survey assignments still always appear
-- in-app (but their *email* copies can be switched off).
create or replace function public.notification_channel_allowed(
  p_user uuid,
  p_type text,
  p_channel text,
  p_priority text default 'normal'
)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  prefs public.notification_preferences%rowtype;
  raw text;
begin
  if p_type = 'system' or p_priority = 'urgent' then
    return true;
  end if;
  if p_channel = 'in_app' and p_type = 'survey' then
    return true;
  end if;

  select * into prefs from public.notification_preferences where user_id = p_user;
  if not found then
    return true;
  end if;

  raw := case p_channel
    when 'push' then prefs.push->>p_type
    when 'email' then prefs.email->>p_type
    else prefs.in_app->>p_type
  end;
  return coalesce(lower(raw), 'true') <> 'false';
end;
$$;

-- Automated claim: same daily cap as 20261021020000, plus the opt-out gate.
create or replace function public.claim_scheduled_survey_emails(
  p_limit integer default 40
)
returns table (
  delivery_id uuid,
  assignment_id uuid,
  user_id uuid,
  email text,
  display_name text,
  survey_id uuid,
  survey_title text,
  is_ched boolean,
  close_at timestamptz,
  kind text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  today date := public.notification_manila_today();
  v_daily_cap integer := 200;
  v_used integer;
  v_limit integer;
begin
  select count(*) into v_used
  from public.notification_deliveries d
  where d.channel = 'email'
    and coalesce(d.data->>'automated', '') = 'true'
    and d.status in ('sent', 'sending')
    and (d.created_at at time zone 'Asia/Manila')::date = today;

  v_limit := least(
    greatest(1, least(coalesce(p_limit, 40), 100)),
    v_daily_cap - coalesce(v_used, 0)
  );
  if v_limit <= 0 then
    return;
  end if;

  return query
  with candidates as (
    select
      a.id as assignment_id,
      a.user_id as uid,
      s.id as sid,
      c.kind as ckind,
      c.urgency as urgency
    from public.survey_assignments a
    join public.surveys s on s.id = a.survey_id
    cross join lateral (
      select
        case
          when s.close_at is not null
               and (s.close_at at time zone 'Asia/Manila')::date - today = 1
            then 'closing_1d'
          when s.close_at is not null
               and (s.close_at at time zone 'Asia/Manila')::date - today = 3
            then 'closing_3d'
          when not exists (
            select 1 from public.notification_deliveries d
            where d.channel = 'email'
              and d.user_id = a.user_id
              and d.data->>'survey_id' = s.id::text
              and d.data->>'kind' = 'assigned'
              and (d.status = 'sent'
                   or (d.status = 'sending'
                       and d.created_at > now() - interval '15 minutes'))
          ) then 'assigned'
          when coalesce(a.auto_email_count, 0) < 3
               and a.last_auto_email_at is not null
               and a.last_auto_email_at <= now() - interval '7 days'
            then 'weekly'
        end as kind,
        case
          when s.close_at is not null
               and (s.close_at at time zone 'Asia/Manila')::date - today in (1, 3)
            then 0
          when a.last_auto_email_at is null then 1
          else 2
        end as urgency
    ) c
    where c.kind is not null
      and a.status <> 'completed'
      and public.notification_survey_accepting(s)
      and public.notification_is_active_alumni(a.user_id)
      and public.notification_channel_allowed(a.user_id, 'survey', 'email', 'normal')
      and (
        c.kind = 'weekly'
        or not exists (
          select 1 from public.notification_deliveries d
          where d.channel = 'email'
            and d.user_id = a.user_id
            and d.data->>'survey_id' = s.id::text
            and d.data->>'kind' = c.kind
            and (d.status = 'sent'
                 or (d.status = 'sending'
                     and d.created_at > now() - interval '15 minutes'))
        )
      )
    order by c.urgency, a.assigned_at
    limit v_limit
  ),
  claimed as (
    insert into public.notification_deliveries (
      channel, user_id, recipient, status, attempts, scheduled_at, data
    )
    select
      'email',
      c.uid,
      lower(trim(u.email)),
      'sending',
      1,
      now(),
      jsonb_build_object(
        'kind', c.ckind,
        'survey_id', c.sid::text,
        'assignment_id', c.assignment_id::text,
        'automated', true
      )
    from candidates c
    join public.users u on u.id = c.uid
    where u.email is not null and trim(u.email) like '%@%'
    returning id, user_id, recipient, data
  )
  select
    cl.id,
    a.id,
    cl.user_id,
    cl.recipient,
    coalesce(nullif(trim(u.display_name), ''), 'Alumni'),
    s.id,
    coalesce(s.title, ''),
    coalesce(s.data->>'kind', '') = 'ched_gts_builtin'
      or coalesce(s.data->>'template_key', '') = 'ched_gts_builtin',
    s.close_at,
    cl.data->>'kind'
  from claimed cl
  join public.survey_assignments a
    on a.id = (cl.data->>'assignment_id')::uuid
  join public.surveys s on s.id = a.survey_id
  join public.users u on u.id = cl.user_id;
end;
$$;

revoke all on function public.claim_scheduled_survey_emails(integer) from public, anon, authenticated;
grant execute on function public.claim_scheduled_survey_emails(integer) to service_role;

commit;
