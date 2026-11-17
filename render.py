"""Tiny pywal-style renderer.

templates/**  ->  generated/**   with placeholders substituted from palette.json
Then (with --deploy) copies files to the destinations listed in deploy.json.

Placeholder syntax:  {{ sakura }}            -> #f4a7c8
                     {{ sakura | strip }}    -> f4a7c8
                     {{ sakura | rgb }}      -> 244, 167, 200
                     {{ sakura | rgba:0.6 }} -> rgba(244, 167, 200, 0.6)
                     {{ sakura | hexa:cc }}  -> #f4a7c8cc
                     {{ sakura | abgr }}     -> 4291340276   (Windows DWORD 0xAABBGGRR, alpha ff)
                     {{ sakura | bgrhex }}   -> c8a7f4       (BBGGRR hex)
                     {{ sakura | r }} / g / b
                     {{ accent }}            roles resolve to colors
                     {{ font.mono }}         fonts
                     {{ meta.name }}         palette name / slug
"""
import json, os, re, shutil, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
PAL = json.loads((ROOT / "palette.json").read_text(encoding="utf-8"))
COLORS = dict(PAL["colors"])
for role, target in PAL["roles"].items():
    COLORS[role] = COLORS[target]

TOKEN = re.compile(r"\{\{\s*([\w.]+)\s*(?:\|\s*([\w]+)(?::([\w.]+))?\s*)?\}\}")
TEXT_EXT = {".json", ".jsonc", ".css", ".scss", ".js", ".ts", ".html", ".toml", ".yaml", ".yml",
            ".ini", ".conf", ".lua", ".ps1", ".nss", ".xaml", ".xml", ".txt", ".md", ".omp", ".reg",
            ".vim", ".qss", ".theme", ".tdesktop-theme", ".jsonl", ".kdl", ""}


def rgb(h):
    h = h.lstrip("#")
    return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)


def sub(m):
    key, flt, arg = m.group(1), m.group(2), m.group(3)
    if key.startswith("font."):
        return PAL["fonts"][key[5:]]
    if key.startswith("meta."):
        return PAL[key[5:]]
    if key not in COLORS:
        raise KeyError(f"unknown palette key '{key}'")
    h = COLORS[key]
    r, g, b = rgb(h)
    if flt in (None, "hex"):
        return h
    if flt == "strip":
        return h.lstrip("#")
    if flt == "rgb":
        return f"{r}, {g}, {b}"
    if flt == "rgbs":
        return f"{r} {g} {b}"
    if flt == "rgba":
        return f"rgba({r}, {g}, {b}, {arg})"
    if flt == "hexa":
        return f"{h}{arg}"
    if flt == "abgr":
        return str((0xFF << 24) | (b << 16) | (g << 8) | r)
    if flt == "bgrhex":
        return f"{b:02x}{g:02x}{r:02x}"
    if flt in ("r", "g", "b"):
        return str({"r": r, "g": g, "b": b}[flt])
    raise KeyError(f"unknown filter '{flt}'")


def render(check=False):
    """Render templates/ -> generated/. With check=True, only validate placeholders (writes nothing)."""
    src, out = ROOT / "templates", ROOT / "generated"
    if out.exists() and not check:
        shutil.rmtree(out)
    n, errors = 0, []
    for f in src.rglob("*"):
        if f.is_dir():
            continue
        dst = out / f.relative_to(src)
        try:
            if f.suffix.lower() in TEXT_EXT:
                text = TOKEN.sub(sub, f.read_text(encoding="utf-8"))
                if not check:
                    dst.parent.mkdir(parents=True, exist_ok=True)
                    dst.write_text(text, encoding="utf-8", newline="")
            elif not check:
                dst.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(f, dst)
        except KeyError as e:
            errors.append(f"{f.relative_to(src)}: {e}")
        n += 1
    for e in errors:
        print("ERROR", e)
    print(f"{'checked' if check else 'rendered'} {n} files" + ("" if check else f" -> {out}"))
    if errors:
        sys.exit(1)


def load_deploy_spec():
    """deploy.d/<group>.json files, each a list of {group, src, dst, [if_exists]}."""
    spec = []
    for f in sorted((ROOT / "deploy.d").glob("*.json")):
        spec += json.loads(f.read_text(encoding="utf-8"))
    return spec


def deploy(only=None):
    for item in load_deploy_spec():
        if only and item["group"] not in only:
            continue
        src = ROOT / "generated" / item["src"]
        dst = Path(os.path.expandvars(item["dst"]))
        if item.get("if_exists") and not Path(os.path.expandvars(item["if_exists"])).exists():
            print(f"skip  {item['src']} (app not present)")
            continue
        if src.is_dir():
            shutil.copytree(src, dst, dirs_exist_ok=True)
        else:
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src, dst)
        print(f"copy  {item['src']} -> {dst}")


if __name__ == "__main__":
    if "--check" in sys.argv:
        render(check=True)
        sys.exit(0)
    render()
    if "--deploy" in sys.argv:
        groups = [a for a in sys.argv[1:] if not a.startswith("--")]
        deploy(groups or None)
