# shellcheck shell=bash disable=SC2034  # sourced; the variables are for the steps
# Shared helpers for macos/install/*.sh, theme.sh and install.sh. Source it, don't run it.
# Written for the bash 3.2 that ships with macOS: no associative arrays, no ${x,,}, no mapfile.
#
# Step scripts follow one contract:
#   install/<step>.sh check   exit 0 when the step can run; otherwise print one line saying why not
#   install/<step>.sh run     do the work; safe to run again
# Every step backs up what it replaces: files through render.py --backup or keep_file,
# defaults values through keep_default. Originals live in macos/backup/ and are never overwritten.

MAC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(dirname "$MAC")"
GEN="$MAC/generated"
BACKUP="$MAC/backup"
STATE="$HOME/Library/Application Support/dotfiles"
ART="$STATE/art"

say()  { printf '  %s\n' "$*"; }
warn() { printf '  ! %s\n' "$*" >&2; }
die()  { printf '  x %s\n' "$*" >&2; exit 1; }

have() { command -v "$1" >/dev/null 2>&1; }

# app_path "Visual Studio Code" -> /Applications/Visual Studio Code.app (or ~/Applications), empty if missing
app_path() {
  local d
  for d in "/Applications/$1.app" "$HOME/Applications/$1.app"; do
    [ -d "$d" ] && { printf '%s\n' "$d"; return 0; }
  done
  return 1
}
has_app() { app_path "$1" >/dev/null; }

# The theme this machine uses: .current-theme, else the first line of macos/themes.
current_theme() {
  if [ -s "$MAC/.current-theme" ]; then tr -d '[:space:]' < "$MAC/.current-theme"; return; fi
  head -n 1 "$MAC/themes" | tr -d '[:space:]'
}

# pal colors.base | pal roles.accent | pal name   (reads the resolved generated/palette.json)
pal() {
  python3 -I - "$GEN/palette.json" "$1" <<'PY'
import json, sys
p = json.load(open(sys.argv[1], encoding="utf-8"))
v = p
for k in sys.argv[2].split("."):
    v = v[k]
if sys.argv[2].startswith("roles."):
    v = p["colors"][v]
print(v)
PY
}

# wallpaper_json <theme> <path>, e.g. wallpaper_json frieren wallpaper.url
wallpaper_json() {
  python3 -I - "$MAC/wallpapers.json" "$1" "$2" <<'PY'
import json, sys
v = json.load(open(sys.argv[1], encoding="utf-8"))[sys.argv[2]]
for k in sys.argv[3].split("."):
    v = v[k]
print(" ".join(map(str, v)) if isinstance(v, list) else v)
PY
}

render() { python3 "$ROOT/render.py" --os macos "$@"; }

# keep_file <path>: copy the first original of a file or folder into backup/originals before we touch it.
keep_file() {
  local src="$1" dst
  [ -e "$src" ] || return 0
  dst="$BACKUP/originals${src}"
  [ -e "$dst" ] && return 0
  mkdir -p "$(dirname "$dst")"
  cp -Rp "$src" "$dst"
  say "kept original $src"
}

# keep_default <domain> <key>: record the current value once, so restore can put it back.
# backup/defaults.tsv lines: domain<TAB>key<TAB>type<TAB>value, where type "missing" means unset.
keep_default() {
  local domain="$1" key="$2" file="$BACKUP/defaults.tsv" value type
  mkdir -p "$BACKUP"
  touch "$file"
  if awk -F'\t' -v d="$domain" -v k="$key" '$1==d && $2==k {f=1} END {exit !f}' "$file"; then return 0; fi
  if value="$(defaults read "$domain" "$key" 2>/dev/null)"; then
    type="$(defaults read-type "$domain" "$key" 2>/dev/null | awk '{print $NF}')"
  else
    type="missing"; value=""
  fi
  printf '%s\t%s\t%s\t%s\n' "$domain" "$key" "$type" "$value" >> "$file"
}

# set_default <domain> <key> <-bool|-int|-float|-string> <value>: keep the original, then write.
set_default() {
  keep_default "$1" "$2"
  defaults write "$1" "$2" "$3" "$4"
}

# download <url> <dest>: fetch once; an existing file is reused.
download() {
  [ -s "$2" ] && return 0
  mkdir -p "$(dirname "$2")"
  curl -fsSL --retry 2 -A "dotfiles-installer" -o "$2.part" "$1" && mv "$2.part" "$2"
}
