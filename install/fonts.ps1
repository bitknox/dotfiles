# Installs rice fonts per-user (no admin): Maple Mono NF (v7) + Shippori Mincho.
$ErrorActionPreference = 'Stop'
$fontDir = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts"
$regKey  = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
$tmp     = Join-Path $env:TEMP "rice-fonts-$(Get-Random)"
New-Item -ItemType Directory -Force $fontDir, $tmp | Out-Null

function Install-FontFile($file) {
    $dest = Join-Path $fontDir $file.Name
    # skip identical files (already-installed fonts are locked by the font cache)
    if (-not ((Test-Path $dest) -and (Get-FileHash $dest).Hash -eq (Get-FileHash $file.FullName).Hash)) {
        Copy-Item $file.FullName $dest -Force
    }
    # value name is only a label; Windows reads the family name from the file itself
    Set-ItemProperty $regKey -Name "$($file.BaseName) (TrueType)" -Value $dest
}

# Maple Mono NF
$ver = 'v7.9'
$base = "https://github.com/subframe7536/maple-font/releases/download/$ver"
Invoke-WebRequest "$base/MapleMono-NF.zip" -OutFile "$tmp\maple.zip" -UseBasicParsing
$shaRaw = (Invoke-WebRequest "$base/MapleMono-NF.sha256" -UseBasicParsing).Content
if ($shaRaw -is [byte[]]) { $shaRaw = [Text.Encoding]::ASCII.GetString($shaRaw) }   # PS 5.1 returns octet-stream as bytes
$expected = ($shaRaw.Trim() -split '\s+')[0]
if ((Get-FileHash "$tmp\maple.zip" -Algorithm SHA256).Hash -ne $expected.ToUpper()) { throw 'Maple Mono checksum mismatch' }
Expand-Archive "$tmp\maple.zip" "$tmp\maple" -Force
Get-ChildItem "$tmp\maple" -Recurse -Filter *.ttf | ForEach-Object { Install-FontFile $_ }

# Shippori Mincho (Google Fonts, OFL)
foreach ($w in 'Regular','Medium','SemiBold','Bold') {
    $f = "$tmp\ShipporiMincho-$w.ttf"
    Invoke-WebRequest "https://raw.githubusercontent.com/google/fonts/main/ofl/shipporimincho/ShipporiMincho-$w.ttf" -OutFile $f -UseBasicParsing
    Install-FontFile (Get-Item $f)
}

Remove-Item $tmp -Recurse -Force
(Get-ItemProperty $regKey).PSObject.Properties.Name | Where-Object { $_ -match '^MapleMono-NF|^ShipporiMincho' }
