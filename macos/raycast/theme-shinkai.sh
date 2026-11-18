#!/bin/bash
# Raycast script command. Add macos/raycast as a script directory in Raycast settings.
#
# @raycast.schemaVersion 1
# @raycast.title Theme: Shinkai skies
# @raycast.mode compact
# @raycast.packageName Dotfiles
# @raycast.description Switch the Mac rice to Shinkai skies

if "$(dirname "$0")/../theme.sh" shinkai >/dev/null 2>&1; then
  echo "Theme: Shinkai skies"
else
  echo "Switch failed; run macos/theme.sh shinkai in a terminal to see why"
  exit 1
fi
