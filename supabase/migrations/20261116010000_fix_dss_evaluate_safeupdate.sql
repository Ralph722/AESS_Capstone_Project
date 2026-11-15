-- Fix dss_evaluate_all for Supabase supautils/safeupdate.
-- PostgREST (non-superuser) rejects UPDATE without a WHERE clause.
-- One temp-table UPDATE set basis for every wave row with no WHERE, so
-- Refresh insights failed with: "UPDATE requires a WHERE clause" (21000)
-- and the app fell back to the in-app engine.
--
-- Patch the installed function body in place (avoids re-shipping the full
-- ~1.3k-line evaluator).

do $patch$
declare
  src text;
  old_frag text := $old$
  update pg_temp.ev_waves wv
  set basis = case
    when wv.accepts then 'open_wave'
    when exists (select 1 from public.dss_wave_cohort_snapshots ws where ws.survey_id = wv.survey_id)
      then 'snapshot'
    else 'current'
  end;
$old$;
  new_frag text := $new$
  update pg_temp.ev_waves wv
  set basis = case
    when wv.accepts then 'open_wave'
    when exists (select 1 from public.dss_wave_cohort_snapshots ws where ws.survey_id = wv.survey_id)
      then 'snapshot'
    else 'current'
  end
  where true;
$new$;
begin
  src := pg_get_functiondef('public.dss_evaluate_all(text, boolean)'::regprocedure);

  -- Normalize CRLF from pg_get_functiondef on some hosts.
  src := replace(src, E'\r\n', E'\n');
  old_frag := replace(old_frag, E'\r\n', E'\n');
  new_frag := replace(new_frag, E'\r\n', E'\n');

  if position(new_frag in src) > 0 then
    raise notice 'dss_evaluate_all already has WHERE true on basis update';
    return;
  end if;

  if position(old_frag in src) = 0 then
    raise exception
      'Could not patch dss_evaluate_all: expected basis UPDATE fragment not found';
  end if;

  src := replace(src, old_frag, new_frag);
  execute src;
end;
$patch$;

comment on function public.dss_evaluate_all(text, boolean) is
  'DSS Refresh on the server. Temp UPDATEs use WHERE true so '
  'supautils/safeupdate allows the call via PostgREST.';
