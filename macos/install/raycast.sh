#!/bin/bash
# Step: the theme switch commands for Raycast.
# Raycast keeps script directories in its own encrypted settings, so instead of script commands
# the step builds two small apps in ~/Applications ("Theme Frieren", "Theme Shinkai skies") that run
# theme.sh. Raycast and Spotlight list them like any app. Raycast itself stays unthemed: custom
# themes need Raycast Pro, and the free plan follows dark mode.
set -u
# shellcheck source-path=SCRIPTDIR source=lib.sh
. "$(dirname "$0")/lib.sh"

# build_app <theme> <name>: an AppleScript app that runs theme.sh and shows the result.
build_app() {
  local app="$HOME/Applications/Theme $2.app" tmp
  tmp="$(mktemp -t theme-app).applescript"
  cat > "$tmp" <<OSA
set out to do shell script "$MAC/theme.sh $1 2>&1"
display notification "Theme: $2" with title "Dotfiles"
OSA
  mkdir -p "$HOME/Applications"
  rm -rf "$app"
  osacompile -o "$app" "$tmp" && say "built $app"
  rm -f "$tmp"
}

case "${1:-}" in
  check)
    has_app Raycast || { echo "Raycast is not installed (brew step)"; exit 1; }
    ;;
  run)
    while IFS= read -r t; do
      [ -n "$t" ] || continue
      build_app "$t" "$(python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1]))["name"])' "$ROOT/palettes/$t.json")"
    done < "$MAC/themes"
    say "type \"theme\" in Raycast or Spotlight to switch"
    say "set Raycast's hotkey to Option-Space in Raycast settings, General"
    ;;
  *) die "usage: $0 check|run" ;;
esac
