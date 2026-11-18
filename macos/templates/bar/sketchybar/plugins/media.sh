#!/bin/bash
# Now playing, left of the notch.
#   media.sh                    update (timer, wake)
#   media.sh toggle             reveal or hide artist, controls and time
#   media.sh play|next|previous control playback
# Reads media-control, which sees any player. Without it, falls back to Spotify over AppleScript.

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
. "$CONFIG_DIR/colors.sh"
. "$CONFIG_DIR/icons.sh"

STATE="$BAR_CACHE/media.open"
EXTRAS="media.artist media.prev media.play media.next media.time"

have() { command -v "$1" >/dev/null 2>&1; }
spotify_running() { pgrep -x Spotify >/dev/null 2>&1; }

control() { # play|next|previous
  if have media-control; then
    case "$1" in
      play) media-control toggle-play-pause ;;
      next) media-control next-track ;;
      previous) media-control previous-track ;;
    esac
  elif spotify_running; then
    case "$1" in
      play) osascript -e 'tell application "Spotify" to playpause' ;;
      next) osascript -e 'tell application "Spotify" to next track' ;;
      previous) osascript -e 'tell application "Spotify" to previous track' ;;
    esac
  fi
}

mmss() { printf '%d:%02d' $(($1 / 60)) $(($1 % 60)); }

# Sets TITLE ARTIST PLAYING (1/0) ELAPSED DURATION (seconds) and ART (an image path or empty).
now_playing() {
  TITLE="" ARTIST="" PLAYING=0 ELAPSED=0 DURATION=0 ART=""
  if have media-control; then
    local json
    json="$(media-control get --micros 2>/dev/null)"
    [ -n "$json" ] && [ "$json" != null ] || return 1
    eval "$(printf '%s' "$json" | jq -r --argjson now "$(($(date +%s) * 1000000))" '
      def secs: (. // 0) / 1000000 | floor;
      "TITLE=\(.title // "" | @sh) ARTIST=\(.artist // "" | @sh) PLAYING=\(if .playing then 1 else 0 end)",
      "DURATION=\(.durationMicros | secs)",
      "ELAPSED=\((.elapsedTimeMicros // 0) + (if .playing then $now - (.timestampEpochMicros // $now) else 0 end) | . / 1000000 | floor)"
    ')"
    cover "$json"
  elif spotify_running; then
    local out
    out="$(osascript -e 'tell application "Spotify"
      if player state is stopped then return ""
      set t to current track
      return (name of t) & "\n" & (artist of t) & "\n" & (player state is playing) & "\n" & (round (player position)) & "\n" & ((duration of t) div 1000)
    end tell' 2>/dev/null)"
    [ -n "$out" ] || return 1
    TITLE="$(sed -n 1p <<<"$out")" ARTIST="$(sed -n 2p <<<"$out")"
    [ "$(sed -n 3p <<<"$out")" = true ] && PLAYING=1
    ELAPSED="$(sed -n 4p <<<"$out")" DURATION="$(sed -n 5p <<<"$out")"
  else
    return 1
  fi
  [ -n "$TITLE" ]
}

# Cover art, cut to 40 px (20 pt on the Retina panel) and cached per track.
cover() {
  local key dir file
  key="$(printf '%s' "$TITLE$ARTIST" | md5 -q)"
  dir="$BAR_CACHE/art"
  file="$dir/$key.png"
  if [ ! -s "$file" ]; then
    mkdir -p "$dir"
    find "$dir" -name '*.png' -mmin +60 -delete 2>/dev/null
    printf '%s' "$1" | jq -r '.artworkData // empty' | base64 -D > "$dir/raw" 2>/dev/null
    [ -s "$dir/raw" ] && sips -s format png -z 40 40 "$dir/raw" --out "$file" >/dev/null 2>&1
    rm -f "$dir/raw"
  fi
  [ -s "$file" ] && ART="$file"
}

update() {
  local args=() i
  if ! now_playing; then
    for i in media $EXTRAS; do args+=(--set "$i" drawing=off); done
    sketchybar "${args[@]}"
    return
  fi
  if [ -n "$ART" ]; then
    args+=(--set media icon="" icon.background.drawing=on icon.background.image="$ART")
  else
    args+=(--set media icon="$ICON_MUSIC" icon.background.drawing=off)
  fi
  args+=(--set media drawing=on label="$TITLE")
  if [ -e "$STATE" ]; then
    local play="$ICON_PLAY"
    [ "$PLAYING" = 1 ] && play="$ICON_PAUSE"
    args+=(--set media.artist label="$ARTIST" --set media.play icon="$play")
    if [ "$DURATION" -gt 0 ]; then
      args+=(--set media.time drawing=on label="$(mmss "$ELAPSED") / $(mmss "$DURATION")")
    else
      args+=(--set media.time drawing=off)
    fi
  fi
  sketchybar "${args[@]}"
}

# The extras fade in from clear while the title brightens; hiding is instant, like closing a menu.
toggle() {
  local args=() i
  if [ -e "$STATE" ]; then
    rm -f "$STATE"
    for i in $EXTRAS; do args+=(--set "$i" drawing=off); done
    sketchybar "${args[@]}" --set media label.color="$BAR_DIM" update_freq=5
    return
  fi
  mkdir -p "$BAR_CACHE" && touch "$STATE"
  update
  local clear_fg="0x00${BAR_FG#0xff}" clear_dim="0x00${BAR_DIM#0xff}" clear_halo="0x00${BAR_HALO#0x??}"
  for i in media.artist media.prev media.play media.next; do
    args+=(--set "$i" drawing=on icon.color="$clear_fg" label.color="$clear_dim"
           icon.shadow.color="$clear_halo" label.shadow.color="$clear_halo")
  done
  args+=(--set media.time icon.color="$clear_fg" label.color="$clear_dim"
         icon.shadow.color="$clear_halo" label.shadow.color="$clear_halo")
  sketchybar "${args[@]}" --set media update_freq=1
  "$CONFIG_DIR/recolor.sh" animate   # instant when Reduce Motion is on
}

case "${1:-}" in
  toggle) toggle ;;
  play|next|previous) control "$1"; sleep 0.3; update ;;
  *) update ;;
esac
