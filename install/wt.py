"""Merge generated/terminal/wt-patch.json into Windows Terminal's settings.json.

- top-level scalars are set
- "profiles.defaults" keys are merged into profiles.defaults
- "schemes" / "themes" entries are upserted by name
Keeps every other user setting (keybindings, profiles, ...). Writes a .bak next to the file.
"""
import json, os, shutil, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SETTINGS = Path(os.path.expandvars(
    r"%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"))

src = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "generated/terminal/wt-patch.json"
patch = json.loads(src.read_text(encoding="utf-8"))
cfg = json.loads(SETTINGS.read_text(encoding="utf-8-sig"))
shutil.copy2(SETTINGS, SETTINGS.with_suffix(".json.bak"))

for key, val in patch.items():
    if key == "profiles.defaults":
        cfg.setdefault("profiles", {}).setdefault("defaults", {}).update(val)
    elif key in ("schemes", "themes"):
        lst = [x for x in cfg.get(key, []) if x.get("name") not in {v["name"] for v in val}]
        cfg[key] = lst + val
    else:
        cfg[key] = val

SETTINGS.write_text(json.dumps(cfg, indent=4, ensure_ascii=False), encoding="utf-8")
print(f"patched {SETTINGS}")
