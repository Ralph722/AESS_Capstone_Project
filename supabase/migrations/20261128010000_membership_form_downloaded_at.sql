-- Track first successful Membership Form download for onboarding gate
-- and a 30-day Profile re-download window.

begin;

alter table public.users
  add column if not exists membership_form_downloaded_at timestamptz;

comment on column public.users.membership_form_downloaded_at is
  'First time the alumnus successfully downloaded/shared their Membership Form PDF. Used to gate onboarding completion and a 30-day Profile re-download window.';

-- Grandfather already-onboarded alumni: give them a 30-day Profile window
-- from migration time without requiring a new onboarding pass.
update public.users
set membership_form_downloaded_at = timezone('utc', now())
where onboarding_complete = true
  and membership_form_downloaded_at is null;

create index if not exists users_membership_form_downloaded_at_idx
  on public.users (membership_form_downloaded_at)
  where membership_form_downloaded_at is not null;

commit;
