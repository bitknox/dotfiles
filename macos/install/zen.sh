#!/bin/bash
# Copies userChrome.css and userContent.css into the default Zen profile and adds the prefs from
# user.js that the profile lacks (existing prefs stay). The profile comes from profiles.ini, never
# a hardcoded folder. Restart Zen to load the styles.
set -u
# shellcheck source-path=SCRIPTDIR source=lib.sh
. "$(dirname "$0")/lib.sh"

ZEN="$HOME/Library/Application Support/zen"

# The profile Zen opens: the Install section's Default, else the profile marked Default=1, else the first.
zen_profile() {
  [ -f "$ZEN/profiles.ini" ] || return 1
  python3 -I - "$ZEN" <<'PY'
import configparser, os, sys
root = sys.argv[1]
ini = configparser.RawConfigParser(strict=False)
ini.optionxform = str
ini.read(os.path.join(root, "profiles.ini"), encoding="utf-8")
installs = [s for s in ini.sections() if s.startswith("Install") and ini.get(s, "Default", fallback="")]
profiles = [s for s in ini.sections() if s.startswith("Profile")]
path, relative = None, True
if installs:
    path = ini.get(installs[0], "Default")
    match = [s for s in profiles if ini.get(s, "Path", fallback="") == path]
    relative = not match or ini.get(match[0], "IsRelative", fallback="1") == "1"
else:
    marked = [s for s in profiles if ini.get(s, "Default", fallback="") == "1"] or profiles
    if marked:
        path = ini.get(marked[0], "Path", fallback=None)
        relative = ini.get(marked[0], "IsRelative", fallback="1") == "1"
if not path:
    sys.exit(1)
full = os.path.join(root, path) if relative and not os.path.isabs(path) else path
if not os.path.isdir(full):
    sys.exit(1)
print(full)
PY
}

case "${1:-}" in
  check)
    have python3 || { echo "python3 is missing"; exit 1; }
    zen_profile >/dev/null || { echo "no Zen profile yet (open Zen once)"; exit 1; }
    ;;
  run)
    profile="$(zen_profile)" || die "no Zen profile found in $ZEN/profiles.ini"
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' EXIT
    out="$(render --out "$tmp" --only apps/zen 2>&1)" || { printf '%s\n' "$out" >&2; die "render failed"; }
    keep_file "$profile/chrome"
    keep_file "$profile/user.js"
    mkdir -p "$profile/chrome"
    cp "$tmp/apps/zen/chrome/userChrome.css" "$tmp/apps/zen/chrome/userContent.css" "$profile/chrome/"
    say "copied chrome/ into $profile"
    touch "$profile/user.js"
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      if ! grep -qxF "$line" "$profile/user.js"; then
        printf '%s\n' "$line" >> "$profile/user.js"
        say "user.js += $line"
      fi
    done < "$tmp/apps/zen/user.js"
    say "restart Zen to load the styles"
    ;;
  *) die "usage: $0 check|run" ;;
esac
