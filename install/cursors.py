"""Build the "Ahri Blossom" Windows cursor scheme from Bibata SVG sources, colored from palette.json.

Output: assets/cursors/ahri-blossom/*.cur|*.ani + install.inf  (install with install/apply-cursors.ps1)

Sources: Bibata Cursor by ful1e5 (GPL-3.0) - https://github.com/ful1e5/Bibata_Cursor
The SVGs use placeholder colors (#00FF00 fill, #0000FF outline, #FF0000 spinner bg) which are swapped
for palette colors here, rendered with resvg and packed into multi-size .cur / .ani by a small writer below.

Requirements (use a venv):  pip install resvg-py pillow
Usage:
  python install/cursors.py --bibata <path to Bibata_Cursor clone>   [--variant night|cream] [--sheet out.png]
If --bibata is omitted, Bibata is shallow-cloned into %LOCALAPPDATA%\\dotfiles-cache\\Bibata_Cursor.
"""
from __future__ import annotations

import argparse
import io
import json
import os
import re
import shutil
import struct
import subprocess
import sys
from pathlib import Path

import resvg_py
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
BIBATA_REPO = "https://github.com/ful1e5/Bibata_Cursor.git"
BIBATA_REV = "ddb09273cde49faeb6a32282660ff4293f52d6e0"  # commit the scheme was tuned against

SCHEME = "Ahri Blossom"
STATIC_SIZES = [32, 40, 48, 64, 96, 128]  # 100/125/150/200/300/400 % (+ pointer-size slider headroom)
ANIM_SIZES = [32, 40, 48, 64]             # keep .ani files small
CONTENT = 22 / 32                         # glyph-to-canvas ratio (Bibata "normal"-ish; 26/32 = "large"). --content overrides
ANIM_FRAME_STEP = 2                       # use every 2nd of Bibata's 54 spinner frames
ANIM_JIFFIES = 3                          # 1 jiffy = 1/60 s -> 20 fps, ~1.35 s per spin

# reg value -> (file stem, Bibata svg name, (hotspot x, y) on the 256 canvas, animated)
CURSORS = {
    "Arrow":       ("pointer",     "left_ptr",          (55, 17),   False),
    "Help":        ("help",        "question_arrow",    (42, 86),   False),
    "AppStarting": ("working",     "left_ptr_watch",    (55, 17),   True),
    "Wait":        ("busy",        "wait",              (128, 128), True),
    "Crosshair":   ("precision",   "crosshair",         (128, 128), False),
    "IBeam":       ("text",        "xterm",             (128, 128), False),
    "NWPen":       ("handwriting", "pencil",            (46, 211),  False),
    "No":          ("unavailable", "circle",            (55, 17),   False),
    "SizeNS":      ("vert",        "sb_v_double_arrow", (128, 128), False),
    "SizeWE":      ("horz",        "sb_h_double_arrow", (128, 128), False),
    "SizeNWSE":    ("dgn1",        "bd_double_arrow",   (128, 128), False),
    "SizeNESW":    ("dgn2",        "fd_double_arrow",   (128, 128), False),
    "SizeAll":     ("move",        "move",              (128, 128), False),
    "UpArrow":     ("alternate",   "sb_up_arrow",       (128, 28),  False),
    "Hand":        ("link",        "hand2",             (114, 18),  False),
    "Pin":         ("pin",         "pin",               (55, 17),   False),
    "Person":      ("person",      "person",            (55, 17),   False),
}

# Variants: fill / outline / spinner background / badge colors, as palette color names.
VARIANTS = {
    "night": {"fill": "base", "outline": "sakura", "watch_bg": "base", "badge_glyph": "cream"},
    "cream": {"fill": "cream", "outline": "blossom", "watch_bg": "base", "badge_glyph": "cream"},
    # calmer: soft pink edge
    "petal": {"fill": "cream", "outline": "sakura", "watch_bg": "base", "badge_glyph": "cream"},
    # calmest: muted plum edge, pink only in spinner + badges
    "dusk":  {"fill": "cream", "outline": "overlay", "watch_bg": "base", "badge_glyph": "cream"},
}
SPINNER = ["sakura", "lavender", "spirit", "violet"]  # replaces Bibata's 4 quadrant colors, in order
SPINNER_SRC = ["#F05024", "#FCB813", "#7EBA41", "#32A0DA"]
BADGES = {"#FE0000": "rose", "#0A6857": "blossom", "#2C2C2C": "violet"}  # unavailable / pin / person
TAG_ON = 'stroke="#0000FF" stroke-width="17"'


def palette() -> dict:
    with open(ROOT / "palette.json", encoding="utf-8") as f:
        return json.load(f)


def ensure_bibata(path: str | None) -> Path:
    if path:
        return Path(path)
    dest = Path(os.environ.get("LOCALAPPDATA", Path.home())) / "dotfiles-cache" / "Bibata_Cursor"
    if not (dest / "svg").is_dir():
        dest.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(["git", "clone", "--filter=blob:none", BIBATA_REPO, str(dest)], check=True)
        subprocess.run(["git", "-C", str(dest), "checkout", "-q", BIBATA_REV], check=True)
    return dest


def resolve(p: Path) -> Path:
    """Bibata's svg/modern/* are symlinks; on Windows checkouts they become text stubs holding the target."""
    for _ in range(4):
        if p.is_file() and p.stat().st_size < 200:
            target = p.read_text(encoding="utf-8").strip()
            if not target.startswith("<"):
                p = (p.parent / target).resolve()
                continue
        if p.is_dir() or p.is_file():
            return p
        if p.with_suffix(".svg").exists():
            p = p.with_suffix(".svg")
            continue
        break
    return p


def sources(bibata: Path, name: str) -> list[Path]:
    base = bibata / "svg" / "modern"
    stub = base / f"{name}.svg"
    p = resolve(stub if stub.exists() else base / name)
    if p.is_dir():
        return sorted(p.glob("*.svg"))
    return [p]


def recolor(svg: str, pal: dict, var: dict, outline_w: float) -> str:
    c = pal["colors"]
    svg = svg.replace(TAG_ON, f'stroke="#0000FF" stroke-width="{outline_w:g}"')
    swaps = {"#00FF00": c[var["fill"]], "#0000FF": c[var["outline"]], "#FF0000": c[var["watch_bg"]]}
    swaps.update({src: c[dst] for src, dst in zip(SPINNER_SRC, SPINNER)})
    swaps.update({src: c[dst] for src, dst in BADGES.items()})
    for src, dst in swaps.items():
        svg = re.sub(re.escape(src), dst, svg, flags=re.IGNORECASE)
    svg = svg.replace('fill="white"', f'fill="{c[var["badge_glyph"]]}"')
    # spinner quadrants are 80% opaque in Bibata; make them solid so the palette colors read true
    svg = svg.replace('fill-opacity="0.8"', 'fill-opacity="0.95"')
    return svg


def render(svg: str, canvas: int) -> Image.Image:
    px = max(1, round(canvas * CONTENT))
    png = resvg_py.svg_to_bytes(svg_string=svg, width=px, height=px)
    glyph = Image.open(io.BytesIO(bytes(png))).convert("RGBA")
    out = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    out.paste(glyph, (0, 0))
    return out


def hotspot(hs: tuple[int, int], canvas: int) -> tuple[int, int]:
    s = canvas * CONTENT / 256
    return tuple(min(canvas - 1, max(0, int(v * s))) for v in hs)


# ---------- .cur / .ani writer ----------
def dib(img: Image.Image) -> bytes:
    w, h = img.size
    px = img.transpose(Image.FLIP_TOP_BOTTOM)
    r, g, b, a = px.split()
    xor = Image.merge("RGBA", (b, g, r, a)).tobytes()
    row = ((w + 31) // 32) * 4
    mask = bytearray(row * h)
    alpha = a.tobytes()
    for y in range(h):
        for x in range(w):
            if alpha[y * w + x] == 0:
                mask[y * row + x // 8] |= 0x80 >> (x % 8)
    hdr = struct.pack("<IiiHHIIiiII", 40, w, h * 2, 1, 32, 0, len(xor) + len(mask), 0, 0, 0, 0)
    return hdr + xor + bytes(mask)


def cur_bytes(images: list[tuple[Image.Image, tuple[int, int]]]) -> bytes:
    blobs = [dib(im) for im, _ in images]
    out = struct.pack("<HHH", 0, 2, len(images))
    off = 6 + 16 * len(images)
    for (im, (hx, hy)), blob in zip(images, blobs):
        w, h = im.size
        out += struct.pack("<BBBBHHII", w % 256, h % 256, 0, 0, hx, hy, len(blob), off)
        off += len(blob)
    return out + b"".join(blobs)


def chunk(cid: bytes, data: bytes) -> bytes:
    return cid + struct.pack("<I", len(data)) + data + (b"\0" if len(data) % 2 else b"")


def ani_bytes(frames: list[bytes], jiffies: int, title: str, artist: str) -> bytes:
    anih = struct.pack("<9I", 36, len(frames), len(frames), 0, 0, 0, 0, jiffies, 1)
    info = b"INFO" + chunk(b"INAM", title.encode() + b"\0") + chunk(b"IART", artist.encode() + b"\0")
    fram = b"fram" + b"".join(chunk(b"icon", f) for f in frames)
    body = b"ACON" + chunk(b"LIST", info) + chunk(b"anih", anih) + chunk(b"LIST", fram)
    return b"RIFF" + struct.pack("<I", len(body)) + body


# ---------- build ----------
def build(bibata: Path, out: Path, pal: dict, variant: str, outline_w: float) -> dict[str, list[Image.Image]]:
    var = VARIANTS[variant]
    if out.exists():
        shutil.rmtree(out)
    out.mkdir(parents=True)
    previews: dict[str, list[Image.Image]] = {}
    for reg, (stem, name, hs, animated) in CURSORS.items():
        files = sources(bibata, name)
        if not files or not files[0].exists():
            sys.exit(f"missing Bibata source for {name}: {files}")
        svgs = [recolor(f.read_text(encoding="utf-8"), pal, var, outline_w) for f in files]
        if animated:
            svgs = svgs[::ANIM_FRAME_STEP]
            frames = [cur_bytes([(render(s, n), hotspot(hs, n)) for n in ANIM_SIZES]) for s in svgs]
            (out / f"{stem}.ani").write_bytes(ani_bytes(frames, ANIM_JIFFIES, f"{SCHEME} {reg}", "Bibata / dotfiles"))
            previews[reg] = [render(s, 32) for s in svgs]
        else:
            (out / f"{stem}.cur").write_bytes(cur_bytes([(render(svgs[0], n), hotspot(hs, n)) for n in STATIC_SIZES]))
            previews[reg] = [render(svgs[0], 32)]
    write_inf(out)
    (out / "LICENSE-Bibata.txt").write_text(
        "Cursor shapes: Bibata Cursor (c) Abdulkaiz Khatri / ful1e5, GPL-3.0\n"
        "https://github.com/ful1e5/Bibata_Cursor  (recolored + repacked by install/cursors.py)\n",
        encoding="utf-8")
    return previews


def write_inf(out: Path) -> None:
    files = [CURSORS[k][0] + (".ani" if CURSORS[k][3] else ".cur") for k in CURSORS]
    order = ["Arrow", "Help", "AppStarting", "Wait", "Crosshair", "IBeam", "NWPen", "No", "SizeNS",
             "SizeWE", "SizeNWSE", "SizeNESW", "SizeAll", "UpArrow", "Hand", "Pin", "Person"]
    fn = {k: CURSORS[k][0] + (".ani" if CURSORS[k][3] else ".cur") for k in CURSORS}
    lines = [
        "; Right-click > Install to register the scheme system-wide (needs admin).",
        "; Per-user install without admin: install/apply-cursors.ps1",
        "[Version]", 'signature="$CHICAGO$"', "",
        "[DefaultInstall]", "CopyFiles = Scheme.Cur", "AddReg = Scheme.Reg", "",
        "[DestinationDirs]", 'Scheme.Cur = 10,"%CUR_DIR%"', "",
        "[Scheme.Reg]",
        'HKCU,"Control Panel\\Cursors\\Schemes","%SCHEME_NAME%",,"'
        + ",".join(f"%10%\\%CUR_DIR%\\{fn[k]}" for k in order) + '"', "",
        "[Scheme.Cur]", *files, "",
        "[Strings]", 'CUR_DIR = "Cursors\\AhriBlossom"', f'SCHEME_NAME = "{SCHEME}"', "",
    ]
    (out / "install.inf").write_text("\r\n".join(lines), encoding="utf-8")


def contact_sheet(previews: dict[str, list[Image.Image]], pal: dict, path: Path) -> None:
    c = pal["colors"]
    zoom, cell, pad = 3, 32 * 3 + 16, 8
    bgs = [c["crust"], c["base"], c["surface1"], "#d8d4dc", "#ffffff"]
    wp = None
    try:
        import winreg
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, r"Control Panel\Desktop") as k:
            wp = Image.open(winreg.QueryValueEx(k, "WallPaper")[0]).convert("RGB")
    except Exception:
        pass
    names = list(previews)
    cols = len(bgs) + (1 if wp else 0)
    anim_w = max(len(v) for v in previews.values() if len(v) > 1) // 3 * 36 + 40
    width = 140 + cols * (cell + 40 + pad) + anim_w
    height = len(names) * (cell + pad) + pad
    sheet = Image.new("RGB", (width, height), c["mantle"])
    from PIL import ImageDraw
    d = ImageDraw.Draw(sheet)
    for i, reg in enumerate(names):
        y = pad + i * (cell + pad)
        d.text((8, y + cell // 2 - 6), reg, fill=c["text"])
        img = previews[reg][0]
        for j in range(cols):
            x = 140 + j * (cell + 40 + pad)
            if j < len(bgs):
                tile = Image.new("RGB", (cell + 40, cell), bgs[j])
            else:
                crop = wp.resize((wp.width // 4, wp.height // 4)).crop((40 + i * 20, 60 + i * 15, 40 + i * 20 + cell + 40, 60 + i * 15 + cell))
                tile = crop
            big = img.resize((96, 96), Image.NEAREST)
            tile.paste(big, (8, 8), big)
            tile.paste(img, (cell + 40 - 40, cell // 2 - 16), img)  # 1:1 actual size
            sheet.paste(tile, (x, y))
        if len(previews[reg]) > 1:
            x0 = 140 + cols * (cell + 40 + pad)
            strip = previews[reg][::3]
            for k, fr in enumerate(strip):
                t = Image.new("RGB", (34, 34), c["crust"])
                t.paste(fr, (1, 1), fr)
                sheet.paste(t, (x0 + (k % 8) * 36, y + (k // 8) * 36))
    sheet.save(path)


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--bibata", help="path to a Bibata_Cursor checkout")
    ap.add_argument("--variant", choices=VARIANTS, default="cream")
    ap.add_argument("--outline", type=float, default=10, help="outline stroke width on the 256 canvas (Bibata: 17; 10 = calmer)")
    ap.add_argument("--out", default=str(ROOT / "assets" / "cursors" / "ahri-blossom"))
    ap.add_argument("--sheet", help="also write a contact-sheet PNG here")
    ap.add_argument("--content", type=float, default=CONTENT, help="glyph size as a fraction of the canvas (22/32 normal, 26/32 large)")
    a = ap.parse_args()
    globals()["CONTENT"] = a.content
    pal = palette()
    previews = build(ensure_bibata(a.bibata), Path(a.out), pal, a.variant, a.outline)
    if a.sheet:
        contact_sheet(previews, pal, Path(a.sheet))
    print(f"built {len(previews)} cursors ({a.variant}) -> {a.out}")


if __name__ == "__main__":
    main()
