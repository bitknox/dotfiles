# Installs (if needed) and themes Nilesoft Shell. Self-elevates; the elevated run is logged to
# %TEMP%\nilesoft-install.log and echoed back here.
#   py -3 render.py           (or --out <dir> --only nilesoft, then pass -Source <dir>\nilesoft)
#   powershell -File install\nilesoft.ps1 [-Source <rendered nilesoft dir>] [-RestartExplorer]
#
# Why elevation matters: the Nilesoft MSI is per-machine. Run unelevated + silent (plain
# `winget install Nilesoft.Shell`) it fails with MSI error 1925 "insufficient privileges", which winget
# reports as exit code 1603. Installing from an elevated process works.
#
# Nilesoft re-reads shell.nss/imports when you hold CTRL while right-clicking, so no Explorer restart
# is needed for theme changes. -RestartExplorer runs `shell.exe -restart` anyway.
# Escape hatch: CTRL+WIN + right-click shows the native menu.
param(
    [string]$Source = "$PSScriptRoot\..\generated\nilesoft",
    [switch]$RestartExplorer,
    [string]$Log = "$env:TEMP\nilesoft-install.log"
)
$ErrorActionPreference = 'Stop'
$Source = (Resolve-Path $Source).Path

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"", '-Source', "`"$Source`"", '-Log', "`"$Log`"")
    if ($RestartExplorer) { $argList += '-RestartExplorer' }
    Remove-Item $Log -ErrorAction SilentlyContinue
    $p = Start-Process powershell.exe -ArgumentList $argList -Verb RunAs -Wait -PassThru
    if (Test-Path $Log) { Get-Content $Log }
    exit $p.ExitCode
}

Start-Transcript -Path $Log -Force | Out-Null
try {
    $dir = 'C:\Program Files\Nilesoft Shell'
    $exe = Join-Path $dir 'shell.exe'

    if (-not (Test-Path $exe)) {
        Write-Host 'Nilesoft Shell not installed - installing elevated via winget (machine scope)'
        winget install --id Nilesoft.Shell -e --scope machine --silent --accept-package-agreements --accept-source-agreements
        if (-not (Test-Path $exe)) { throw "install failed (winget exit $LASTEXITCODE)" }
        # the MSI's OnInstall action already runs `shell.exe -register -restart`
    }

    Get-ChildItem $Source -Recurse -File | ForEach-Object {
        $rel = $_.FullName.Substring($Source.Length).TrimStart('\')
        $dst = Join-Path $dir $rel
        New-Item -ItemType Directory -Force (Split-Path $dst) | Out-Null
        if ((Test-Path $dst) -and -not (Test-Path "$dst.orig")) { Copy-Item $dst "$dst.orig" }   # keep stock file once
        Copy-Item $_.FullName $dst -Force
        Write-Host "copy  $rel -> $dst"
    }

    if ($RestartExplorer) { & $exe -restart -silent; Write-Host 'explorer restarted' }
    else { Write-Host 'done - hold CTRL while right-clicking once to reload the config' }
} catch {
    Write-Host "ERROR: $_"
    $global:LASTEXITCODE = 1
} finally {
    Stop-Transcript | Out-Null
}
exit $LASTEXITCODE
