$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$url = 'http://127.0.0.1:8769/health'
try {
  $h = Invoke-RestMethod -Uri $url -TimeoutSec 2
  if ($h.ok -and $h.version -eq '1.0') { exit 0 }
  throw 'Port 8769 is occupied by another service.'
} catch {
  if (Get-NetTCPConnection -LocalPort 8769 -State Listen -ErrorAction SilentlyContinue) { throw 'Port 8769 is occupied. Check the service.' }
}
$python = Get-Command py.exe -ErrorAction Stop
Start-Process -FilePath $python.Source -ArgumentList @('-3', ('"' + (Join-Path $root 'server.py') + '"')) -WorkingDirectory $root -WindowStyle Minimized
for ($i=0; $i -lt 30; $i++) {
  try {
    $h=Invoke-RestMethod -Uri $url -TimeoutSec 1
    if ($h.ok -and $h.version -eq '1.0') { exit 0 }
  } catch {}
  Start-Sleep -Milliseconds 250
}
throw 'Sproutlings server could not be started.'
