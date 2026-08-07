-- GTS live profile columns on public.users (Section A extras, B item 12, employment status).
-- All nullable / defaulted so existing rows are unaffected.

alter table public.users
  add column if not exists telephone_number text not null default '',
  add column if not exists mobile_number text not null default '',
  add column if not exists region_of_origin text not null default '',
  add column if not exists province text not null default '',
  add column if not exists location_of_residence text not null default '',
  add column if not exists college_university text not null default '',
  add column if not exists honors_awards text not null default '',
  add column if not exists employment_status text not null default '';

-- Backfill mobile from legacy contact_number when empty.
update public.users
set mobile_number = contact_number
where mobile_number = ''
  and contact_number <> '';

-- Keep contact_number in sync as mobile alias for legacy code paths.
update public.users
set contact_number = mobile_number
where contact_number = ''
  and mobile_number <> '';
