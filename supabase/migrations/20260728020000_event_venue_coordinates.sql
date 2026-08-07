-- Optional exact map pin for event venues (keeps free-text venue label).
alter table public.events
  add column if not exists venue_latitude double precision,
  add column if not exists venue_longitude double precision;
