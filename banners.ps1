# Banner permutations for the installer header. Run and screenshot:
#   powershell -File banners.ps1
# Each banner = [SavedVariables glyph] + [bridge] + [WoW Forever glyph], rows zipped
# together so alignment is automatic; colors are 24-bit ANSI (Win10+ console).
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$e = [char]27
function C($r, $g, $b) { "$e[38;2;$r;$g;${b}m" }
$TEAL = C 90 200 190      # SavedVariables side (neutral teal)
$BLUE = C 38 120 150      # Forever ring
$GOLD = C 214 180 120     # Forever W / compass
$GRAY = C 110 110 110     # bridge stone
$DIM  = C 70 70 70        # separators, water
$WHITE = C 225 225 225
$R = "$e[0m"

# ---- glyphs (each row same width) ------------------------------------------
$E_big = @(
" ╭──────────╮  ",
" │ ┌──────┐ │  ",
" │ │  SV  │ │  ",
" │ └──────┘ │  ",
" │          │  ",
" │  ▐████▌  │  ",
" ╰──────────╯  ")
$W_big = @(
"       ◆       ",
"   ╭───┴───╮   ",
" ◆─┤ ∞ W ∞ ├─◆ ",
"   │   W   │   ",
"   ╰───┬───╯   ",
"       ◆       ",
"               ")
$E_mid = @(
" ╭───────╮ ",
" │ ┌───┐ │ ",
" │ │SV │ │ ",
" │ ▐███▌ │ ",
" ╰───────╯ ")
$W_mid = @(
"     ◆     ",
"  ╭──┴──╮  ",
"◆─┤ ∞W∞ ├─◆",
"  ╰──┬──╯  ",
"     ◆     ")
$E_small = @("       ", " [ SV ]", "       ")
$W_small = @("       ", " ( W ) ", "       ")

# ---- bridges (same row count as the glyph they pair with) ------------------
$suspension = @(
"                                    ",
"          │                │        ",
"       ╭──┼──╮          ╭──┼──╮     ",
"    ╭──╯  │  ╰──────────╯  │  ╰──╮  ",
" ═══╧═════╧════════════════╧═════╧═══",
"    ║     ║                ║     ║  ",
" ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ")
$arch = @(
"                                    ",
"                                    ",
"     S a v e d V a r i a b l e s    ",
" ═══════════════════════════════════",
"   ╱‾‾‾╲    ╱‾‾‾╲    ╱‾‾‾╲    ╱‾‾‾╲ ",
"  ╱     ╲  ╱     ╲  ╱     ╲  ╱     ╲",
" ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ")
$rope = @(
"                                ",
"  ╭────────────────────────────╮",
" ─╡╪╪╪╪╪╪╪╪╪╪╪╪╪╪╪╪╪╪╪╪╪╪╪╪╪╪╪╪╞─",
"  ╰────────────────────────────╯",
"                                ")
$arrow = @(
"                             ",
"  ━━━━━  SavedVariables  ━━━▶",
"                             ")
$rail = @(
"                                    ",
"   ┃   ┃   ┃   ┃   ┃   ┃   ┃   ┃    ",
" ══╋═══╋═══╋═══╋═══╋═══╋═══╋═══╋════",
"   ┃   ┃   ┃   ┃   ┃   ┃   ┃   ┃    ",
" ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ")

# ---- composition ------------------------------------------------------------
function Paint-W($row) { $row -replace 'W', "$GOLD`W$BLUE" -replace '◆', "$GOLD◆$BLUE" -replace '∞', "$GOLD∞$BLUE" }
function Paint-Bridge($row) {
    $row -replace '~', "$DIM~$GRAY" -replace 'SavedVariables', "$WHITE`SavedVariables$GRAY" -replace 'S a v e d V a r i a b l e s', "$WHITE`S a v e d V a r i a b l e s$GRAY"
}
function Pad($rows) { $m = ($rows | Measure-Object Length -Maximum).Maximum; $rows | ForEach-Object { $_.PadRight($m) } }
function Show-Banner($title, $left, $bridge, $right, $labels) {
    $left = Pad $left; $bridge = Pad $bridge; $right = Pad $right
    $w = ($left[0].Length + $bridge[0].Length + $right[0].Length)
    Write-Host ""
    Write-Host ("$DIM" + "╶" + ("─" * 3) + " $WHITE$title $DIM" + ("─" * ($w - $title.Length - 7)) + "╴$R")
    Write-Host ""
    for ($i = 0; $i -lt $left.Count; $i++) {
        Write-Host ("  $TEAL" + $left[$i] + "$GRAY" + (Paint-Bridge $bridge[$i]) + "$BLUE" + (Paint-W $right[$i]) + $R)
    }
    if ($labels) {
        $mid = $bridge[0].Length
        $l = "SAVED VARS".PadLeft(($left[0].Length + 10) / 2).PadRight($left[0].Length)
        $m = "Forever SV Bridge  v0.2".PadLeft(($mid + 23) / 2).PadRight($mid)
        $r = "WoW: FOREVER".PadLeft(($right[0].Length + 12) / 2).PadRight($right[0].Length)
        Write-Host ""
        Write-Host ("  $TEAL$l$DIM$m$GOLD$r$R")
    }
    Write-Host ""
    Write-Host ("$DIM" + ("─" * ($w + 2)) + $R)
}

Show-Banner "1 · suspension"  $E_big   $suspension $W_big   $true
Show-Banner "2 · arches"      $E_big   $arch       $W_big   $true
Show-Banner "3 · rope bridge" $E_mid   $rope       $W_mid   $true
Show-Banner "4 · rail"        $E_mid   $rail       $W_mid   $true
Show-Banner "5 · minimal"     $E_small $arrow      $W_small $false
Write-Host ""
