# forever sv bridge - keeps addon settings across reloads and logins on the wow forever beta
#
# install:   irm https://sv.melting.lol | iex              windows powershell
#            pwsh -c 'irm https://sv.melting.lol | iex'    linux (wow under wine / lutris / proton)
# remove:    forever_sv_bridge.ps1 -Uninstall              from the install dir below
#
# downloads forever_sv_bridge.ps1 to %LOCALAPPDATA%\ForeverSVBridge (linux ~/.local/share/ForeverSVBridge)
# and runs it, that sets up a background watcher and the !!ForeverSVBridge addon
$ErrorActionPreference = "Stop"
$win = $env:OS -eq "Windows_NT"
$dir = if ($win) { "$env:LOCALAPPDATA\ForeverSVBridge" } else { "$(if ($env:XDG_DATA_HOME) { $env:XDG_DATA_HOME } else { "$HOME/.local/share" })/ForeverSVBridge" }
$dst = Join-Path $dir "forever_sv_bridge.ps1"
New-Item -ItemType Directory -Force -Path $dir | Out-Null
Invoke-WebRequest -UseBasicParsing -Uri "https://sv.melting.lol/forever_sv_bridge.ps1" -OutFile $dst
$b = [IO.File]::ReadAllBytes($dst)
if (-not ($b.Length -ge 3 -and $b[0] -eq 0xEF -and $b[1] -eq 0xBB -and $b[2] -eq 0xBF)) { [IO.File]::WriteAllBytes($dst, [byte[]](0xEF, 0xBB, 0xBF) + $b) }
if ($win) { Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force }
& $dst
