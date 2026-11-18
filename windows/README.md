# Windows 11: Spirit Blossom Ahri

A Windows 11 setup with a night-violet base, a sakura pink accent, and lavender and spirit-teal highlights. There is no tiling window manager. Zebar draws a bar along the top, and Windhawk restyles the native taskbar as a centered dock.

```powershell
git clone https://github.com/bitknox/dotfiles $HOME\dotfiles
cd $HOME\dotfiles
powershell -ExecutionPolicy Bypass -File .\windows\install.ps1 -DryRun   # show the plan
powershell -ExecutionPolicy Bypass -File .\windows\install.ps1           # run it
```

Commands in this file run from the repo root. File paths are relative to `windows\`. The palette, the template syntax and `render.py` are described in the [root README](../README.md).

## Components

| Component | Tool | Files |
|---|---|---|
| Top bar | Zebar 3.x (`glzr-io.zebar`) | `templates/zebar/ahri-blossom/`, installed by `install/zebar.ps1` |
| Dock | Windhawk Windows 11 Taskbar Styler, DockLike theme | `templates/windhawk/windows-11-taskbar-styler.json`, `install/taskbar.ps1` |
| Start menu | Windhawk Windows 11 Start Menu Styler | `templates/windhawk/windows-11-start-menu-styler.json` |
| Notification center | Windhawk Windows 11 Notification Center Styler, TranslucentShell | `templates/windhawk/windows-11-notification-center-styler.json` |
| Explorer | Windhawk Windows 11 File Explorer Styler, Translucent Explorer11 with acrylic | `templates/windhawk/windows-11-file-explorer-styler.json` |
| Window borders | Windhawk window-border-customizer: sakura when focused, surface2 otherwise | `templates/windhawk/window-border-customizer.json` |
| Intellihide (off) | Windhawk taskbar-auto-hide-when-maximized, `mode: never` | `templates/windhawk/taskbar-auto-hide-when-maximized.json` |
| Launcher | Flow Launcher 2.x on Alt+Space | `templates/flow/AhriBlossom.xaml`, `install/flow.ps1`, `install/powertoys.ps1` (frees Alt+Space) |
| Context menu | Nilesoft Shell | `templates/nilesoft/imports/theme.nss`, `install/nilesoft.ps1` |
| Terminal | Windows Terminal scheme, theme and profiles | `templates/terminal/wt-patch.json`, merged by `install/wt.py` |
| Shell | pwsh 7 and 5.1 profile, Starship, PSReadLine colors, zoxide, eza, bat, yazi | `templates/terminal/profile.ps1`, `templates/terminal/starship.toml` |
| Greeter | fastfetch with a pre-encoded sixel logo | `templates/terminal/fastfetch/config.jsonc`, `install/fastfetch-art.ps1` and `.py` |
| Visualizer | cava, opened from the "cava" Terminal profile | `templates/terminal/cava/config` |
| Cursors | "Ahri Blossom", a recolored Bibata | `assets/cursors/ahri-blossom/` (built by `install/cursors.py`), `install/apply-cursors.ps1` |
| Fonts | Maple Mono NF v7.9, Shippori Mincho | `install/fonts.ps1` |
| Accent and dark mode | registry (Personalize, Accent, DWM) | `install/accent.ps1` |
| Wallpaper | Wallpaper Engine, workshop item 2184359275, capped at 60 fps | `install/wallpaper.ps1` |
| Lock screen | Spirit Blossom splash from CommunityDragon | `install/lockscreen.ps1` |
| Discord | Vencord theme | `templates/apps/discord/` |
| Spotify | Spicetify theme `AhriBlossom`, scheme `Blossom` | `templates/apps/spicetify/AhriBlossom/` |
| Zen | `userChrome.css` and `userContent.css`, plus an add-on list | `templates/apps/zen/`, `install/zen-extensions.txt`, `install/zen-addons.ps1` |
| OBS | `.ovt` theme | `templates/apps/obs/` |
| VS Code and Cursor | theme extension, packed to `.vsix` locally | `templates/editors/vscode/`, `install/vscode-theme.ps1` |
| Neovim (LazyVim) | colorscheme, lualine theme and the plugin spec that selects them | `templates/editors/nvim/` |
| JetBrains | `.icls` color scheme | `templates/editors/jetbrains/` |
| Notepad++ | Style Configurator theme | `templates/editors/notepadpp/` |
| Telegram | `.tdesktop-theme` | `templates/apps/telegram/` |

Maple Mono NF is used in the terminal, the bar and code. Menus, Flow and Start use Segoe UI Variable, and the bar clock's kanji uses Shippori Mincho (`font.display`). Every other app keeps its own UI font.

## Deploying

`py -3 render.py --deploy` handles everything that is a plain file copy. The groups are `terminal`, `zebar`, `flow`, `editors`, `discord`, `spotify`, `zen` and `obs`.

The rest goes through `install/`:

- Windhawk settings live in the HKLM registry, so `install/windhawk.py` imports them with elevation.
- Nilesoft lives under Program Files and also needs elevation.
- Windows Terminal settings are merged into your existing `settings.json`, which keeps your own keybindings and profiles.
- Flow's settings are merged, and Flow is restarted.
- The VS Code theme is packed into a `.vsix` and installed.
- The accent color is written to the registry straight from `palette.json`.

`deploy.d` hardcodes this machine's Zen profile (`kk4sqtcv.Default (release)`) and JetBrains versions (`Rider2025.1`, `IdeaIC2023.2`). On another machine those entries are skipped, and the `zen` and `jetbrains` install steps look up the real paths.

### Changing a color everywhere

1. Edit `../palette.json`. Change a value under `colors`, or point a role somewhere else. For example, `"accent": "lavender"` changes the accent in every app.
2. Run `py -3 render.py --check`.
3. Run `.\windows\install.ps1 -Only render,deploy,accent,terminal,flow,nilesoft,zebar,windhawk,vscode-theme,jetbrains,zen,spicetify`.
4. Restart Discord, Zen and OBS. Ctrl + right-click once reloads Nilesoft.
5. The cursors are prebuilt. To recolor them, run `install/cursors.py` (it needs a venv with `resvg-py` and `pillow`, and clones Bibata), then `-Only cursors`.

## Bootstrap

Run `install.ps1` from a normal, non-elevated shell. Steps that need admin raise their own UAC prompt. Each step checks its prerequisites first and is skipped with a reason when something is missing. A failed step doesn't stop the run, and a summary table prints at the end. Re-running is safe.

```powershell
.\windows\install.ps1 -List                 # steps and descriptions
.\windows\install.ps1 -DryRun               # what would run or be skipped on this machine right now
.\windows\install.ps1                       # all default steps
.\windows\install.ps1 -All                  # also the optional steps (apps, zen-addons)
.\windows\install.ps1 -Only zebar,flow      # just these, optional steps allowed
.\windows\install.ps1 -Skip wallpaper,lockscreen
.\windows\install.ps1 -Force                # redo steps that detect they're done (fonts, backup, restore point)
```

| Step | What it does |
|---|---|
| `backup` | Runs once. Exports every registry key the setup changes, plus Terminal settings and PowerShell profiles, to `backup/pre-rice-<stamp>/`, and creates a "Pre Ahri rice" restore point (UAC). |
| `packages` | Installs with winget: Python 3.13, pwsh, Windows Terminal, Windhawk, Zebar, Flow, fastfetch, Starship, yazi, bat, eza, zoxide, cava, Spicetify, and Spotify (non-elevated only). Packages already present are skipped and never upgraded. |
| `apps` (optional) | Installs with winget: Zen, Discord, Steam, PowerToys, VS Code, Cursor, Neovim, Notepad++, Telegram, OBS. |
| `fonts` | Maple Mono NF (checksum verified) and Shippori Mincho, per user. |
| `render`, `deploy` | `render.py`, then `render.py --deploy`. |
| `accent` | Dark mode, transparency, accent color and AccentPalette. Title bars stay dark. |
| `terminal` | Deploys the terminal group, merges the Terminal settings, builds the fastfetch sixel. |
| `cursors` | Applies the cursor scheme. The previous one is saved to `backup/cursors-before.reg`. |
| `flow` | Theme, settings merge, HKCU Run entry, Flow restart. |
| `nilesoft` | Installs Nilesoft Shell at machine scope if it's missing, then copies the theme (elevated). |
| `zebar` | Copies the widget pack, sets `startupConfigs` in Zebar's `settings.json`, adds a startup shortcut, restarts Zebar. |
| `windhawk` | Writes settings for the mods that are installed and lists the ones that aren't. |
| `taskbar` | Keeps the dock always visible and hides the Task View and Search buttons. This restarts Explorer. |
| `powertoys` | Turns off PowerToys Run and Command Palette so Flow can have Alt+Space. |
| `wallpaper` | Sets the Wallpaper Engine fps cap and `overridelockscreen`, then opens the workshop wallpaper. |
| `lockscreen` | Downloads the splash and sets it through WinRT. |
| `vscode-theme` | Builds the `.vsix` without Node and installs it into `code` and `cursor`. |
| `jetbrains` | Copies the `.icls` into every `%APPDATA%\JetBrains\<IDE><version>\colors`. |
| `zen` | Finds the default profile in `profiles.ini`, copies `chrome/` and appends the stylesheet pref to `user.js`. |
| `spicetify` | Configures Spicetify, runs `backup apply` or `apply`, and blocks Spotify self-updates. |
| `vencord` | Patches Discord with the official Vencord CLI when needed, then deploys and enables the theme. |
| `zen-addons` (optional) | Opens each add-on's page on addons.mozilla.org as a tab in Zen. |

Optional steps only run with `-All` or when named in `-Only`.

### Manual steps

| App | What to do |
|---|---|
| Windhawk | Install the mods from the Explore tab, then run `-Only windhawk`. The step prints any that are still missing. The mods are `windows-11-taskbar-styler`, `windows-11-start-menu-styler`, `windows-11-notification-center-styler`, `windows-11-file-explorer-styler`, `window-border-customizer` and `taskbar-auto-hide-when-maximized` (pages at `https://windhawk.net/mods/<id>`). |
| Wallpaper Engine | Install it through Steam, subscribe to workshop item 2184359275 ("Ahri: Spirit Blossom in 4K"), then run `-Only wallpaper`. |
| Spotify | Launch it and log in once, because Spicetify needs the `prefs` file that creates. Then run `-Only spicetify`. |
| Windows Terminal | Open it once so `settings.json` exists, then run `-Only terminal`. |
| Apps installed later | Launch the app once so its config folder exists, then run `-Only deploy`. |
| Telegram | Open `generated\apps\telegram\ahri-blossom.tdesktop-theme` with Telegram (or send it to Saved Messages and click it), then choose Keep changes. |
| JetBrains | Settings, Editor, Color Scheme, AhriBlossom. |
| Notepad++ | Settings, Style Configurator, AhriBlossom. |
| OBS | Settings, Appearance, AhriBlossom. |
| VS Code and Cursor | Pick the Ahri Spirit Blossom theme if the step reports that it isn't active. |
| Neovim | Install the LazyVim starter into `%LOCALAPPDATA%\nvim`. The `editors` deploy group then adds the colorscheme and the plugin spec that turns it on. |
| Zen | Import bookmarks and passwords from your old browser. Run `-Only zen-addons` and click Add to Firefox on each tab. Move Tampermonkey scripts with its export and import. |

## When things break

| Symptom | Fix |
|---|---|
| After Patch Tuesday the dock, Start or Explorer look stock again | Windhawk mods find their hooks through debug symbols, which change with each update. Turn the affected mod off and on in Windhawk to force a fresh symbol lookup, then check the mod page for an update. KB5132061 is known to break symbols for these mods. |
| A mod makes the shell unusable | Start Windhawk in safe mode, which loads no mods: `& "C:\Program Files\Windhawk\windhawk.exe" -safe-mode` |
| A Discord update removed Vencord | `.\windows\install.ps1 -Only vencord` reinstalls it and turns the theme back on. |
| A Spotify update removed Spicetify | Updates are blocked by a deny ACL on `%LOCALAPPDATA%\Spotify\Update`. If one gets through anyway, run `spicetify restore backup apply`. To allow updates again, run `icacls "$env:LOCALAPPDATA\Spotify\Update" /remove:d $env:USERNAME`. |
| The Nilesoft menu is broken | Ctrl + Win + right-click opens the native context menu. Ctrl + right-click reloads the config. |
| The bar and dock overlap, or maximized windows sit under the dock | `install\taskbar.ps1` restores the always-visible dock (the default). `install\taskbar.ps1 -AutoHide` switches to Windows auto-hide, which works with the intellihide mod. |
| Alt+Space does nothing | Alt+Space should open Flow. If PowerToys took the hotkey back, run `-Only powertoys,flow`. |
| Cursors reset after an update | `-Only cursors`. It warns if Windows reverts the values. |
| You want it all gone | Restore the "Pre Ahri rice" restore point. Registry exports and original configs are in `backup/` (`pre-rice-*/*.reg`, `cursors-before.reg`, `*.bak`). The scripts also leave `*.orig`, `*.bak` or `*.ahri-orig` copies next to the files they replace. |

## Design rules

- No colored glows. Elevation is a neutral dark shadow and a 1px hairline.
- No accent stripes and no gradients. Each surface gets one accent.
- Selection is a solid inverted fill in launcher lists and a one-step lighter surface in menus. Nothing uses a translucent tinted wash.
- Radii stay modest: 8 for windows, 4 for items.
- UI opened from the keyboard doesn't animate. Hover only changes color, in 150ms or less.
- Apps keep their own fonts. Maple Mono is limited to the terminal, the bar and code, and menus and the launcher use Segoe UI Variable.
- Readable text never uses `overlay`. That color is only for hints and comments.
