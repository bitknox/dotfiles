#!/bin/bash
# Raycast script command. Add macos/raycast as a script directory in Raycast settings.
#
# @raycast.schemaVersion 1
# @raycast.title Theme: Frieren
# @raycast.mode compact
# @raycast.packageName Dotfiles
# @raycast.description Switch the Mac rice to Frieren

if "$(dirname "$0")/../theme.sh" frieren >/dev/null 2>&1; then
  echo "Theme: Frieren"
else
  echo "Switch failed; run macos/theme.sh frieren in a terminal to see why"
  exit 1
fi
