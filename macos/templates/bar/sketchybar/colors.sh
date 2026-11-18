#!/bin/bash
# shellcheck disable=SC2034  # sourced by the plugins
# Rendered from palettes/{{ meta.slug }}.json. SketchyBar colors are 0xAARRGGBB.

THEME="{{ meta.slug }}"
FLAIR="{{ meta.flair }}"

# Bar text sits on the wallpaper with no backing, the way the native menu bar does. Each theme picks
# ink that reads on its own picture and a one pixel halo below it in the opposite tone.
BAR_FG={{ bar_fg | argb }}
BAR_DIM={{ bar_dim | argb }}
BAR_ACCENT={{ bar_accent | argb }}
BAR_HALO={{ bar_halo | argb:80 }}

# Popups are glass panels in the theme's own dark base.
POPUP_BG={{ base | argb:c7 }}
POPUP_RING=0x1fffffff
POPUP_TEXT={{ text | argb }}
POPUP_SUB={{ subtext | argb }}
POPUP_ACCENT={{ accent | argb }}
POPUP_ON_ACCENT={{ base | argb }}
POPUP_TRACK={{ subtext | argb:38 }}

# The bar runs under launchd; make sure Homebrew tools (jq, media-control, SwitchAudioSource) resolve.
PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

# Shared state between the plugins and theme.sh, which run with different TMPDIRs.
BAR_CACHE="$HOME/.cache/sketchybar"

FONT_UI="{{ font.ui }}"
FONT_MONO="{{ font.mono }}"
FONT_DISPLAY="{{ font.display }}"
