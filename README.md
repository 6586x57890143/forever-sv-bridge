# forever sv bridge

keeps addon settings across reloads and logins on the wow forever beta. the client writes savedvariables but rarely loads them back, this copies them into an addon that loads them for it

## install

windows, paste into a powershell window

```powershell
irm https://sv.melting.lol | iex
```

linux and steam deck (wow under wine, lutris, bottles or proton), paste into a terminal

```sh
curl -fsSL https://sv.melting.lol/install.sh | sh
```

it fetches the same powershell script and runs it with pwsh; if there is no pwsh it unpacks powershell 7 into `~/.local/share/powershell` (user-local, no root, so it also works on the deck's read-only system). game folder somewhere unusual: `curl -fsSL https://sv.melting.lol/install.sh | sh -s -- -GamePath /path/to/_classic_beta_`

then log out to the character screen once so the client picks up the new addon. after that /reload and relog keep your settings

**linux support is untested on a real wine install so far** (only the test suite has run on linux). if it misbehaves, `journalctl --user -u ForeverSVBridge` and the log file are where to look

## remove

```powershell
& "$env:LOCALAPPDATA\ForeverSVBridge\forever_sv_bridge.ps1" -Uninstall     # windows
pwsh ~/.local/share/ForeverSVBridge/forever_sv_bridge.ps1 -Uninstall       # linux
```

## how it works

a background watcher (logon task on windows, systemd user service on linux) follows `WTF\Account\<acct>\` and copies every non blizzard savedvariables file into `Interface\AddOns\!!ForeverSVBridge\seeds\`. that addon loads first and runs the copies as lua, so every addon finds its settings already in place. per character files are wrapped per character and a loader picks the set for whoever logs in. empty or half written files are skipped

if ellesmereui is installed a shim sets `EllesmereUI.FOREVER_SV_BUG = false` so it stops clearing its own settings at logout

everything lives in `Interface\AddOns\!!ForeverSVBridge\` and `%LOCALAPPDATA%\ForeverSVBridge\` (linux `~/.local/share/ForeverSVBridge/` plus the unit in `~/.config/systemd/user/`; a pwsh that install.sh unpacked stays in `~/.local/share/powershell`)

## notes

- linux: the game folder is looked up in the usual wine prefixes (`~/Games/*`, `~/.wine`, bottles, steam compatdata native / flatpak / deck sd card under `/run/media`); anywhere else pass `-GamePath /path/to/_classic_beta_` or answer the prompt
- several wow accounts on one install: the most recently active one wins
- per character matching goes by character name, realm is ignored
- steam deck: run the install line from desktop mode (konsole); the service then also runs in game mode. after a steamos update `~/.local` survives, so nothing to redo

## development

`forever_sv_bridge.tests.ps1 -Coverage` runs the tests on windows powershell and pwsh (ci covers both plus linux). `forever_sv_bridge.ps1` stays utf-8 with bom, `install.ps1` stays plain ascii, `install.sh` stays lf and posix sh (ci runs it against a stub pwsh). `npx wrangler deploy` publishes

## license

mit
