-- DSS resolve closed-loop: verify impact, intervention detail, linked actions.

begin;

alter table public.dss_flags
  add column if not exists verify_due_at timestamptz,
  add column if not exists impact_verdict text
    check (
      impact_verdict is null
      or impact_verdict in (
        'improved',
        'unchanged',
        'still_flagged',
        'insufficient_data'
      )
    ),
  add column if not exists intervention_detail text,
  add column if not exists linked_announcement_id text,
  add column if not exists followup_sample_n integer;

create index if not exists idx_dss_flags_verify_due
  on public.dss_flags (verify_due_at)
  where verify_due_at is not null and status = 'resolved';

create index if not exists idx_dss_flags_assigned
  on public.dss_flags (assigned_to)
  where assigned_to is not null;

commit;
