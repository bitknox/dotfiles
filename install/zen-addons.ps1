# Opens the AMO page of every add-on in zen-extensions.txt as tabs in Zen (click "Add to Firefox" on each).
$zen = 'C:\Program Files\Zen Browser\zen.exe'
$slugs = Get-Content "$PSScriptRoot\zen-extensions.txt" | ForEach-Object { ($_ -split '#')[0].Trim() } | Where-Object { $_ }
$args = foreach ($s in $slugs) { '-new-tab'; "https://addons.mozilla.org/firefox/addon/$s/" }
Start-Process $zen -ArgumentList $args
"opened $($slugs.Count) add-on pages"
