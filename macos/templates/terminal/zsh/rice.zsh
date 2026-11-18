# {{ meta.name }} shell setup, rendered from ~/dotfiles/macos/templates/terminal/zsh/rice.zsh.
# Edit the template and run render.py; this copy is replaced on every theme switch.
#
# ~/.zshrc sources this as its last line. It leaves PATH alone, only fills variables that are still
# unset, and skips every tool that is not installed.

# Scripts, `zsh -c` and other non-interactive shells get nothing.
[[ -o interactive ]] || return 0

_rice_has() { command -v "$1" >/dev/null 2>&1; }

# Prompt
if _rice_has starship; then
  eval "$(starship init zsh)"
fi

# Jumping around: `cd` learns the folders you visit, `cdi` picks one with fzf.
if _rice_has zoxide; then
  eval "$(zoxide init zsh --cmd cd)"
fi

# Listings
if _rice_has eza; then
  alias ls='eza --icons=auto --group-directories-first'
  alias la='eza -a --icons=auto --group-directories-first'
  alias ll='eza -la --icons=auto --group-directories-first --git'
  alias lt='eza --tree --level=2 --icons=auto'
fi

# bat follows the terminal's ANSI colors, so it changes with the theme.
if _rice_has bat; then
  export BAT_THEME="${BAT_THEME:-ansi}"
  [[ -n ${MANPAGER-} ]] || export MANPAGER="sh -c 'col -bx | bat --language=man --plain'"
  [[ -n ${MANROFFOPT-} ]] || export MANROFFOPT=-c
  alias cat='bat --paging=never --style=plain'
fi

# fzf colors come from the palette. A value set elsewhere is kept.
if _rice_has fzf; then
  _rice_fzf='--color=fg:{{ subtext }},fg+:{{ text }},bg:-1,bg+:{{ surface0 }}'
  _rice_fzf+=' --color=hl:{{ accent }},hl+:{{ accent }},query:{{ text }},info:{{ info }}'
  _rice_fzf+=' --color=prompt:{{ accent }},pointer:{{ accent }},marker:{{ ok }},spinner:{{ accent2 }}'
  _rice_fzf+=' --color=header:{{ overlay }},border:{{ surface2 }},label:{{ accent2 }},gutter:-1'
  _rice_fzf+=' --color=separator:{{ surface1 }},scrollbar:{{ surface2 }}'
  if [[ -z ${FZF_DEFAULT_OPTS-} || $FZF_DEFAULT_OPTS == "${DOTFILES_FZF_OPTS-}" ]]; then
    export FZF_DEFAULT_OPTS="$_rice_fzf"
  fi
  export DOTFILES_FZF_OPTS="$_rice_fzf"
  unset _rice_fzf
  # Ctrl+T files, Ctrl+R history, Option+C folders (fzf 0.48 and newer).
  if _rice_fzf_init="$(fzf --zsh 2>/dev/null)"; then
    eval "$_rice_fzf_init"
  fi
  unset _rice_fzf_init
fi

# `y` opens yazi and moves the shell to the folder yazi was in when it quit.
if _rice_has yazi; then
  y() {
    local tmp cwd
    tmp="$(mktemp -t yazi-cwd.XXXXXX)" || return
    yazi "$@" --cwd-file="$tmp"
    cwd="$(<"$tmp")"
    [[ -n $cwd && $cwd != "$PWD" && -d $cwd ]] && builtin cd -- "$cwd"
    rm -f -- "$tmp"
  }
fi

rice() { builtin cd -- "$HOME/dotfiles"; }

# Greeting: fastfetch once per Ghostty window or tab. Nested shells inherit DOTFILES_GREETED and stay quiet,
# and so do SSH sessions, tmux, editor terminals and splits too small to fit the logo.
if [[ ${TERM_PROGRAM-} == ghostty && -z ${DOTFILES_GREETED-} && -t 1 ]] \
  && [[ -z ${SSH_CONNECTION-}${SSH_TTY-}${TMUX-}${INSIDE_EMACS-}${TERMINAL_EMULATOR-}${VSCODE_INJECTION-} ]] \
  && (( COLUMNS >= 80 && LINES >= 20 )) && _rice_has fastfetch; then
  export DOTFILES_GREETED=1
  if [[ -r "$HOME/Library/Application Support/dotfiles/art/{{ meta.slug }}/logo.png" ]]; then
    fastfetch
  else
    # The art step has not run yet: the small built-in Apple logo stands in.
    fastfetch --logo macos_small --logo-type builtin
  fi
fi

unfunction _rice_has
