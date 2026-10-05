-- Phase 3: architecture fixes from the database audit.
--   * programs table; the roster owns course, ID number and graduation year
--   * batch_year is kept equal to year_graduated (one graduation year)
--   * survey assignment/response counters maintained by the database
--   * jobs.views column; job columns are authoritative over the data JSON
--   * get_public_profiles() for peer names and avatars
--   * gts_question_catalog seeded from the built-in CHED GTS schema
-- employment_records is retired in Phase 5 together with the GTS metric layer.

-- ---------------------------------------------------------------------------
-- Leftover from Phase 2: surveys.created_by uses ON DELETE SET NULL
-- ---------------------------------------------------------------------------
alter table public.surveys alter column created_by drop not null;

-- ---------------------------------------------------------------------------
-- Programs
-- ---------------------------------------------------------------------------
create table if not exists public.programs (
  code text primary key,
  name text not null,
  active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

insert into public.programs (code, name, sort_order) values
  ('BSIT', 'Bachelor of Science in Information Technology', 1),
  ('BFPT', 'Bachelor in Food Processing Technology', 2),
  ('BTLED-IA', 'Bachelor of Technology and Livelihood Education major in Industrial Arts', 3),
  ('BTLED-ICT', 'Bachelor of Technology and Livelihood Education major in Information and Communication Technology', 4),
  ('BTLED-HE', 'Bachelor of Technology and Livelihood Education major in Home Economics', 5)
on conflict (code) do nothing;

alter table public.programs enable row level security;

drop policy if exists programs_select_all on public.programs;
create policy programs_select_all
  on public.programs for select to anon, authenticated
  using (true);

drop policy if exists programs_admin_write on public.programs;
create policy programs_admin_write
  on public.programs for all to authenticated
  using ((select public.is_admin()))
  with check ((select public.is_admin()));

revoke all on public.programs from anon, authenticated;
grant select on public.programs to anon, authenticated;
grant insert, update, delete on public.programs to authenticated;

alter table public.alumni_members
  drop constraint if exists alumni_members_course_fkey,
  add constraint alumni_members_course_fkey
    foreign key (course) references public.programs (code) on update cascade;

-- ---------------------------------------------------------------------------
-- One graduation year
-- ---------------------------------------------------------------------------
create or replace function public.normalize_grad_year(raw text)
returns text
language sql
immutable
set search_path = public
as $$
  select coalesce(substring(coalesce(raw, '') from '(?:19|20)[0-9]{2}'), '');
$$;

revoke all on function public.normalize_grad_year(text) from public, anon;
grant execute on function public.normalize_grad_year(text) to authenticated, service_role;

update public.users
set year_graduated = public.normalize_grad_year(coalesce(nullif(year_graduated, ''), batch_year)),
    batch_year = public.normalize_grad_year(coalesce(nullif(year_graduated, ''), batch_year))
where year_graduated is distinct from public.normalize_grad_year(coalesce(nullif(year_graduated, ''), batch_year))
   or batch_year is distinct from public.normalize_grad_year(coalesce(nullif(year_graduated, ''), batch_year));

update public.alumni_members
set year_graduated = nullif(public.normalize_grad_year(coalesce(nullif(year_graduated, ''), batch_year)), ''),
    batch_year = public.normalize_grad_year(coalesce(nullif(year_graduated, ''), batch_year))
where year_graduated is distinct from nullif(public.normalize_grad_year(coalesce(nullif(year_graduated, ''), batch_year)), '')
   or batch_year is distinct from public.normalize_grad_year(coalesce(nullif(year_graduated, ''), batch_year));

-- Roster rows without a year take the year the linked alumnus already gave.
update public.alumni_members m
set year_graduated = u.year_graduated,
    batch_year = u.year_graduated
from public.users u
where u.id = m.auth_uid
  and m.year_graduated is null
  and u.year_graduated <> '';

alter table public.users
  drop constraint if exists users_year_graduated_format,
  add constraint users_year_graduated_format
    check (year_graduated = '' or year_graduated ~ '^(19|20)[0-9]{2}$'),
  drop constraint if exists users_batch_year_matches,
  add constraint users_batch_year_matches
    check (batch_year = year_graduated);

alter table public.alumni_members
  drop constraint if exists alumni_members_year_graduated_format,
  add constraint alumni_members_year_graduated_format
    check (year_graduated is null or year_graduated ~ '^(19|20)[0-9]{2}$'),
  drop constraint if exists alumni_members_batch_year_matches,
  add constraint alumni_members_batch_year_matches
    check (batch_year = coalesce(year_graduated, ''));

create or replace function public.alumni_members_normalize_year()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_year text;
begin
  if tg_op = 'INSERT' then
    v_year := public.normalize_grad_year(coalesce(nullif(new.year_graduated, ''), new.batch_year));
  elsif new.year_graduated is distinct from old.year_graduated then
    v_year := public.normalize_grad_year(new.year_graduated);
  elsif new.batch_year is distinct from old.batch_year then
    v_year := public.normalize_grad_year(new.batch_year);
  else
    v_year := coalesce(old.year_graduated, '');
  end if;

  new.year_graduated := nullif(v_year, '');
  new.batch_year := v_year;
  return new;
end;
$$;

drop trigger if exists trg_alumni_members_normalize_year on public.alumni_members;
create trigger trg_alumni_members_normalize_year
  before insert or update on public.alumni_members
  for each row execute function public.alumni_members_normalize_year();

-- Alumni clients send whole profile rows; server-owned columns are kept as-is
-- instead of failing the save. Program, ID number and (once on the roster)
-- graduation year come from the roster.
create or replace function public.users_guard_protected_columns()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_privileged boolean := current_user not in ('authenticated', 'anon') or public.is_admin();
  v_sid text;
  v_course text;
  v_roster_year text;
  v_year text;
begin
  if tg_op = 'INSERT' then
    v_year := public.normalize_grad_year(coalesce(nullif(new.year_graduated, ''), new.batch_year));
  elsif new.year_graduated is distinct from old.year_graduated then
    v_year := public.normalize_grad_year(new.year_graduated);
    if v_year = '' and not v_privileged then
      v_year := old.year_graduated;
    end if;
  elsif new.batch_year is distinct from old.batch_year then
    v_year := public.normalize_grad_year(new.batch_year);
    if v_year = '' and not v_privileged then
      v_year := old.year_graduated;
    end if;
  else
    v_year := old.year_graduated;
  end if;

  if not v_privileged then
    select m.student_id, m.course, m.year_graduated
    into v_sid, v_course, v_roster_year
    from public.alumni_members m
    where m.auth_uid = new.id;
    if v_roster_year is not null then
      v_year := v_roster_year;
    end if;
  end if;

  new.year_graduated := coalesce(v_year, '');
  new.batch_year := new.year_graduated;

  if v_privileged then
    return new;
  end if;

  if tg_op = 'INSERT' then
    new.role := 'user';
    new.email := coalesce(auth.jwt() ->> 'email', '');
    new.student_id := coalesce(v_sid, '');
    new.program := coalesce(v_course, '');
    new.deactivated_at := null;
    new.anonymized_at := null;
    return new;
  end if;

  new.id := old.id;
  new.role := old.role;
  new.email := old.email;
  new.student_id := old.student_id;
  new.program := old.program;
  new.created_at := old.created_at;
  new.deactivated_at := old.deactivated_at;
  new.anonymized_at := old.anonymized_at;
  return new;
end;
$$;

-- An alumnus's first year entry fills a blank roster year; after that the
-- roster value wins.
create or replace function public.users_fill_roster_year()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.year_graduated <> ''
     and (tg_op = 'INSERT' or new.year_graduated is distinct from old.year_graduated) then
    update public.alumni_members
    set year_graduated = new.year_graduated
    where auth_uid = new.id
      and year_graduated is null;
  end if;
  return null;
end;
$$;

drop trigger if exists trg_users_fill_roster_year on public.users;
create trigger trg_users_fill_roster_year
  after insert or update of year_graduated on public.users
  for each row execute function public.users_fill_roster_year();

create or replace function public.alumni_members_sync_user_identity()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.auth_uid is null then
    return null;
  end if;

  update public.users u
  set program = new.course,
      student_id = new.student_id,
      year_graduated = coalesce(new.year_graduated, u.year_graduated)
  where u.id = new.auth_uid
    and u.role <> 'admin'
    and u.anonymized_at is null
    and (u.program is distinct from new.course
         or u.student_id is distinct from new.student_id
         or (new.year_graduated is not null and u.year_graduated is distinct from new.year_graduated));
  return null;
end;
$$;

drop trigger if exists trg_alumni_members_sync_user_identity on public.alumni_members;
create trigger trg_alumni_members_sync_user_identity
  after insert or update of course, student_id, year_graduated, auth_uid on public.alumni_members
  for each row execute function public.alumni_members_sync_user_identity();

-- ---------------------------------------------------------------------------
-- Survey counters
-- ---------------------------------------------------------------------------
create or replace function public.surveys_recount(p_survey_ids uuid[])
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_survey_ids is null or cardinality(p_survey_ids) = 0 then
    return;
  end if;

  perform set_config('aess.survey_counter_sync', 'on', true);
  update public.surveys s
  set assignment_count = (
        select count(*) from public.survey_assignments a where a.survey_id = s.id
      ),
      response_count = (
        select count(*) from public.survey_responses r
        where r.survey_id = s.id and r.status = 'submitted'
      )
  where s.id = any (p_survey_ids)
    and (s.assignment_count is distinct from (
          select count(*) from public.survey_assignments a where a.survey_id = s.id)
         or s.response_count is distinct from (
          select count(*) from public.survey_responses r
          where r.survey_id = s.id and r.status = 'submitted'));
  perform set_config('aess.survey_counter_sync', 'off', true);
end;
$$;

revoke all on function public.surveys_recount(uuid[]) from public, anon, authenticated;

create or replace function public.surveys_guard_counters()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if coalesce(current_setting('aess.survey_counter_sync', true), '') = 'on' then
    return new;
  end if;

  if tg_op = 'INSERT' then
    new.assignment_count := 0;
    new.response_count := 0;
  else
    new.assignment_count := old.assignment_count;
    new.response_count := old.response_count;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_surveys_guard_counters on public.surveys;
create trigger trg_surveys_guard_counters
  before insert or update on public.surveys
  for each row execute function public.surveys_guard_counters();

create or replace function public.survey_children_recount()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ids uuid[];
begin
  if tg_op = 'INSERT' then
    select array_agg(distinct survey_id) into v_ids from new_rows;
  elsif tg_op = 'DELETE' then
    select array_agg(distinct survey_id) into v_ids from old_rows;
  else
    select array_agg(distinct x.survey_id) into v_ids
    from (select survey_id from new_rows union select survey_id from old_rows) x;
  end if;

  perform public.surveys_recount(v_ids);
  return null;
end;
$$;

drop trigger if exists trg_survey_assignments_recount_ins on public.survey_assignments;
create trigger trg_survey_assignments_recount_ins
  after insert on public.survey_assignments
  referencing new table as new_rows
  for each statement execute function public.survey_children_recount();

drop trigger if exists trg_survey_assignments_recount_del on public.survey_assignments;
create trigger trg_survey_assignments_recount_del
  after delete on public.survey_assignments
  referencing old table as old_rows
  for each statement execute function public.survey_children_recount();

drop trigger if exists trg_survey_responses_recount_ins on public.survey_responses;
create trigger trg_survey_responses_recount_ins
  after insert on public.survey_responses
  referencing new table as new_rows
  for each statement execute function public.survey_children_recount();

drop trigger if exists trg_survey_responses_recount_upd on public.survey_responses;
create trigger trg_survey_responses_recount_upd
  after update on public.survey_responses
  referencing old table as old_rows new table as new_rows
  for each statement execute function public.survey_children_recount();

drop trigger if exists trg_survey_responses_recount_del on public.survey_responses;
create trigger trg_survey_responses_recount_del
  after delete on public.survey_responses
  referencing old table as old_rows
  for each statement execute function public.survey_children_recount();

select public.surveys_recount(array(select id from public.surveys));

-- ---------------------------------------------------------------------------
-- Jobs: views column; columns win over the data JSON
-- ---------------------------------------------------------------------------
alter table public.jobs
  add column if not exists views integer not null default 0;

alter table public.jobs
  drop constraint if exists jobs_views_nonnegative,
  add constraint jobs_views_nonnegative check (views >= 0);

update public.jobs
set views = (data->>'views')::integer
where data->>'views' ~ '^[0-9]{1,9}$'
  and views is distinct from (data->>'views')::integer;

create or replace function public.jobs_sync_columns()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_data jsonb := coalesce(new.data, '{}'::jsonb);
begin
  new.title := coalesce(nullif(new.title, ''), v_data->>'jobTitle', '');
  new.company := coalesce(nullif(new.company, ''), v_data->>'companyName', '');
  new.location := coalesce(nullif(new.location, ''), v_data->>'location', '');
  new.description := coalesce(nullif(new.description, ''), v_data->>'description', '');
  new.status := lower(coalesce(nullif(new.status, ''), v_data->>'status', 'active'));

  -- Views only move through increment_job_views().
  if tg_op = 'INSERT' then
    new.views := greatest(
      coalesce(new.views, 0),
      case when v_data->>'views' ~ '^[0-9]{1,9}$' then (v_data->>'views')::integer else 0 end
    );
  elsif coalesce(current_setting('aess.job_views_bump', true), '') <> 'on' then
    new.views := old.views;
  end if;

  new.data := v_data || jsonb_build_object(
    'jobTitle', new.title,
    'companyName', new.company,
    'location', new.location,
    'description', new.description,
    'status', new.status,
    'isActive', new.status = 'active',
    'views', new.views
  );
  return new;
end;
$$;

drop trigger if exists trg_jobs_sync_columns on public.jobs;
create trigger trg_jobs_sync_columns
  before insert or update on public.jobs
  for each row execute function public.jobs_sync_columns();

create or replace function public.increment_job_views(p_job_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_signed_in() then
    return;
  end if;

  perform set_config('aess.job_views_bump', 'on', true);
  update public.jobs
  set views = views + 1
  where id = p_job_id;
  perform set_config('aess.job_views_bump', 'off', true);
end;
$$;

revoke all on function public.increment_job_views(uuid) from public, anon;
grant execute on function public.increment_job_views(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Peer profiles: name, avatar, program and year for any signed-in user;
-- email only for admins (or yourself).
-- ---------------------------------------------------------------------------
create or replace function public.get_public_profiles(p_ids uuid[])
returns table (
  id uuid,
  display_name text,
  profile_image_base64 text,
  program text,
  year_graduated text,
  batch_year text,
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
      when u.anonymized_at is not null then 'Deleted alumni'
      when nullif(trim(u.display_name), '') is not null then u.display_name
      when u.role = 'admin' then 'Admin'
      else 'Alumnus'
    end,
    case when u.anonymized_at is null then u.profile_image_base64 end,
    u.program,
    u.year_graduated,
    u.batch_year,
    u.role,
    case when public.is_admin() or u.id = auth.uid() then u.email else '' end
  from public.users u
  where public.is_signed_in()
    and u.id = any (p_ids[1:500]);
$$;

revoke all on function public.get_public_profiles(uuid[]) from public, anon;
grant execute on function public.get_public_profiles(uuid[]) to authenticated;

-- ---------------------------------------------------------------------------
-- CHED GTS question catalog (generated by tool/gen_gts_catalog.dart)
-- ---------------------------------------------------------------------------
create table if not exists public.gts_question_catalog (
  schema_version text not null,
  item_id text not null,
  ched_number text not null,
  section text not null check (section in ('a', 'b', 'c', 'd')),
  field_type text not null
    check (field_type in ('text', 'longText', 'single', 'multi', 'date', 'matrix', 'tableRows')),
  prompt text not null,
  help_text text,
  options jsonb not null default '[]'::jsonb,
  matrix_rows jsonb not null default '[]'::jsonb,
  matrix_columns jsonb not null default '[]'::jsonb,
  table_columns jsonb not null default '[]'::jsonb,
  required boolean not null default false,
  others_specify_id text,
  is_others_specify boolean not null default false,
  sort_order integer not null,
  created_at timestamptz not null default now(),
  primary key (schema_version, item_id)
);

alter table public.gts_question_catalog enable row level security;

drop policy if exists gts_question_catalog_select_signed_in on public.gts_question_catalog;
create policy gts_question_catalog_select_signed_in
  on public.gts_question_catalog for select to authenticated
  using ((select public.is_signed_in()));

revoke all on public.gts_question_catalog from anon, authenticated;
grant select on public.gts_question_catalog to authenticated;

insert into public.gts_question_catalog (
  schema_version, item_id, ched_number, section, field_type, prompt,
  help_text, options, matrix_rows, matrix_columns, table_columns,
  required, others_specify_id, is_others_specify, sort_order
)
values
  ('3.0.0', 'ched_1', '1', 'a', 'text', 'Name', 'Write your full name: Last name, First name, Middle name.', '[]'::jsonb, '[]'::jsonb, '[]'::jsonb, '[]'::jsonb, true, null, false, 1),
  ('3.0.0', 'ched_2', '2', 'a', 'text', 'Permanent Address', 'House no. or street, barangay, city or municipality, and province.', '[]'::jsonb, '[]'::jsonb, '[]'::jsonb, '[]'::jsonb, true, null, false, 2),
  ('3.0.0', 'ched_3', '3', 'a', 'text', 'E-mail Address', 'Use an email address you check regularly.', '[]'::jsonb, '[]'::jsonb, '[]'::jsonb, '[]'::jsonb, true, null, false, 3),
  ('3.0.0', 'ched_4', '4', 'a', 'text', 'Telephone or Contact Number(s)', 'A landline or another number where you can be reached. If you only have a mobile number, you can write it here too.', '[]'::jsonb, '[]'::jsonb, '[]'::jsonb, '[]'::jsonb, true, null, false, 4),
  ('3.0.0', 'ched_5', '5', 'a', 'text', 'Mobile Number', 'Your active mobile number, e.g. 0917 123 4567.', '[]'::jsonb, '[]'::jsonb, '[]'::jsonb, '[]'::jsonb, true, null, false, 5),
  ('3.0.0', 'ched_6', '6', 'a', 'single', 'Civil Status', null, '["Single","Married","Separated","Single Parent","Widow or Widower"]'::jsonb, '[]'::jsonb, '[]'::jsonb, '[]'::jsonb, true, null, false, 6),
  ('3.0.0', 'ched_7', '7', 'a', 'single', 'Sex', null, '["Male","Female"]'::jsonb, '[]'::jsonb, '[]'::jsonb, '[]'::jsonb, true, null, false, 7),
  ('3.0.0', 'ched_8', '8', 'a', 'date', 'Birthday', null, '[]'::jsonb, '[]'::jsonb, '[]'::jsonb, '[]'::jsonb, true, null, false, 8),
  ('3.0.0', 'ched_9', '9', 'a', 'single', 'Region of Origin', 'The region of your home province, e.g. Region 10 for Misamis Oriental or Bukidnon.', '["Region 1","Region 2","Region 3","Region 4","Region 5","Region 6","Region 7","Region 8","Region 9","Region 10","Region 11","Region 12","NCR","CAR","ARMM","CARAGA"]'::jsonb, '[]'::jsonb, '[]'::jsonb, '[]'::jsonb, true, null, false, 9),
  ('3.0.0', 'ched_10', '10', 'a', 'text', 'Province', 'The province of your permanent address, e.g. Misamis Oriental.', '[]'::jsonb, '[]'::jsonb, '[]'::jsonb, '[]'::jsonb, true, null, false, 10),
  ('3.0.0', 'ched_11', '11', 'a', 'single', 'Location of Residence', 'Choose City if you live in a city, or Municipality if you live in a town.', '["City","Municipality"]'::jsonb, '[]'::jsonb, '[]'::jsonb, '[]'::jsonb, true, null, false, 11),
  ('3.0.0', 'ched_12', '12', 'b', 'tableRows', 'Educational Attainment (Baccalaureate Degree only)', 'Your bachelor''s degree (e.g. BS Information Technology), school, year graduated, and honors such as Cum Laude. Add a row for each degree.', '[]'::jsonb, '[]'::jsonb, '[]'::jsonb, '["Degree(s) & Specialization(s)","College or University","Year Graduated","Honor(s) or Award(s) Received"]'::jsonb, true, null, false, 12),
  ('3.0.0', 'ched_13', '13', 'b', 'tableRows', 'Professional Examination(s) Passed', 'Licensure or civil service exams you passed, e.g. LET or Civil Service Professional. Leave blank if none.', '[]'::jsonb, '[]'::jsonb, '[]'::jsonb, '["Name of Examination","Date Taken","Rating"]'::jsonb, false, null, false, 13),
  ('3.0.0', 'ched_14', '14', 'b', 'matrix', 'Reason(s) for taking the course(s) or pursuing degree(s). You may check more than one answer.', 'Tick every reason that applies. Use the Undergraduate column for your bachelor''s degree, and the Graduate column only if you took a master''s or PhD.', '[]'::jsonb, '["High grades in the course or subject area(s) related to the course","Good grades in high school","Influence of parents or relatives","Peer Influence","Inspired by a role model","Strong passion for the profession","Prospect for immediate employment","Status or prestige of the profession","Availability of course offering in chosen institution","Prospect of career advancement","Affordable for the family","Prospect of attractive compensation","Opportunity for employment abroad","No particular choice or no better idea","Others, please specify"]'::jsonb, '["Undergraduate/AB/BS","Graduate/MS/MA/PhD"]'::jsonb, '[]'::jsonb, false, 'ched_14_other', false, 14),
  ('3.0.0', 'ched_14_other', '14', 'b', 'text', 'Others, please specify (reasons for taking the course)', null, '[]'::jsonb, '[]'::jsonb, '[]'::jsonb, '[]'::jsonb, true, null, true, 15),
  ('3.0.0', 'ched_15a', '15a', 'c', 'tableRows', 'Please list down all professional or work-related training program(s) including advance studies you have attended after college.', 'Seminars, certifications, short courses or graduate studies after college, e.g. "CCNA Certification, 40 hours, Cisco Networking Academy". Leave blank if none.', '[]'::jsonb, '[]'::jsonb, '[]'::jsonb, '["Title of Training or Advance Study","Duration and Credits Earned","Name of Training Institution/College/University"]'::jsonb, false, null, false, 16),
  ('3.0.0', 'ched_15b', '15b', 'c', 'single', 'What made you pursue advance studies?', 'Answer only if you took advance studies such as a master''s degree. Otherwise, skip it.', '["For promotion","For professional development","Others, please specify"]'::jsonb, '[]'::jsonb, '[]'::jsonb, '[]'::jsonb, false, 'ched_15b_other', false, 17),
  ('3.0.0', 'ched_15b_other', '15b', 'c', 'text', 'Others, please specify (advance studies)', null, '[]'::jsonb, '[]'::jsonb, '[]'::jsonb, '[]'::jsonb, true, null, true, 18),
  ('3.0.0', 'ched_16', '16', 'd', 'single', 'Are you presently employed?', 'Yes if you have paid work now, including part-time or self-employment. No if you worked before but not now. Never Employed if you have never had a job.', '["Yes","No","Never Employed"]'::jsonb, '[]'::jsonb, '[]'::jsonb, '[]'::jsonb, true, null, false, 19),
  ('3.0.0', 'ched_17', '17', 'd', 'multi', 'Please state reason(s) why you are not yet employed. You may check more than one answer.', 'Tick every reason that explains why you are not working right now.', '["Advance or further study","Family concern and decided not to find a job","Health-related reason(s)","Lack of work experience","No job opportunity","Did not look for a job","Other reason(s), please specify"]'::jsonb, '[]'::jsonb, '[]'::jsonb, '[]'::jsonb, true, 'ched_17_other', false, 20),
  ('3.0.0', 'ched_17_other', '17', 'd', 'text', 'Other reason(s), please specify (not employed)', null, '[]'::jsonb, '[]'::jsonb, '[]'::jsonb, '[]'::jsonb, true, null, true, 21),
  ('3.0.0', 'ched_18', '18', 'd', 'single', 'Present Employment Status', 'Regular or Permanent: a permanent position, usually after probation. Temporary: a short-term post, such as a substitute role. Casual: paid per day or only when needed. Contractual: a fixed-term or project-based contract. Self-employed: you run your own business or freelance.', '["Regular or Permanent","Temporary","Casual","Contractual","Self-employed"]'::jsonb, '[]'::jsonb, '[]'::jsonb, '[]'::jsonb, true, null, false, 22),
  ('3.0.0', 'ched_18_skills', '18', 'd', 'text', 'If self-employed, what skills acquired in college were you able to apply in your work?', 'For example: programming, bookkeeping, customer service or marketing skills you use in your business.', '[]'::jsonb, '[]'::jsonb, '[]'::jsonb, '[]'::jsonb, false, null, false, 23),
  ('3.0.0', 'ched_19', '19', 'd', 'text', 'Present occupation (Ex. Grade School Teacher, Electrical Engineer, Self-employed)', 'Write your job title, e.g. Web Developer, Sales Associate or Delivery Driver. If you run your own business, write Self-employed and what you do.', '[]'::jsonb, '[]'::jsonb, '[]'::jsonb, '[]'::jsonb, true, null, false, 24),
  ('3.0.0', 'ched_20', '20', 'd', 'single', 'Major line of business of the company you are presently employed in. Check one only.', 'Not sure where your company fits? IT, software, BPO and consulting firms fall under Real Estate, Renting and Business Activities; telecommunications falls under Transport Storage and Communication. If none fits, choose Others, please specify.', '["Agriculture, Hunting and Forestry","Fishing","Mining and Quarrying","Manufacturing","Electricity, Gas and Water Supply","Construction","Wholesale and Retail Trade, repair of motor vehicles, motorcycles and personal and household goods","Hotels and Restaurants","Transport Storage and Communication","Financial Intermediation","Real Estate, Renting and Business Activities","Public Administration and Defense; Compulsory Social Security","Education","Health and Social Work","Other Community, Social and Personal Service Activities","Private Households with Employed Persons","Extra-territorial Organizations and Bodies","Others, please specify"]'::jsonb, '[]'::jsonb, '[]'::jsonb, '[]'::jsonb, true, 'ched_20_other', false, 25),
  ('3.0.0', 'ched_20_other', '20', 'd', 'text', 'Others, please specify (line of business)', null, '[]'::jsonb, '[]'::jsonb, '[]'::jsonb, '[]'::jsonb, true, null, true, 26),
  ('3.0.0', 'ched_21', '21', 'd', 'single', 'Place of work', 'Local if your workplace is in the Philippines, Abroad if it is in another country.', '["Local","Abroad"]'::jsonb, '[]'::jsonb, '[]'::jsonb, '[]'::jsonb, true, null, false, 27),
  ('3.0.0', 'ched_22', '22', 'd', 'single', 'Is this your first job after college?', 'Yes if this is the first job you had after graduating. No if you worked somewhere else before this job.', '["Yes","No"]'::jsonb, '[]'::jsonb, '[]'::jsonb, '[]'::jsonb, true, null, false, 28),
  ('3.0.0', 'ched_23', '23', 'd', 'multi', 'What are your reason(s) for staying on the job? You may check more than one answer.', 'Tick every reason that keeps you in your current job.', '["Salaries and benefits","Career challenge","Related to special skill","Related to course or program of study","Proximity to residence","Peer influence","Family influence","Other reason(s), please specify"]'::jsonb, '[]'::jsonb, '[]'::jsonb, '[]'::jsonb, true, 'ched_23_other', false, 29),
  ('3.0.0', 'ched_23_other', '23', 'd', 'text', 'Other reason(s), please specify (staying on the job)', null, '[]'::jsonb, '[]'::jsonb, '[]'::jsonb, '[]'::jsonb, true, null, true, 30),
  ('3.0.0', 'ched_24a', '24', 'd', 'single', 'Is your first job related to the course you took up in college?', 'Yes if your first job after college used the knowledge or skills from your course.', '["Yes","No"]'::jsonb, '[]'::jsonb, '[]'::jsonb, '[]'::jsonb, true, null, false, 31),
  ('3.0.0', 'ched_24b', '25', 'd', 'multi', 'What were your reasons for accepting the job? You may check more than one answer.', 'Think about why you accepted your first job offer. Tick all that apply.', '["Salaries & benefits","Career challenge","Related to special skills","Proximity to residence","Other reason(s), please specify"]'::jsonb, '[]'::jsonb, '[]'::jsonb, '[]'::jsonb, true, 'ched_24b_other', false, 32),
  ('3.0.0', 'ched_24b_other', '25', 'd', 'text', 'Other reason(s), please specify (accepting the job)', null, '[]'::jsonb, '[]'::jsonb, '[]'::jsonb, '[]'::jsonb, true, null, true, 33),
  ('3.0.0', 'ched_25', '26', 'd', 'multi', 'What were your reason(s) for changing job? You may check more than one answer.', 'Answer if you have changed jobs since your first job. Tick every reason you moved.', '["Salaries & benefits","Career challenge","Related to special skills","Proximity to residence","Other reason(s), please specify"]'::jsonb, '[]'::jsonb, '[]'::jsonb, '[]'::jsonb, true, 'ched_25_other', false, 34),
  ('3.0.0', 'ched_25_other', '26', 'd', 'text', 'Other reason(s), please specify (changing job)', null, '[]'::jsonb, '[]'::jsonb, '[]'::jsonb, '[]'::jsonb, true, null, true, 35),
  ('3.0.0', 'ched_27', '27', 'd', 'single', 'How long did you stay in your first job?', 'Count from your first day to your last day in your first job. If you are still there, count up to today.', '["Less than a month","1 to 6 months","7 to 11 months","1 year to less than 2 years","2 years to less than 3 years","3 years to less than 4 years","Others, please specify"]'::jsonb, '[]'::jsonb, '[]'::jsonb, '[]'::jsonb, true, 'ched_27_other', false, 36),
  ('3.0.0', 'ched_27_other', '27', 'd', 'text', 'Others, please specify (length of stay in first job)', null, '[]'::jsonb, '[]'::jsonb, '[]'::jsonb, '[]'::jsonb, true, null, true, 37),
  ('3.0.0', 'ched_28', '28', 'd', 'single', 'How did you find your first job?', 'Advertisement: you applied to a job post (online, print or social media). Walk-in: you applied in person without a posting. Recommended: someone referred or endorsed you. Friends: friends told you about the opening.', '["Response to an advertisement","As walk-in applicant","Recommended by someone","Information from friends","Arranged by school''s job placement officer","Family business","Job Fair or Public Employment Service Office (PESO)","Others, please specify"]'::jsonb, '[]'::jsonb, '[]'::jsonb, '[]'::jsonb, true, 'ched_28_other', false, 38),
  ('3.0.0', 'ched_28_other', '28', 'd', 'text', 'Others, please specify (how you found first job)', null, '[]'::jsonb, '[]'::jsonb, '[]'::jsonb, '[]'::jsonb, true, null, true, 39),
  ('3.0.0', 'ched_29', '29', 'd', 'single', 'How long did it take you to land your first job?', 'Count from your graduation to the day you started your first job.', '["Less than a month","1 to 6 months","7 to 11 months","1 year to less than 2 years","2 years to less than 3 years","3 years to less than 4 years","Others, please specify"]'::jsonb, '[]'::jsonb, '[]'::jsonb, '[]'::jsonb, true, 'ched_29_other', false, 40),
  ('3.0.0', 'ched_29_other', '29', 'd', 'text', 'Others, please specify (time to land first job)', null, '[]'::jsonb, '[]'::jsonb, '[]'::jsonb, '[]'::jsonb, true, null, true, 41),
  ('3.0.0', 'ched_30', '30', 'd', 'matrix', 'Job Level Position', 'Tick one level for your first job and one for your current job. Rank or Clerical: staff or support roles, e.g. clerk, cashier, encoder. Professional, Technical or Supervisory: specialist or team-lead roles, e.g. engineer, teacher, programmer, supervisor. Managerial or Executive: you head a department or company. Self-employed: you run your own business.', '[]'::jsonb, '["Rank or Clerical","Professional, Technical or Supervisory","Managerial or Executive","Self-employed"]'::jsonb, '["30.1. First Job","30.2. Current or Present Job"]'::jsonb, '[]'::jsonb, true, null, false, 42),
  ('3.0.0', 'ched_31', '31', 'd', 'single', 'What is your initial gross monthly earning in your first job after college?', 'Your monthly pay before deductions (tax, SSS, PhilHealth, Pag-IBIG) when you started your first job.', '["Below P5,000.00","P5,000.00 to less than P10,000.00","P10,000.00 to less than P15,000.00","P15,000.00 to less than P20,000.00","P20,000.00 to less than P25,000.00","P25,000.00 and above"]'::jsonb, '[]'::jsonb, '[]'::jsonb, '[]'::jsonb, true, null, false, 43),
  ('3.0.0', 'ched_32', '32', 'd', 'single', 'Was the curriculum you had in college relevant to your first job?', 'Yes if what you studied in college was useful in your first job.', '["Yes","No"]'::jsonb, '[]'::jsonb, '[]'::jsonb, '[]'::jsonb, true, null, false, 44),
  ('3.0.0', 'ched_33', '33', 'd', 'multi', 'If YES, what competencies learned in college did you find very useful in your first job? You may check more than one answer.', 'Answer only if you said Yes to question 32. Tick every skill from college that helped you.', '["Communication skills","Human Relations skills","Entrepreneurial skills","Information Technology skills","Problem-solving skills","Critical Thinking skills","Other skills, please specify"]'::jsonb, '[]'::jsonb, '[]'::jsonb, '[]'::jsonb, true, 'ched_33_other', false, 45),
  ('3.0.0', 'ched_33_other', '33', 'd', 'text', 'Other skills, please specify', null, '[]'::jsonb, '[]'::jsonb, '[]'::jsonb, '[]'::jsonb, true, null, true, 46),
  ('3.0.0', 'ched_34', '34', 'd', 'longText', 'List down suggestions to further improve your course curriculum', 'Optional. Share subjects, skills or tools you wish your course had covered, e.g. more hands-on projects or industry tools.', '[]'::jsonb, '[]'::jsonb, '[]'::jsonb, '[]'::jsonb, false, null, false, 47)
on conflict (schema_version, item_id) do update set
  ched_number = excluded.ched_number,
  section = excluded.section,
  field_type = excluded.field_type,
  prompt = excluded.prompt,
  help_text = excluded.help_text,
  options = excluded.options,
  matrix_rows = excluded.matrix_rows,
  matrix_columns = excluded.matrix_columns,
  table_columns = excluded.table_columns,
  required = excluded.required,
  others_specify_id = excluded.others_specify_id,
  is_others_specify = excluded.is_others_specify,
  sort_order = excluded.sort_order;

-- ---------------------------------------------------------------------------
-- Trigger functions don't need EXECUTE; pin search_path
-- ---------------------------------------------------------------------------
do $$
declare
  fn record;
begin
  for fn in
    select p.oid::regprocedure as sig
    from pg_proc p
    where p.pronamespace = 'public'::regnamespace
      and p.prorettype = 'trigger'::regtype
      and not exists (select 1 from pg_depend d where d.objid = p.oid and d.deptype = 'e')
  loop
    execute format('revoke execute on function %s from public, anon, authenticated', fn.sig);
  end loop;

  for fn in
    select p.oid::regprocedure as sig
    from pg_proc p
    where p.pronamespace = 'public'::regnamespace
      and p.proconfig is null
      and not exists (select 1 from pg_depend d where d.objid = p.oid and d.deptype = 'e')
  loop
    execute format('alter function %s set search_path = public', fn.sig);
  end loop;
end;
$$;

notify pgrst, 'reload schema';
