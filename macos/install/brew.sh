#!/bin/bash
# Step: install everything in macos/Brewfile. Existing installs are left as they are (no upgrades).
set -u
# shellcheck source-path=SCRIPTDIR source=lib.sh
. "$(dirname "$0")/lib.sh"

case "${1:-}" in
  check)
    have brew || { echo "Homebrew is missing; install it from brew.sh first"; exit 1; }
    ;;
  run)
    HOMEBREW_NO_AUTO_UPDATE=1 brew bundle --no-upgrade --file "$MAC/Brewfile"
    ;;
  *) die "usage: $0 check|run" ;;
esac
