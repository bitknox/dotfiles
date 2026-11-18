#!/bin/bash
# Wi-Fi on or off. A click opens Wi-Fi settings (set in sketchybarrc).

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
. "$CONFIG_DIR/icons.sh"

dev=$(networksetup -listallhardwareports 2>/dev/null | awk '/Hardware Port: Wi-Fi/ { getline; print $2; exit }')
if [ -n "$dev" ] && ipconfig getifaddr "${dev}" >/dev/null 2>&1; then
  sketchybar --set "$NAME" icon="$ICON_WIFI"
else
  sketchybar --set "$NAME" icon="$ICON_WIFI_OFF"
fi
