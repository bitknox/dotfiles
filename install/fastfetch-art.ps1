# Builds ~/.config/fastfetch/ahri.sixel (see fastfetch-art.py). Keeps a tiny Pillow venv outside the repo.
$venv = "$env:LOCALAPPDATA\ahri-rice\venv"
if (-not (Test-Path "$venv\Scripts\python.exe")) {
    py -3 -m venv $venv
    & "$venv\Scripts\python.exe" -m pip install -q pillow
}
& "$venv\Scripts\python.exe" -I "$PSScriptRoot\fastfetch-art.py" @args
