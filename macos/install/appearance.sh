#!/bin/bash
# Step: dark mode, the macOS accent preset nearest the theme's accent, and a text selection color
# mixed from the accent and the base. theme.sh runs it again after a switch. Old values go to
# backup/defaults.tsv first. Open apps pick up the accent when they relaunch.
set -u
# shellcheck source-path=SCRIPTDIR source=lib.sh
. "$(dirname "$0")/lib.sh"

case "${1:-}" in
  check)
    [ -s "$GEN/palette.json" ] || { echo "no rendered palette yet (render step)"; exit 1; }
    ;;
  run)
    # One line out: "<accent preset number> <highlight as r g b floats>".
    read -r preset r g b <<<"$(python3 -I - "$GEN/palette.json" <<'PY'
import colorsys, json, sys
p = json.load(open(sys.argv[1], encoding="utf-8"))
c = p["colors"]
def rgb(h): return [int(h.lstrip("#")[i:i + 2], 16) / 255 for i in (0, 2, 4)]
acc, base = rgb(c[p["roles"]["accent"]]), rgb(c["base"])
hue = colorsys.rgb_to_hls(*acc)[0] * 360
# macOS presets and their hues: red 0, orange 1, yellow 2, green 3, blue 4, purple 5, pink 6.
presets = {0: 0, 1: 30, 2: 50, 3: 135, 4: 211, 5: 285, 6: 330}
near = min(presets, key=lambda k: min(abs(hue - presets[k]), 360 - abs(hue - presets[k])))
mix = [0.5 * a + 0.5 * b for a, b in zip(acc, base)]
print(near, *(f"{v:.6f}" for v in mix))
PY
)"
    keep_default NSGlobalDomain AppleInterfaceStyle
    osascript -e 'tell application "System Events" to tell appearance preferences to set dark mode to true' >/dev/null
    set_default NSGlobalDomain AppleAccentColor -int "$preset"
    set_default NSGlobalDomain AppleHighlightColor -string "$r $g $b Other"
    say "dark mode, accent preset $preset, selection color from the palette (apps update on relaunch)"
    ;;
  *) die "usage: $0 check|run" ;;
esac
