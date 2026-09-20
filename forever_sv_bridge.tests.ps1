# Self-check for forever_sv_bridge.ps1 (no framework).
#   powershell -File forever_sv_bridge.tests.ps1            run checks
#   powershell -File forever_sv_bridge.tests.ps1 -Coverage  + line coverage via breakpoints
# Dot-sources the real script (its dispatcher returns early when dot-sourced) and points
# the functions at a fake WoW tree + install dir in TEMP. Anything that touches the machine
# (scheduled tasks, registry, sleep) is shadowed by a same-named function.
param([switch]$Coverage)
$ErrorActionPreference = "Stop"
$script = Join-Path $PSScriptRoot "forever_sv_bridge.ps1"

if ($Coverage) {
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($script, [ref]$null, [ref]$null)
    $lines = $ast.FindAll({ param($a) $a -is [System.Management.Automation.Language.StatementAst] -and
            $a -isnot [System.Management.Automation.Language.FunctionDefinitionAst] -and
            $a -isnot [System.Management.Automation.Language.ParamBlockAst] }, $true) |
        ForEach-Object { $_.Extent.StartLineNumber } | Sort-Object -Unique
    $bps = $lines | ForEach-Object { Set-PSBreakpoint -Script $script -Line $_ -Action {} }
}

. $script

$fails = 0
function Check($name, $cond) {
    if ($cond) { Write-Host "  ok   $name" } else { Write-Host "  FAIL $name" -ForegroundColor Red; $script:fails++ }
}
function Touch($path, $text, $ageSec = 5) {
    New-Item -ItemType Directory -Force -Path (Split-Path $path) | Out-Null
    [IO.File]::WriteAllText($path, $text)
    (Get-Item -LiteralPath $path).LastWriteTimeUtc = (Get-Date).ToUniversalTime().AddSeconds(-$ageSec)
}
function Unmock { foreach ($n in $args) { Remove-Item "function:$n" -ErrorAction SilentlyContinue } }

# ---- fake install ----------------------------------------------------------
$Temp       = Join-Path $env:TEMP ("svbridge_test_" + [guid]::NewGuid().ToString("N"))
$InstallDir = "$Temp\install"
$Log        = "$InstallDir\forever_sv_bridge.log"
$GamePath   = "$Temp\World of Warcraft\_classic_beta_"
Use-GameDir $GamePath
New-Item -ItemType Directory -Force -Path "$Addons\RXPGuides" | Out-Null       # no EllesmereUI folder yet
Touch "$Root\WowB.exe" ""
$acct = "$Root\WTF\Account\NEW#1"
$old  = "$Root\WTF\Account\OLD#1"
Touch "$old\SavedVariables\RXPGuides.lua"  "RXPData = {`n[`"old`"] = 1,`n}`n" 600
Touch "$acct\SavedVariables\RXPGuides.lua" "`nRXPData = {`n[`"v`"] = 1,`n}`nRXPSettings = nil`n"
Touch "$acct\SavedVariables\Blizzard_CombatLog.lua" "X = {`n[`"k`"] = 1,`n}`n"   # Blizzard: never seeded
Touch "$acct\SavedVariables\Empty.lua" "EmptyDB = {`n}`n"                        # empty table: skipped
Touch "$acct\SavedVariables\Gone.lua" "GoneDB = nil`n"                           # nil: skipped
Touch "$acct\SavedVariables\Gone.lua.bak" "GoneDB = {`n[`"k`"] = 1,`n}`n"        # .bak: ignored
Touch "$acct\70\Log-Off\SavedVariables\RXPGuides.lua" "RXPCData = {`n[`"step`"] = 12,`n}`n"
Touch "$acct\70\Star-Eyes\SavedVariables\RXPGuides.lua" "RXPCData = {`n[`"step`"] = 3,`n}`n"
Touch "$acct\70\Star-Eyes\SavedVariables\Blizzard_TimeManager.lua" "Y = {`n[`"k`"] = 1,`n}`n"

Write-Host "Test-Valid"
Check "nil is invalid"            (-not (Test-Valid "$acct\SavedVariables\Gone.lua"))
Check "empty table is invalid"    (-not (Test-Valid "$acct\SavedVariables\Empty.lua"))
Check "real table is valid"       (Test-Valid "$acct\SavedVariables\RXPGuides.lua")
Touch "$Root\half.lua" "X = {`n[`"k`"] = {`n"
Check "unbalanced braces invalid" (-not (Test-Valid "$Root\half.lua"))

Write-Host "Get-AccountDir / Get-Sources / Say"
Check "newest account wins" ((Get-AccountDir) -eq $acct)
$src = Get-Sources $acct
Check "account files first, then per-character"  (($src | ForEach-Object Rel) -join "," -eq "acct\Empty.lua,acct\Gone.lua,acct\RXPGuides.lua,char\Log-Off\RXPGuides.lua,char\Star-Eyes\RXPGuides.lua")
Check "Blizzard_* and .bak excluded"             (-not ($src | Where-Object { $_.Rel -like "*Blizzard*" -or $_.Rel -like "*.bak" }))
Check "char folder captured"                     (($src | Where-Object Rel -like "char\Log-Off\*").Char -eq "Log-Off")
Say "hello log" | Out-Null
Check "Say creates install dir and appends to log" ((Get-Content $Log) -match "hello log")

Write-Host "Sync-Seeds / Write-Seed"
$state = @{}
Check "first pass reports change"        (Sync-Seeds $acct $state)
Check "account file copied verbatim"     ((Get-Content -Raw "$Seed\seeds\acct\RXPGuides.lua") -eq (Get-Content -Raw "$acct\SavedVariables\RXPGuides.lua"))
Check "empty / nil not copied"           (-not (Test-Path "$Seed\seeds\acct\Empty.lua") -and -not (Test-Path "$Seed\seeds\acct\Gone.lua"))
$wrapped = Get-Content -Raw "$Seed\seeds\char\Log-Off\RXPGuides.lua"
Check "char file wrapped per character"  ($wrapped -match '^ForeverSVBridge\.char\["Log-Off"\] = ForeverSVBridge\.char\["Log-Off"\] or \{\}\nForeverSVBridge\.char\["Log-Off"\]\["RXPGuides"\] = function\(\)\n')
Check "wrapper keeps body and closes"    ($wrapped -match '\["step"\] = 12' -and $wrapped -match '\nend\n$')
Check "second pass reports no change"    (-not (Sync-Seeds $acct $state))
Touch "$acct\SavedVariables\RXPGuides.lua" "RXPData = {`n[`"v`"] = 2,`n}`n" 0   # just written
Check "fresh write (<1 s) is skipped"    (-not (Sync-Seeds $acct $state))
(Get-Item -LiteralPath "$acct\SavedVariables\RXPGuides.lua").LastWriteTimeUtc = (Get-Date).ToUniversalTime().AddSeconds(-3)
Check "settled write is picked up"       (Sync-Seeds $acct $state)
Check "seed has new content"             ((Get-Content -Raw "$Seed\seeds\acct\RXPGuides.lua") -match '"v"\] = 2')
Touch "$acct\SavedVariables\RXPGuides.lua" "RXPData = nil`n" 5
Check "later nil does not clobber seed"  (-not (Sync-Seeds $acct $state) -and ((Get-Content -Raw "$Seed\seeds\acct\RXPGuides.lua") -match '"v"\] = 2'))

Write-Host "Write-Addon"
Write-Addon
$toc = Get-Content -Raw "$Seed\$AddonName.toc"
Check "toc: head, acct seeds, char seeds, loader" ($toc -match "(?m)^Bridge_Head\.lua\r\n^seeds\\acct\\RXPGuides\.lua\r\n^seeds\\char\\Log-Off\\RXPGuides\.lua\r\n^seeds\\char\\Star-Eyes\\RXPGuides\.lua\r\n^Bridge_Loader\.lua\r\n$")
Check "toc declares no SavedVariables"   ($toc -notmatch "SavedVariables:")
Check "toc is CRLF"                      ($toc -notmatch "(?<!\r)\n")
Check "no EllesmereUI shim without the addon" (-not (Test-Path "$Seed\Bridge_EllesmereUI.lua") -and $toc -notmatch "EllesmereUI")
$head = Get-Content -Raw "$Seed\Bridge_Head.lua"; $loader = Get-Content -Raw "$Seed\Bridge_Loader.lua"
Check "head defines the char table"      ($head -match 'ForeverSVBridge = \{ char = \{\} \}' -and $head -match "forever_sv_bridge.ps1 $([regex]::Escape($Version)) ")
Check "loader matches name, dashes, or single char" ($loader -match 'chars\[me\] or chars\[\(me:gsub\("%s", "-"\)\)\] or \(n == 1 and only\)')
Check "generated lua is LF only"         ($head -notmatch "\r" -and $loader -notmatch "\r")
New-Item -ItemType Directory -Force -Path "$Addons\EllesmereUI" | Out-Null
Write-Addon
$toc = Get-Content -Raw "$Seed\$AddonName.toc"; $eui = Get-Content -Raw "$Seed\Bridge_EllesmereUI.lua"
Check "shim emitted when EllesmereUI exists, right after head" ($toc -match "(?m)^Bridge_Head\.lua\r\n^Bridge_EllesmereUI\.lua\r\n")
Check "shim forces FOREVER_SV_BUG"       ($eui -match 'if k == "FOREVER_SV_BUG" then v = false end')
Check "shim never nils a store"          ($eui -notmatch '(?<![=~])= nil')
Check "shim restores a nil'd store"      ($eui -match 'if EllesmereUIDB == nil then\s+EllesmereUIDB = seeded')
Check "shim keys on our addon name"      ($eui -match 'if name == "!!ForeverSVBridge" then seeded = EllesmereUIDB')

Write-Host "Start-Watch (driven by a fake Start-Sleep)"
Remove-Item -LiteralPath $Seed -Recurse -Force
Remove-Item -LiteralPath "$Root\WTF" -Recurse -Force                    # no account yet -> wait branch
Touch "$Root\WTF_hidden\Account\NEW#1\SavedVariables\RXPGuides.lua" "RXPData = {`n[`"a`"] = 1,`n}`n"   # appears on tick 1
$script:tick = 0; $script:sleeps = @()
function Start-Sleep { param($Seconds, $Milliseconds) $script:sleeps += "$Seconds/$Milliseconds"; $script:tick++
    switch ($script:tick) {
        1 { Rename-Item -LiteralPath "$Root\WTF_hidden" "WTF" }
        2 { Remove-Item -LiteralPath "$Seed\Bridge_Head.lua"                    # WowUp wiped us -> rebuild branch
            Touch "$Root\WTF\Account\NEW#1\70\Newbie\SavedVariables\RXPGuides.lua" "RXPCData = {`n[`"n`"] = 1,`n}`n" }   # new char mid-run
        4 { throw "stop" } } }
function Get-Process { param($Name) if ($script:tick -eq 1) { @{ Id = 1 } } }   # game "running" once
try { Start-Watch } catch { Check "loop ended by fake sleep" ($_.Exception.Message -eq "stop") }
Unmock Start-Sleep Get-Process
Check "waited for account, then fast, slow polls" (($script:sleeps -join " ") -eq "30/ /250 5/ 5/")
Check "addon rebuilt after wipe"                  (Test-Path -LiteralPath "$Seed\Bridge_Head.lua")
Check "seeded after wait"                         ((Get-Content -Raw "$Seed\seeds\acct\RXPGuides.lua") -match '"a"')
Check "new character picked up and listed"        ((Get-Content -Raw "$Seed\$AddonName.toc") -match "seeds\\char\\Newbie\\RXPGuides\.lua")
Check "log records wait and rebuild"              ((Get-Content -Raw $Log) -match "I'll wait" -and (Get-Content -Raw $Log) -match "rebuilding")

Write-Host "Find-BetaDir"
function Get-ItemProperty { @{ InstallPath = "$Temp\World of Warcraft\_retail_\" } }   # registry points at the retail sibling
Check "found via registry"       ((Find-BetaDir) -eq $Root)
function Get-ItemProperty { $null }                                       # no registry hit
$env:ProgramData = "$Temp\pd"
Touch "$Temp\pd\Battle.net\Agent\product.db" ("junk`0" + ($Temp -replace '\\', '/') + "/World of Warcraft`0more")
Check "found via product.db"     ((Find-BetaDir) -eq $Root)
Remove-Item "$Temp\pd" -Recurse -Force
${env:ProgramFiles(x86)} = "$Temp\nope"; $env:ProgramFiles = "$Temp\nope"
$script:asked = 0
function Read-Host { $script:asked++; if ($script:asked -eq 1) { "C:\wrong" } else { "`"$Root`"" } }
Check "prompts until a WowB.exe folder" ((Find-BetaDir) -eq $Root -and $script:asked -eq 2)
Unmock Get-ItemProperty Read-Host

Write-Host "Install-Bridge / Uninstall-Bridge (task cmdlets shadowed)"
$script:calls = @{}
foreach ($c in "New-ScheduledTaskAction", "New-ScheduledTaskTrigger", "New-ScheduledTaskSettingsSet", "Register-ScheduledTask",
               "Start-ScheduledTask", "Stop-ScheduledTask", "Unregister-ScheduledTask") {
    Set-Item "function:$c" ([scriptblock]::Create("`$script:calls['$c'] = `$args; 'x'"))
}
$Self = $script                                                           # run from the repo -> copies itself
Install-Bridge | Out-Null
Check "script copied into install dir"    ([IO.File]::ReadAllBytes("$InstallDir\forever_sv_bridge.ps1").Length -eq [IO.File]::ReadAllBytes($script).Length)
Check "repo file keeps its BOM"           ([IO.File]::ReadAllBytes($script)[0] -eq 0xEF)
Check "task registered, stopped, started" ($script:calls.ContainsKey("Register-ScheduledTask") -and $script:calls.ContainsKey("Stop-ScheduledTask") -and $script:calls.ContainsKey("Start-ScheduledTask"))
Check "task points at copy + game path" (($script:calls["New-ScheduledTaskAction"] -join " ") -like "*$InstallDir\forever_sv_bridge.ps1`" -Watch -GamePath `"$Root`"*")
$GamePath = $null                                                         # no -GamePath -> asks Find-BetaDir
function Find-BetaDir { $script:calls["find"] = 1; "$Temp\World of Warcraft\_classic_beta_" }
Install-Bridge | Out-Null
Check "falls back to Find-BetaDir"     ($script:calls["find"] -eq 1)

Uninstall-Bridge | Out-Null
Check "uninstall stops and removes task" ($script:calls.ContainsKey("Stop-ScheduledTask") -and $script:calls.ContainsKey("Unregister-ScheduledTask"))
Check "uninstall removes addon and install dir" (-not (Test-Path -LiteralPath $Seed) -and -not (Test-Path $InstallDir))
Check "uninstall leaves the game folder" (Test-Path -LiteralPath "$Root\WowB.exe")

Remove-Item -LiteralPath $Temp -Recurse -Force
Write-Host ("`n{0}" -f $(if ($fails) { "$fails FAILED" } else { "all passed" })) -ForegroundColor $(if ($fails) { "Red" } else { "Green" })

if ($Coverage) {
    $hit = @(Get-PSBreakpoint -Script $script | Where-Object HitCount -gt 0 | ForEach-Object Line)
    $miss = $lines | Where-Object { $hit -notcontains $_ }
    $bps | Remove-PSBreakpoint
    Write-Host ("coverage: {0}/{1} lines = {2:P0}" -f $hit.Count, $lines.Count, ($hit.Count / $lines.Count))
    if ($miss) { Write-Host ("missed: " + ($miss -join ", ")) }
}
exit $fails
