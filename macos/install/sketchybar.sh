#!/bin/bash
# Step: hide the native menu bar and start SketchyBar in its place.
# The menu bar still slides in when the pointer touches the top edge. The old setting is kept in
# backup/defaults.tsv. SketchyBar needs Screen Recording permission to show the menu extra icons.
set -u
# shellcheck source-path=SCRIPTDIR source=lib.sh
. "$(dirname "$0")/lib.sh"

case "${1:-}" in
  check)
    have sketchybar || { echo "sketchybar is not installed (brew step)"; exit 1; }
    [ -x "$HOME/.config/sketchybar/sketchybarrc" ] || { echo "no SketchyBar config yet (deploy step)"; exit 1; }
    ;;
  run)
    keep_default NSGlobalDomain _HIHideMenuBar
    osascript -e 'tell application "System Events" to set autohide menu bar of dock preferences to true' >/dev/null
    brew services restart sketchybar >/dev/null && say "SketchyBar is running"
    say "for the VPN, Tailscale and Bitwarden icons, allow SketchyBar under Privacy & Security, Screen Recording"
    ;;
  *) die "usage: $0 check|run" ;;
esac
