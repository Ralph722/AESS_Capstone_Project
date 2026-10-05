# Database regression suites from the 2026-10 audit (phases 1-8).
#
# Every suite runs inside a transaction that is rolled back, so nothing is
# changed on the linked project. They use three fixed test accounts (alumnus A,
# alumnus B, admin); if those accounts are removed the suites must be updated.
#
# Usage (from the repo root, with `supabase link` already done):
#   .\supabase\regression\run_all.ps1                   # phase suites vs baselines
#   .\supabase\regression\run_all.ps1 -Reports          # also parity + cron dry run
#   .\supabase\regression\run_all.ps1 -Edge             # also Edge Function abuse tests
#   .\supabase\regression\run_all.ps1 -UpdateBaselines  # accept current output
#
# A DIFF is not automatically a failure: after an intended schema or data
# change, review the lines and rerun with -UpdateBaselines.
param(
  [switch]$Reports,
  [switch]$Edge,
  [switch]$UpdateBaselines
)

$here = $PSScriptRoot
$baselines = Join-Path $here 'baselines'
$outDir = Join-Path $env:TEMP 'aess_regression'
New-Item -ItemType Directory -Force $outDir | Out-Null
$noise = 'recommend updating|new version|Connecting|NativeCommandError|CategoryInfo|FullyQualifiedErrorId|supabase.ps1|node\$exe|~~~~|^\s*$'

function Invoke-Suite([string]$file) {
  supabase db query --linked -f $file -o csv 2>&1 | ForEach-Object { "$_" } | Where-Object { $_ -notmatch $noise }
}

Push-Location (Join-Path $here '..\..')
try {
  $failed = 0
  foreach ($suite in Get-ChildItem $here -Filter 'phase*.sql' | Sort-Object Name) {
    $name = $suite.BaseName
    $actual = @(Invoke-Suite $suite.FullName)
    $outFile = Join-Path $outDir "$name.txt"
    $actual | Set-Content $outFile -Encoding utf8
    $baseFile = Join-Path $baselines "$name.txt"

    if ($UpdateBaselines) {
      Copy-Item $outFile $baseFile -Force
      "{0,-28} baseline updated ({1} lines)" -f $name, $actual.Count
      continue
    }
    if (-not (Test-Path $baseFile)) {
      "{0,-28} NO BASELINE (output in {1})" -f $name, $outFile
      $failed++
      continue
    }
    $diff = Compare-Object (Get-Content $baseFile) $actual
    if (-not $diff) {
      "{0,-28} PASS" -f $name
    } else {
      $failed++
      "{0,-28} DIFF ({1} lines; '<=' baseline, '=>' now)" -f $name, @($diff).Count
      $diff | ForEach-Object { "    {0} {1}" -f $_.SideIndicator, $_.InputObject }
    }
  }

  if ($Reports) {
    foreach ($report in Get-ChildItem $here -Filter 'report_*.sql' | Sort-Object Name) {
      ""
      "--- $($report.BaseName) ---"
      Invoke-Suite $report.FullName
    }
  }

  if ($Edge) {
    ""
    "--- edge functions ---"
    & (Join-Path $here 'edge_functions.ps1')
  }

  ""
  if ($UpdateBaselines) { "Baselines written to $baselines" }
  elseif ($failed -eq 0) { "All phase suites match their baselines." }
  else { "$failed suite(s) differ from their baselines; review the lines above." }
} finally {
  Pop-Location
}
