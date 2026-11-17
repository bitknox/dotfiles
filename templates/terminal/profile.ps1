# Ahri Blossom PowerShell profile (rendered from ~/dotfiles/templates/terminal/profile.ps1 — edit there)
# Works in Windows PowerShell 5.1 and PowerShell 7.

$esc = [char]27

# --- prompt -------------------------------------------------------------------
if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    oh-my-posh init $(if ($PSVersionTable.PSEdition -eq 'Core') { 'pwsh' } else { 'powershell' }) `
        --config "$HOME\.config\ahri-blossom.omp.json" | Invoke-Expression
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
        InlinePrediction   = & $c '{{ overlay | ansi }}'
        Selection          = "$esc[{{ surface2 | ansibg }}m"
    }
    try { Set-PSReadLineOption -PredictionSource History -PredictionViewStyle InlineView -ErrorAction Stop } catch {}
    Set-PSReadLineOption -BellStyle None
    Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
}

# --- tools ----------------------------------------------------------------------
$env:BAT_THEME = 'ansi'                       # bat follows the terminal's Ahri ANSI palette
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (zoxide init powershell --cmd cd | Out-String) })
}
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
