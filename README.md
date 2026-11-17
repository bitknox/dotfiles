# Ahri Spirit Blossom — Windows 11 rice

Night-violet base, sakura accent, lavender and spirit-teal highlights. One palette (`palette.json`) is rendered into every app's native theme format. No tiling WM: Zebar top bar + the native taskbar restyled as a centered dock.

```powershell
git clone <this repo> $HOME\dotfiles; cd $HOME\dotfiles
powershell -ExecutionPolicy Bypass -File .\install.ps1 -DryRun   # see the plan
powershell -ExecutionPolicy Bypass -File .\install.ps1           # do it
```

## Components

| Component | Tool | Config in repo |
|---|---|---|
| Top bar | Zebar 3.x (`glzr-io.zebar`) | `templates/zebar/ahri-blossom/` → `install/zebar.ps1` |
| Taskbar → centered dock | Windhawk *Windows 11 Taskbar Styler* (DockLike) | `templates/windhawk/windows-11-taskbar-styler.json`, `install/taskbar.ps1` |
| Start menu | Windhawk *Windows 11 Start Menu Styler* | `templates/windhawk/windows-11-start-menu-styler.json` |
| Notification center | Windhawk *Windows 11 Notification Center Styler* (TranslucentShell) | `templates/windhawk/windows-11-notification-center-styler.json` |
| Explorer | Windhawk *Windows 11 File Explorer Styler* (Translucent Explorer11, acrylic) | `templates/windhawk/windows-11-file-explorer-styler.json` |
| Window borders | Windhawk *window-border-customizer* (sakura focused, surface2 unfocused) | `templates/windhawk/window-border-customizer.json` |
| Intellihide (inactive) | Windhawk *taskbar-auto-hide-when-maximized* (`mode: never`) | `templates/windhawk/taskbar-auto-hide-when-maximized.json` |
| Launcher | Flow Launcher 2.x, Alt+Space | `templates/flow/AhriBlossom.xaml`, `install/flow.ps1`, `install/powertoys.ps1` (frees Alt+Space) |
| Context menu | Nilesoft Shell | `templates/nilesoft/imports/theme.nss`, `install/nilesoft.ps1` |
| Terminal | Windows Terminal (scheme, theme, profiles) | `templates/terminal/wt-patch.json` → `install/wt.py` |
| Shell | pwsh 7 + 5.1 profile, Starship, PSReadLine colors, zoxide/eza/bat/yazi | `templates/terminal/profile.ps1`, `templates/terminal/starship.toml` |
| Greeter | fastfetch, pre-encoded sixel logo | `templates/terminal/fastfetch/config.jsonc`, `install/fastfetch-art.{ps1,py}` |
| Visualizer | cava (WT profile "cava") | `templates/terminal/cava/config` |
| Cursors | "Ahri Blossom", recolored Bibata | `assets/cursors/ahri-blossom/` (built by `install/cursors.py`), `install/apply-cursors.ps1` |
| Fonts | Maple Mono NF v7.9, Shippori Mincho | `install/fonts.ps1` |
| Accent / dark mode | registry (Personalize, Accent, DWM) | `install/accent.ps1` |
| Wallpaper | Wallpaper Engine, workshop 2184359275, 60 fps | `install/wallpaper.ps1` |
| Lock screen | Spirit Blossom splash (CommunityDragon) | `install/lockscreen.ps1` |
| Discord | Vencord theme | `templates/apps/discord/` |
| Spotify | Spicetify theme `AhriBlossom`, scheme `Blossom` | `templates/apps/spicetify/AhriBlossom/` |
| Zen | `userChrome.css` / `userContent.css` + add-on list | `templates/apps/zen/`, `install/zen-extensions.txt`, `install/zen-addons.ps1` |
| OBS | `.ovt` theme | `templates/apps/obs/` |
| VS Code / Cursor | theme extension, packed to `.vsix` locally | `templates/editors/vscode/`, `install/vscode-theme.ps1` |
| Neovim (LazyVim) | `colors/ahri-blossom.lua` + lualine theme | `templates/editors/nvim/` |
| JetBrains | `.icls` color scheme | `templates/editors/jetbrains/` |
| Notepad++ | Style Configurator theme | `templates/editors/notepadpp/` |
| Telegram | `.tdesktop-theme` | `templates/apps/telegram/` |

Fonts: **Maple Mono NF** for terminal, bar, and code. **Segoe UI Variable** for menus, Flow, and Start. **Shippori Mincho** for the bar clock (`font.display`). Every other app keeps its native UI font.

## How theming works

```
palette.json ──► templates/** ──render.py──► generated/** ──deploy.d/*.json──► app config dirs
 colors, roles,    {{ sakura }} placeholders     (gitignored)      group/src/dst/if_exists
 fonts, name
```

- `palette.json` holds `colors` (hex), `roles` (`accent → sakura`, `border_inactive → surface2`, …), `fonts` (`mono`, `ui`, `display`), `name` and `slug`.
- Placeholders: `{{ key }}` gives `#f4a7c8`. Filters: `strip`, `rgb`, `rgbs`, `rgba:0.6`, `hexa:cc`, `abgr` (Windows DWORD), `bgrhex`, `r`/`g`/`b`, `ansi`/`ansibg`. `{{ font.mono }}` and `{{ meta.name }}` also work. Go-template syntax (`{{ .Path }}`, `{{ end }}`) passes through untouched.
- `deploy.d/*.json` is a list of `{group, src, dst, if_exists}`. An entry is skipped when its `if_exists` path is missing, so apps that aren't installed are ignored. Groups: `terminal`, `zebar`, `flow`, `editors`, `discord`, `spotify`, `zen`, `obs`.
- Some targets need more than a file copy, so `install/` handles them: Windhawk (HKLM registry), Nilesoft (Program Files, elevated), WT (JSON merge), Flow (settings merge + restart), VS Code (`.vsix`), accent (registry, reads `palette.json` directly).

```powershell
py -3 render.py --check                     # validate every placeholder, write nothing
py -3 render.py                             # templates/ -> generated/
py -3 render.py --out $env:TEMP\r --only zebar   # render one subtree to a scratch dir
py -3 render.py --deploy                    # render + deploy every group
py -3 render.py --deploy zebar flow         # render + deploy selected groups
```

### Change a color everywhere

1. Edit `palette.json`. Change a `colors` value, or point a `roles` entry at another color. For example, `"accent": "lavender"` moves the accent everywhere.
2. Run `py -3 render.py --check`.
3. Run `.\install.ps1 -Only render,deploy,accent,terminal,flow,nilesoft,zebar,windhawk,vscode-theme,jetbrains,zen,spicetify`.
4. Restart Discord, Zen, and OBS. Hold Ctrl and right-click once to reload Nilesoft.
5. Cursors are prebuilt assets. To recolor them, rebuild with `install/cursors.py` (needs a venv with `resvg-py` and `pillow`; it clones Bibata), then run `-Only cursors`.

## Bootstrap (`install.ps1`)

Run it from a normal (non-elevated) shell. Steps that need admin raise their own UAC prompt. Every step checks its prerequisites first and is skipped with a reason if they're missing. A failed step doesn't stop the run, and a summary table prints at the end. Re-running is safe.

```powershell
.\install.ps1 -List                 # steps + descriptions
.\install.ps1 -DryRun               # what would run / be skipped on this machine right now
.\install.ps1                       # all default steps
.\install.ps1 -All                  # + optional steps (apps, zen-addons)
.\install.ps1 -Only zebar,flow      # just these (optional steps allowed)
.\install.ps1 -Skip wallpaper,lockscreen
.\install.ps1 -Force                # redo steps that detect they're done (fonts, backup, restore point)
```

| Step | Does |
|---|---|
| `backup` | Once: `reg export` of every key the rice changes, plus WT settings and PS profiles, into `backup/pre-rice-<stamp>/`. Also creates the "Pre Ahri rice" restore point (UAC) |
| `packages` | winget: Python 3.13, pwsh, Windows Terminal, Windhawk, Zebar, Flow, fastfetch, Starship, yazi, bat, eza, zoxide, cava, Spicetify, Spotify (non-elevated only). Packages already present are skipped and never upgraded |
| `apps` * | winget: Zen, Discord, Steam, PowerToys, VS Code, Cursor, Neovim, Notepad++, Telegram, OBS |
| `fonts` | Maple Mono NF (checksum-verified) + Shippori Mincho, per-user |
| `render` / `deploy` | `render.py`, then `render.py --deploy` |
| `accent` | dark mode, transparency, accent + AccentPalette; title bars stay dark |
| `terminal` | deploy terminal group, merge WT settings, build the fastfetch sixel |
| `cursors` | apply the cursor scheme (backs up the old one to `backup/cursors-before.reg`) |
| `flow` | theme + settings merge, HKCU Run entry, restart Flow |
| `nilesoft` | installs Nilesoft Shell at machine scope if missing, then copies the theme (elevated) |
| `zebar` | pack, `settings.json` startupConfigs, shell:startup shortcut, restart |
| `windhawk` | writes settings for the installed mods only, and lists the ones still to install |
| `taskbar` | dock always visible, Task View and Search buttons hidden; **restarts Explorer** |
| `powertoys` | disables PowerToys Run / Command Palette (Alt+Space) |
| `wallpaper` | WE fps cap, `overridelockscreen`, opens the workshop wallpaper |
| `lockscreen` | downloads the splash and sets it via WinRT |
| `vscode-theme` | builds the `.vsix` (no node) and installs it into `code` and `cursor` |
| `jetbrains` | copies the `.icls` into every `%APPDATA%\JetBrains\<IDE><ver>\colors` |
| `zen` | resolves the default profile from `profiles.ini`, copies `chrome/`, appends the pref to `user.js` |
| `spicetify` | config, `backup apply` / `apply`, Spotify update block |
| `vencord` | patches Discord with the official Vencord CLI if needed, deploys and enables the theme |
| `zen-addons` * | opens each add-on's AMO page as a Zen tab |

`*` = optional, runs only with `-All` or `-Only`.

`deploy.d` hardcodes this machine's Zen profile (`kk4sqtcv.Default (release)`) and JetBrains versions (`Rider2025.1`, `IdeaIC2023.2`). On a fresh install those entries skip, and the `zen` and `jetbrains` steps find the real paths instead.

### Manual steps

- **Windhawk mods.** Install these in the Windhawk UI (Explore tab), then run `.\install.ps1 -Only windhawk`. The step prints any that are still missing.
  `windows-11-taskbar-styler`, `windows-11-start-menu-styler`, `windows-11-notification-center-styler`, `windows-11-file-explorer-styler`, `window-border-customizer`, `taskbar-auto-hide-when-maximized` (pages: `https://windhawk.net/mods/<id>`)
- **Wallpaper Engine.** Install it via Steam, subscribe to workshop item **2184359275** ("Ahri: Spirit Blossom in 4K"), then run `-Only wallpaper`.
- **Spotify.** Launch it and log in once. Spicetify needs the `prefs` file that creates. Then run `-Only spicetify`.
- **Windows Terminal.** Open it once so `settings.json` exists, then run `-Only terminal`.
- **Apps installed later.** Launch each app once so its config dir exists, then run `-Only deploy`.
- **Telegram.** Open `generated\apps\telegram\ahri-blossom.tdesktop-theme` with Telegram (or send it to Saved Messages and click it), then choose *Keep changes*.
- **JetBrains.** Settings › Editor › Color Scheme › *AhriBlossom*.
- **Notepad++.** Settings › Style Configurator › *AhriBlossom*.
- **OBS.** Settings › Appearance › *AhriBlossom*.
- **VS Code / Cursor.** Select the *Ahri Spirit Blossom* theme if the step reports it isn't active.
- **Neovim.** LazyVim starter in `%LOCALAPPDATA%\nvim`, plus `lua/plugins/colorscheme.lua`, which is not in the repo:
  ```lua
  return { { "LazyVim/LazyVim", opts = { colorscheme = "ahri-blossom" } } }
  ```
- **Zen.** Import bookmarks and passwords from the old browser. Run `-Only zen-addons` and click *Add to Firefox* on each tab. Move Tampermonkey scripts by export and import.

### Not in the repo (on purpose)

- **Riot art.** The fastfetch logo (Data Dragon tile, skin 27) and the lock-screen splash (CommunityDragon) are fetched at install time. They are never committed. Output: `~/.config/fastfetch/ahri.sixel`, `%LOCALAPPDATA%\ahri-rice\lockscreen.jpg`.
- **`generated/`** is derived; regenerate it with `py -3 render.py`.
- **`backup/`** is machine-local.

## When things break

| Symptom | Fix |
|---|---|
| Patch Tuesday: dock/Start/Explorer back to stock | Windhawk mods hook by symbols and lose them when binaries change. Toggle the affected mod off and on in Windhawk to force a fresh symbol lookup, then check the mod page for an update. **Known:** KB5132061 has a symbol issue with these mods. |
| Shell unusable because of a mod | Start Windhawk in safe mode, which loads no mods: `& "C:\Program Files\Windhawk\windhawk.exe" -safe-mode` |
| Discord update dropped Vencord | `.\install.ps1 -Only vencord` re-runs the installer and re-enables the theme |
| Spotify updated, Spicetify gone | Updates are blocked by a deny ACL on `%LOCALAPPDATA%\Spotify\Update`. If one gets through anyway: `spicetify restore backup apply`. To allow updates again: `icacls "$env:LOCALAPPDATA\Spotify\Update" /remove:d $env:USERNAME` |
| Nilesoft menu broken | **Ctrl+Win + right-click** shows the native context menu. Hold Ctrl and right-click to reload the config |
| Bar/dock overlap, maximized windows under the dock | `install\taskbar.ps1` restores the always-visible dock (default). `install\taskbar.ps1 -AutoHide` switches to Windows auto-hide, which suits the intellihide mod |
| Lost the launcher | **Alt+Space** opens Flow. If PowerToys took the hotkey back: `-Only powertoys,flow` |
| Cursors reset after an update | `-Only cursors` (it warns if values revert) |
| Want it all gone | Restore point **"Pre Ahri rice"**. Registry exports and original configs are in `backup/` (`pre-rice-*/*.reg`, `cursors-before.reg`, `*.bak`). Scripts also leave `*.orig` / `*.bak` / `*.ahri-orig` next to the files they replace |

## Design rules

- No colored glows. Elevation is a neutral dark shadow plus a 1px hairline.
- No accent stripes and no gradients. Each surface gets one accent.
- Selection is a solid inverted fill (launcher lists) or a quiet surface step (menus). Never a tinted, translucent wash.
- Radii are modest: 8 for windows, 4 for items. Keyboard-summoned UI has no animation. Hover changes color only, in 150ms or less.
- Apps keep their native fonts. Maple Mono appears only in the terminal, the bar, and code. Menus and the launcher use Segoe UI Variable.
- Readable text never uses `overlay`. That color is for hints and comments only.
