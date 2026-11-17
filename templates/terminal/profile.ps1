# Ahri Blossom PowerShell profile (rendered from ~/dotfiles/templates/terminal/profile.ps1 — edit there)
# Works in Windows PowerShell 5.1 and PowerShell 7.

$esc = [char]27

# UTF-8 console I/O: the legacy OEM code page turns prompt glyphs (✿, Nerd Font icons) into '?'
[Console]::OutputEncoding = [Console]::InputEncoding = $OutputEncoding = [Text.UTF8Encoding]::new($false)
$env:STARSHIP_LOG = 'error'   # no WARN lines (e.g. slow directory scans in big folders) in the terminal

# Tools installed after this terminal started may not be on PATH yet — add their known dirs.
foreach ($d in "$env:ProgramFiles\starship\bin", "$env:LOCALAPPDATA\cava") {
    if ((Test-Path $d) -and ($env:Path -notlike "*$d*")) { $env:Path += ";$d" }
}

# --- cached init scripts --------------------------------------------------------------
# Generating init scripts is the slow part of shell startup; cache them and only
# regenerate when the tool's binary changes (i.e. after an update).
function Import-CachedInit([string]$Name, [string]$Exe, [string[]]$InitArgs) {
    $cmd = Get-Command $Exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $cmd) { return }
    if ($Exe -eq 'starship') { $env:STARSHIP_EXE = $cmd.Source }
    $dir = "$env:LOCALAPPDATA\ahri-rice\init"
    $cache = "$dir\$Name-$($PSVersionTable.PSEdition).ps1"
    if (-not (Test-Path $cache) -or (Get-Item $cmd.Source).LastWriteTime -gt (Get-Item $cache).LastWriteTime) {
        New-Item -ItemType Directory -Force $dir | Out-Null
        $script = & $cmd.Source @InitArgs | Out-String
        if ($Name -eq 'starship') {
            # starship runs itself once at load just to fetch the continuation prompt; bake it in instead
            $script = [regex]::Replace($script, '(?s)Set-PSReadLineOption -ContinuationPrompt \(\s*Invoke-Native.*?--continuation"\s*\)\s*\)',
                "Set-PSReadLineOption -ContinuationPrompt `"`$([char]27)[38;2;{{ overlay | r }};{{ overlay | g }};{{ overlay | b }}m❯❯ `$([char]27)[0m`"")
        }
        $script | Set-Content $cache -Encoding utf8
    }
    . $cache
}

# --- prompt -------------------------------------------------------------------
$env:STARSHIP_CONFIG = "$HOME\.config\starship.toml"
Import-CachedInit starship starship @('init', 'powershell', '--print-full-init')
if (Get-Command Enable-TransientPrompt -ErrorAction SilentlyContinue) {
    function global:Invoke-Starship-TransientFunction { &starship module character }
    Enable-TransientPrompt
}

# --- PSReadLine -------------------------------------------------------------------
if (Get-Module -ListAvailable PSReadLine) {
    $c = { param($ansi) "$esc[$($ansi)m" }
    Set-PSReadLineOption -Colors @{
        Command            = & $c '{{ sakura | ansi }}'
        Parameter          = & $c '{{ lavender | ansi }}'
        String             = & $c '{{ mint | ansi }}'
        Number             = & $c '{{ peach | ansi }}'
        Operator           = & $c '{{ spirit | ansi }}'
        Variable           = & $c '{{ text | ansi }}'
        Member             = & $c '{{ sky | ansi }}'
        Type               = & $c '{{ gold | ansi }}'
        Keyword            = & $c '{{ lavender | ansi }}'
        Comment            = & $c '{{ overlay | ansi }}'
        Default            = & $c '{{ text | ansi }}'
        Error              = & $c '{{ rose | ansi }}'
    }
    # Windows PowerShell 5.1 ships PSReadLine 2.0, which lacks these: set them only where supported
    $opt = Get-PSReadLineOption
    if ($opt.PSObject.Properties['InlinePredictionColor']) {
        Set-PSReadLineOption -Colors @{ InlinePrediction = & $c '{{ overlay | ansi }}' }
        try { Set-PSReadLineOption -PredictionSource History -PredictionViewStyle InlineView -ErrorAction Stop } catch {}
    }
    if ($opt.PSObject.Properties['SelectionColor']) {
        Set-PSReadLineOption -Colors @{ Selection = "$esc[{{ surface2 | ansibg }}m" }
    }
    Set-PSReadLineOption -BellStyle None
    Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
}

# --- tools ----------------------------------------------------------------------
$env:BAT_THEME = 'ansi'                       # bat follows the terminal's Ahri ANSI palette
Import-CachedInit zoxide zoxide @('init', 'powershell', '--cmd', 'cd')
if (Get-Command eza -ErrorAction SilentlyContinue) {
    Remove-Item Alias:ls -Force -ErrorAction SilentlyContinue
    function ls { eza --icons=auto --group-directories-first @args }
    function ll { eza -la --icons=auto --group-directories-first --git @args }
    function lt { eza --tree --level=2 --icons=auto @args }
}
if (Get-Command bat -ErrorAction SilentlyContinue) {
    Remove-Item Alias:cat -Force -ErrorAction SilentlyContinue
    function cat { bat --paging=never --style=plain @args }
}
if (Get-Command yazi -ErrorAction SilentlyContinue) {
    # `y` opens yazi and cds into the directory you quit in
    function y {
        $tmp = [IO.Path]::GetTempFileName()
        yazi @args --cwd-file="$tmp"
        $cwd = Get-Content -Path $tmp -Encoding UTF8
        if ($cwd -and $cwd -ne $PWD.Path) { Set-Location -LiteralPath $cwd }
        Remove-Item -Path $tmp
    }
}
function rice { Set-Location "$HOME\dotfiles" }

# --- greeting ---------------------------------------------------------------------
# fastfetch once per Windows Terminal window (not in nested shells / editors)
if ($env:WT_SESSION -and -not $env:AHRI_GREETED -and (Get-Command fastfetch -ErrorAction SilentlyContinue)) {
    $env:AHRI_GREETED = 1
    fastfetch
}
