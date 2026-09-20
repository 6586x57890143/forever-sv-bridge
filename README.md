# forever sv bridge

addon settings that survive the wow forever beta

the beta client writes addon savedvariables to `WTF\` but rarely loads them back. most logins start from defaults. ellesmereui profiles, restedxp guide progress, anything an addon remembers is gone after a reload. this puts it back

## install

open a powershell window (win+x, terminal) and paste

```powershell
irm https://sv.melting.lol | iex
```

paste it into an open window. do not launch powershell with the line on its command line (win+r style), defender flags that pattern as `Trojan:Win32/Commando.A!ml` no matter what the script does

the one liner downloads `forever_sv_bridge.ps1` to `%LOCALAPPDATA%\ForeverSVBridge` and runs it. it finds your `_classic_beta_` folder, registers a hidden logon task called `ForeverSVBridge` that keeps watching and starts it right away

then log out to the character screen once so the client sees the new addon. from there `/reload` and relog keep your settings

manual route: download `forever_sv_bridge.ps1` and run `powershell -ExecutionPolicy Bypass -File forever_sv_bridge.ps1`

## remove

```powershell
& "$env:LOCALAPPDATA\ForeverSVBridge\forever_sv_bridge.ps1" -Uninstall
```

removes the task, `Interface\AddOns\!!ForeverSVBridge` and the install folder. nothing else was touched

## what it does

- watches `WTF\Account\<acct>\` and copies every non blizzard savedvariables file into a generated addon at `Interface\AddOns\!!ForeverSVBridge\seeds\`. that addon sorts first and executes the copies as lua so every addon finds its globals already there
- account wide files are copied as they are. per character files under `<realm>\<char>\SavedVariables\` are wrapped per character and a small loader runs the set for whoever logs in
- files that are nil, empty or half written are never copied so a bad logout cannot overwrite a good seed
- if ellesmereui is installed a shim forces `EllesmereUI.FOREVER_SV_BUG = false` (9.2.1 and up nils its own settings at logout otherwise) and checks at its `ADDON_LOADED` whether the client loaded the real file by itself. if it did you get a chat line. no addon file is edited

plain file copy outside the game. it never touches game memory and never writes to `WTF\`. the only things it writes are `Interface\AddOns\!!ForeverSVBridge\` in the game folder and its own `%LOCALAPPDATA%\ForeverSVBridge\` for the script and log. polls every 250 ms while `WowB.exe` runs and every 5 s otherwise

## caveats

- windows only. windows powershell 5.1 or newer, both come with windows
- several wow accounts on one install: the account whose files changed last wins
- per character matching goes by character name. the wtf folder is the name with spaces as dashes and the realm is ignored, so the same name on two realms shares one seed and the last write wins. one character on the account always matches
- blizzards own `Blizzard_*` files are not bridged
- settings from before you installed cannot come back if the client already wrote nil over them
- if the addons folder gets wiped the watcher rebuilds `!!ForeverSVBridge` on its own

## development

`forever_sv_bridge.tests.ps1 -Coverage` runs the self check. no framework, about 97% line coverage, ci runs it on windows powershell 5.1 and powershell 7. running `forever_sv_bridge.ps1` from the repo installs the current copy, the task runs the copy in `%LOCALAPPDATA%` so run it again after edits. `banners.ps1` previews the banner variants

encoding rules, ci checks them

- `forever_sv_bridge.ps1` is utf-8 with bom. windows powershell reads a bomless file as ansi and the box drawing art then decodes to `”` (0x94) which the parser takes as a quote, the file stops parsing
- `install.ps1` is pure ascii without bom. `irm` keeps a bom in the string it returns and `iex` fails on a first token that starts with U+FEFF, so the file that goes through `irm | iex` cannot have one. it downloads the main script as bytes and adds the bom if missing

## hosting

an assets only cloudflare worker on `sv.melting.lol`. `wrangler.jsonc` points the assets directory at the repo root and `.assetsignore` lets only the two scripts through. `_headers` serves them as `text/plain; charset=utf-8` with `Cache-Control: no-cache` and `X-Robots-Tag: noindex`, `_redirects` maps `/` to `install.ps1`. `npx wrangler deploy` ships a new version. the zone has a `*.melting.lol/*` route on another worker, the explicit `sv.melting.lol/*` route in the config outranks it

## note for ellesmereui

the shim depends on `EllesmereUI_Lite.lua` doing `EllesmereUI = EllesmereUI or {}` before it assigns `FOREVER_SV_BUG`. a one line switch upstream would remove that dependency

```lua
EllesmereUI.FOREVER_SV_BUG = EllesmereUI.IS_FOREVER and not EUI_FOREVER_SV_BRIDGE
```
