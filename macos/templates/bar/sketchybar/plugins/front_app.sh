#!/bin/bash
# The front app's name, in semibold where the app menu used to be.

if [ "${SENDER:-}" = front_app_switched ]; then
  sketchybar --set "$NAME" label="$INFO"
fi
