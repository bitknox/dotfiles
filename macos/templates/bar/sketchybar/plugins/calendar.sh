#!/bin/bash
# calendar.sh toggle: fill the calendar popup under the clock, then open it (or close it).
# Monday first, the current week in the accent, the month's old Japanese name beside the header.

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
. "$CONFIG_DIR/colors.sh"
. "$CONFIG_DIR/plugins/popup.sh"

if popup_is_open clock; then popup_close_all; exit 0; fi

year=$(date +%Y) month=$(date +%m) today=$((10#$(date +%d)))
first=$(date -j -f %Y-%m-%d "$year-$month-01" +%u)       # 1 = Monday
last=$((10#$(date -j -v1d -v+1m -v-1d +%d)))
OLD_NAMES="睦月 如月 弥生 卯月 皐月 水無月 文月 葉月 長月 神無月 霜月 師走"
# shellcheck disable=SC2086  # split the list into lines
old=$(printf '%s\n' $OLD_NAMES | sed -n "$((10#$month))p")

args=(--set cal.head icon="$(date +%B) $year" label="$old"
      --set cal.rdays label="$(printf '%4s' M T W T F S S)"
      --set cal.week label="Week $((10#$(date +%V)))")

row=1 line="" col=1 today_row=1
while [ $col -lt "$first" ]; do line="$line    "; col=$((col + 1)); done
for day in $(seq 1 "$last"); do
  line="$line$(printf '%4s' "$day")"
  [ "$day" = "$today" ] && today_row=$row
  if [ $col = 7 ] || [ "$day" = "$last" ]; then
    args+=(--set "cal.r$row" drawing=on label="$line" label.color="$POPUP_TEXT")
    row=$((row + 1)) line="" col=1
  else
    col=$((col + 1))
  fi
done
while [ $row -le 6 ]; do args+=(--set "cal.r$row" drawing=off); row=$((row + 1)); done
args+=(--set "cal.r$today_row" label.color="$POPUP_ACCENT")
mkdir -p "$BAR_CACHE" && printf '%s' "$today_row" > "$BAR_CACHE/cal.row"

sketchybar "${args[@]}"
popup_open clock
