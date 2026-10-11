-- DSS Phase 6: accountability (docs/dss-capability-audit.md Part 10.4).
--   1. dss_flags: owner office, responsible person, start / due / review
--      dates (assigned_to stays the responsible admin account)
--   2. dss_flag_evidence: offline evidence (meeting, event, document, ...);
--      no file uploads; entries are soft-removed, never deleted
--   3. Note event type 'evidence'; adding or removing evidence is logged
--      on the flag automatically
--   4. Playbook steps may carry a cause; three rules get cause-specific
--      steps (data quality, not currently employed, looking for work)
-- Additive: no row is deleted. The note event-type check is replaced with a
-- wider version of itself.

-- ---------------------------------------------------------------------------
-- 1. Owner and dates
-- ---------------------------------------------------------------------------
alter table public.dss_flags
  add column if not exists owner_office text,
  add column if not exists responsible_name text,
  add column if not exists start_date date,
  add column if not exists due_date date,
  add column if not exists review_date date;

comment on column public.dss_flags.owner_office is
  'Office responsible for acting on the finding (free text).';
comment on column public.dss_flags.responsible_name is
  'Person responsible, who may not have an admin account.';
comment on column public.dss_flags.review_date is
  'Next progress check while the work is under way (verify_due_at is the '
  'check after resolving).';

alter table public.dss_flags
  drop constraint if exists dss_flags_owner_office_check;
alter table public.dss_flags
  add constraint dss_flags_owner_office_check
  check (owner_office is null
         or (btrim(owner_office) <> '' and char_length(owner_office) <= 120));

alter table public.dss_flags
  drop constraint if exists dss_flags_responsible_name_check;
alter table public.dss_flags
  add constraint dss_flags_responsible_name_check
  check (responsible_name is null
         or (btrim(responsible_name) <> '' and char_length(responsible_name) <= 120));

alter table public.dss_flags
  drop constraint if exists dss_flags_plan_dates_check;
alter table public.dss_flags
  add constraint dss_flags_plan_dates_check
  check ((start_date is null or due_date is null or due_date >= start_date)
         and (start_date is null or review_date is null or review_date >= start_date));

create index if not exists idx_dss_flags_due_date
  on public.dss_flags (due_date)
  where due_date is not null and status in ('open', 'in_progress');

-- Blank names are stored as null; a superseded flag keeps its owner and
-- dates as they were.
create or replace function public.dss_flags_guard_accountability()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.owner_office := nullif(btrim(new.owner_office), '');
  new.responsible_name := nullif(btrim(new.responsible_name), '');
  if tg_op = 'UPDATE' and old.status = 'superseded'
     and (new.owner_office, new.responsible_name, new.start_date,
          new.due_date, new.review_date, new.assigned_to)
         is distinct from
         (old.owner_office, old.responsible_name, old.start_date,
          old.due_date, old.review_date, old.assigned_to) then
    raise exception 'A superseded flag is final.' using errcode = '23514';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_dss_flags_guard_accountability on public.dss_flags;
create trigger trg_dss_flags_guard_accountability
  before insert or update of owner_office, responsible_name, start_date,
    due_date, review_date, assigned_to
  on public.dss_flags
  for each row execute function public.dss_flags_guard_accountability();

-- ---------------------------------------------------------------------------
-- 2. Evidence
-- ---------------------------------------------------------------------------
create table if not exists public.dss_flag_evidence (
  id uuid primary key default gen_random_uuid(),
  flag_id uuid not null references public.dss_flags (id) on delete cascade,
  evidence_type text not null
    check (evidence_type in (
      'meeting', 'event', 'communication', 'document', 'report', 'other'
    )),
  title text not null
    check (btrim(title) <> '' and char_length(title) <= 200),
  evidence_date date not null,
  description text not null default ''
    check (char_length(description) <= 2000),
  link text
    check (link is null or (link ~* '^https?://\S+$' and char_length(link) <= 2000)),
  created_by uuid references auth.users (id) on delete set null,
  created_by_name text not null default '',
  created_at timestamptz not null default now(),
  removed_at timestamptz,
  removed_by uuid references auth.users (id) on delete set null,
  constraint dss_flag_evidence_removed_check
    check (removed_by is null or removed_at is not null)
);

comment on table public.dss_flag_evidence is
  'Offline evidence for a DSS flag. Removing an entry hides it '
  '(removed_at); rows are never deleted.';

create index if not exists idx_dss_flag_evidence_flag
  on public.dss_flag_evidence (flag_id, evidence_date desc);
create index if not exists idx_dss_flag_evidence_created_by
  on public.dss_flag_evidence (created_by);
create index if not exists idx_dss_flag_evidence_removed_by
  on public.dss_flag_evidence (removed_by);

-- The author and remover are always the caller; only removal can change.
create or replace function public.dss_flag_evidence_stamp()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_status text;
begin
  if tg_op = 'INSERT' then
    select status into v_status from public.dss_flags where id = new.flag_id;
    if v_status = 'superseded' then
      raise exception 'A superseded flag is final. Add evidence to the newer flag.'
        using errcode = '23514';
    end if;
    if new.evidence_date > (now() at time zone 'Asia/Manila')::date then
      raise exception 'The evidence date cannot be in the future.'
        using errcode = '23514';
    end if;
    new.title := btrim(new.title);
    new.description := btrim(coalesce(new.description, ''));
    new.link := nullif(btrim(new.link), '');
    new.created_at := now();
    new.removed_at := null;
    new.removed_by := null;
    if v_uid is not null then
      new.created_by := v_uid;
      select coalesce(nullif(btrim(u.display_name), ''), nullif(btrim(u.email), ''), 'Admin')
      into new.created_by_name
      from public.users u
      where u.id = v_uid;
      new.created_by_name := coalesce(new.created_by_name, 'Admin');
    end if;
    return new;
  end if;

  if old.removed_at is not null then
    raise exception 'This evidence entry was already removed.' using errcode = '23514';
  end if;
  if new.removed_at is null then
    return old;
  end if;
  new := old;
  new.removed_at := now();
  new.removed_by := v_uid;
  return new;
end;
$$;

drop trigger if exists trg_dss_flag_evidence_stamp on public.dss_flag_evidence;
create trigger trg_dss_flag_evidence_stamp
  before insert or update on public.dss_flag_evidence
  for each row execute function public.dss_flag_evidence_stamp();

alter table public.dss_flag_evidence enable row level security;

drop policy if exists dss_flag_evidence_admin_select on public.dss_flag_evidence;
create policy dss_flag_evidence_admin_select
  on public.dss_flag_evidence
  for select to authenticated
  using ((select public.is_admin()));

drop policy if exists dss_flag_evidence_admin_insert on public.dss_flag_evidence;
create policy dss_flag_evidence_admin_insert
  on public.dss_flag_evidence
  for insert to authenticated
  with check ((select public.is_admin()));

drop policy if exists dss_flag_evidence_admin_update on public.dss_flag_evidence;
create policy dss_flag_evidence_admin_update
  on public.dss_flag_evidence
  for update to authenticated
  using ((select public.is_admin()))
  with check ((select public.is_admin()));

drop policy if exists active_caller_only on public.dss_flag_evidence;
create policy active_caller_only
  on public.dss_flag_evidence as restrictive
  for all to authenticated
  using ((select public.caller_is_active()))
  with check ((select public.caller_is_active()));

revoke all on public.dss_flag_evidence from public, anon, authenticated;
grant select, insert on public.dss_flag_evidence to authenticated;
grant update (removed_at) on public.dss_flag_evidence to authenticated;
grant all on public.dss_flag_evidence to service_role;

-- ---------------------------------------------------------------------------
-- 3. Evidence in the action log
-- ---------------------------------------------------------------------------
alter table public.dss_flag_notes
  drop constraint if exists dss_flag_notes_event_type_check;
alter table public.dss_flag_notes
  add constraint dss_flag_notes_event_type_check
  check (
    event_type in (
      'note',
      'status',
      'assign',
      'impact',
      'announcement',
      'reopen',
      'action',
      'evidence'
    )
  );

create or replace function public.dss_flag_evidence_log()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_removed boolean := tg_op = 'UPDATE';
  v_type text := case new.evidence_type
    when 'meeting' then 'Meeting / consultation'
    when 'event' then 'Event / activity'
    when 'communication' then 'Communication sent'
    when 'document' then 'Document / memo'
    when 'report' then 'Report / data'
    else 'Other'
  end;
begin
  if v_removed and (old.removed_at is not null or new.removed_at is null) then
    return null;
  end if;
  insert into public.dss_flag_notes (flag_id, note, event_type, metadata)
  values (
    new.flag_id,
    case when v_removed then 'Evidence removed: ' else 'Evidence added: ' end
      || v_type || ', "' || new.title || '" ('
      || to_char(new.evidence_date, 'YYYY-MM-DD') || ')',
    'evidence',
    jsonb_strip_nulls(jsonb_build_object(
      'action', case when v_removed then 'removed' else 'added' end,
      'evidence_id', new.id,
      'evidence_type', new.evidence_type,
      'title', new.title,
      'evidence_date', new.evidence_date,
      'link', new.link
    ))
  );
  return null;
end;
$$;

drop trigger if exists trg_dss_flag_evidence_log on public.dss_flag_evidence;
create trigger trg_dss_flag_evidence_log
  after insert or update of removed_at on public.dss_flag_evidence
  for each row execute function public.dss_flag_evidence_log();

revoke all on function public.dss_flag_evidence_stamp() from public, anon, authenticated;
revoke all on function public.dss_flag_evidence_log() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 4. Cause-specific playbooks
-- ---------------------------------------------------------------------------
-- A step without "cause" always shows. A step with a cause shows only when
-- the app detects that cause from the flag's stored facts; "default" steps
-- show when no cause was detected.
update public.dss_rules
set playbook = '[
    {"cause": "sparse", "step": "Check how many alumni in this course/batch are on the roster and assigned to the survey."},
    {"cause": "sparse", "step": "Invite more alumni to complete the tracer (announcement or message)."},
    {"cause": "sparse", "step": "Wait until more responses arrive, then click Refresh insights."},
    {"cause": "low_rate", "step": "Open Surveys and see who has not completed this tracer wave."},
    {"cause": "low_rate", "step": "Send a reminder announcement or message to non-respondents."},
    {"cause": "low_rate", "step": "After more alumni submit, refresh Program Insights before reviewing employment flags."},
    {"cause": "both", "step": "Open Surveys and check that everyone in this group is on the roster and assigned to the wave."},
    {"cause": "both", "step": "Send a reminder announcement or message to non-respondents."},
    {"cause": "both", "step": "After more alumni submit, refresh Program Insights before reviewing employment flags."},
    {"cause": "default", "step": "Check how many alumni in this course/batch still need to submit."},
    {"cause": "default", "step": "Send reminders (announcement or message) to non-respondents."},
    {"cause": "default", "step": "Refresh DSS insights after more responses arrive."}
  ]'::jsonb,
  updated_at = now()
where rule_id = 'DATA_QUALITY_LOW';

update public.dss_rules
set playbook = '[
    {"step": "Read the Q17 reasons on this flag to see why alumni are not employed."},
    {"cause": "seeking", "step": "Most are looking for work: publish matching job postings and send them with the Job matches action."},
    {"cause": "seeking", "step": "Coordinate with the Career Center on a job fair, coaching or employer referrals for this group."},
    {"cause": "not_seeking", "step": "Most are not looking for work (further study, family, health or did not look). A job fair is unlikely to help."},
    {"cause": "not_seeking", "step": "Offer career counseling to those who want it, for example alumni finishing further study."},
    {"cause": "not_seeking", "step": "Check the Looking for work rule for this group before planning job-supply actions."},
    {"cause": "default", "step": "Review unemployed respondents in Reports (filtered by course/batch/wave)."},
    {"cause": "default", "step": "Coordinate with Career Center on a job fair or coaching session."},
    {"cause": "default", "step": "Publish relevant job postings and announce them to the cohort."},
    {"step": "Record actions and evidence on this flag, then resolve and recheck after the next wave."}
  ]'::jsonb,
  updated_at = now()
where rule_id = 'UNEMPLOYMENT_HIGH';

update public.dss_rules
set playbook = '[
    {"step": "Check the Q17 reasons on this flag."},
    {"cause": "no_opportunity", "step": "Most cite no job opportunity: publish matching job postings and ask employer partners for openings."},
    {"cause": "no_opportunity", "step": "Coordinate with the Career Center on a job fair for this group."},
    {"cause": "lack_experience", "step": "Most cite lack of work experience: arrange OJT, internships or a work-readiness session with the Career Center."},
    {"cause": "lack_experience", "step": "Pair alumni with mentors or entry-level placements from employer partners."},
    {"cause": "default", "step": "Publish matching job postings and announce them to the group."},
    {"cause": "default", "step": "Coordinate with the Career Center on a job fair, OJT or work-readiness session."},
    {"step": "Record actions and evidence on this flag, then recheck after the next wave."}
  ]'::jsonb,
  updated_at = now()
where rule_id = 'SEEKING_WORK_HIGH';

notify pgrst, 'reload schema';
