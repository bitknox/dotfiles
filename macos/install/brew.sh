#!/bin/bash
# Step: install everything in macos/Brewfile. Existing installs are left as they are (no upgrades).
set -u
# shellcheck source-path=SCRIPTDIR source=lib.sh
. "$(dirname "$0")/lib.sh"

case "${1:-}" in
  check)
    have brew || { echo "Homebrew is missing; install it from brew.sh first"; exit 1; }
    ;;
  run)
    # Homebrew only loads formulae from third-party taps once they are trusted. Trust just the one we use.
    brew trust --formula felixkratz/formulae/borders >/dev/null 2>&1 || true
    status=0
    HOMEBREW_NO_AUTO_UPDATE=1 brew bundle --no-upgrade --file "$MAC/Brewfile" || status=1
    # SF Pro: the cask runs Apple's installer with sudo, so unpack its download into ~/Library/Fonts.
    if ! ls "$HOME"/Library/Fonts/SF-Pro-Text-Regular.otf /Library/Fonts/SF-Pro-Text-Regular.otf >/dev/null 2>&1; then
      # Homebrew downloads Apple's disk image; the package inside holds the fonts.
      HOMEBREW_NO_AUTO_UPDATE=1 brew fetch --cask font-sf-pro >/dev/null 2>&1
      dmg="$(brew --cache --cask font-sf-pro 2>/dev/null)"
      tmp="$(mktemp -d)"
      pkg=""
      if [ -s "$dmg" ] && hdiutil attach -nobrowse -readonly -mountpoint "$tmp/dmg" "$dmg" >/dev/null 2>&1; then
        pkg="$(find "$tmp/dmg" -maxdepth 1 -name '*.pkg' | head -n 1)"
      fi
      if [ -n "$pkg" ] && pkgutil --expand-full "$pkg" "$tmp/x" >/dev/null 2>&1; then
        find "$tmp/x" -name 'SF-Pro*.otf' -exec cp {} "$HOME/Library/Fonts/" \;
        say "SF Pro installed for this user"
      else
        warn "could not install SF Pro"
      fi
      [ -d "$tmp/dmg" ] && hdiutil detach "$tmp/dmg" -quiet >/dev/null 2>&1
      rm -rf "$tmp"
    fi
    have borders || status=1
    exit $status
    ;;
  *) die "usage: $0 check|run" ;;
esac
