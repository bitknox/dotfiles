#!/bin/bash
# Step: the cava audio visualizer. cava 1.0 taps the system output through Core Audio, so no
# virtual device or audio routing is needed. The first run asks for System Audio Recording
# permission for the terminal it runs in.
set -u
# shellcheck source-path=SCRIPTDIR source=lib.sh
. "$(dirname "$0")/lib.sh"

case "${1:-}" in
  check)
    have cava || { echo "cava is missing (brew install cava)"; exit 1; }
    ;;
  run)
    render --deploy cava --backup "$BACKUP/originals" || die "render.py could not deploy the cava config"
    say "the first cava run asks for System Audio Recording permission for the terminal; allow it, then start cava again"
    ;;
  *)
    die "usage: $0 check|run"
    ;;
esac
