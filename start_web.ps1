param([switch]$Share)
$ErrorActionPreference='Stop'
Set-Location $PSScriptRoot
$port=8770
$root=$PSScriptRoot
$health="http://127.0.0.1:$port/health"
$python=(Get-Command python.exe -ErrorAction Stop).Source
function CheckGame {
  try { $r=Invoke-RestMethod $health -TimeoutSec 2; return ($r.ok -and $r.version -eq '2.0') } catch { return $false }
}
if (!(CheckGame)) {
  if (Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue) { throw 'Port 8770 occupied' }
  $env:SPROUT_TUNNEL='1'
  $s=Start-Process -FilePath $python -ArgumentList @('server.py','--port','8770') -WorkingDirectory $root -WindowStyle Minimized -PassThru
  $s.Id | Set-Content server.pid
  for($i=0;$i -lt 30 -and !(CheckGame);$i++){Start-Sleep -Milliseconds 300}
}
if (!(CheckGame)){throw 'Server could not start'}
if (!$Share){Start-Process "http://127.0.0.1:$port/"; exit 0}
$exe=Join-Path $env:LOCALAPPDATA 'SproutlingsTools\cloudflared.exe'
if (!(Test-Path $exe)) { throw 'Install official cloudflared in %LOCALAPPDATA%\SproutlingsTools first' }
if (Test-Path tunnel.pid) {
  $old=Get-Process -Id ([int](Get-Content tunnel.pid)) -ErrorAction SilentlyContinue
  if ($old -and $old.ProcessName -eq 'cloudflared' -and (Test-Path public-url.txt)) {
    $url=Get-Content public-url.txt
    try { if((Invoke-RestMethod "$url/health" -TimeoutSec 5).version -eq '2.0'){Write-Output $url; Start-Process $url; exit 0} }catch{}
    Stop-Process -Id $old.Id
  }
}
Remove-Item tunnel.log,tunnel-out.log,public-url.txt -ErrorAction SilentlyContinue
$t=Start-Process -FilePath $exe -ArgumentList @('tunnel','--no-autoupdate','--protocol','http2','--url',"http://127.0.0.1:$port") -WorkingDirectory $root -RedirectStandardError (Join-Path $root 'tunnel.log') -RedirectStandardOutput (Join-Path $root 'tunnel-out.log') -WindowStyle Minimized -PassThru
$t.Id | Set-Content tunnel.pid
for($i=0;$i -lt 80;$i++){
  if($t.HasExited){throw 'Tunnel exited; see tunnel.log'}
  $log=Get-Content tunnel.log -Raw -ErrorAction SilentlyContinue
  $m=[regex]::Match([string]$log,'https://[a-z0-9-]+\.trycloudflare\.com')
  if($m.Success){
    $url=$m.Value
    try{
      if((Invoke-RestMethod "$url/health" -TimeoutSec 3).version -eq '2.0'){
        $url | Set-Content public-url.txt
        Write-Output $url
        Start-Process $url
        exit 0
      }
    }catch{}
  }
  Start-Sleep -Milliseconds 500
}
throw 'Public HTTPS URL not verified. See tunnel.log.'
