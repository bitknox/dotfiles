# Turns on Windows' native taskbar auto-hide (required by the Windhawk
# "taskbar-auto-hide-keyboard-only" mod, which then keeps it hidden unless summoned by keyboard).
#   -Off  restores the always-visible taskbar.
param([switch]$Off)
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
