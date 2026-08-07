-- Add birth_date to public.users (tracer / onboarding demographic field).
-- alumni_members already has this column; users did not in phase 1.

alter table public.users
  add column if not exists birth_date date;
