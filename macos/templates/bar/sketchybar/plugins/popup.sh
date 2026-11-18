#!/bin/bash
# Sourced by the plugins that own a popup (clock, volume, battery). Only one popup is open at a time.
# Popups open instantly, like native menu bar menus, and close when the pointer leaves the item and
# its popup.

POPUP_OWNERS="clock volume battery"

popup_is_open() { [ "$(sketchybar --query "$1" 2>/dev/null | jq -r '.popup.drawing' 2>/dev/null)" = on ]; }

popup_close_all() {
  local args=() o
  for o in $POPUP_OWNERS; do args+=(--set "$o" popup.drawing=off); done
  sketchybar "${args[@]}"
}

popup_open() {
  local args=() o
  for o in $POPUP_OWNERS; do [ "$o" = "$1" ] || args+=(--set "$o" popup.drawing=off); done
  sketchybar "${args[@]}" --set "$1" popup.drawing=on
}
