#!/bin/bash
# Step: the native menu bar. The clock shows the weekday and date beside the time, and the battery
# shows its percentage. Old values go to backup/defaults.tsv first. Two settings macOS 27 only offers
# in System Settings are printed as a short list instead.
set -u
# shellcheck source-path=SCRIPTDIR source=lib.sh
. "$(dirname "$0")/lib.sh"

case "${1:-}" in
  check) exit 0 ;;
  run)
    set_default com.apple.menuextra.clock ShowDate -int 1          # always
    set_default com.apple.menuextra.clock ShowDayOfWeek -bool true
    set_default com.apple.menuextra.clock ShowSeconds -bool false
    keep_default com.apple.controlcenter BatteryShowPercentage
    defaults -currentHost write com.apple.controlcenter BatteryShowPercentage -bool true
    killall ControlCenter 2>/dev/null   # it redraws the clock and battery with the new settings
    say "clock: weekday, date and time; battery: percentage"
    say "by hand in System Settings, Menu Bar:"
    say "  turn off Show menu bar background, so the bar sits on the wallpaper"
    say "  under Menu Bar Controls, show Sound and Now Playing"
    ;;
  *) die "usage: $0 check|run" ;;
esac
