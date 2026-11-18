#!/bin/bash
# Step: download each theme's wallpaper and cut its fastfetch logo. Pictures live in
# ~/Library/Application Support/dotfiles/art/<theme>/ and never go into the repo.
#   wallpaper.jpg   the desktop picture
#   logo.png        a square crop of the picture, 512 px, for the fastfetch logo
set -u
# shellcheck source-path=SCRIPTDIR source=lib.sh
. "$(dirname "$0")/lib.sh"

# fetch_theme <theme>: download what is missing, cut the logo once.
fetch_theme() {
  local t="$1" dir="$ART/$1" logo_src x y w h
  download "$(wallpaper_json "$t" wallpaper.url)" "$dir/wallpaper.jpg" || { warn "$t: wallpaper download failed"; return 1; }
  logo_src="$dir/wallpaper.jpg"
  if [ "$(wallpaper_json "$t" logo.url)" != "$(wallpaper_json "$t" wallpaper.url)" ]; then
    logo_src="$dir/logo-source.jpg"
    download "$(wallpaper_json "$t" logo.url)" "$logo_src" || { warn "$t: logo picture download failed"; return 1; }
  fi
  if [ ! -s "$dir/logo.png" ]; then
    read -r x y w h <<<"$(wallpaper_json "$t" logo.crop)"
    # --cropOffset counts from the top-left corner, row first.
    if ! sips -s format png --cropToHeightWidth "$h" "$w" --cropOffset "$y" "$x" \
              "$logo_src" --out "$dir/logo-crop.png" >/dev/null ||
       ! sips -Z 512 "$dir/logo-crop.png" --out "$dir/logo.png" >/dev/null; then
      rm -f "$dir/logo-crop.png"
      warn "$t: could not cut the logo"
      return 1
    fi
    rm -f "$dir/logo-crop.png"
  fi
  say "$t: $dir"
}

case "${1:-}" in
  check)
    have curl || { echo "curl is missing"; exit 1; }
    have sips || { echo "sips is missing"; exit 1; }
    ;;
  run)
    ok=0
    while IFS= read -r t; do [ -n "$t" ] && { fetch_theme "$t" || ok=1; }; done < "$MAC/themes"
    exit $ok
    ;;
  *) die "usage: $0 check|run" ;;
esac
