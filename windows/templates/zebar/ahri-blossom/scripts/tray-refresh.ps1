# Run by bar.html on right-click of the tray chevron (powershell -File): asks apps to re-add tray icons.
Add-Type -Name N -Namespace W -MemberDefinition '[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern uint RegisterWindowMessage(string s); [DllImport("user32.dll")] public static extern bool SendNotifyMessage(IntPtr h, uint m, IntPtr w, IntPtr l);'
[void][W.N]::SendNotifyMessage([IntPtr]0xffff, [W.N]::RegisterWindowMessage('TaskbarCreated'), [IntPtr]::Zero, [IntPtr]::Zero)
