#!/bin/bash
# recolor.sh [animate]: apply colors.sh to every item. sketchybarrc runs it at startup; theme.sh runs
# it with "animate" after deploying a new theme, so the colors crossfade straight from one theme to the
# other. Reduce Motion is read, never changed, and turns the crossfade off.

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
. "$CONFIG_DIR/colors.sh"

ANIM=()
if [ "${1:-}" = animate ] && [ "$(defaults read com.apple.universalaccess reduceMotion 2>/dev/null)" != 1 ]; then
  ANIM=(--animate sin 20)
fi

TITLE=$BAR_DIM
[ -e "$BAR_CACHE/media.open" ] && TITLE=$BAR_FG

ARGS=(
  # On the wallpaper: icons in the dim ink, values in the full ink, a halo under both.
  --set '/.*/' icon.color="$BAR_DIM" label.color="$BAR_FG"
               icon.shadow.color="$BAR_HALO" label.shadow.color="$BAR_HALO"
  --set front_app label.color="$BAR_FG"
  --set clock icon="$FLAIR"
  --set media label.color="$TITLE"
  --set media.artist label.color="$BAR_DIM"
  --set '/media\.(prev|play|next)/' icon.color="$BAR_FG"
  --set media.time label.color="$BAR_DIM"
  --set date label.color="$BAR_DIM"

  # Popups: glass in the theme's dark base, text from the main palette.
  --set '/clock|volume|battery/' popup.background.color="$POPUP_BG"
                                 popup.background.border_color="$POPUP_RING"
  --set '/(cal|bat|vol)\..*/' icon.color="$POPUP_TEXT" label.color="$POPUP_TEXT"
  --set cal.head label.color="$POPUP_SUB"
  --set cal.rdays label.color="$POPUP_SUB"
  --set cal.week label.color="$POPUP_SUB"
  --set bat.time label.color="$POPUP_SUB"
  --set vol.outputs icon.color="$POPUP_SUB"
  --set '/vol\.out\..*/' icon.color="$POPUP_ACCENT"
  --set vol.slider slider.highlight_color="$POPUP_ACCENT" slider.background.color="$POPUP_TRACK"
)

# The calendar marks the current week in the accent (calendar.sh records which row that is).
ROW="$(cat "$BAR_CACHE/cal.row" 2>/dev/null)"
[ -n "$ROW" ] && ARGS+=(--set "cal.r$ROW" label.color="$POPUP_ACCENT")

# Menu extras are pictures of the real icons; tint them like the other icons.
while IFS= read -r alias; do
  [ -n "$alias" ] && ARGS+=(--set "$alias" alias.color="$BAR_DIM")
done <<EOF
$(sketchybar --query bar 2>/dev/null | jq -r '.items[] | select(contains(","))' 2>/dev/null)
EOF

sketchybar "${ANIM[@]}" "${ARGS[@]}"
