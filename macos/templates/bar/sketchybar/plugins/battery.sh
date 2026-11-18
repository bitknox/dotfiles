#!/bin/bash
# Battery. The bar shows the charge; the popup adds the time left and the power source.
#   battery.sh          update (timer, power source change, wake, pointer leaving)
#   battery.sh toggle   refresh and open the popup, or close it

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
. "$CONFIG_DIR/icons.sh"
. "$CONFIG_DIR/plugins/popup.sh"

update() {
  local batt pct time icon status
  batt=$(pmset -g batt)
  pct=$(printf '%s' "$batt" | grep -Eo '[0-9]+%' | head -n 1 | tr -d %)
  [ -n "$pct" ] || { sketchybar --set battery drawing=off; return; }
  time=$(printf '%s' "$batt" | grep -Eo '[0-9]+:[0-9]+ remaining' | head -n 1 | cut -d' ' -f1)
  [ "$time" = "0:00" ] && time=""

  if   [ "$pct" -ge 90 ]; then icon="$ICON_BAT_100"
  elif [ "$pct" -ge 65 ]; then icon="$ICON_BAT_70"
  elif [ "$pct" -ge 40 ]; then icon="$ICON_BAT_50"
  elif [ "$pct" -ge 20 ]; then icon="$ICON_BAT_30"
  else icon="$ICON_BAT_10"
  fi

  case "$batt" in
    *"; charging"*)
      icon="$ICON_BAT_CHARGING"
      status="Charging"; [ -n "$time" ] && status="Charging, $time until full" ;;
    *"; charged"*|*"finishing charge"*) status="Fully charged" ;;
    *"AC attached"*|*"not charging"*) status="On the power adapter, not charging" ;;
    *)
      status="On battery"; [ -n "$time" ] && status="$time remaining, on battery" ;;
  esac
  sketchybar --set battery drawing=on icon="$icon" label="$pct%" \
             --set bat.head label="$pct%" \
             --set bat.time label="$status"
}

case "${1:-}" in
  toggle)
    if popup_is_open battery; then popup_close_all; exit 0; fi
    update
    popup_open battery
    exit 0 ;;
esac

case "${SENDER:-}" in
  mouse.exited.global) sketchybar --set battery popup.drawing=off ;;
  *) update ;;
esac
