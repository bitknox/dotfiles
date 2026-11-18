#!/bin/bash
# clock (flair and time) and date, right of the notch. Both open the calendar.

case "${SENDER:-}" in
  mouse.exited.global) sketchybar --set clock popup.drawing=off; exit 0 ;;
esac

if [ "$NAME" = date ]; then
  sketchybar --set date label="$(date +%a) $(date +%e | tr -d ' ') $(date +%b)"
else
  sketchybar --set clock label="$(date +%H:%M)"
fi
