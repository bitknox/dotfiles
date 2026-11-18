#!/bin/bash
# Sound. The bar shows the output volume; the popup has a slider and the output devices.
#   volume.sh           event handler (volume_change, slider clicks, pointer leaving)
#   volume.sh toggle    fill and open the popup, or close it
#   volume.sh outputs   refill the device list (after picking one)

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
. "$CONFIG_DIR/colors.sh"
. "$CONFIG_DIR/icons.sh"
. "$CONFIG_DIR/plugins/popup.sh"

show() { # volume 0-100
  local icon="$ICON_VOL_HIGH" muted
  muted=$(osascript -e 'output muted of (get volume settings)' 2>/dev/null)
  if [ "$muted" = true ] || [ "$1" = 0 ]; then icon="$ICON_VOL_OFF"
  elif [ "$1" -lt 34 ]; then icon="$ICON_VOL_LOW"
  elif [ "$1" -lt 67 ]; then icon="$ICON_VOL_MED"
  fi
  sketchybar --set volume icon="$icon" label="$1%" --set vol.slider slider.percentage="$1"
}

outputs() {
  local args=(--remove '/vol\.out\..*/') i=0 current name check
  if command -v SwitchAudioSource >/dev/null 2>&1; then
    current=$(SwitchAudioSource -c -t output 2>/dev/null)
    while IFS= read -r name; do
      [ -n "$name" ] || continue
      check=""
      [ "$name" = "$current" ] && check="$ICON_CHECK"
      args+=(--add item "vol.out.$i" popup.volume
             --set "vol.out.$i" icon="$check" icon.width=22 icon.font="$FONT_MONO:Regular:14.0"
                   icon.padding_left=14 icon.padding_right=4 icon.color="$POPUP_ACCENT"
                   label="$name" label.font="$FONT_UI:Regular:13.0" label.color="$POPUP_TEXT"
                   label.padding_right=14 height=30
                   icon.shadow.drawing=off label.shadow.drawing=off
                   click_script="SwitchAudioSource -t output -s $(printf '%q' "$name") >/dev/null; $(printf '%q' "$CONFIG_DIR/plugins/volume.sh") outputs")
      i=$((i + 1))
    done <<OUT
$(SwitchAudioSource -a -t output 2>/dev/null)
OUT
  fi
  sketchybar "${args[@]}"
}

case "${1:-}" in
  toggle)
    if popup_is_open volume; then popup_close_all; exit 0; fi
    show "$(osascript -e 'output volume of (get volume settings)')"
    outputs
    popup_open volume
    exit 0 ;;
  outputs) outputs; exit 0 ;;
esac

# shellcheck disable=SC2153  # NAME comes from SketchyBar
case "${SENDER:-}" in
  volume_change) show "$INFO" ;;
  mouse.clicked) [ "$NAME" = vol.slider ] && osascript -e "set volume output volume ${PERCENTAGE:-0}" ;;
  mouse.exited.global) sketchybar --set volume popup.drawing=off ;;
  *) show "$(osascript -e 'output volume of (get volume settings)')" ;;
esac
