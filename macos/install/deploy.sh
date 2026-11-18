#!/bin/bash
# Step: copy generated/ into each app's config folder, as listed in deploy.d/*.json.
# render.py keeps the first original of every file it replaces in backup/originals.
set -u
# shellcheck source-path=SCRIPTDIR source=lib.sh
. "$(dirname "$0")/lib.sh"

case "${1:-}" in
  check)
    have python3 || { echo "python3 is missing (xcode-select --install)"; exit 1; }
    ;;
  run)
    render --deploy --backup "$BACKUP/originals"
    ;;
  *) die "usage: $0 check|run" ;;
esac
