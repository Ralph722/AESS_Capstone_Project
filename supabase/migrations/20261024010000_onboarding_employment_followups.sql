-- Migration: Onboarding employment follow-up columns and trigger
-- Adds Q18 (type), Q19 (occupation), Q17 (reasons not employed) columns to public.users,
-- plus metadata tracking when and where the employment snapshot was recorded.

alter table public.users
  add column if not exists employment_type text not null default '',
  add column if not exists employment_occupation text not null default '',
  add column if not exists not_employed_reasons text[] not null default '{}',
  add column if not exists not_employed_reason_other text not null default '',
  add column if not exists employment_updated_at timestamptz,
  add column if not exists employment_source text not null default '';

comment on column public.users.employment_type is
  'CHED GTS Q18: Regular or Permanent, Temporary, Casual, Contractual, Self-employed';
comment on column public.users.employment_occupation is
  'CHED GTS Q19: Present occupation title (e.g. Web Developer)';
comment on column public.users.not_employed_reasons is
  'CHED GTS Q17: Array of reasons why not yet employed';
comment on column public.users.not_employed_reason_other is
  'CHED GTS Q17: Specified text when Other reason(s) is selected';
comment on column public.users.employment_updated_at is
  'Timestamp when the employment snapshot was last updated (from onboarding or CHED GTS)';
comment on column public.users.employment_source is
  'Origin of the current employment snapshot: onboarding or ched_gts';

-- Trigger function to automatically maintain employment_updated_at
create or replace function public.fn_users_employment_updated_at()
returns trigger
language plpgsql
as $$
begin
  if (new.employment_status is distinct from old.employment_status)
     or (new.employment_type is distinct from old.employment_type)
     or (new.employment_occupation is distinct from old.employment_occupation)
     or (new.not_employed_reasons is distinct from old.not_employed_reasons)
     or (new.not_employed_reason_other is distinct from old.not_employed_reason_other) then
    if new.employment_updated_at is null or new.employment_updated_at = old.employment_updated_at then
      new.employment_updated_at = now();
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_users_employment_updated_at on public.users;
create trigger trg_users_employment_updated_at
  before update on public.users
  for each row
  execute function public.fn_users_employment_updated_at();

-- Backfill existing profiles with an employment status
update public.users
set employment_updated_at = coalesce(updated_at, created_at, now()),
    employment_source = 'onboarding'
where coalesce(btrim(employment_status), '') <> ''
  and employment_updated_at is null;
