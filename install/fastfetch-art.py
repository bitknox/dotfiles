"""Build the fastfetch logo: Spirit Blossom Ahri art -> pre-encoded sixel file.

Fastfetch's own sixel/chafa renderers need the terminal's cell size in pixels, which Windows
Terminal doesn't report (getCharacterPixelDimensions() fails), so we encode the sixel ourselves
at a fixed size and fastfetch prints it with logo type "raw".

The art is Riot's (Data Dragon CDN, fan-use) and is NOT stored in the repo; this script fetches it.

usage: python install/fastfetch-art.py [--skin 27] [--cols 34] [--rows 16] [--cell 10x21]
needs: Pillow
"""
import argparse, io, os, urllib.request
from pathlib import Path
from PIL import Image, ImageDraw

ap = argparse.ArgumentParser()
ap.add_argument("--skin", type=int, default=27)          # 27 = Spirit Blossom Ahri
ap.add_argument("--cols", type=int, default=34)
ap.add_argument("--rows", type=int, default=16)
ap.add_argument("--cell", default="10x21", help="terminal cell size in px (Maple Mono NF 12pt in WT)")
ap.add_argument("--radius", type=int, default=10, help="corner radius in px (0 = square)")
ap.add_argument("--out", default=str(Path.home() / ".config" / "fastfetch" / "ahri.sixel"))
a = ap.parse_args()

cw, ch = (int(v) for v in a.cell.lower().split("x"))
W, H = a.cols * cw, a.rows * ch
H -= H % 6                                                # sixel bands are 6px tall

url = f"https://ddragon.leagueoflegends.com/cdn/img/champion/tiles/Ahri_{a.skin}.jpg"
with urllib.request.urlopen(url, timeout=30) as r:
    img = Image.open(io.BytesIO(r.read())).convert("RGB")

# cover-crop to the target aspect, biased toward the top (face)
src_ratio, dst_ratio = img.width / img.height, W / H
if src_ratio > dst_ratio:
    nw = int(img.height * dst_ratio); x0 = (img.width - nw) // 2
    img = img.crop((x0, 0, x0 + nw, img.height))
else:
    nh = int(img.width / dst_ratio); img = img.crop((0, 0, img.width, nh))
img = img.resize((W, H), Image.LANCZOS)

# palette-quantize; index 0 reserved for transparent corners
q = img.quantize(colors=255, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.FLOYDSTEINBERG)
pal = q.getpalette()[: 255 * 3]
px = [[v + 1 for v in row] for row in (list(q.getdata())[y * W:(y + 1) * W] for y in range(H))]
if a.radius:
    mask = Image.new("L", (W, H), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, W - 1, H - 1), a.radius, fill=255)
    m = mask.load()
    for y in range(H):
        for x in range(W):
            if m[x, y] < 128:
                px[y][x] = 0

out = ["\x1bP0;1;0q", f'"1;1;{W};{H}']               # P2=1: pixels with value 0 stay transparent
for i in range(len(pal) // 3):
    r, g, b = pal[i * 3:i * 3 + 3]
    out.append(f"#{i + 1};2;{r * 100 // 255};{g * 100 // 255};{b * 100 // 255}")
for band in range(0, H, 6):
    rows = px[band:band + 6]
    colors = sorted({c for row in rows for c in row if c})
    for n, c in enumerate(colors):
        line, run_ch, run_len = [f"#{c}"], None, 0
        for x in range(W):
            bits = sum(1 << dy for dy, row in enumerate(rows) if row[x] == c)
            chv = chr(63 + bits)
            if chv == run_ch:
                run_len += 1
            else:
                if run_ch:
                    line.append(f"!{run_len}{run_ch}" if run_len > 3 else run_ch * run_len)
                run_ch, run_len = chv, 1
        line.append(f"!{run_len}{run_ch}" if run_len > 3 else run_ch * run_len)
        out.append("".join(line) + ("$" if n < len(colors) - 1 else ""))
    out.append("-")
out.append("\x1b\\")

dst = Path(a.out); dst.parent.mkdir(parents=True, exist_ok=True)
dst.write_bytes("".join(out).encode("ascii"))
print(f"wrote {W}x{H}px sixel ({dst.stat().st_size // 1024} KB) -> {dst}  [{a.cols} cols x {a.rows} rows]")
