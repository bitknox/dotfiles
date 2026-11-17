# Applies the Ahri Blossom look to Flow Launcher 2.x.
#   1. closes Flow (it rewrites Settings.json on exit)
#   2. copies the rendered theme into %APPDATA%\FlowLauncher\Themes (from generated/, or -ThemeSource)
#   3. merges our keys into Settings.json (everything else is kept), backing up the original once
#   4. makes sure the HKCU Run entry exists, then restarts Flow
# Usage:  py -3 render.py --deploy flow ; powershell -File install\flow.ps1
#         powershell -File install\flow.ps1 -ThemeSource <rendered AhriBlossom.xaml>
param(
    [string]$ThemeSource = "$PSScriptRoot\..\generated\flow\AhriBlossom.xaml",
    [string]$Hotkey = 'Alt + Space',
    [switch]$NoRestart
)
$ErrorActionPreference = 'Stop'
$pal      = Get-Content "$PSScriptRoot\..\palette.json" -Raw | ConvertFrom-Json
$font     = $pal.fonts.mono
$data     = "$env:APPDATA\FlowLauncher"
$settings = "$data\Settings\Settings.json"
$exe      = "$env:LOCALAPPDATA\FlowLauncher\Flow.Launcher.exe"   # Squirrel stub, survives updates

if (-not (Test-Path $exe)) { throw "Flow Launcher not found at $exe" }

# First run: let Flow create its settings, then close it.
if (-not (Test-Path $settings)) {
    Start-Process $exe
    for ($i = 0; $i -lt 30 -and -not (Test-Path $settings); $i++) { Start-Sleep 1 }
    Start-Sleep 2
}

Get-Process Flow.Launcher -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep 1

if (Test-Path $ThemeSource) {
    New-Item -ItemType Directory -Force "$data\Themes" | Out-Null
    Copy-Item $ThemeSource "$data\Themes\AhriBlossom.xaml" -Force
    Write-Host "theme  -> $data\Themes\AhriBlossom.xaml"
} elseif (-not (Test-Path "$data\Themes\AhriBlossom.xaml")) {
    Write-Warning "No rendered theme at $ThemeSource - run: py -3 render.py --deploy flow"
}

if (-not (Test-Path "$settings.ahri-orig")) { Copy-Item $settings "$settings.ahri-orig" }

$overrides = [ordered]@{
    Theme                           = 'AhriBlossom'
    ColorScheme                     = 'Dark'
    BackdropType                    = 1        # 0 none, 1 acrylic, 2 mica, 3 mica-alt
    UseDropShadowEffect             = $true
    Hotkey                          = $Hotkey
    WindowSize                      = 760
    WindowHeightSize                = 46
    ItemHeightSize                  = 50
    QueryBoxFontSize                = 18
    ResultItemFontSize              = 15
    ResultSubItemFontSize           = 12
    QueryBoxFont                    = $font
    ResultFont                      = $font
    ResultSubFont                   = $font
    MaxResultsToShow                = 7
    UseAnimation                    = $false   # keyboard-summoned, used constantly: open/close instantly
    AnimationSpeed                  = 'Fast'
    SearchWindowAlign               = 'Center'
    StartFlowLauncherOnSystemStartup = $true
    HideOnStartup                   = $true
}

# Merge with Python's json (PowerShell 5.1's ConvertTo-Json mangles nesting/escaping).
$tmp = [IO.Path]::GetTempFileName()
$overrides | ConvertTo-Json | Set-Content -Encoding utf8 $tmp
@'
import json, sys
path, ov = sys.argv[1], sys.argv[2]
with open(path, encoding="utf-8-sig") as f: s = json.load(f)
with open(ov, encoding="utf-8-sig") as f: o = json.load(f)
changed = {k: v for k, v in o.items() if s.get(k) != v}
s.update(o)
with open(path, "w", encoding="utf-8") as f: json.dump(s, f, indent=2, ensure_ascii=False)
print("settings:", ", ".join(f"{k}={v}" for k, v in changed.items()) or "already up to date")
'@ | py -3 -I - $settings $tmp
if ($LASTEXITCODE) { throw "settings merge failed" }
Remove-Item $tmp

# Flow only writes its Run entry when the toggle is flipped in its UI, so ensure it here.
Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' 'Flow.Launcher' "`"$exe`""

if (-not $NoRestart) { Start-Process $exe; Write-Host "Flow restarted" }
