#!/bin/bash
# Renders the Xcode color theme once per theme in macos/themes and copies each file into
# Xcode's FontAndColorThemes folder. Xcode names a theme after its file, so each one is
# saved under the palette name. Pick it in Xcode Settings, Themes.
set -u
# shellcheck source-path=SCRIPTDIR source=lib.sh
. "$(dirname "$0")/lib.sh"

DEST="$HOME/Library/Developer/Xcode/UserData/FontAndColorThemes"

theme_slugs() { sed -e 's/[[:space:]]//g' -e '/^$/d' "$MAC/themes"; }
theme_name() { python3 -I -c 'import json, sys; print(json.load(open(sys.argv[1], encoding="utf-8"))["name"])' "$ROOT/palettes/$1.json"; }

case "${1:-}" in
  check)
    have python3 || { echo "python3 is missing"; exit 1; }
    has_app Xcode || { echo "Xcode is not installed"; exit 1; }
    ;;
  run)
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' EXIT
    mkdir -p "$DEST"
    for slug in $(theme_slugs); do
      out="$(render --theme "$slug" --out "$tmp/$slug" --only editors/xcode 2>&1)" || { printf '%s\n' "$out" >&2; die "render failed for $slug"; }
      dst="$DEST/$(theme_name "$slug").xccolortheme"
      keep_file "$dst"
      cp "$tmp/$slug/editors/xcode/dotfiles.xccolortheme" "$dst"
      say "copied $dst"
    done
    say "restart Xcode, then pick the theme in Settings, Themes"
    ;;
  *) die "usage: $0 check|run" ;;
esac
