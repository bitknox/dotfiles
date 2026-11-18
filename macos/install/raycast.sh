#!/bin/bash
# Step: Raycast theme links and the theme switch commands.
# Raycast has no file to drop a theme into. Opening a raycast://theme link shows the theme, and one
# click in Raycast saves it. The step prints both links. The script commands in macos/raycast/ call
# theme.sh; Raycast finds them once that folder is added as a script directory.
set -u
# shellcheck source-path=SCRIPTDIR source=lib.sh
. "$(dirname "$0")/lib.sh"

# theme_link <theme>: the raycast://theme import link, colors in the order Raycast expects.
theme_link() {
  python3 -I - "$ROOT/palettes/$1.json" <<'PY'
import json, sys
from urllib.parse import quote
p = json.load(open(sys.argv[1], encoding="utf-8"))
c = p["colors"]
r = lambda k: c[p["roles"].get(k, k)]
order = [c["base"], c["mantle"], c["text"], r("accent"), r("accent"),
         c["ansi1"], c["ansi9"], c["ansi3"], c["ansi2"], c["ansi4"], c["ansi5"], c["ansi13"]]
meta = {"author": "dotfiles", "authorUsername": "dotfiles", "version": "1", "name": p["name"], "appearance": "dark"}
q = "&".join(f"{k}={quote(v, safe='')}" for k, v in meta.items())
print(f"raycast://theme?{q}&colors=" + ",".join(quote(h, safe="") for h in order))
PY
}

case "${1:-}" in
  check)
    has_app Raycast || { echo "Raycast is not installed (brew step)"; exit 1; }
    ;;
  run)
    chmod +x "$MAC"/raycast/*.sh
    say "1. In Raycast settings, Extensions, Script Commands, add this folder as a script directory:"
    say "   $MAC/raycast"
    say "2. Open each link once and choose Add to Raycast:"
    while IFS= read -r t; do [ -n "$t" ] && say "   $t: $(theme_link "$t")"; done < "$MAC/themes"
    say "3. Set Raycast's hotkey to Option-Space in Raycast settings, General"
    ;;
  link) theme_link "${2:-$(current_theme)}" ;;
  *) die "usage: $0 check|run|link [theme]" ;;
esac
