#!/bin/bash
# Step: source rice.zsh from ~/.zshrc and let starship draw the prompt.
#
# Two edits, nothing else: one line at the end of ~/.zshrc that sources ~/.config/zsh/rice.zsh when it
# exists, and an active ZSH_THEME= line turned into a comment that starts with "# rice: ". PATH lines,
# plugins and everything else stay as they are. The first original is kept in backup/originals.
set -u
# shellcheck source-path=SCRIPTDIR source=lib.sh
. "$(dirname "$0")/lib.sh"

ZSHRC="$HOME/.zshrc"
LINE='[ -f ~/.config/zsh/rice.zsh ] && source ~/.config/zsh/rice.zsh'

case "${1:-}" in
  check)
    have zsh || { echo "zsh is missing"; exit 1; }
    exit 0
    ;;
  run)
    keep_file "$ZSHRC"
    [ -e "$ZSHRC" ] || : > "$ZSHRC"
    tmp="$(mktemp -t rice-zshrc)" || die "could not create a temporary file"
    # Comment out an active theme line; already commented lines start with # and are left alone.
    awk '/^[[:space:]]*(export[[:space:]]+)?ZSH_THEME=/ { print "# rice: " $0; next } { print }' "$ZSHRC" > "$tmp" \
      || { rm -f "$tmp"; die "could not read $ZSHRC"; }
    if ! grep -qxF "$LINE" "$tmp"; then
      # Finish an unterminated last line before appending.
      if [ -s "$tmp" ] && [ -n "$(tail -c 1 "$tmp")" ]; then printf '\n' >> "$tmp"; fi
      printf '%s\n' "$LINE" >> "$tmp"
    fi
    if cmp -s "$tmp" "$ZSHRC"; then
      say ".zshrc already sources rice.zsh"
    else
      # Write through the existing file, so a symlinked .zshrc stays a symlink.
      cat "$tmp" > "$ZSHRC" || { rm -f "$tmp"; die "could not write $ZSHRC"; }
      say ".zshrc now sources rice.zsh"
    fi
    rm -f "$tmp"
    have starship || warn "starship is not installed yet, so the old prompt stays until it is"
    say "open a new terminal window to see the prompt"
    ;;
  *)
    die "usage: $0 check|run"
    ;;
esac
