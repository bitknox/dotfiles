#!/bin/bash
# Step (optional): the cava audio visualizer.
#
# macOS cannot capture what the speakers play, so cava listens to the BlackHole 2ch virtual device.
# This step only deploys the cava config. It never changes audio devices or routing; the Multi-Output
# Device that feeds BlackHole is set up by hand, and the steps are printed at the end.
set -u
# shellcheck source-path=SCRIPTDIR source=lib.sh
. "$(dirname "$0")/lib.sh"

# has_blackhole: true when the BlackHole 2ch device is installed.
has_blackhole() {
  if have SwitchAudioSource; then
    SwitchAudioSource -a 2>/dev/null | grep -qx 'BlackHole 2ch' && return 0
  fi
  system_profiler SPAudioDataType 2>/dev/null | grep -q 'BlackHole 2ch'
}

case "${1:-}" in
  check)
    have cava || { echo "cava is missing (brew install cava)"; exit 1; }
    has_blackhole || { echo "BlackHole 2ch is missing (brew install --cask blackhole-2ch, then log out and in)"; exit 1; }
    exit 0
    ;;
  run)
    render --deploy cava --backup "$BACKUP/originals" || die "render.py could not deploy the cava config"
    say "cava listens to BlackHole 2ch. To send music there and still hear it:"
    say "  1. Open Audio MIDI Setup (Applications > Utilities)."
    say "  2. Click + at the bottom left and choose Create Multi-Output Device."
    say "  3. Tick your speakers or headphones first, then BlackHole 2ch."
    say "  4. Make the speakers the primary device and turn on Drift Correction for BlackHole 2ch."
    say "  5. Pick the Multi-Output Device as the sound output in Control Center > Sound."
    say "The volume keys do not work on a Multi-Output Device; switch back to the speakers when cava is off."
    ;;
  *)
    die "usage: $0 check|run"
    ;;
esac
