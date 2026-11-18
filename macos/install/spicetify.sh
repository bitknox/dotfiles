#!/bin/bash
# Copies the Dotfiles theme into Spicetify's Themes folder, selects it, then applies. The first run
# takes Spicetify's backup of Spotify; later runs only apply.
set -u
# shellcheck source-path=SCRIPTDIR source=lib.sh
. "$(dirname "$0")/lib.sh"

# True when config-xpui.ini records a backup ([Backup] with a version).
backed_up() {
  [ -f "$1" ] || return 1
  awk '/^[[:space:]]*\[/ { sec = $0; gsub(/[][[:space:]]/, "", sec); next }
       sec == "Backup" && /^[[:space:]]*version[[:space:]]*=[[:space:]]*[^[:space:]]/ { found = 1 }
       END { exit !found }' "$1"
}

case "${1:-}" in
  check)
    have python3 || { echo "python3 is missing"; exit 1; }
    have spicetify || { echo "spicetify is not installed"; exit 1; }
    has_app Spotify || { echo "Spotify is not installed"; exit 1; }
    [ -d "$HOME/Library/Application Support/Spotify" ] || { echo "Spotify has never run (open it and log in once)"; exit 1; }
    ;;
  run)
    userdata="$(spicetify path userdata 2>/dev/null | tail -n 1)"
    [ -n "$userdata" ] || die "spicetify path userdata printed nothing"
    cfg="$userdata/config-xpui.ini"
    [ -f "$cfg" ] || spicetify config >/dev/null || die "spicetify could not create its config"
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' EXIT
    out="$(render --out "$tmp" --only apps/spicetify 2>&1)" || { printf '%s\n' "$out" >&2; die "render failed"; }
    keep_file "$cfg"
    keep_file "$userdata/Themes/Dotfiles"
    mkdir -p "$userdata/Themes/Dotfiles"
    cp "$tmp/apps/spicetify/Dotfiles/color.ini" "$tmp/apps/spicetify/Dotfiles/user.css" "$userdata/Themes/Dotfiles/"
    say "copied the theme into $userdata/Themes/Dotfiles"
    spicetify config current_theme Dotfiles color_scheme Dotfiles inject_css 1 replace_colors 1 || die "spicetify config failed"
    if backed_up "$cfg"; then
      spicetify apply || die "spicetify apply failed"
    else
      spicetify backup apply || die "spicetify backup apply failed"
    fi
    ;;
  *) die "usage: $0 check|run" ;;
esac
