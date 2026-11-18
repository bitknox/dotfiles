#!/bin/bash
# Step: the Dock hides itself, gets smaller and stops showing recent apps. Old values go to
# backup/defaults.tsv first.
set -u
# shellcheck source-path=SCRIPTDIR source=lib.sh
. "$(dirname "$0")/lib.sh"

case "${1:-}" in
  check) exit 0 ;;
  run)
    set_default com.apple.dock autohide -bool true
    set_default com.apple.dock tilesize -int 44
    set_default com.apple.dock show-recents -bool false
    killall Dock
    say "Dock: hidden until the pointer reaches the edge, 44 pt icons, no recent apps"
    ;;
  *) die "usage: $0 check|run" ;;
esac
