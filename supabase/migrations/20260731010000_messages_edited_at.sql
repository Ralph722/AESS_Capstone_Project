-- Track true content edits separately from updated_at (which also bumps on
-- read receipts and reactions).

alter table public.messages
  add column if not exists edited_at timestamptz;

create or replace function public.messages_set_edited_at()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'UPDATE'
     and new.body is distinct from old.body then
    new.edited_at := now();
  end if;
  return new;
end;
$$;

drop trigger if exists trg_messages_set_edited_at on public.messages;
create trigger trg_messages_set_edited_at
before update on public.messages
for each row
execute function public.messages_set_edited_at();
