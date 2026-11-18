#!/bin/bash
# Copies the Dotfiles theme into the themes folder of Vencord (Discord) and Vesktop, whichever is
# present. Enabling it stays a choice in Discord: Vencord settings, Themes.
set -u
# shellcheck source-path=SCRIPTDIR source=lib.sh
. "$(dirname "$0")/lib.sh"

SUPPORT="$HOME/Library/Application Support"

# Print each Vencord data folder that exists, one per line.
vencord_dirs() {
  local d
  for d in "$SUPPORT/Vencord" "$SUPPORT/vesktop"; do
    [ -d "$d" ] && printf '%s\n' "$d"
  done
}

case "${1:-}" in
  check)
    have python3 || { echo "python3 is missing"; exit 1; }
    [ -n "$(vencord_dirs)" ] || { echo "Vencord is not installed (install it, then open Discord once)"; exit 1; }
    ;;
  run)
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' EXIT
    out="$(render --out "$tmp" --only apps/discord 2>&1)" || { printf '%s\n' "$out" >&2; die "render failed"; }
    while IFS= read -r dir; do
      [ -n "$dir" ] || continue
      dst="$dir/themes/dotfiles.theme.css"
      keep_file "$dst"
      mkdir -p "$dir/themes"
      cp "$tmp/apps/discord/dotfiles.theme.css" "$dst"
      say "copied $dst"
    done <<EOT
$(vencord_dirs)
EOT
    say "enable it in Discord: Vencord settings, Themes, then turn on dotfiles.theme.css"
    ;;
  *) die "usage: $0 check|run" ;;
esac
