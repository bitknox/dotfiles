#!/bin/bash
# Step: check every template against every theme, then render the current theme into generated/.
set -u
# shellcheck source-path=SCRIPTDIR source=lib.sh
. "$(dirname "$0")/lib.sh"

case "${1:-}" in
  check)
    have python3 || { echo "python3 is missing (xcode-select --install)"; exit 1; }
    ;;
  run)
    render --check --all-themes && render
    ;;
  *) die "usage: $0 check|run" ;;
esac
