# Spawned by main.js via zebar.shellSpawn (powershell -File; allowed by the regex in zpack.json).
# 1. Re-broadcasts TaskbarCreated once Zebar's tray spy is up, so apps register their icons with it.
# 2. Keeps the top 52px of the primary monitor reserved: on this machine Explorer ignores
#    SHAppBarMessage (Zebar's dockToEdge), so the work area is set directly and re-applied if reset.
# 3. Exits (and releases the reservation) when the parent zebar.exe is gone.
Add-Type -Name A -Namespace W -MemberDefinition '[DllImport("user32.dll")] public static extern bool SystemParametersInfo(int a, int b, int[] r, int f); [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern uint RegisterWindowMessage(string s); [DllImport("user32.dll")] public static extern bool SendNotifyMessage(IntPtr h, uint m, IntPtr w, IntPtr l);'
$top = 52
$zebar = (Get-CimInstance Win32_Process -Filter "ProcessId=$PID").ParentProcessId
function Get-Work { $r = New-Object int[] 4; [void][W.A]::SystemParametersInfo(0x30, 0, $r, 0); $r }
Start-Sleep -Milliseconds 2500
[void][W.A]::SendNotifyMessage([IntPtr]0xffff, [W.A]::RegisterWindowMessage('TaskbarCreated'), [IntPtr]::Zero, [IntPtr]::Zero)
while (Get-Process -Id $zebar -ErrorAction SilentlyContinue) {
  $r = Get-Work
  if ($r[1] -lt $top) { $r[1] = $top; [void][W.A]::SystemParametersInfo(0x2F, 0, $r, 2) }
  Start-Sleep -Seconds 3
}
$r = Get-Work
if ($r[1] -eq $top) { $r[1] = 0; [void][W.A]::SystemParametersInfo(0x2F, 0, $r, 2) }
