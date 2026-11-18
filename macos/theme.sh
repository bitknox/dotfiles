#!/bin/bash
# theme.sh [theme]: switch the whole Mac rice to another theme. With no argument, lists the themes.
#
#   ./theme.sh shinkai
#
# Renders the theme, copies it into place (keeping first originals in backup/), then has each app
# pick it up: SketchyBar crossfades its colors, borders and Ghostty reload in place, the wallpaper
# and accent change, and Zen, Spotify, Discord and the editors get the new theme. Apps that need a
# click or a restart are listed at the end.
set -u
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"   # Raycast runs this with a short PATH
# shellcheck source-path=SCRIPTDIR source=install/lib.sh
. "$(dirname "$0")/install/lib.sh"

if [ $# -eq 0 ]; then
  now="$(current_theme)"
  while IFS= read -r t; do
    [ -n "$t" ] || continue
    name="$(python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1]))["name"])' "$ROOT/palettes/$t.json")"
    if [ "$t" = "$now" ]; then printf '* %-10s %s\n' "$t" "$name"; else printf '  %-10s %s\n' "$t" "$name"; fi
  done < "$MAC/themes"
  exit 0
fi

target="$1"
grep -qx "$target" "$MAC/themes" || die "no theme called '$target' (run theme.sh with no argument for the list)"
printf '%s\n' "$target" > "$MAC/.current-theme"
render --check >/dev/null || die "the $target templates did not check out; nothing was changed"
render --deploy --backup "$BACKUP/originals" >/dev/null || die "deploy failed"
say "theme: $(pal name)"

step() { # step <name>: re-run an install step quietly when it can run
  bash "$MAC/install/$1.sh" check >/dev/null 2>&1 && bash "$MAC/install/$1.sh" run >/dev/null 2>&1
}

LATER=""

# Bar and borders change in place.
if pgrep -x sketchybar >/dev/null; then
  "$HOME/.config/sketchybar/recolor.sh" animate && say "bar"
fi
if pgrep -x borders >/dev/null; then
  "$HOME/.config/borders/bordersrc" && say "borders"   # borders with arguments updates the running one
fi

# Ghostty reloads its config on SIGUSR2.
if pgrep -x ghostty >/dev/null; then
  pkill -USR2 -x ghostty && say "Ghostty"
fi

step wallpaper && say "wallpaper"
step appearance && say "accent and selection color"

# Editors: the extension holds both themes; point each editor's settings at the new one.
NAME="$(pal name)"
for dir in "Code" "Code - Insiders" "Cursor"; do
  f="$HOME/Library/Application Support/$dir/User/settings.json"
  [ -f "$f" ] || continue
  keep_file "$f"
  python3 -I - "$f" "$NAME" <<'PY' && say "$dir"
import re, sys
path, name = sys.argv[1], sys.argv[2]
text = open(path, encoding="utf-8").read()
line = '"workbench.colorTheme": ' + '"' + name + '"'
# settings.json may hold comments, so edit the one key as text instead of rewriting the file.
new, n = re.subn(r'"workbench\.colorTheme"\s*:\s*"[^"]*"', lambda m: line, text)
if n == 0:
    # No key yet: add it as the first entry of the top-level object.
    body = text.strip()
    if body in ("", "{}") or re.fullmatch(r"\{\s*\}", body):
        new = "{\n  " + line + "\n}\n"
    else:
        new = text.replace("{", "{\n  " + line + ",", 1)
open(path, "w", encoding="utf-8").write(new)
PY
done

if step zen; then say "Zen"; LATER="$LATER
  Zen: restart it to load the new styles"; fi
if step spicetify; then say "Spotify"; fi
if step vencord; then say "Discord"; fi
if step helium; then LATER="$LATER
  Helium: press Reload on the theme in chrome://extensions"; fi
LATER="$LATER
  Raycast: open this link once and choose Add to Raycast:
    $(bash "$MAC/install/raycast.sh" link "$target")
  Xcode and Android Studio: both themes are installed; pick $NAME in their settings"
printf '\nStill to do by hand:%s\n' "$LATER"
