#!/bin/bash
# Builds one VS Code extension that holds every theme in macos/themes, then installs it into
# VS Code, VS Code Insiders and Cursor, whichever are present. User settings are left alone;
# pick the theme with "Preferences: Color Theme".
set -u
# shellcheck source-path=SCRIPTDIR source=lib.sh
. "$(dirname "$0")/lib.sh"

VSIX_DIR="$STATE/vscode"

# Print one editor CLI per line: the one on PATH, else the copy inside the app bundle.
editor_clis() {
  local entry cli app bin dir
  for entry in "code|Visual Studio Code|code" "code-insiders|Visual Studio Code - Insiders|code" "cursor|Cursor|cursor"; do
    IFS='|' read -r cli app bin <<EOT
$entry
EOT
    if have "$cli"; then
      command -v "$cli"
    elif dir="$(app_path "$app")" && [ -x "$dir/Contents/Resources/app/bin/$bin" ]; then
      printf '%s\n' "$dir/Contents/Resources/app/bin/$bin"
    fi
  done
}

theme_slugs() { sed -e 's/[[:space:]]//g' -e '/^$/d' "$MAC/themes"; }

case "${1:-}" in
  check)
    have python3 || { echo "python3 is missing"; exit 1; }
    [ -n "$(editor_clis)" ] || { echo "VS Code, VS Code Insiders and Cursor are not installed"; exit 1; }
    ;;
  run)
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' EXIT
    mkdir -p "$tmp/ext/themes" "$VSIX_DIR"
    slugs=""
    for slug in $(theme_slugs); do
      out="$(render --theme "$slug" --out "$tmp/render/$slug" --only editors/vscode 2>&1)" || { printf '%s\n' "$out" >&2; die "render failed for $slug"; }
      cp "$tmp/render/$slug/editors/vscode/themes/color-theme.json" "$tmp/ext/themes/$slug-color-theme.json"
      slugs="$slugs $slug"
    done
    [ -n "$slugs" ] || die "no themes listed in $MAC/themes"
    # A .vsix is a zip with [Content_Types].xml, extension.vsixmanifest and the extension under extension/.
    # shellcheck disable=SC2086
    vsix="$(python3 -I - "$tmp" "$VSIX_DIR" $slugs <<'PY'
import json, sys, zipfile
from pathlib import Path
from xml.sax.saxutils import escape

tmp, out_dir, slugs = Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3:]
ext = tmp / "ext"
pkg, themes = None, []
for slug in slugs:
    p = json.loads((tmp / "render" / slug / "editors/vscode/package.json").read_text(encoding="utf-8"))
    entry = dict(p["contributes"]["themes"][0], path=f"./themes/{slug}-color-theme.json")
    themes.append(entry)
    pkg = pkg or p
pkg["contributes"]["themes"] = themes
(ext / "package.json").write_text(json.dumps(pkg, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

e = lambda s: escape(str(s), {'"': "&quot;"})
manifest = f"""<?xml version="1.0" encoding="utf-8"?>
<PackageManifest Version="2.0.0" xmlns="http://schemas.microsoft.com/developer/vsx-schema/2011" xmlns:d="http://schemas.microsoft.com/developer/vsx-schema-design/2011">
  <Metadata>
    <Identity Language="en-US" Id="{e(pkg['name'])}" Version="{e(pkg['version'])}" Publisher="{e(pkg['publisher'])}" />
    <DisplayName>{e(pkg['displayName'])}</DisplayName>
    <Description xml:space="preserve">{e(pkg['description'])}</Description>
    <Tags>{e(','.join(dict.fromkeys(pkg.get('keywords', []) + ['theme'])))}</Tags>
    <Categories>Themes</Categories>
    <GalleryFlags>Public</GalleryFlags>
    <Properties>
      <Property Id="Microsoft.VisualStudio.Code.Engine" Value="{e(pkg['engines']['vscode'])}" />
      <Property Id="Microsoft.VisualStudio.Code.ExtensionKind" Value="ui,workspace" />
    </Properties>
  </Metadata>
  <Installation>
    <InstallationTarget Id="Microsoft.VisualStudio.Code" />
  </Installation>
  <Dependencies />
  <Assets>
    <Asset Type="Microsoft.VisualStudio.Code.Manifest" Path="extension/package.json" Addressable="true" />
  </Assets>
</PackageManifest>
"""
content_types = """<?xml version="1.0" encoding="utf-8"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension=".json" ContentType="application/json" />
  <Default Extension=".vsixmanifest" ContentType="text/xml" />
</Types>
"""
vsix = Path(out_dir) / f"{pkg['name']}-{pkg['version']}.vsix"
with zipfile.ZipFile(vsix, "w", zipfile.ZIP_DEFLATED) as z:
    z.writestr("[Content_Types].xml", content_types)
    z.writestr("extension.vsixmanifest", manifest)
    for f in sorted(ext.rglob("*")):
        if f.is_file():
            z.write(f, "extension/" + f.relative_to(ext).as_posix())
print(vsix)
PY
)" || die "building the extension failed"
    say "built $vsix"
    status=0
    while IFS= read -r cli; do
      [ -n "$cli" ] || continue
      if "$cli" --install-extension "$vsix" --force </dev/null >/dev/null; then
        say "installed into $cli"
      else
        warn "installing with $cli failed"; status=1
      fi
    done <<EOT
$(editor_clis)
EOT
    say "pick a theme with Preferences: Color Theme"
    exit "$status"
    ;;
  *) die "usage: $0 check|run" ;;
esac
