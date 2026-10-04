-- Event RSVPs are now Going / Not going ('cant_attend'). "Interested" is
-- retired: existing interested answers are cleared so those alumni can answer
-- again, and the status check no longer accepts it.

delete from public.event_rsvps where status = 'interested';

do $$
declare
  c record;
begin
  for c in
    select con.conname
    from pg_constraint con
    where con.conrelid = 'public.event_rsvps'::regclass
      and con.contype = 'c'
      and pg_get_constraintdef(con.oid) ilike '%status%'
  loop
    execute format('alter table public.event_rsvps drop constraint %I', c.conname);
  end loop;
end $$;

alter table public.event_rsvps
  add constraint event_rsvps_status_check
  check (status in ('going', 'cant_attend'));
