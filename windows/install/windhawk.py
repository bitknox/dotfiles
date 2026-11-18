"""Apply rendered Windhawk mod settings (generated/windhawk/<mod-id>.json) to the registry.

Windhawk stores mod settings flattened under
  HKLM\\SOFTWARE\\Windhawk\\Engine\\Mods\\<mod-id>\\Settings
using the same names mods read via Wh_Get*Setting, e.g.
  controlStyles[0].target, controlStyles[0].styles[1], normal_window_border.dark_color
Strings -> REG_SZ, ints/bools -> REG_DWORD.

Only mods that are installed (key exists) are touched. Each mod's Settings key is replaced
wholesale (so stale array entries disappear), then SettingsChangeTime is bumped so running
processes reload. Needs admin: writes a .reg file and imports it elevated.

usage: py -3 install/windhawk.py [src_dir]   (default: generated/windhawk)
"""
import json, subprocess, sys, tempfile, time, winreg
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "generated" / "windhawk"
BASE = r"SOFTWARE\Windhawk\Engine\Mods"


def flatten(obj, prefix=""):
    if isinstance(obj, dict):
        for k, v in obj.items():
            yield from flatten(v, f"{prefix}.{k}" if prefix else k)
    elif isinstance(obj, list):
        for i, v in enumerate(obj):
            yield from flatten(v, f"{prefix}[{i}]")
    else:
        yield prefix, obj


def reg_value(name, val):
    esc = lambda s: s.replace("\\", "\\\\").replace('"', '\\"')
    if isinstance(val, bool):
        return f'"{esc(name)}"=dword:{int(val):08x}'
    if isinstance(val, int):
        return f'"{esc(name)}"=dword:{val & 0xFFFFFFFF:08x}'
    return f'"{esc(name)}"="{esc(str(val))}"'


def installed_mods():
    try:
        with winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE, BASE) as k:
            return {winreg.EnumKey(k, i) for i in range(winreg.QueryInfoKey(k)[0])}
    except FileNotFoundError:
        return set()


mods = installed_mods()
lines = ["Windows Registry Editor Version 5.00", ""]
applied, skipped = [], []
for f in sorted(SRC.glob("*.json")):
    mod = f.stem
    if mod not in mods:
        skipped.append(mod)
        continue
    data = json.loads(f.read_text(encoding="utf-8-sig"))
    key = f"HKEY_LOCAL_MACHINE\\{BASE}\\{mod}"
    lines += [f"[-{key}\\Settings]", f"[{key}\\Settings]"]
    lines += [reg_value(n, v) for n, v in flatten(data)]
    lines += ["", f"[{key}]", f'"SettingsChangeTime"=dword:{int(time.time()) & 0xFFFFFFFF:08x}', ""]
    applied.append(mod)

if not applied:
    sys.exit(f"no installed mods to configure (skipped: {', '.join(skipped)})")

reg = Path(tempfile.gettempdir()) / "ahri-windhawk.reg"
reg.write_text("\r\n".join(lines) + "\r\n", encoding="utf-16")
ps = (f"$p = Start-Process reg.exe -ArgumentList 'import','\"{reg}\"' -Verb RunAs -Wait -WindowStyle Hidden -PassThru; exit $p.ExitCode")
rc = subprocess.run(["powershell", "-NoProfile", "-Command", ps]).returncode
if rc != 0:
    sys.exit(f"reg import failed (exit {rc}) - settings NOT applied (UAC declined?)")
print("applied:", ", ".join(applied))
if skipped:
    print("not installed (skipped):", ", ".join(skipped))
