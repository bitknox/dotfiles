#!/bin/bash
# cpu and memory. Plain numbers every five seconds; they never animate.

case "$NAME" in
  cpu)
    cores=$(sysctl -n hw.ncpu)
    pct=$(ps -A -o %cpu= | awk -v n="$cores" '{ s += $1 } END { printf "%d", s / n + 0.5 }')
    ;;
  memory)
    free=$(memory_pressure -Q 2>/dev/null | awk -F': ' '/percentage/ { print $2 + 0 }')
    pct=$((100 - ${free:-100}))
    ;;
esac
sketchybar --set "$NAME" label="${pct}%"
