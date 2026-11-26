Set-Location $PSScriptRoot
foreach($f in @('tunnel.pid','server.pid')){
  if(Test-Path $f){
    $proc=Get-Process -Id ([int](Get-Content $f)) -ErrorAction SilentlyContinue
    if($proc -and (($f -eq 'tunnel.pid' -and $proc.ProcessName -eq 'cloudflared') -or ($f -eq 'server.pid' -and $proc.ProcessName -eq 'python'))){
      $cmd=(Get-CimInstance Win32_Process -Filter "ProcessId=$($proc.Id)").CommandLine
      if(($f -eq 'tunnel.pid' -and $cmd -match '8770') -or ($f -eq 'server.pid' -and $cmd -match 'server.py.*8770')){Stop-Process -Id $proc.Id}
    }
    Remove-Item $f -ErrorAction SilentlyContinue
  }
}
Remove-Item public-url.txt -ErrorAction SilentlyContinue
