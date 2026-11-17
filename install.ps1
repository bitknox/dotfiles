<#
.SYNOPSIS
    One-shot bootstrap for the Ahri Spirit Blossom rice. Idempotent: safe to re-run any time.

.DESCRIPTION
    Runs the scripts in install\ in dependency order. Every step checks its prerequisites first and
    is SKIPPED (not failed) when the app it themes is missing. A failing step never stops the run.
    A summary table (step | result | note) is printed at the end.

    Run from a normal, non-elevated shell. Steps that need admin (restore point, Nilesoft, Windhawk
    registry import, some winget installers) raise their own UAC prompt. Spotify and Spicetify refuse
    to run elevated, so they are skipped when this script itself is elevated.

    Nothing here uninstalls or deletes user data. Configs that get replaced are backed up by the
    individual scripts (*.bak / *.orig / backup\).

.PARAMETER Only
    Run just these steps (in canonical order). Optional steps can be named here too.
.PARAMETER Skip
    Run everything except these steps.
.PARAMETER DryRun
    Print the plan: each step, whether its prerequisites are met right now, and what it would run.
.PARAMETER List
    List the steps with one-line descriptions and exit.
.PARAMETER All
    Include the optional steps (apps, zen-addons) in a full run.
.PARAMETER Force
    Re-run steps that detect they are already done (fonts, backup, restore point).

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\install.ps1
.EXAMPLE
    .\install.ps1 -DryRun
.EXAMPLE
    .\install.ps1 -Only render,deploy,zebar
.EXAMPLE
    .\install.ps1 -Skip wallpaper,lockscreen -All
#>
[CmdletBinding()]
param(
    [string[]]$Only,
    [string[]]$Skip,
    [switch]$DryRun,
    [switch]$List,
    [switch]$All,
    [switch]$Force
)

# NOTE: keep this file pure ASCII and Windows PowerShell 5.1 compatible (fresh installs have no pwsh).
$ErrorActionPreference = 'Stop'
$Root     = $PSScriptRoot
$Inst     = Join-Path $Root 'install'
$Gen      = Join-Path $Root 'generated'
$RenderPy = Join-Path $Root 'render.py'
$PS51     = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
$IsAdmin  = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
                [Security.Principal.WindowsBuiltInRole]::Administrator)

# Paths the steps probe (same ones the install scripts hardcode)
$WindhawkExe = "$env:ProgramFiles\Windhawk\windhawk.exe"
$ZebarExe    = "$env:ProgramFiles\glzr.io\Zebar\zebar.exe"
$FlowExe     = "$env:LOCALAPPDATA\FlowLauncher\Flow.Launcher.exe"
$WtSettings  = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
$WeExe       = "${env:ProgramFiles(x86)}\Steam\steamapps\common\wallpaper_engine\wallpaper64.exe"
$WeProject   = "${env:ProgramFiles(x86)}\Steam\steamapps\workshop\content\431960\2184359275\project.json"
$ZenExe      = "$env:ProgramFiles\Zen Browser\zen.exe"
$SpotifyExe  = "$env:APPDATA\Spotify\Spotify.exe"
$DiscordDir  = "$env:LOCALAPPDATA\Discord"
$PowerToysCfg = "$env:LOCALAPPDATA\Microsoft\PowerToys\settings.json"
$VencordCli  = 'https://github.com/Vencord/Installer/releases/latest/download/VencordInstallerCli.exe'
$VencordTheme = 'ahri-blossom.theme.css'

# winget packages. Test = optional scriptblock that detects a non-winget install of the same thing.
$CorePackages = @(
    @{ Id = 'Python.Python.3.13';          Why = 'render.py + install scripts'; Test = { Test-Cmd py } }
    @{ Id = 'Microsoft.PowerShell';        Why = 'pwsh 7, default terminal profile' }
    @{ Id = 'Microsoft.WindowsTerminal';   Why = 'terminal';                     Test = { Test-Cmd wt } }
    @{ Id = 'RamenSoftware.Windhawk';      Why = 'dock, Start, borders, Explorer'; Test = { Test-Path $WindhawkExe } }
    @{ Id = 'glzr-io.zebar';               Why = 'top bar';                      Test = { Test-Path $ZebarExe } }
    @{ Id = 'Flow-Launcher.Flow-Launcher'; Why = 'launcher';                     Test = { Test-Path $FlowExe } }
    @{ Id = 'Fastfetch-cli.Fastfetch';     Why = 'terminal greeter' }
    @{ Id = 'Starship.Starship';           Why = 'prompt' }
    @{ Id = 'sxyazi.yazi';                 Why = 'file manager (y)' }
    @{ Id = 'sharkdp.bat';                 Why = 'cat' }
    @{ Id = 'eza-community.eza';           Why = 'ls' }
    @{ Id = 'ajeetdsouza.zoxide';          Why = 'cd' }
    @{ Id = 'karlstav.cava';               Why = 'visualizer'; Test = { Test-Path "$env:LOCALAPPDATA\cava\cava.exe" } }
    @{ Id = 'Spicetify.Spicetify';         Why = 'Spotify theming' }
    @{ Id = 'Spotify.Spotify';             Why = 'desktop Spotify (not the Store one)'; UserOnly = $true; Test = { Test-Path $SpotifyExe } }
)
# Apps that only get themed. Optional: most people already have the ones they use.
$AppPackages = @(
    @{ Id = 'Zen-Team.Zen-Browser';     Why = 'browser';              Test = { Test-Path $ZenExe } }
    @{ Id = 'Discord.Discord';          Why = 'Vencord theme';        UserOnly = $true; Test = { Test-Path "$DiscordDir\Update.exe" } }
    @{ Id = 'Valve.Steam';              Why = 'Wallpaper Engine host'; Test = { Test-Path "${env:ProgramFiles(x86)}\Steam\steam.exe" } }
    @{ Id = 'Microsoft.PowerToys';      Why = 'PowerToys (Run gets disabled for Flow)' }
    @{ Id = 'Microsoft.VisualStudioCode'; Why = 'editor theme'; Test = { Test-Cmd code } }
    @{ Id = 'Anysphere.Cursor';         Why = 'editor theme';   Test = { Test-Cmd cursor } }
    @{ Id = 'Neovim.Neovim';            Why = 'LazyVim colorscheme'; Test = { (Test-Cmd nvim) -or (Test-Path "$env:ProgramFiles\Neovim\bin\nvim.exe") } }
    @{ Id = 'Notepad++.Notepad++';      Why = 'Style Configurator theme' }
    @{ Id = 'Telegram.TelegramDesktop'; Why = '.tdesktop-theme' }
    @{ Id = 'OBSProject.OBSStudio';     Why = '.ovt theme' }
)

# ---------------------------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------------------------
function Test-Cmd([string]$Name) { [bool](Get-Command $Name -ErrorAction SilentlyContinue) }

function Update-SessionPath {
    # pick up PATH changes from installers that ran during this session
    $m = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $u = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = "$m;$u;$env:LOCALAPPDATA\Microsoft\WinGet\Links"
}

function Write-Section([string]$Title) {
    Write-Host ''
    Write-Host ('== ' + $Title + ' ').PadRight(78, '=') -ForegroundColor Magenta
}

function Write-Info([string]$Text) { Write-Host "   $Text" -ForegroundColor DarkGray }

function Invoke-Native([string]$Exe, [string[]]$Arguments = @()) {
    Write-Info ("> " + (Split-Path $Exe -Leaf) + ' ' + ($Arguments -join ' '))
    & $Exe @Arguments
    if ($LASTEXITCODE) { throw "$(Split-Path $Exe -Leaf) exited with code $LASTEXITCODE" }
}

# install\*.ps1 run in a fresh Windows PowerShell 5.1 process: isolates their `exit`, Add-Type and
# $ErrorActionPreference, and lockscreen.ps1 needs 5.1 for WinRT anyway.
function Invoke-InstallScript([string]$Name, [string[]]$Arguments = @()) {
    Invoke-Native $PS51 (@('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $Inst $Name)) + $Arguments)
}

function Invoke-Py([string[]]$Arguments) { Invoke-Native 'py' (@('-3') + $Arguments) }

# Render templates/ -> generated/ once per run (steps that consume generated/ call this, so -Only works).
function Invoke-Render {
    if ($script:Rendered) { return }
    Invoke-Py @($RenderPy)
    $script:Rendered = $true
}

function Get-NeedPy { if (-not (Test-Cmd py)) { 'Python launcher (py) not found - run the packages step first' } }

$script:WingetIds = $null
function Get-WingetInstalledIds {
    if ($null -ne $script:WingetIds) { return $script:WingetIds }
    $ids = @()
    if (Test-Cmd winget) {
        $tmp = Join-Path $env:TEMP "ahri-winget-export-$PID.json"
        $ErrorActionPreference = 'Continue'
        & winget export -o $tmp --accept-source-agreements --disable-interactivity 2>&1 | Out-Null
        $ErrorActionPreference = 'Stop'
        if (Test-Path $tmp) {
            $j = Get-Content $tmp -Raw | ConvertFrom-Json
            $ids = @($j.Sources | ForEach-Object { $_.Packages } | ForEach-Object { $_.PackageIdentifier })
            Remove-Item $tmp -Force
        }
    }
    $script:WingetIds = $ids
    return $ids
}

function Test-PackagePresent($Pkg) {
    if ($Pkg.Test -and (& $Pkg.Test)) { return $true }
    $ids = Get-WingetInstalledIds
    if ($ids.Count) { return ($ids -contains $Pkg.Id) }
    # export failed: ask winget directly
    $ErrorActionPreference = 'Continue'
    & winget list --id $Pkg.Id -e --accept-source-agreements --disable-interactivity 2>&1 | Out-Null
    $found = ($LASTEXITCODE -eq 0)
    $ErrorActionPreference = 'Stop'
    return $found
}

function Get-PackagePlan($Packages) {
    foreach ($p in $Packages) {
        $state = if (Test-PackagePresent $p) { 'present' }
                 elseif ($p.UserOnly -and $IsAdmin) { 'skip (needs non-elevated shell)' }
                 else { 'would install' }
        '{0,-30} {1,-34} {2}' -f $p.Id, $state, $p.Why
    }
}

function Install-Packages($Packages) {
    $failed = @(); $installed = @(); $skipped = @()
    foreach ($p in $Packages) {
        if (Test-PackagePresent $p) { Write-Info "present  $($p.Id)"; continue }
        if ($p.UserOnly -and $IsAdmin) {
            Write-Host "   skip     $($p.Id) (per-user installer refuses to run elevated; re-run from a normal shell)" -ForegroundColor Yellow
            $skipped += $p.Id; continue
        }
        Write-Host "   install  $($p.Id)  ($($p.Why))"
        & winget install --id $p.Id -e --silent --accept-package-agreements --accept-source-agreements --disable-interactivity
        if ($LASTEXITCODE) { Write-Host "   winget exit $LASTEXITCODE for $($p.Id)" -ForegroundColor Red; $failed += $p.Id }
        else { $installed += $p.Id }
    }
    Update-SessionPath
    $script:WingetIds = $null
    $parts = @()
    if ($installed.Count) { $parts += "installed: $($installed -join ', ')" }
    if ($skipped.Count)   { $parts += "skipped: $($skipped -join ', ')" }
    if ($failed.Count)    { $parts += "FAILED: $($failed -join ', ')" }
    $script:Note = if ($parts.Count) { $parts -join '; ' } else { 'all present' }
    if ($failed.Count) { throw $script:Note }
}

function Get-ZenProfileDir {
    $ini = "$env:APPDATA\zen\profiles.ini"
    if (-not (Test-Path $ini)) { return $null }
    $sections = @(); $cur = $null
    foreach ($l in Get-Content $ini) {
        if ($l -match '^\s*\[(.+)\]\s*$') { $cur = @{ __name = $Matches[1] }; $sections += $cur }
        elseif ($cur -and $l -match '^\s*([^=]+?)\s*=\s*(.*)$') { $cur[$Matches[1]] = $Matches[2] }
    }
    # the [Install<hash>] Default= is the profile Zen actually opens; fall back to Default=1, then the first
    $rel = ($sections | Where-Object { $_.__name -like 'Install*' -and $_.Default } | Select-Object -First 1).Default
    if (-not $rel) { $rel = ($sections | Where-Object { $_.__name -like 'Profile*' -and $_.Default -eq '1' } | Select-Object -First 1).Path }
    if (-not $rel) { $rel = ($sections | Where-Object { $_.__name -like 'Profile*' } | Select-Object -First 1).Path }
    if (-not $rel) { return $null }
    $rel = $rel.Replace('/', '\')
    $dir = if ([IO.Path]::IsPathRooted($rel)) { $rel } else { Join-Path "$env:APPDATA\zen" $rel }
    if (Test-Path $dir) { return $dir } else { return $null }
}

function Get-JetBrainsConfigDirs {
    @(Get-ChildItem "$env:APPDATA\JetBrains" -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '\d{4}\.\d+$' })
}

function Test-SpicetifyBackedUp {
    $ini = "$env:APPDATA\spicetify\config-xpui.ini"
    if (-not (Test-Path $ini)) { return $false }
    $inBackup = $false
    foreach ($l in Get-Content $ini) {
        if ($l -match '^\s*\[(.+)\]') { $inBackup = ($Matches[1] -eq 'Backup'); continue }
        if ($inBackup -and $l -match '^\s*version\s*=\s*\S+') { return $true }
    }
    return $false
}

function Get-DiscordAppDir {
    Get-ChildItem $DiscordDir -Directory -Filter 'app-*' -ErrorAction SilentlyContinue |
        Sort-Object { try { [version]($_.Name -replace '^app-', '') } catch { [version]'0.0' } } -Descending |
        Select-Object -First 1
}

function Test-VencordPatched {
    $app = Get-DiscordAppDir
    # the Vencord installer moves Discord's app.asar to _app.asar and drops in a tiny loader
    return [bool]($app -and (Test-Path (Join-Path $app.FullName 'resources\_app.asar')))
}

function Get-WindhawkMods {
    $wanted = @(Get-ChildItem (Join-Path $Root 'templates\windhawk') -Filter *.json | ForEach-Object { $_.BaseName })
    $have = @(Get-ChildItem 'HKLM:\SOFTWARE\Windhawk\Engine\Mods' -ErrorAction SilentlyContinue | ForEach-Object { $_.PSChildName })
    [pscustomobject]@{
        Wanted    = $wanted
        Installed = @($wanted | Where-Object { $have -contains $_ })
        Missing   = @($wanted | Where-Object { $have -notcontains $_ })
    }
}

# ---------------------------------------------------------------------------------------------
# steps
# ---------------------------------------------------------------------------------------------
$Steps = New-Object System.Collections.Generic.List[object]
function Add-Step {
    param([string]$Name, [string]$Desc, [scriptblock]$Check, [scriptblock]$Plan, [scriptblock]$Run, [switch]$Optional)
    $Steps.Add([pscustomobject]@{ Name = $Name; Desc = $Desc; Check = $Check; Plan = $Plan; Run = $Run; Optional = [bool]$Optional })
}

Add-Step 'backup' 'Export the registry keys the rice changes to backup\pre-rice-<stamp> + "Pre Ahri rice" restore point (UAC)' `
    -Check {
        $haveBackup = @(Get-ChildItem (Join-Path $Root 'backup') -Directory -Filter 'pre-rice-*' -ErrorAction SilentlyContinue).Count -gt 0
        $rpLog = Join-Path $Root 'backup\restore-point.log'
        $haveRp = (Test-Path $rpLog) -and ((Get-Content $rpLog -Raw) -match '(?m)^OK')
        if ($haveBackup -and $haveRp -and -not $Force) { 'backup\pre-rice-* and restore point already exist (-Force to redo)' }
    } `
    -Plan { 'reg export HKCU accent/colors/cursors/desktop/dwm/explorer/personalize/sounds/taskbar/themes/lockscreen keys', 'copy WT settings.json + PowerShell profiles', 'elevated: Checkpoint-Computer -Description "Pre Ahri rice"' } `
    -Run {
        $notes = @()
        $existing = @(Get-ChildItem (Join-Path $Root 'backup') -Directory -Filter 'pre-rice-*' -ErrorAction SilentlyContinue)
        if ($existing.Count -and -not $Force) {
            Write-Info "registry backup exists: $($existing[0].Name)"
        } else {
            $dir = Join-Path $Root ("backup\pre-rice-" + (Get-Date -Format 'yyyyMMdd-HHmmss'))
            New-Item -ItemType Directory -Force $dir | Out-Null
            $keys = [ordered]@{
                'accent'            = 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Accent'
                'colors'            = 'HKCU\Control Panel\Colors'
                'cursors'           = 'HKCU\Control Panel\Cursors'
                'desktop'           = 'HKCU\Control Panel\Desktop'
                'dwm'               = 'HKCU\Software\Microsoft\Windows\DWM'
                'explorer-advanced' = 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
                'personalize'       = 'HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
                'sounds'            = 'HKCU\AppEvents\Schemes'
                'stuckrects3'       = 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3'
                'themes'            = 'HKCU\Software\Microsoft\Windows\CurrentVersion\Themes'
                'content-delivery'  = 'HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
            }
            $ErrorActionPreference = 'Continue'
            foreach ($k in $keys.Keys) { & reg.exe export $keys[$k] (Join-Path $dir "$k.reg") /y 2>&1 | Out-Null }
            $ErrorActionPreference = 'Stop'
            if (Test-Path $WtSettings) { Copy-Item $WtSettings (Join-Path $dir 'wt-settings.json') }
            $docs = [Environment]::GetFolderPath('MyDocuments')
            foreach ($pp in @("$docs\WindowsPowerShell\Microsoft.PowerShell_profile.ps1", "$docs\PowerShell\Microsoft.PowerShell_profile.ps1")) {
                if (Test-Path $pp) { Copy-Item $pp (Join-Path $dir ((Split-Path (Split-Path $pp) -Leaf) + '-profile.ps1')) }
            }
            Write-Info "registry + config backup -> $dir"
            $notes += 'backup written'
        }

        $rpLog = Join-Path $Root 'backup\restore-point.log'
        if ((Test-Path $rpLog) -and ((Get-Content $rpLog -Raw) -match '(?m)^OK') -and -not $Force) {
            Write-Info 'restore point already created (backup\restore-point.log)'
        } else {
            $cmd = "try { Checkpoint-Computer -Description 'Pre Ahri rice' -RestorePointType MODIFY_SETTINGS -ErrorAction Stop; 'OK' } " +
                   "catch { 'ERROR: ' + `$_.Exception.Message }; Get-ComputerRestorePoint | Select-Object -Last 1 | Format-Table -AutoSize | Out-String -Width 200"
            $wrapped = "& { $cmd } *> '$rpLog'"
            $enc = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($wrapped))
            Write-Info 'creating restore point (UAC prompt; Windows allows one per 24h)'
            Start-Process $PS51 -Verb RunAs -Wait -WindowStyle Hidden -ArgumentList '-NoProfile', '-EncodedCommand', $enc
            $out = if (Test-Path $rpLog) { (Get-Content $rpLog -Raw).Trim() } else { 'no log written' }
            Write-Info $out
            if ($out -match '(?m)^OK') { $notes += 'restore point created' }
            else { $notes += 'restore point NOT created (System Protection off? see backup\restore-point.log)' }
        }
        $script:Note = $notes -join '; '
    }

Add-Step 'packages' 'winget installs of the core tools (Windhawk, Zebar, Flow, pwsh, starship, fastfetch, CLI tools, Spicetify, Spotify)' `
    -Check { if (-not (Test-Cmd winget)) { 'winget not found (install "App Installer" from the Microsoft Store)' } } `
    -Plan  { Get-PackagePlan $CorePackages; 'Nilesoft.Shell                 (installed by the nilesoft step: needs --scope machine, elevated)' } `
    -Run   { Install-Packages $CorePackages }

Add-Step 'apps' 'winget installs of the themed apps (Zen, Discord, Steam, PowerToys, VS Code, Cursor, Neovim, Notepad++, Telegram, OBS)' -Optional `
    -Check { if (-not (Test-Cmd winget)) { 'winget not found' } } `
    -Plan  { Get-PackagePlan $AppPackages } `
    -Run   { Install-Packages $AppPackages; $script:Note += ' - launch each app once, then: .\install.ps1 -Only deploy' }

Add-Step 'fonts' 'Maple Mono NF v7.9 + Shippori Mincho, per-user (no admin)' `
    -Check {
        $names = @((Get-ItemProperty 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts' -ErrorAction SilentlyContinue).PSObject.Properties.Name)
        $maple = @($names | Where-Object { $_ -match '^MapleMono-NF' }).Count
        $mincho = @($names | Where-Object { $_ -match '^ShipporiMincho' }).Count
        if ($maple -and $mincho -and -not $Force) { "already installed ($maple Maple Mono + $mincho Shippori faces; -Force to reinstall)" }
    } `
    -Plan  { 'install\fonts.ps1' } `
    -Run   { Invoke-InstallScript 'fonts.ps1' }

Add-Step 'render' 'Render templates\ -> generated\ from palette.json' `
    -Check { Get-NeedPy } `
    -Plan  { 'py -3 render.py' } `
    -Run   { $script:Rendered = $false; Invoke-Render }

Add-Step 'deploy' 'Copy generated\ to app config dirs (deploy.d\*.json; apps that are not present are skipped)' `
    -Check { Get-NeedPy } `
    -Plan  { 'py -3 render.py --deploy' } `
    -Run   { Invoke-Py @($RenderPy, '--deploy'); $script:Rendered = $true }

Add-Step 'accent' 'Dark mode, transparency, sakura accent + AccentPalette (title bars stay dark)' `
    -Plan  { 'install\accent.ps1' } `
    -Run   { Invoke-InstallScript 'accent.ps1' }

Add-Step 'terminal' 'Windows Terminal scheme/theme/profiles, PowerShell profile, starship, cava, fastfetch sixel logo' `
    -Check {
        $p = Get-NeedPy; if ($p) { return $p }
        if (-not (Test-Path $WtSettings)) { 'Windows Terminal settings.json not found - open Windows Terminal once, then: .\install.ps1 -Only terminal' }
    } `
    -Plan  { 'py -3 render.py --deploy terminal', 'py -3 install\wt.py', 'install\fastfetch-art.ps1  (fetches Riot art; Pillow venv in %LOCALAPPDATA%\ahri-rice\venv)' } `
    -Run   {
        Invoke-Py @($RenderPy, '--deploy', 'terminal'); $script:Rendered = $true
        Invoke-Py @((Join-Path $Inst 'wt.py'))
        Invoke-InstallScript 'fastfetch-art.ps1'
    }

Add-Step 'cursors' 'Apply the Ahri Blossom cursor scheme (committed assets, per-user)' `
    -Check { if (-not (Test-Path (Join-Path $Root 'assets\cursors\ahri-blossom\pointer.cur'))) { 'assets\cursors\ahri-blossom missing - build with install\cursors.py' } } `
    -Plan  { 'install\apply-cursors.ps1' } `
    -Run   { Invoke-InstallScript 'apply-cursors.ps1' }

Add-Step 'flow' 'Flow Launcher theme + settings (Alt+Space, Segoe UI Variable); restarts Flow' `
    -Check { $p = Get-NeedPy; if ($p) { return $p }; if (-not (Test-Path $FlowExe)) { "Flow Launcher not installed ($FlowExe)" } } `
    -Plan  { 'py -3 render.py (once)', 'install\flow.ps1' } `
    -Run   { Invoke-Render; Invoke-InstallScript 'flow.ps1' }

Add-Step 'nilesoft' 'Nilesoft Shell context menu: installs it (machine scope) if missing + theme; self-elevates (UAC)' `
    -Check { Get-NeedPy } `
    -Plan  { 'py -3 render.py (once)', 'install\nilesoft.ps1  (elevated; winget install Nilesoft.Shell --scope machine if missing)' } `
    -Run   { Invoke-Render; Invoke-InstallScript 'nilesoft.ps1' }

Add-Step 'zebar' 'Zebar top bar pack, startup shortcut; restarts Zebar' `
    -Check { $p = Get-NeedPy; if ($p) { return $p }; if (-not (Test-Path $ZebarExe)) { "Zebar not installed ($ZebarExe)" } } `
    -Plan  { 'py -3 render.py (once)', 'install\zebar.ps1' } `
    -Run   { Invoke-Render; Invoke-InstallScript 'zebar.ps1' }

Add-Step 'windhawk' 'Write settings for installed Windhawk mods (HKLM, UAC); lists mods still to install in the Windhawk UI' `
    -Check {
        $p = Get-NeedPy; if ($p) { return $p }
        if (-not (Test-Path $WindhawkExe)) { return "Windhawk not installed ($WindhawkExe)" }
        $m = Get-WindhawkMods
        if (-not $m.Installed.Count) { "no rice mods installed yet - install in Windhawk UI: $($m.Missing -join ', ')" }
    } `
    -Plan  {
        $m = Get-WindhawkMods
        'py -3 render.py (once)', 'py -3 install\windhawk.py generated\windhawk  (reg import, elevated)'
        "installed: $(if ($m.Installed.Count) { $m.Installed -join ', ' } else { '-' })"
        "missing:   $(if ($m.Missing.Count) { $m.Missing -join ', ' } else { '-' })"
    } `
    -Run   {
        Invoke-Render
        Invoke-Py @((Join-Path $Inst 'windhawk.py'), (Join-Path $Gen 'windhawk'))
        $m = Get-WindhawkMods
        if ($m.Missing.Count) {
            Write-Host '   Install these in Windhawk (Explore tab), then re-run: .\install.ps1 -Only windhawk' -ForegroundColor Yellow
            foreach ($id in $m.Missing) { Write-Host "     https://windhawk.net/mods/$id" -ForegroundColor Yellow }
            $script:Note = "missing mods: $($m.Missing -join ', ')"
        }
    }

Add-Step 'taskbar' 'Taskbar always visible (dock reserves its strip), hide Task View/Search buttons; restarts Explorer' `
    -Plan  { 'install\taskbar.ps1   (use install\taskbar.ps1 -AutoHide for intellihide instead)' } `
    -Run   { Invoke-InstallScript 'taskbar.ps1' }

Add-Step 'powertoys' 'Disable PowerToys Run / Command Palette so Alt+Space goes to Flow' `
    -Check { $p = Get-NeedPy; if ($p) { return $p }; if (-not (Test-Path $PowerToysCfg)) { 'PowerToys not installed/configured - nothing to free' } } `
    -Plan  { 'install\powertoys.ps1' } `
    -Run   { Invoke-InstallScript 'powertoys.ps1' }

Add-Step 'wallpaper' 'Wallpaper Engine: workshop 2184359275 on monitor 0, 60 fps cap, overridelockscreen' `
    -Check {
        $p = Get-NeedPy; if ($p) { return $p }
        if (-not (Test-Path $WeExe)) { return 'Wallpaper Engine not installed (Steam)' }
        if (-not (Test-Path $WeProject)) { 'workshop item 2184359275 not downloaded - subscribe to "Ahri: Spirit Blossom in 4K" in Wallpaper Engine' }
    } `
    -Plan  { 'install\wallpaper.ps1' } `
    -Run   { Invoke-InstallScript 'wallpaper.ps1' }

Add-Step 'lockscreen' 'Lock/sign-in screen = Spirit Blossom splash (fetched from CommunityDragon, not committed)' `
    -Plan  { 'install\lockscreen.ps1   (Windows PowerShell 5.1, WinRT)' } `
    -Run   { Invoke-InstallScript 'lockscreen.ps1' }

Add-Step 'vscode-theme' 'Build the theme .vsix locally and install it into VS Code and Cursor' `
    -Check { $p = Get-NeedPy; if ($p) { return $p }; if (-not ((Test-Cmd code) -or (Test-Cmd cursor))) { 'neither VS Code nor Cursor on PATH' } } `
    -Plan  { 'py -3 render.py (once)', 'install\vscode-theme.ps1' } `
    -Run   {
        Invoke-Render
        Invoke-InstallScript 'vscode-theme.ps1'
        $unset = @()
        foreach ($app in 'Code', 'Cursor') {
            $f = "$env:APPDATA\$app\User\settings.json"
            if ((Test-Path $f) -and -not (Select-String -Path $f -Pattern '"workbench.colorTheme"\s*:\s*"Ahri Spirit Blossom"' -Quiet)) { $unset += $app }
        }
        if ($unset.Count) { $script:Note = "select 'Ahri Spirit Blossom' in: $($unset -join ', ')" }
    }

Add-Step 'jetbrains' 'Copy AhriBlossom.icls into every %APPDATA%\JetBrains\<IDE><version>\colors' `
    -Check { $p = Get-NeedPy; if ($p) { return $p }; if (-not (Get-JetBrainsConfigDirs).Count) { 'no JetBrains IDE config dirs found' } } `
    -Plan  { 'py -3 render.py (once)'; Get-JetBrainsConfigDirs | ForEach-Object { "copy AhriBlossom.icls -> $($_.FullName)\colors" } } `
    -Run   {
        Invoke-Render
        $src = Join-Path $Gen 'editors\jetbrains\AhriBlossom.icls'
        $done = @()
        foreach ($d in Get-JetBrainsConfigDirs) {
            New-Item -ItemType Directory -Force (Join-Path $d.FullName 'colors') | Out-Null
            Copy-Item $src (Join-Path $d.FullName 'colors\AhriBlossom.icls') -Force
            Write-Info "copy  AhriBlossom.icls -> $($d.FullName)\colors"
            $done += $d.Name
        }
        $script:Note = "$($done -join ', ') - pick the scheme in Settings > Editor > Color Scheme"
    }

Add-Step 'zen' 'Zen userChrome/userContent into the default profile (resolved from profiles.ini, not hardcoded)' `
    -Check { $p = Get-NeedPy; if ($p) { return $p }; if (-not (Get-ZenProfileDir)) { 'no Zen profile yet - start Zen once' } } `
    -Plan  { 'py -3 render.py (once)'; "copy generated\apps\zen\chrome -> $(Get-ZenProfileDir)\chrome"; 'add legacyUserProfileCustomizations pref to user.js (append, keeps existing prefs)' } `
    -Run   {
        Invoke-Render
        $prof = Get-ZenProfileDir
        Copy-Item (Join-Path $Gen 'apps\zen\chrome') $prof -Recurse -Force
        Write-Info "copy  chrome\ -> $prof\chrome"
        $userJs = Join-Path $prof 'user.js'
        $existing = if (Test-Path $userJs) { Get-Content $userJs -Raw } else { '' }
        foreach ($line in Get-Content (Join-Path $Gen 'apps\zen\user.js')) {
            if ($line.Trim() -and -not $existing.Contains($line.Trim())) {
                Add-Content -Path $userJs -Value $line -Encoding UTF8
                Write-Info "user.js += $line"
            }
        }
        $script:Note = 'restart Zen to load userChrome'
    }

Add-Step 'spicetify' 'Spicetify: AhriBlossom/Blossom theme, backup + apply, block Spotify self-updates (deny ACL)' `
    -Check {
        $p = Get-NeedPy; if ($p) { return $p }
        if ($IsAdmin) { return 'spicetify refuses to run elevated - re-run from a normal shell' }
        if (-not (Test-Cmd spicetify)) { return 'spicetify not installed' }
        if (-not (Test-Path $SpotifyExe)) { return "desktop Spotify not installed ($SpotifyExe)" }
        if (-not (Test-Path "$env:APPDATA\Spotify\prefs")) { 'Spotify never started - launch it and log in once' }
    } `
    -Plan  {
        'spicetify config   (creates %APPDATA%\spicetify on first run)'
        'py -3 render.py --deploy spotify'
        'spicetify config current_theme AhriBlossom color_scheme Blossom inject_css 1 replace_colors 1 overwrite_assets 1 inject_theme_js 1'
        if (Test-SpicetifyBackedUp) { 'spicetify apply' } else { 'spicetify backup apply' }
        'icacls %LOCALAPPDATA%\Spotify\Update /deny <user>:(OI)(CI)(W,D,DC)   (if not already denied)'
    } `
    -Run   {
        if (-not (Test-Path "$env:APPDATA\spicetify\config-xpui.ini")) { Invoke-Native 'spicetify' @('config') | Out-Null }
        Invoke-Py @($RenderPy, '--deploy', 'spotify'); $script:Rendered = $true
        Invoke-Native 'spicetify' @('config', 'current_theme', 'AhriBlossom', 'color_scheme', 'Blossom', 'inject_css', '1',
                                    'replace_colors', '1', 'overwrite_assets', '1', 'inject_theme_js', '1')
        if (Test-SpicetifyBackedUp) { Invoke-Native 'spicetify' @('apply') } else { Invoke-Native 'spicetify' @('backup', 'apply') }

        # Spotify updates replace the patched xpui.spa; deny the user write access to the updater's staging dir.
        $upd = "$env:LOCALAPPDATA\Spotify\Update"
        $me  = "$env:USERDOMAIN\$env:USERNAME"
        New-Item -ItemType Directory -Force $upd | Out-Null
        $denied = @((Get-Acl $upd).Access | Where-Object { $_.AccessControlType -eq 'Deny' -and $_.IdentityReference.Value -eq $me })
        if ($denied.Count) { Write-Info 'Spotify updates already blocked' }
        else { Invoke-Native 'icacls.exe' @($upd, '/deny', "${me}:(OI)(CI)(W,D,DC)"); $script:Note = 'Spotify updates blocked' }
    }

Add-Step 'vencord' 'Patch Discord with Vencord (official CLI installer) if needed, deploy + enable the theme' `
    -Check {
        $p = Get-NeedPy; if ($p) { return $p }
        if (-not (Test-Path "$DiscordDir\Update.exe")) { 'Discord not installed' }
    } `
    -Plan  {
        if (Test-VencordPatched) { 'Discord already patched with Vencord' }
        else { "download $VencordCli -> %TEMP%\ahri-rice", 'close Discord; VencordInstallerCli.exe -install -branch stable' }
        'py -3 render.py --deploy discord'
        "add $VencordTheme to %APPDATA%\Vencord\settings\settings.json enabledThemes (closes Discord if it needs the edit)"
    } `
    -Run   {
        $notes = @()
        $wasRunning = [bool](Get-Process Discord -ErrorAction SilentlyContinue)
        $closed = $false
        if (-not (Test-VencordPatched)) {
            $cli = Join-Path $env:TEMP 'ahri-rice\VencordInstallerCli.exe'
            New-Item -ItemType Directory -Force (Split-Path $cli) | Out-Null
            Write-Info "download $VencordCli"
            Invoke-WebRequest $VencordCli -OutFile $cli -UseBasicParsing
            Get-Process Discord -ErrorAction SilentlyContinue | Stop-Process -Force; $closed = $true
            Start-Sleep 2
            Invoke-Native $cli @('-install', '-branch', 'stable')
            $notes += 'Vencord installed'
        }
        Invoke-Py @($RenderPy, '--deploy', 'discord'); $script:Rendered = $true

        $settings = "$env:APPDATA\Vencord\settings\settings.json"
        $enabled = $false
        if (Test-Path $settings) {
            $cfg = Get-Content $settings -Raw | ConvertFrom-Json
            $enabled = @($cfg.enabledThemes) -contains $VencordTheme
        }
        if ($enabled) {
            Write-Info 'theme already enabled'
        } else {
            # Vencord keeps settings in memory and rewrites the file, so edit it while Discord is closed
            if (Get-Process Discord -ErrorAction SilentlyContinue) { Get-Process Discord | Stop-Process -Force; $closed = $true; Start-Sleep 2 }
            $code = @'
import json, os, sys
p, name = sys.argv[1], sys.argv[2]
s = json.load(open(p, encoding="utf-8-sig")) if os.path.exists(p) else {}
t = s.setdefault("enabledThemes", [])
if name not in t:
    t.append(name)
os.makedirs(os.path.dirname(p), exist_ok=True)
json.dump(s, open(p, "w", encoding="utf-8"), indent=4)
print("enabledThemes:", t)
'@
            $code | & py -3 -I - $settings $VencordTheme
            if ($LASTEXITCODE) { throw 'enabling the Vencord theme failed' }
            $notes += 'theme enabled'
        }
        if ($closed -and $wasRunning) { Start-Process "$DiscordDir\Update.exe" -ArgumentList '--processStart', 'Discord.exe'; $notes += 'Discord restarted' }
        $script:Note = $notes -join '; '
    }

Add-Step 'zen-addons' 'Open the AMO page of every add-on in install\zen-extensions.txt as Zen tabs' -Optional `
    -Check { if (-not (Test-Path $ZenExe)) { "Zen not installed ($ZenExe)" } } `
    -Plan  { 'install\zen-addons.ps1   (click "Add to Firefox" on each tab)' } `
    -Run   { Invoke-InstallScript 'zen-addons.ps1' }

# ---------------------------------------------------------------------------------------------
# selection
# ---------------------------------------------------------------------------------------------
$names = @($Steps | ForEach-Object { $_.Name })
# `powershell -File install.ps1 -Only a,b` passes "a,b" as one string; split it
$Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$Skip = @($Skip | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$unknown = @(($Only + $Skip) | Where-Object { $names -notcontains $_ })
if ($unknown.Count) {
    Write-Host "unknown step(s): $($unknown -join ', ')" -ForegroundColor Red
    Write-Host "valid: $($names -join ', ')"
    exit 2
}

if ($List) {
    Write-Host ''
    Write-Host 'Steps (run in this order; * = optional, only with -All or -Only):'
    Write-Host ''
    foreach ($s in $Steps) {
        $mark = if ($s.Optional) { '*' } else { ' ' }
        Write-Host ('  {0} {1,-13} {2}' -f $mark, $s.Name, $s.Desc)
    }
    Write-Host ''
    return
}

$selected = @($Steps | Where-Object {
    if ($Only.Count) { $Only -contains $_.Name } else { (-not $_.Optional) -or $All }
} | Where-Object { $Skip -notcontains $_.Name })

if (-not $selected.Count) { Write-Host 'nothing selected'; return }

# ---------------------------------------------------------------------------------------------
# run
# ---------------------------------------------------------------------------------------------
Write-Host ''
Write-Host "Ahri Spirit Blossom rice  -  $Root" -ForegroundColor Magenta
Write-Host ("{0} step(s): {1}" -f $selected.Count, (($selected | ForEach-Object { $_.Name }) -join ', '))
if ($DryRun) { Write-Host 'DRY RUN: prerequisites are checked against the machine as it is now; nothing is changed.' -ForegroundColor Yellow }
elseif ($IsAdmin) { Write-Warning 'Running elevated. Spotify and spicetify will be skipped; per-user steps are best run from a normal shell (admin steps prompt for UAC on their own).' }

Update-SessionPath
$script:Rendered = $false
$results = New-Object System.Collections.Generic.List[object]
$i = 0
foreach ($s in $selected) {
    $i++
    Write-Section ("[{0}/{1}] {2}" -f $i, $selected.Count, $s.Name)
    Write-Info $s.Desc

    $reason = ''
    if ($s.Check) {
        try { $reason = (@(& $s.Check) | Where-Object { $_ }) -join '; ' }
        catch { $reason = "prerequisite check failed: $($_.Exception.Message)" }
    }

    if ($DryRun) {
        if ($reason) {
            Write-Host "   would skip: $reason" -ForegroundColor Yellow
            $results.Add([pscustomobject]@{ Step = $s.Name; Result = 'would skip'; Note = $reason })
        } else {
            Write-Host '   would run:'
            foreach ($line in @(& $s.Plan)) { Write-Host "     $line" }
            $results.Add([pscustomobject]@{ Step = $s.Name; Result = 'would run'; Note = '' })
        }
        continue
    }

    if ($reason) {
        Write-Host "   skipped: $reason" -ForegroundColor Yellow
        $results.Add([pscustomobject]@{ Step = $s.Name; Result = 'skipped'; Note = $reason })
        continue
    }

    $script:Note = ''
    try {
        & $s.Run | Out-Host
        Write-Host '   ok' -ForegroundColor Green
        $results.Add([pscustomobject]@{ Step = $s.Name; Result = 'ok'; Note = $script:Note })
    } catch {
        $msg = $_.Exception.Message
        Write-Host "   FAILED: $msg" -ForegroundColor Red
        $results.Add([pscustomobject]@{ Step = $s.Name; Result = 'failed'; Note = $msg })
    }
    Update-SessionPath
}

Write-Section 'summary'
$results | Format-Table -AutoSize -Wrap | Out-Host

if (-not $DryRun) {
    Write-Host 'Manual bits (see README "Manual steps"):' -ForegroundColor Magenta
    Write-Host '  - Windhawk: install missing mods in its UI, then .\install.ps1 -Only windhawk'
    Write-Host '  - Wallpaper Engine: subscribe to workshop 2184359275, then .\install.ps1 -Only wallpaper'
    Write-Host '  - Spotify: log in once (then .\install.ps1 -Only spicetify)'
    Write-Host '  - Telegram: open generated\apps\telegram\ahri-blossom.tdesktop-theme with Telegram'
    Write-Host '  - JetBrains / Notepad++ / OBS: pick the AhriBlossom scheme/theme in the app'
    Write-Host '  - Zen: import data, add-ons via .\install.ps1 -Only zen-addons'
    Write-Host ''
}

$failedCount = @($results | Where-Object { $_.Result -eq 'failed' }).Count
if ($failedCount) { exit 1 }
