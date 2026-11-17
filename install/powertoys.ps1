# Frees Alt+Space for Flow Launcher by disabling PowerToys Run (and Command Palette, if present).
# Every other PowerToys module is left as-is.
$f = "$env:LOCALAPPDATA\Microsoft\PowerToys\settings.json"
if (-not (Test-Path $f)) { 'PowerToys not configured; nothing to do'; return }
Get-Process PowerToys* -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 800
py -3 -c @"
import json, sys
p = sys.argv[1]
cfg = json.load(open(p, encoding='utf-8-sig'))
for k in ('PowerToys Run', 'CmdPal'):
    if k in cfg.get('enabled', {}):
        cfg['enabled'][k] = False
json.dump(cfg, open(p, 'w', encoding='utf-8'), separators=(',', ':'))
print('disabled:', [k for k in ('PowerToys Run', 'CmdPal') if k in cfg['enabled']])
"@ $f
$exe = @("$env:LOCALAPPDATA\PowerToys\PowerToys.exe", "$env:ProgramFiles\PowerToys\PowerToys.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
if ($exe) { Start-Process $exe; "restarted $exe" }
