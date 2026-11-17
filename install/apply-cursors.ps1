# Installs the "Ahri Blossom" cursor scheme per-user (no admin) and applies it immediately.
# Build first with: install/cursors.py  (output: assets/cursors/ahri-blossom)
# Revert: Settings > Bluetooth & devices > Mouse > Additional mouse settings > Pointers > Scheme "Windows Default",
#         or import backup\cursors-before.reg and re-run SPI_SETCURSORS.
$ErrorActionPreference = 'Stop'
$scheme = 'Ahri Blossom'
$src = Join-Path $PSScriptRoot '..\assets\cursors\ahri-blossom'
$dst = Join-Path $env:LOCALAPPDATA 'Cursors\AhriBlossom'

# Registry value -> file, in the standard Schemes order
$map = [ordered]@{
  Arrow = 'pointer.cur'; Help = 'help.cur'; AppStarting = 'working.ani'; Wait = 'busy.ani'
  Crosshair = 'precision.cur'; IBeam = 'text.cur'; NWPen = 'handwriting.cur'; No = 'unavailable.cur'
  SizeNS = 'vert.cur'; SizeWE = 'horz.cur'; SizeNWSE = 'dgn1.cur'; SizeNESW = 'dgn2.cur'
  SizeAll = 'move.cur'; UpArrow = 'alternate.cur'; Hand = 'link.cur'; Pin = 'pin.cur'; Person = 'person.cur'
}

foreach ($f in $map.Values) { if (-not (Test-Path (Join-Path $src $f))) { throw "missing $f in $src - run install/cursors.py first" } }

# one-time backup of the current cursor settings
$backup = Join-Path $PSScriptRoot '..\backup'
$bfile = Join-Path $backup 'cursors-before.reg'
if (-not (Test-Path $bfile)) {
  New-Item -ItemType Directory -Force $backup | Out-Null
  & reg.exe export 'HKCU\Control Panel\Cursors' $bfile /y | Out-Null
}

New-Item -ItemType Directory -Force $dst | Out-Null
foreach ($f in $map.Values) { Copy-Item (Join-Path $src $f) (Join-Path $dst $f) -Force }

$key = 'HKCU:\Control Panel\Cursors'
foreach ($name in $map.Keys) {
  New-ItemProperty -Path $key -Name $name -Value (Join-Path $dst $map[$name]) -PropertyType ExpandString -Force | Out-Null
}
Set-ItemProperty -Path $key -Name '(default)' -Value $scheme
New-ItemProperty -Path $key -Name 'Scheme Source' -Value 1 -PropertyType DWord -Force | Out-Null  # 1 = user scheme

$schemes = "$key\Schemes"
if (-not (Test-Path $schemes)) { New-Item -Path $schemes -Force | Out-Null }
$list = ($map.Values | ForEach-Object { Join-Path $dst $_ }) -join ','
New-ItemProperty -Path $schemes -Name $scheme -Value $list -PropertyType ExpandString -Force | Out-Null

# Reload cursors from the registry: SPI_SETCURSORS (0x57), SPIF_UPDATEINIFILE|SPIF_SENDCHANGE (0x03)
if (-not ('Rice.Cursors' -as [type])) {
  Add-Type -Namespace Rice -Name Cursors -MemberDefinition @'
[DllImport("user32.dll", SetLastError=true)] public static extern bool SystemParametersInfo(uint a, uint b, IntPtr c, uint d);
[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr LoadCursorFromFile(string f);
[DllImport("user32.dll")] public static extern bool SetSystemCursor(IntPtr h, uint id);
'@
}
# SPIF_UPDATEINIFILE can return FALSE from restricted/sandboxed processes; the values are already written
# above, so fall back to SPIF_SENDCHANGE only (reloads + broadcasts WM_SETTINGCHANGE).
if (-not [Rice.Cursors]::SystemParametersInfo(0x57, 0, [IntPtr]::Zero, 0x03)) {
  if (-not [Rice.Cursors]::SystemParametersInfo(0x57, 0, [IntPtr]::Zero, 0x02)) { throw "SystemParametersInfo(SPI_SETCURSORS) failed" }
}
# SPI_SETCURSORS (25H2) does not reload the Pin cursor from the registry; push Pin/Person live directly.
# (Registry values above still cover the next logon.)
foreach ($p in @(@('Pin', 32671), @('Person', 32672))) {
  $h = [Rice.Cursors]::LoadCursorFromFile((Join-Path $dst $map[$p[0]]))
  if ($h -ne [IntPtr]::Zero) { [void][Rice.Cursors]::SetSystemCursor($h, $p[1]) }
}

# Verify the values stuck (some 2026 cumulative updates have been seen resetting custom cursors)
Start-Sleep -Milliseconds 500
$now = Get-ItemProperty $key
$bad = @($map.Keys | Where-Object { $now.$_ -ne (Join-Path $dst $map[$_]) })
if ($now.'(default)' -ne $scheme) { $bad += '(default)' }
if ($bad.Count) { Write-Warning "cursor values reverted: $($bad -join ', ')" } else { Write-Host "Ahri Blossom cursors applied ($($map.Count) roles) from $dst" }
