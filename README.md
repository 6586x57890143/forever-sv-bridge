# forever sv bridge

keeps addon settings across reloads and logins on the wow forever beta. the client writes savedvariables but rarely loads them back, this copies them into an addon that loads them for it

## install

paste into an open powershell window

```powershell
irm https://sv.melting.lol | iex
```

then log out to the character screen once so the client picks up the new addon

## remove

```powershell
& "$env:LOCALAPPDATA\ForeverSVBridge\forever_sv_bridge.ps1" -Uninstall
```

## how it works

a hidden logon task watches `WTF\Account\<acct>\` and copies every non blizzard savedvariables file into `Interface\AddOns\!!ForeverSVBridge\seeds\`. that addon loads first and executes the copies as lua so every addon finds its globals already set. per character files are wrapped per character and a loader runs the set for whoever logs in. nil, empty or half written files are skipped

if ellesmereui is present a shim sets `EllesmereUI.FOREVER_SV_BUG = false` so it stops clearing its own settings at logout

writes only `Interface\AddOns\!!ForeverSVBridge\` and `%LOCALAPPDATA%\ForeverSVBridge\`

## notes

- windows only
- several wow accounts on one install: the most recently active one wins
- per character matching goes by character name, realm is ignored
- do not launch powershell with the install line on its command line (win+r), defender flags that pattern

## development

`forever_sv_bridge.tests.ps1 -Coverage` runs the tests. `forever_sv_bridge.ps1` must stay utf-8 with bom, `install.ps1` must stay plain ascii without one. `npx wrangler deploy` publishes

## license

mit
