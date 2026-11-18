#!/bin/bash
# Step: start JankyBorders. It reads ~/.config/borders/bordersrc, rendered from the current theme.
set -u
# shellcheck source-path=SCRIPTDIR source=lib.sh
. "$(dirname "$0")/lib.sh"

case "${1:-}" in
  check)
    have borders || { echo "borders is not installed (brew step)"; exit 1; }
    [ -x "$HOME/.config/borders/bordersrc" ] || { echo "no bordersrc yet (deploy step)"; exit 1; }
    ;;
  run)
    brew services restart borders >/dev/null && say "borders is running"
    say "borders needs Accessibility permission the first time; macOS asks for it"
    ;;
  *) die "usage: $0 check|run" ;;
esac
