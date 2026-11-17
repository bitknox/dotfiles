# Sets Windows dark mode + accent color (and its 8-shade AccentPalette) from palette.json.
# Title bars stay dark (ColorPrevalence=0); window borders are colored by Windhawk's window-border-customizer.
$ErrorActionPreference = 'Stop'
$pal = Get-Content "$PSScriptRoot\..\palette.json" -Raw | ConvertFrom-Json
$accentHex = $pal.colors.($pal.roles.accent)

function ConvertTo-Rgb($hex) { $h = $hex.TrimStart('#'); ,@([Convert]::ToByte($h.Substring(0,2),16), [Convert]::ToByte($h.Substring(2,2),16), [Convert]::ToByte($h.Substring(4,2),16)) }
function Get-Mix($rgb, $target, $t) { ,@($rgb | ForEach-Object -Begin { $i = 0 } -Process { [byte][Math]::Round($_ + ($target[$i++] - $_) * $t) }) }
function Get-Abgr($rgb) { [int64](0xFF000000 -bor ($rgb[2] -shl 16) -bor ($rgb[1] -shl 8) -bor $rgb[0]) }

$acc = ConvertTo-Rgb $accentHex
$white = @(255,255,255); $black = @(0,0,0)
# AccentPalette: light3, light2, light1, accent, dark1, dark2, dark3, (unused)
$shades = @(
  (Get-Mix $acc $white 0.60), (Get-Mix $acc $white 0.40), (Get-Mix $acc $white 0.20), $acc,
  (Get-Mix $acc $black 0.25), (Get-Mix $acc $black 0.45), (Get-Mix $acc $black 0.65), (Get-Mix $acc $black 0.80)
)
$bytes = [byte[]]($shades | ForEach-Object { $_[0], $_[1], $_[2], 0 })

$p = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
Set-ItemProperty $p AppsUseLightTheme 0 -Type DWord
Set-ItemProperty $p SystemUsesLightTheme 0 -Type DWord
Set-ItemProperty $p EnableTransparency 1 -Type DWord
Set-ItemProperty $p ColorPrevalence 0 -Type DWord          # no accent on Start/taskbar surfaces

$a = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Accent'
Set-ItemProperty $a AccentPalette $bytes -Type Binary
Set-ItemProperty $a AccentColorMenu (Get-Abgr $acc) -Type DWord
Set-ItemProperty $a StartColorMenu (Get-Abgr $shades[5]) -Type DWord

$d = 'HKCU:\Software\Microsoft\Windows\DWM'
$argb = [int64](0xC4000000 -bor ($acc[0] -shl 16) -bor ($acc[1] -shl 8) -bor $acc[2])
Set-ItemProperty $d AccentColor (Get-Abgr $acc) -Type DWord
Set-ItemProperty $d ColorizationColor $argb -Type DWord
Set-ItemProperty $d ColorizationAfterglow $argb -Type DWord
Set-ItemProperty $d ColorPrevalence 0 -Type DWord           # title bars stay dark
Set-ItemProperty $d EnableWindowColorization 0 -Type DWord

# Tell running apps the immersive color set changed
Add-Type -Namespace Rice -Name Native -MemberDefinition '[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr SendMessageTimeout(IntPtr h, uint m, UIntPtr w, string l, uint f, uint t, out UIntPtr r);'
$r = [UIntPtr]::Zero
[void][Rice.Native]::SendMessageTimeout([IntPtr]0xffff, 0x1A, [UIntPtr]::Zero, 'ImmersiveColorSet', 2, 3000, [ref]$r)
"accent set to $accentHex"
