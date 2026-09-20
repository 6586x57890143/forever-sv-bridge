#!/bin/sh
# Forever SV Bridge bootstrap for Linux - mirrors install.ps1:   curl -fsSL https://sv.melting.lol/install.sh | sh
# Downloads forever_sv_bridge.ps1 (UTF-8 with BOM) to the same install dir and runs it with pwsh. Extra
# arguments go to the script (sh -s -- -GamePath /path/to/_classic_beta_). No root: if pwsh is missing it
# is unpacked into ~/.local/share/powershell (Steam Deck's root filesystem is read-only, pacman is no help).
set -eu
base=${SV_BASE:-https://sv.melting.lol}
data=${XDG_DATA_HOME:-$HOME/.local/share}
dir=$data/ForeverSVBridge
dst=$dir/forever_sv_bridge.ps1

command -v curl >/dev/null || { echo "install.sh: curl is required" >&2; exit 1; }
if ! command -v pwsh >/dev/null; then
    case $(uname -m) in x86_64) arch=x64 ;; aarch64) arch=arm64 ;; *) echo "install.sh: no PowerShell build for $(uname -m)" >&2; exit 1 ;; esac
    v=$(curl -fsSLI -o /dev/null -w '%{url_effective}' https://github.com/PowerShell/PowerShell/releases/latest); v=${v##*/v}
    echo "  powershell 7 not found: unpacking $v into $data/powershell (user-local, no root)"
    mkdir -p "$data/powershell" "$HOME/.local/bin"
    curl -fsSL "https://github.com/PowerShell/PowerShell/releases/download/v$v/powershell-$v-linux-$arch.tar.gz" | tar xz -C "$data/powershell"
    chmod +x "$data/powershell/pwsh"
    ln -sf "$data/powershell/pwsh" "$HOME/.local/bin/pwsh"
    PATH=$HOME/.local/bin:$PATH
fi

mkdir -p "$dir"
curl -fsSL "$base/forever_sv_bridge.ps1" -o "$dst"
# same BOM guarantee as install.ps1, so both installers leave the same bytes on disk
[ "$(head -c 3 "$dst" | od -An -tx1 | tr -d ' \n')" = "efbbbf" ] || { printf '\357\273\277' | cat - "$dst" > "$dst.bom" && mv "$dst.bom" "$dst"; }
# piped through sh: hand the terminal back so the game-folder prompt can read it
if [ ! -t 0 ] && ( : </dev/tty ) 2>/dev/null; then exec pwsh -NoProfile -File "$dst" "$@" </dev/tty; fi
exec pwsh -NoProfile -File "$dst" "$@"
