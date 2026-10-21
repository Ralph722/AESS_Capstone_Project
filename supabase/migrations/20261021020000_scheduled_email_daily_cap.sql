-- Daily budget for automated survey emails (follows
-- 20261021010000_scheduled_survey_emails.sql).
--
-- All AESS email shares one Gmail account: registration/password codes
-- (Supabase Auth), manual admin reminders and contact-verification codes
-- (Edge Functions), and these automated survey emails. A free Gmail
-- account allows roughly 500 recipients per rolling 24 hours before
-- Google starts rejecting mail (Workspace accounts: ~2,000).
--
-- Automated mail therefore gets a fixed budget of 200 recipients per
-- Asia/Manila day, leaving the rest of the quota for codes and manual
-- reminders, which are never capped here. Anything not sent today stays
-- eligible and is simply picked up tomorrow — claiming is what reserves
-- a recipient, so an exhausted budget delays mail, it never drops it.
-- Urgency ordering (closing warnings first) still applies, so deadline
-- mail is the last thing a backlog would ever delay.
--
-- To raise the budget later (e.g. after moving to a Workspace account or
-- a domain sender such as Resend/SES), change v_daily_cap below.

begin;

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
