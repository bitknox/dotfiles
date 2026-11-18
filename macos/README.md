# macOS: Frieren and Shinkai skies

A setup for a 14" MacBook Pro with a notch, in two themes you switch between with one command. Frieren is the default: a night-sky base, moonweed blue accent, silver and gold. Shinkai skies is dark teal water with a sky blue second accent and warm brick. There is no tiling window manager. SketchyBar replaces the menu bar around the notch, JankyBorders outlines the focused window, and the Dock stays hidden until you reach for it.

```sh
git clone https://github.com/bitknox/dotfiles ~/dotfiles
cd ~/dotfiles
macos/install.sh --dry-run   # show the plan
macos/install.sh             # run it
macos/theme.sh shinkai       # switch themes later
```

Commands in this file run from the repo root. File paths are relative to `macos/`. The palettes, the template syntax and `render.py` are described in the [root README](../README.md).

## Components

| Component | Tool | Files |
|---|---|---|
| Top bar | SketchyBar, transparent, split by the notch | `templates/bar/sketchybar/`, `install/sketchybar.sh` |
| Window borders | JankyBorders: accent when focused, surface2 otherwise | `templates/bar/borders/bordersrc`, `install/borders.sh` |
| Dock | `defaults`: hidden, 44 pt, no recent apps | `install/dock.sh` |
| Launcher | Raycast on Option-Space, a theme link per theme, two theme commands | `raycast/`, `install/raycast.sh` |
| Terminal | Ghostty with a generated theme | `templates/terminal/ghostty/` |
| Shell | zsh with Starship, zoxide, eza, bat, fzf and yazi | `templates/terminal/zsh/rice.zsh`, `templates/terminal/starship.toml`, `install/shell.sh` |
| Greeter | fastfetch, logo through the kitty graphics protocol | `templates/terminal/fastfetch/config.jsonc` |
| Visualizer | cava (optional step) | `templates/terminal/cava/config`, `install/cava.sh` |
| Wallpaper | one picture per theme, set on every desktop | `wallpapers.json`, `install/art.sh`, `install/wallpaper.sh` |
| Accent and dark mode | `defaults`: nearest accent preset, selection color from the palette | `install/appearance.sh` |
| Fonts | Maple Mono NF, SF Pro, Shippori Mincho | `Brewfile` |
| Discord | Vencord theme, also copied for Vesktop | `templates/apps/discord/`, `install/vencord.sh` |
| Spotify | Spicetify theme `Dotfiles` | `templates/apps/spicetify/Dotfiles/`, `install/spicetify.sh` |
| Zen | `userChrome.css`, `userContent.css` and the missing `user.js` prefs | `templates/apps/zen/`, `install/zen.sh` |
| Helium | unpacked Chromium theme | `templates/apps/helium/`, `install/helium.sh` |
| VS Code, Insiders and Cursor | one extension holding both themes, packed to `.vsix` locally | `templates/editors/vscode/`, `install/vscode.sh` |
| Xcode | `.xccolortheme`, one per theme | `templates/editors/xcode/`, `install/xcode.sh` |
| Android Studio | `.icls`, one per theme | `templates/editors/jetbrains/`, `install/android-studio.sh` |

Cursors are left alone, because macOS only changes them through an accessibility setting.

## The bar

Like the native menu bar, the bar has no backing. Its text sits on the wallpaper in ink each theme chooses for its own picture: light ink on the Frieren night sky, dark ink on the bright Shinkai water. A one pixel halo under the text keeps it readable where the picture changes. The native menu bar is set to hide itself and still slides in when the pointer touches the top edge.

Left of the notch are the front app's name and now playing. A click on the title shows the artist, the controls and the time. Right of the notch is the clock with the theme's flair; a click opens the calendar. On the far right are the VPN, Tailscale and Bitwarden menu extras, then CPU, memory, Wi-Fi, sound and battery. Sound and battery open popups with an output list and the time left.

The menu extras are live pictures of the real icons, so SketchyBar needs Screen Recording permission (System Settings, Privacy & Security). Now playing reads `media-control`, which sees any player, and falls back to Spotify over AppleScript.

Compared with the design board:

- The calendar marks the current week in the accent, not today's date in a circle. SketchyBar draws one line of text per row.
- Popups open instantly, as native menu bar menus do. SketchyBar can't scale a popup in.
- Now playing has no progress line under it, and the battery popup has no list of apps using a lot of energy.

## Switching themes

```sh
macos/theme.sh           # list the themes, the current one starred
macos/theme.sh shinkai   # switch
```

`theme.sh` writes `.current-theme`, renders and deploys, then has each app pick up the change. The bar crossfades straight to the new colors (instantly with Reduce Motion on). Borders and Ghostty reload in place. The wallpaper, the accent color, Zen, Spotify, Discord and the editor setting `workbench.colorTheme` follow. It ends with what still needs a click: the Raycast theme link, a Zen restart, the Helium reload, and picking the theme in Xcode and Android Studio.

The Raycast commands "Theme: Frieren" and "Theme: Shinkai skies" run the same script. Add `macos/raycast` as a script directory in Raycast settings, under Extensions.

## Bootstrap

`install.sh` runs each script in `install/` in order. Every step checks first and is skipped with the reason when something is missing, a failing step doesn't stop the run, and a summary table prints at the end. Everything a step replaces is kept in `backup/` first: files under `backup/originals/`, `defaults` values in `backup/defaults.tsv`. Running it again is safe.

| Step | What it does |
|---|---|
| `brew` | `brew bundle` with the `Brewfile`. Nothing already installed is upgraded. |
| `render`, `deploy` | Checks every template against both themes, renders the current one, copies it into place. |
| `art` | Downloads each theme's wallpaper and cuts its fastfetch logo, a scenery detail, into `~/Library/Application Support/dotfiles/art/`. |
| `wallpaper` | Sets the current wallpaper on every desktop. |
| `shell` | Adds one line to `.zshrc` that sources `rice.zsh` and comments out `ZSH_THEME`. PATH lines stay. |
| `sketchybar` | Hides the native menu bar and starts SketchyBar as a service. |
| `borders` | Starts JankyBorders as a service. It asks for Accessibility permission once. |
| `dock` | Hidden Dock, 44 pt icons, no recent apps. |
| `appearance` | Dark mode, accent preset and selection color. |
| `raycast` | Prints the script directory to add, the two theme links and the hotkey to set. |
| `vscode`, `xcode`, `android-studio` | Install both editor themes. |
| `zen`, `helium`, `spicetify`, `vencord` | Theme the apps that are present. |
| `cava` (optional) | cava config. Needs BlackHole 2ch and a multi-output device, so it changes audio routing; run it with `--only cava`. |

```sh
macos/install.sh --list            # every step
macos/install.sh --only dock,raycast
macos/install.sh --skip shell
```

## Undoing it

Each first original is in `backup/originals/<absolute path>`; copy it back. `backup/defaults.tsv` lists every `defaults` key the steps changed with its old value, where `missing` means it was unset (`defaults delete` it). Stop the bar and borders with `brew services stop sketchybar borders`.
