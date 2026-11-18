#!/bin/bash
# Renders the JetBrains color scheme once per theme in macos/themes and copies both files into
# the colors folder of every Android Studio version found. Pick the scheme in Settings, Editor,
# Color Scheme after a restart.
set -u
# shellcheck source-path=SCRIPTDIR source=lib.sh
. "$(dirname "$0")/lib.sh"

GOOGLE="$HOME/Library/Application Support/Google"

theme_slugs() { sed -e 's/[[:space:]]//g' -e '/^$/d' "$MAC/themes"; }

# Print every Android Studio config folder, one per line (stable and preview versions).
studio_dirs() {
  local d
  for d in "$GOOGLE"/AndroidStudio*; do
    [ -d "$d" ] && printf '%s\n' "$d"
  done
}

case "${1:-}" in
  check)
    have python3 || { echo "python3 is missing"; exit 1; }
    [ -n "$(studio_dirs)" ] || { echo "no Android Studio config folder in $GOOGLE (open Android Studio once)"; exit 1; }
    ;;
  run)
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' EXIT
    slugs=""
    for slug in $(theme_slugs); do
      out="$(render --theme "$slug" --out "$tmp/$slug" --only editors/jetbrains 2>&1)" || { printf '%s\n' "$out" >&2; die "render failed for $slug"; }
      slugs="$slugs $slug"
    done
    while IFS= read -r dir; do
      [ -n "$dir" ] || continue
      mkdir -p "$dir/colors"
      for slug in $slugs; do
        dst="$dir/colors/dotfiles-$slug.icls"
        keep_file "$dst"
        cp "$tmp/$slug/editors/jetbrains/dotfiles.icls" "$dst"
        say "copied $dst"
      done
    done <<EOT
$(studio_dirs)
EOT
    say "restart Android Studio, then pick the scheme in Settings, Editor, Color Scheme"
    ;;
  *) die "usage: $0 check|run" ;;
esac
