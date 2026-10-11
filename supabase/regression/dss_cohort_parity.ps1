# Dart-vs-SQL parity check for dss_cohort_metrics on the DEMO project.
# Read-only: exports the DSS inputs and the SQL rows of every CHED GTS wave
# to a temp folder, then runs test/dss/dss_cohort_parity_test.dart on them.
# Never runs against live (refuses any URL that is not the demo project).
# Not 'Stop': Windows PowerShell treats the CLI's stderr progress as errors.
$ErrorActionPreference = 'Continue'
$repo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$line = Get-Content "$repo\supabase\.env.demo" | Where-Object { $_ -match '^DEMO_DB_URL=' } | Select-Object -First 1
$db = ($line -replace '^DEMO_DB_URL=', '').Trim().Trim('"')
if ($db -notmatch 'ogxyvjjkgjtzfmsaeeir' -or $db -match 'lhukeauszbnsyybazauy') { throw 'Refused: DEMO_DB_URL is not the demo project.' }

$out = Join-Path $env:TEMP 'aess_dss_parity'
New-Item -ItemType Directory -Force -Path $out | Out-Null

$inputs = @"
select json_build_object(
  'now', now(),
  'members', (select coalesce(json_agg(json_build_object(
      'id', m.id, 'course', m.course, 'year_graduated', m.year_graduated,
      'auth_uid', m.auth_uid, 'is_registered_user', m.is_registered_user,
      'is_deactivated', m.is_deactivated, 'created_at', m.created_at)), '[]'::json)
    from public.alumni_members m),
  'surveys', (select coalesce(json_agg(json_build_object(
      'id', s.id, 'title', s.title, 'status', s.status, 'open_at', s.open_at,
      'close_at', s.close_at, 'created_at', s.created_at,
      'data', json_build_object('archived', s.data -> 'archived', 'kind', s.data -> 'kind',
        'template_key', s.data -> 'template_key', 'publishedAt', s.data -> 'publishedAt'))), '[]'::json)
    from public.surveys s where s.data ->> 'template_key' = 'ched_gts_builtin'),
  'responses', (select coalesce(json_agg(json_build_object(
      'survey_id', r.survey_id, 'user_id', r.user_id, 'answers', r.answers,
      'status', r.status, 'submitted_at', r.submitted_at, 'updated_at', r.updated_at)), '[]'::json)
    from public.survey_responses r join public.surveys s on s.id = r.survey_id
    where s.data ->> 'template_key' = 'ched_gts_builtin' and r.status = 'submitted'),
  'rules', (select coalesce(json_agg(row_to_json(d)), '[]'::json) from public.dss_rules d),
  'snapshots', (select coalesce(json_agg(row_to_json(w)), '[]'::json) from public.dss_wave_cohort_snapshots w)
) as payload
"@

$rows = @"
select coalesce(json_agg(x), '[]'::json) as payload from (
  select s.id as survey_id, m.*
  from public.surveys s
  cross join lateral public.dss_cohort_metrics(s.id) m
  where s.data ->> 'template_key' = 'ched_gts_builtin'
) x
"@

foreach ($q in @(@{ name = 'inputs.json'; sql = $inputs }, @{ name = 'sql_rows.json'; sql = $rows })) {
  $file = Join-Path $out ('query_' + $q.name + '.sql')
  [IO.File]::WriteAllText($file, $q.sql, (New-Object Text.UTF8Encoding($false)))
  $raw = (supabase db query --db-url $db -f $file 2>$null | Out-String).Replace($db, '<db>')
  Remove-Item $file
  if ($raw -notmatch '"payload"') { throw "Query for $($q.name) failed." }
  [IO.File]::WriteAllText((Join-Path $out $q.name), $raw, (New-Object Text.UTF8Encoding($false)))
}

$env:DSS_PARITY_DIR = $out
Push-Location $repo
try { flutter test test/dss/dss_cohort_parity_test.dart }
finally {
  Pop-Location
  Remove-Item Env:DSS_PARITY_DIR
  Remove-Item -Recurse -Force $out
}
