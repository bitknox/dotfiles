#!/bin/bash
# Step: set the current theme's wallpaper on every desktop. theme.sh runs it after a switch.
set -u
# shellcheck source-path=SCRIPTDIR source=lib.sh
. "$(dirname "$0")/lib.sh"

case "${1:-}" in
  check)
    [ -s "$ART/$(current_theme)/wallpaper.jpg" ] || { echo "no wallpaper yet; run the art step first"; exit 1; }
    ;;
  run)
    pic="$ART/$(current_theme)/wallpaper.jpg"
    osascript - "$pic" <<'OSA' >/dev/null
on run argv
  tell application "System Events"
    repeat with d in desktops
      set picture of d to (item 1 of argv)
    end repeat
  end tell
end run
OSA
    say "wallpaper: $pic"
    ;;
  *) die "usage: $0 check|run" ;;
esac
