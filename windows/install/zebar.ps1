# Installs the Ahri Blossom Zebar bar (widget pack "ahri-blossom", widget "bar").
#   1. copies the rendered pack to ~\.glzr\zebar\ahri-blossom (from generated/, or -PackSource)
#   2. points ~\.glzr\zebar\settings.json startupConfigs at it (original backed up once)
#   3. adds a "Zebar" shortcut to shell:startup so the bar starts at login
#   4. restarts Zebar (unless -NoRestart)
# Usage:  py -3 render.py --deploy zebar ; powershell -File install\zebar.ps1
#         powershell -File install\zebar.ps1 -PackSource <rendered zebar\ahri-blossom dir>
param(
    [string]$PackSource = "$PSScriptRoot\..\generated\zebar\ahri-blossom",
    [switch]$NoRestart
)
$ErrorActionPreference = 'Stop'
$exe      = "$env:ProgramFiles\glzr.io\Zebar\zebar.exe"
$cfgDir   = "$env:USERPROFILE\.glzr\zebar"
$packDir  = "$cfgDir\ahri-blossom"
$settings = "$cfgDir\settings.json"

if (-not (Test-Path $exe)) { throw "Zebar not found at $exe" }

New-Item -ItemType Directory -Force $packDir | Out-Null
if (Test-Path "$PackSource\zpack.json") {
    Copy-Item "$PackSource\*" $packDir -Recurse -Force
} elseif (-not (Test-Path "$packDir\zpack.json")) {
    throw "No rendered pack at $PackSource (run: py -3 render.py --deploy zebar)"
}

if ((Test-Path $settings) -and -not (Test-Path "$settings.bak")) { Copy-Item $settings "$settings.bak" }
$json = [ordered]@{
    '$schema'      = 'https://github.com/glzr-io/zebar/raw/v3.3.1/resources/settings-schema.json'
    startupConfigs = @([ordered]@{ pack = 'ahri-blossom'; widget = 'bar'; preset = 'default' })
} | ConvertTo-Json -Depth 5
[IO.File]::WriteAllText($settings, $json + "`n", (New-Object Text.UTF8Encoding $false))

$lnk = "$([Environment]::GetFolderPath('Startup'))\Zebar.lnk"
$sc = (New-Object -ComObject WScript.Shell).CreateShortcut($lnk)
$sc.TargetPath       = $exe
$sc.Arguments        = ''   # no args: starts startupConfigs, no-op if already running
$sc.WorkingDirectory = Split-Path $exe
$sc.Description      = 'Zebar - Ahri Blossom bar'
$sc.Save()

if (-not $NoRestart) {
    Get-Process zebar -ErrorAction SilentlyContinue | Stop-Process -Force
    # Zebar's WebView2 helpers keep the profile dir locked for a few seconds; a new instance started
    # before they exit can't load the bar page (blank bar). Wait for them, then force the stragglers.
    $helpers = { Get-CimInstance Win32_Process -Filter "Name='msedgewebview2.exe'" | Where-Object CommandLine -match 'webview-exe-name=zebar\.exe' }
    foreach ($i in 1..20) { if (-not (& $helpers)) { break }; Start-Sleep -Milliseconds 250 }
    & $helpers | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    Start-Sleep -Milliseconds 500
    Start-Process $exe -WorkingDirectory (Split-Path $exe)    # same as the login shortcut
    # the bar's script spawns guard.ps1 within a few seconds once the page is up
    $ok = $false
    foreach ($i in 1..30) { Start-Sleep -Milliseconds 500; if (Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object CommandLine -match 'guard\.ps1') { $ok = $true; break } }
    if (-not $ok) { Write-Warning 'zebar restarted but the bar page did not come up (guard not running) - run this script again' }
}
"zebar: pack -> $packDir, startup shortcut -> $lnk"
