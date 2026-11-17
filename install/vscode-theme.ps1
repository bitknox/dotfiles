# Builds a .vsix from generated/editors/vscode/ahri-blossom-theme and installs it into VS Code and Cursor.
# (VS Code 1.9x+ / Cursor ignore unregistered folders dropped into ~/.vscode/extensions, so a real install is needed.)
# No node/vsce required: a .vsix is just a zip with [Content_Types].xml, extension.vsixmanifest and extension/**.
# Usage:  py -3 render.py   (so generated/ is fresh)   then   powershell -File install\vscode-theme.ps1
param([switch]$NoInstall)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem

$src = Resolve-Path "$PSScriptRoot\..\generated\editors\vscode\ahri-blossom-theme"
$pkg = Get-Content "$src\package.json" -Raw | ConvertFrom-Json
$id  = "$($pkg.publisher).$($pkg.name)"
$vsix = Join-Path (Split-Path $src) "$($pkg.name)-$($pkg.version).vsix"

function ConvertTo-XmlText($s) { [Security.SecurityElement]::Escape([string]$s) }

$manifest = @"
<?xml version="1.0" encoding="utf-8"?>
<PackageManifest Version="2.0.0" xmlns="http://schemas.microsoft.com/developer/vsx-schema/2011" xmlns:d="http://schemas.microsoft.com/developer/vsx-schema-design/2011">
  <Metadata>
    <Identity Language="en-US" Id="$(ConvertTo-XmlText $pkg.name)" Version="$(ConvertTo-XmlText $pkg.version)" Publisher="$(ConvertTo-XmlText $pkg.publisher)" />
    <DisplayName>$(ConvertTo-XmlText $pkg.displayName)</DisplayName>
    <Description xml:space="preserve">$(ConvertTo-XmlText $pkg.description)</Description>
    <Tags>$(ConvertTo-XmlText (($pkg.keywords + 'theme' | Select-Object -Unique) -join ','))</Tags>
    <Categories>Themes</Categories>
    <GalleryFlags>Public</GalleryFlags>
    <Properties>
      <Property Id="Microsoft.VisualStudio.Code.Engine" Value="$(ConvertTo-XmlText $pkg.engines.vscode)" />
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
"@

$contentTypes = @"
<?xml version="1.0" encoding="utf-8"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension=".json" ContentType="application/json" />
  <Default Extension=".vsixmanifest" ContentType="text/xml" />
  <Default Extension=".md" ContentType="text/markdown" />
  <Default Extension=".txt" ContentType="text/plain" />
</Types>
"@

if (Test-Path $vsix) { Remove-Item $vsix -Force }
$utf8 = New-Object Text.UTF8Encoding $false
$zip = [IO.Compression.ZipFile]::Open($vsix, 'Create')
try {
  foreach ($e in @(@('[Content_Types].xml', $contentTypes), @('extension.vsixmanifest', $manifest))) {
    $w = New-Object IO.StreamWriter(($zip.CreateEntry($e[0])).Open(), $utf8); $w.Write($e[1]); $w.Dispose()
  }
  Get-ChildItem $src -Recurse -File | ForEach-Object {
    $rel = 'extension/' + $_.FullName.Substring($src.Path.Length + 1).Replace('\', '/')   # forward slashes required
    [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $_.FullName, $rel)
  }
} finally { $zip.Dispose() }
Write-Host "built $vsix ($id)"
if ($NoInstall) { return }

$env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
foreach ($cli in 'code', 'cursor') {
  if (-not (Get-Command $cli -ErrorAction SilentlyContinue)) { Write-Host "skip  $cli (not installed)"; continue }
  & $cli --install-extension $vsix --force
}
