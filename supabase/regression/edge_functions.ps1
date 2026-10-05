# Abuse tests for the deployed Edge Functions. Reads supabase/.env (never
# printed), signs in as test alumnus A with a magic link (no email is sent)
# and signs out at the end.
$ErrorActionPreference = 'Stop'
$envMap = @{}
Get-Content (Join-Path $PSScriptRoot '..\.env') | Where-Object { $_ -match '^\s*([A-Z_]+)\s*=\s*(.*)$' } | ForEach-Object {
  $envMap[$Matches[1]] = $Matches[2].Trim().Trim('"')
}
$url = $envMap['SUPABASE_URL']; $anon = $envMap['SUPABASE_ANON_KEY']; $svc = $envMap['SUPABASE_SERVICE_ROLE_KEY']
$fn = "$url/functions/v1"
$results = New-Object System.Collections.Generic.List[object]

function Call($name, $expect, $path, $headers, $body, $method = 'POST') {
  $status = 0; $text = ''
  try {
    $params = @{ Uri = "$fn/$path"; Method = $method; Headers = $headers; ContentType = 'application/json'; TimeoutSec = 40 }
    if ($null -ne $body) { $params.Body = $body }
    $r = Invoke-WebRequest @params -UseBasicParsing
    $status = [int]$r.StatusCode; $text = $r.Content
  } catch {
    if ($_.Exception.Response) {
      $status = [int]$_.Exception.Response.StatusCode
      try { $sr = New-Object IO.StreamReader($_.Exception.Response.GetResponseStream()); $text = $sr.ReadToEnd() } catch {}
    } else { $text = $_.Exception.Message }
  }
  if ($text.Length -gt 90) { $text = $text.Substring(0, 90) }
  $results.Add([pscustomobject]@{ Test = $name; Expected = $expect; Status = $status; Body = $text })
}

$svcHeaders = @{ apikey = $svc; Authorization = "Bearer $svc" }
$a = Invoke-RestMethod -Uri "$url/rest/v1/users?id=eq.6f6c569a-9ded-4c90-acab-19d78ab2a3f3&select=email" -Headers $svcHeaders
$link = Invoke-RestMethod -Method Post -Uri "$url/auth/v1/admin/generate_link" -Headers $svcHeaders -ContentType 'application/json' -Body (@{ type = 'magiclink'; email = $a[0].email } | ConvertTo-Json)
$hashed = if ($link.hashed_token) { $link.hashed_token } else { $link.properties.hashed_token }
$sess = Invoke-RestMethod -Method Post -Uri "$url/auth/v1/verify" -Headers @{ apikey = $anon } -ContentType 'application/json' -Body (@{ type = 'magiclink'; token_hash = $hashed } | ConvertTo-Json)
$userTok = $sess.access_token
$userHeaders = @{ apikey = $anon; Authorization = "Bearer $userTok" }
$anonHeaders = @{ apikey = $anon; Authorization = "Bearer $anon" }
$noAuth = @{ apikey = $anon }

$emailBody = @{ to = 'nobody@example.com'; subject = 'x'; text = 'x' } | ConvertTo-Json
Call 'send-email: no Authorization'            '401' 'send-email' $noAuth $emailBody
Call 'send-email: anon key as bearer'          '401' 'send-email' $anonHeaders $emailBody
Call 'send-email: forged/garbage JWT'          '401' 'send-email' @{ apikey = $anon; Authorization = 'Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ4In0.bad' } $emailBody
Call 'send-email: signed-in alumnus'           '403' 'send-email' $userHeaders $emailBody
Call 'send-email: GET method'                  '405' 'send-email' $userHeaders $null 'GET'

Call 'send-push: no secret (anon)'             '401/403' 'send-push' $anonHeaders '{}'
Call 'send-push: signed-in alumnus, no secret' '403' 'send-push' $userHeaders '{}'
Call 'send-push: wrong secret'                 '403' 'send-push' ($userHeaders + @{ 'x-dispatch-secret' = 'guess' }) '{}'

$long = 'x' * 301
Call 'tracer-help: no Authorization'           '401' 'tracer-help' $noAuth (@{ surveyId = '87ee0e35-299c-4392-a6b1-f8b0521ad98c'; description = 'teacher' } | ConvertTo-Json)
Call 'tracer-help: anon key as bearer'         '401' 'tracer-help' $anonHeaders (@{ surveyId = '87ee0e35-299c-4392-a6b1-f8b0521ad98c'; description = 'teacher' } | ConvertTo-Json)
Call 'tracer-help: malformed JSON'             '400' 'tracer-help' $userHeaders '{not json'
Call 'tracer-help: input over 300 chars'       '400' 'tracer-help' $userHeaders (@{ surveyId = '87ee0e35-299c-4392-a6b1-f8b0521ad98c'; description = $long } | ConvertTo-Json)
Call 'tracer-help: unknown survey id'          '403' 'tracer-help' $userHeaders (@{ surveyId = '00000000-0000-4000-8000-000000000000'; description = 'teacher' } | ConvertTo-Json)
Call 'tracer-help: SQL-ish survey id'          '403/400' 'tracer-help' $userHeaders (@{ surveyId = "x' or 1=1 --"; description = 'teacher' } | ConvertTo-Json)

try { Invoke-RestMethod -Method Post -Uri "$url/auth/v1/logout?scope=local" -Headers $userHeaders | Out-Null; $out = 'signed out' } catch { $out = 'logout failed: ' + $_.Exception.Message }
Call 'session revoked: send-email after logout' '401' 'send-email' $userHeaders $emailBody

$results | Format-Table -AutoSize -Wrap | Out-String -Width 220
"test session: $out"
$failed = @($results | Where-Object { ($_.Expected -split '/') -notcontains [string]$_.Status })
"edge functions: {0}/{1} passed" -f ($results.Count - $failed.Count), $results.Count
