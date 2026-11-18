#!/bin/bash
# Bootstrap for the Mac rice. Safe to re-run any time.
#
# Runs macos/install/<step>.sh in the order below. Each step checks its prerequisites first and is
# skipped, with the reason, when something is missing. A failing step never stops the run, and a
# summary table prints at the end. Everything a step replaces is backed up to macos/backup/ first.
#
#   ./install.sh                 run every default step
#   ./install.sh --list          list the steps
#   ./install.sh --dry-run       show each step, whether it can run right now, and nothing else
#   ./install.sh --only a,b      run just these steps (optional ones included)
#   ./install.sh --skip a,b      run everything except these
#   ./install.sh --all           include the optional steps
set -u
. "$(dirname "$0")/install/lib.sh"

# name|optional|description
STEPS="
brew|0|Homebrew bundle: SketchyBar, JankyBorders, Ghostty, Raycast, Zen, fonts and the CLI tools
render|0|Check every template against both themes, then render the current theme into generated/
deploy|0|Copy generated/ into each app's config folder (deploy.d/*.json), keeping the originals
art|0|Download each theme's wallpaper and cut its fastfetch logo (never committed)
wallpaper|0|Set the current theme's wallpaper on every desktop
shell|0|Source rice.zsh from .zshrc, switch the prompt to starship (keeps your PATH lines)
sketchybar|0|Hide the native menu bar and start SketchyBar
borders|0|Start JankyBorders (focused window in the accent color)
dock|0|Dock auto-hides, smaller, no recent apps
appearance|0|Dark mode, nearest accent color, highlight color from the palette
raycast|0|Install the theme script commands; prints the theme import link to confirm in Raycast
vscode|0|Build the theme extension and install it into VS Code, Insiders and Cursor
xcode|0|Copy both Xcode color themes into place
android-studio|0|Copy the color schemes into every Android Studio version
zen|0|Zen userChrome, userContent and user.js into the default profile
helium|0|Render the Helium (Chromium) theme folder and print how to load it
spicetify|0|Spicetify theme for Spotify, then apply
vencord|0|Vencord theme for Discord
cava|1|cava visualizer config; needs BlackHole 2ch and a multi-output device (changes audio routing)
"

ONLY="" SKIP="" DRY=0 ALL=0 LIST=0
while [ $# -gt 0 ]; do
  case "$1" in
    --only) ONLY=",$2,"; shift ;;
    --skip) SKIP=",$2,"; shift ;;
    --dry-run) DRY=1 ;;
    --all) ALL=1 ;;
    --list) LIST=1 ;;
    -h|--help) sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "unknown option $1 (see --help)" ;;
  esac
  shift
done

if [ "$LIST" = 1 ]; then
  printf '%s\n' "$STEPS" | while IFS='|' read -r name opt desc; do
    [ -n "$name" ] || continue
    [ "$opt" = 1 ] && desc="$desc (optional)"
    printf '  %-15s %s\n' "$name" "$desc"
  done
  exit 0
fi

wanted() { # name optional
  if [ -n "$ONLY" ]; then case "$ONLY" in *",$1,"*) return 0 ;; *) return 1 ;; esac; fi
  case "$SKIP" in *",$1,"*) return 1 ;; esac
  [ "$2" = 0 ] || [ "$ALL" = 1 ]
}

if [ -n "$ONLY$SKIP" ]; then
  for n in $(printf '%s' "$ONLY$SKIP" | tr ',' ' '); do
    printf '%s\n' "$STEPS" | grep -q "^$n|" || die "no step called '$n' (see --list)"
  done
fi

printf 'Mac rice, theme %s%s\n\n' "$(current_theme)" "$([ "$DRY" = 1 ] && echo ', dry run')"
SUMMARY=""
while IFS='|' read -r name opt desc; do
  [ -n "$name" ] || continue
  wanted "$name" "$opt" || continue
  script="$MAC/install/$name.sh"
  printf '%s: %s\n' "$name" "$desc"
  if [ ! -f "$script" ]; then
    result="skipped" note="install/$name.sh is missing"
  elif ! note="$(bash "$script" check 2>&1 </dev/null)"; then
    result="skipped"; note="${note:-prerequisites missing}"
  elif [ "$DRY" = 1 ]; then
    result="ready" note=""
  elif bash "$script" run </dev/null; then   # steps never read this loop's input
    result="done" note=""
  else
    result="failed" note="see the output above"
  fi
  [ "$result" = skipped ] && say "skipped: $note"
  SUMMARY="$SUMMARY$name|$result|$(printf '%s' "$note" | head -n 1)
"
done <<EOF
$STEPS
EOF

printf '\n%-15s %-8s %s\n' step result note
printf '%s' "$SUMMARY" | while IFS='|' read -r name result note; do
  printf '%-15s %-8s %s\n' "$name" "$result" "$note"
done
