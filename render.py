"""Tiny pywal-style renderer.

<os>/templates/**  ->  <os>/generated/**   with placeholders substituted from palettes/<theme>.json
Then (with --deploy) copies files to the destinations listed in <os>/deploy.d/*.json.
<os> is the platform folder (windows, linux, macos). --os <name> overrides the current platform.
The resolved palette is also written to <os>/generated/palette.json for install scripts to read.

Theme:  --theme <slug>, else <os>/.current-theme (machine-local, gitignored),
        else the first line of <os>/themes (the platform default). <os>/themes lists every theme
        the platform supports; --check --all-themes validates the templates against each of them.

Placeholder syntax:  {{ sakura }}            -> #f4a7c8
                     {{ sakura | strip }}    -> f4a7c8
                     {{ sakura | rgb }}      -> 244, 167, 200
                     {{ sakura | rgba:0.6 }} -> rgba(244, 167, 200, 0.6)
                     {{ sakura | hexa:cc }}  -> #f4a7c8cc
                     {{ sakura | abgr }}     -> 4291340276   (Windows DWORD 0xAABBGGRR, alpha ff)
                     {{ sakura | bgrhex }}   -> c8a7f4       (BBGGRR hex)
                     {{ sakura | argb }}     -> 0xfff4a7c8   (SketchyBar, JankyBorders; argb:cc for alpha)
                     {{ sakura | float }}    -> 0.957 0.655 0.784   (Xcode)
                     {{ sakura | r }} / g / b
                     {{ sakura | ansi }}     -> 38;2;244;167;200  (ansibg -> 48;2;...)
                     Go-template syntax ({{ .Path }}, {{ end }}) is left untouched.
                     {{ accent }}            roles resolve to colors
                     {{ font.mono }}         fonts
                     {{ meta.name }}         palette name / slug
"""
import json, os, re, shutil, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
PLATFORMS = {"win32": "windows", "linux": "linux", "darwin": "macos"}


def _opt(name):
    return sys.argv[sys.argv.index(name) + 1] if name in sys.argv else None


OS = _opt("--os") or PLATFORMS.get(sys.platform, sys.platform)
BASE = ROOT / OS


def themes():
    """Theme slugs the platform supports, default first."""
    f = BASE / "themes"
    return [l.strip() for l in f.read_text(encoding="utf-8").splitlines() if l.strip()] if f.exists() else []


def current_theme():
    if _opt("--theme"):
        return _opt("--theme")
    local = BASE / ".current-theme"
    if local.exists() and local.read_text(encoding="utf-8").strip():
        return local.read_text(encoding="utf-8").strip()
    listed = themes()
    if not listed:
        sys.exit(f"no theme: pass --theme or list themes in {BASE / 'themes'}")
    return listed[0]


PAL, COLORS = {}, {}


def load(theme):
    """Make `theme` the palette that placeholders resolve against."""
    f = ROOT / "palettes" / f"{theme}.json"
    if not f.exists():
        sys.exit(f"unknown theme '{theme}' ({f} missing)")
    PAL.clear()
    PAL.update(json.loads(f.read_text(encoding="utf-8")))
    COLORS.clear()
    COLORS.update(PAL["colors"])
    for role, target in PAL["roles"].items():
        COLORS[role] = COLORS[target]
    return f

# Keys must start with a letter, so Go-template syntax like {{ .Path }} (oh-my-posh) passes through.
TOKEN = re.compile(r"\{\{\s*([A-Za-z_][\w.]*)\s*(?:\|\s*([\w]+)(?::([\w.]+))?\s*)?\}\}")
GO_TEMPLATE_WORDS = {"end", "else", "if", "range", "with", "define", "template", "block", "break", "continue"}
TEXT_EXT = {".json", ".jsonc", ".css", ".scss", ".js", ".ts", ".html", ".toml", ".yaml", ".yml",
            ".ini", ".conf", ".lua", ".ps1", ".nss", ".xaml", ".xml", ".txt", ".md", ".omp", ".reg",
            ".vim", ".qss", ".theme", ".tdesktop-theme", ".tdesktop-palette", ".ovt", ".obt",
            ".icls", ".jsonl", ".kdl", ".sh", ".zsh", ".xccolortheme", ""}


def rgb(h):
    h = h.lstrip("#")
    return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)


def sub(m):
    key, flt, arg = m.group(1), m.group(2), m.group(3)
    if key in GO_TEMPLATE_WORDS and flt is None:
        return m.group(0)
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
    if flt == "ansi":
        return f"38;2;{r};{g};{b}"
    if flt == "ansibg":
        return f"48;2;{r};{g};{b}"
    if flt == "rgba":
        return f"rgba({r}, {g}, {b}, {arg})"
    if flt == "hexa":
        return f"{h}{arg}"
    if flt == "abgr":
        return str((0xFF << 24) | (b << 16) | (g << 8) | r)
    if flt == "bgrhex":
        return f"{b:02x}{g:02x}{r:02x}"
    if flt == "argb":
        return f"0x{arg or 'ff'}{h.lstrip('#')}"
    if flt == "float":
        return f"{r / 255:.3f} {g / 255:.3f} {b / 255:.3f}"
    if flt in ("r", "g", "b"):
        return str({"r": r, "g": g, "b": b}[flt])
    raise KeyError(f"unknown filter '{flt}'")


def render(check=False, out=None, only=None):
    """Render <os>/templates/ -> <os>/generated/ (or `out`). check=True only validates placeholders.
    `only` restricts to a templates/ subfolder prefix, e.g. "zebar"."""
    src, out = BASE / "templates", Path(out) if out else BASE / "generated"
    if only:
        src = src / only
        out = out / only
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
                    shutil.copymode(f, dst)  # keeps the executable bit on rendered scripts
            elif not check:
                dst.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(f, dst)
        except KeyError as e:
            errors.append(f"{f.relative_to(src)}: {e}")
        n += 1
    if not check:
        out.mkdir(parents=True, exist_ok=True)
        (out / "palette.json").write_text(json.dumps(PAL, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    errors += contrast_errors()
    for e in errors:
        print("ERROR", e)
    print(f"{'checked' if check else 'rendered'} {n} files ({PAL['slug']})" + ("" if check else f" -> {out}"))
    return not errors


def _lum(h):
    c = [x / 255 for x in rgb(h)]
    c = [x / 12.92 if x <= 0.03928 else ((x + 0.055) / 1.055) ** 2.4 for x in c]
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]


def ratio(a, b):
    la, lb = sorted((_lum(a), _lum(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)


def contrast_errors():
    """Palettes with "aa": true promise WCAG AA: text, roles and ANSI colors at 4.5:1 on base and the
    surfaces, the overlay (hints, comments) at 4.5:1 on base and 3:1 on the surfaces."""
    if not PAL.get("aa"):
        return []
    fg = ["text", "subtext"] + list(PAL["roles"]) + [f"ansi{i}" for i in range(1, 16) if i != 8]
    fg = [k for k in dict.fromkeys(fg) if k not in ("bg", "bg_alt", "border_inactive")]
    out = []
    for bg in ("base", "surface0", "surface1"):
        for k in fg + ["overlay"]:
            need = 3.0 if k == "overlay" and bg != "base" else 4.5
            r = ratio(COLORS[k], COLORS[bg])
            if r < need:
                out.append(f"contrast: {k} {COLORS[k]} on {bg} {COLORS[bg]} is {r:.2f}, needs {need}")
    return out


def load_deploy_spec():
    """<os>/deploy.d/<group>.json files, each a list of {group, src, dst, [if_exists]}."""
    spec = []
    for f in sorted((BASE / "deploy.d").glob("*.json")):
        spec += json.loads(f.read_text(encoding="utf-8-sig"))  # tolerate BOM (PowerShell-written files)
    return spec


def backup(dst, root):
    """Keep the first original of `dst` under `root`, mirroring its absolute path. Later runs leave it alone."""
    keep = Path(root) / str(dst.resolve()).lstrip("/\\").replace(":", "")
    if keep.exists() or not dst.exists():
        return
    keep.parent.mkdir(parents=True, exist_ok=True)
    (shutil.copytree if dst.is_dir() else shutil.copy2)(dst, keep)
    print(f"keep  {dst} -> {keep}")


def deploy(only=None, backup_root=None):
    for item in load_deploy_spec():
        if only and item["group"] not in only:
            continue
        src = BASE / "generated" / item["src"]
        dst = Path(os.path.expandvars(item["dst"]))
        if item.get("if_exists") and not Path(os.path.expandvars(item["if_exists"])).exists():
            print(f"skip  {item['src']} (app not present)")
            continue
        if backup_root:
            backup(dst, backup_root)
        if src.is_dir():
            shutil.copytree(src, dst, dirs_exist_ok=True)
        else:
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src, dst)
        print(f"copy  {item['src']} -> {dst}")


if __name__ == "__main__":
    # py -3 render.py --check                       validate all templates, write nothing
    # py -3 render.py --out <dir> [--only <sub>]    render into a scratch dir (safe for parallel work)
    # py -3 render.py [--deploy [group ...]]        render into <os>/generated/ and optionally deploy
    # py -3 render.py --check --all-themes          validate against every theme in <os>/themes
    # py -3 render.py --deploy --backup <dir>        keep the first original of every replaced file in <dir>
    # --os <name> on any of these targets another platform folder, --theme <slug> picks the palette
    if not (BASE / "templates").is_dir():
        sys.exit(f"no templates for '{OS}' ({BASE / 'templates'} missing)")
    if "--check" in sys.argv:
        ok = True
        for theme in (themes() if "--all-themes" in sys.argv else [current_theme()]):
            load(theme)
            ok = render(check=True) and ok
        sys.exit(0 if ok else 1)
    load(current_theme())
    if "--out" in sys.argv:
        sys.exit(0 if render(out=_opt("--out"), only=_opt("--only")) else 1)
    if not render():
        sys.exit(1)
    if "--deploy" in sys.argv:
        groups = [a for a in sys.argv[1:] if not a.startswith("--") and a not in (_opt("--os"), _opt("--theme"), _opt("--backup"))]
        deploy(groups or None, _opt("--backup"))
