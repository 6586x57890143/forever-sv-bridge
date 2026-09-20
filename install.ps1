# Forever SV Bridge bootstrap - pure ASCII, no BOM, safe through:   irm https://sv.melting.lol/install.ps1 | iex
# Downloads forever_sv_bridge.ps1 (UTF-8 with BOM: it carries box-drawing art) to the install dir and runs it.
$ErrorActionPreference = "Stop"
$dir = "$env:LOCALAPPDATA\ForeverSVBridge"
$dst = "$dir\forever_sv_bridge.ps1"
New-Item -ItemType Directory -Force -Path $dir | Out-Null
Invoke-WebRequest -UseBasicParsing -Uri "https://sv.melting.lol/forever_sv_bridge.ps1" -OutFile $dst
$b = [IO.File]::ReadAllBytes($dst)
if (-not ($b.Length -ge 3 -and $b[0] -eq 0xEF -and $b[1] -eq 0xBB -and $b[2] -eq 0xBF)) { [IO.File]::WriteAllBytes($dst, [byte[]](0xEF, 0xBB, 0xBF) + $b) }
# run it in this session; the policy change lasts for this process only (the default Restricted policy would refuse the file)
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
& $dst
