-- Richer DSS action-log events for expandable audit rows.

begin;

alter table public.dss_flag_notes
  add column if not exists event_type text not null default 'note'
    check (
      event_type in (
        'note',
        'status',
        'assign',
        'impact',
        'announcement',
        'reopen'
      )
    );

alter table public.dss_flag_notes
  add column if not exists metadata jsonb not null default '{}'::jsonb;

-- Best-effort backfill for older rows.
update public.dss_flag_notes
set event_type = 'status'
where event_type = 'note'
  and status_from is not null
  and status_to is not null
  and status_from is distinct from status_to;

update public.dss_flag_notes
set event_type = 'impact'
where event_type = 'note'
  and note ilike 'Impact recheck:%';

update public.dss_flag_notes
set event_type = 'assign'
where event_type = 'note'
  and (note ilike 'Assigned to%' or note ilike 'Owner cleared%');

update public.dss_flag_notes
set event_type = 'announcement'
where event_type = 'note'
  and note ilike 'Created reminder announcement%';

update public.dss_flag_notes
set event_type = 'reopen'
where event_type = 'note'
  and status_to = 'open'
  and status_from in ('resolved', 'dismissed');

commit;
