#!/bin/bash
# Renders the current theme as a Chromium theme folder for Helium. Chromium only loads an unpacked
# theme by hand, so the step prints where to point it. After a theme switch, run it again and press
# Reload on the extension.
set -u
# shellcheck source-path=SCRIPTDIR source=lib.sh
. "$(dirname "$0")/lib.sh"

DEST="$STATE/helium-theme"

case "${1:-}" in
  check)
    have python3 || { echo "python3 is missing"; exit 1; }
    has_app Helium || { echo "Helium is not installed"; exit 1; }
    ;;
  run)
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' EXIT
    out="$(render --out "$tmp" --only apps/helium 2>&1)" || { printf '%s\n' "$out" >&2; die "render failed"; }
    mkdir -p "$DEST"
    cp "$tmp/apps/helium/manifest.json" "$DEST/manifest.json"
    say "rendered $DEST"
    say "in Helium open chrome://extensions, turn on Developer mode, choose Load unpacked and pick $DEST"
    ;;
  *) die "usage: $0 check|run" ;;
esac
