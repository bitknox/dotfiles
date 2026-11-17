# Taskbar = the Ahri dock (Windhawk Taskbar Styler "DockLike"). Default: always visible, so it
# reserves its strip and maximized windows stop above it.
#   -AutoHide  turns Windows' auto-hide on instead (needed if you want the
#              "taskbar-auto-hide-when-maximized" mod's intellihide behaviour).
param([switch]$AutoHide)
$Off = -not $AutoHide
$k = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3'
$v = (Get-ItemProperty $k).Settings
$v[8] = if ($Off) { 0x02 } else { 0x03 }
Set-ItemProperty $k Settings $v
# Hide clutter buttons (they only show when the taskbar is summoned anyway)
$adv = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
Set-ItemProperty $adv ShowTaskViewButton 0 -Type DWord
Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search' SearchboxTaskbarMode 0 -Type DWord -ErrorAction SilentlyContinue
Stop-Process -Name explorer -Force   # explorer auto-restarts
"taskbar auto-hide: $(if ($Off) { 'off' } else { 'on' })"
