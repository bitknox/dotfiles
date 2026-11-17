# Wallpaper Engine: frame cap + Ahri wallpaper on the primary monitor.
# Workshop item 2184359275 = "Ahri: Spirit Blossom in 4K" (must be subscribed in Wallpaper Engine).
param([string]$WorkshopId = '2184359275', [int]$Fps = 60)
$ErrorActionPreference = 'Stop'
$we  = 'C:\Program Files (x86)\Steam\steamapps\common\wallpaper_engine'
$exe = "$we\wallpaper64.exe"
$project = "C:\Program Files (x86)\Steam\steamapps\workshop\content\431960\$WorkshopId\project.json"
if (-not (Test-Path $project)) { throw "Workshop item $WorkshopId not found - subscribe to it in Wallpaper Engine first" }

# WE rewrites config.json on exit, so edit it while WE is closed
Get-Process wallpaper32, wallpaper64 -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep 2
py -3 -c @"
import json, sys
p = sys.argv[1]; fps = int(sys.argv[2])
cfg = json.load(open(p, encoding='utf-8-sig'))
n = 0
for user in cfg.values():
    u = user.get('general', {}).get('user') if isinstance(user, dict) else None
    if isinstance(u, dict) and 'fps' in u:
        u['fps'] = fps
        u['overridelockscreen'] = True   # lock/sign-in screen = native-res still of the wallpaper
        n += 1
json.dump(cfg, open(p, 'w', encoding='utf-8'), indent='\t', ensure_ascii=False)
print(f'fps={fps} for {n} user profile(s)')
"@ "$we\config.json" $Fps

Start-Process $exe
Start-Sleep 6
& $exe -control openWallpaper -file $project -monitor 0
"wallpaper -> $((Get-Content $project -Raw -Encoding utf8 | ConvertFrom-Json).title)"
