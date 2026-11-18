# Lock screen (and therefore the sign-in screen) = full-resolution Spirit Blossom Ahri splash.
# Art is Riot's, fetched from CommunityDragon (raw game assets), kept out of the repo.
# Run in Windows PowerShell 5.1 (needs WinRT).
param([int]$ChampionId = 103, [int]$Skin = 27)
$ErrorActionPreference = 'Stop'
$dir = "$env:LOCALAPPDATA\ahri-rice"; New-Item -ItemType Directory -Force $dir | Out-Null
$img = "$dir\lockscreen.jpg"
# resolve the skin's uncentered splash path from the champion data (CDragon serves /lol-game-data/assets/... lowercased)
$id = $ChampionId * 1000 + $Skin
$base = 'https://raw.communitydragon.org/latest/plugins/rcp-be-lol-game-data/global/default'
$champ = Invoke-RestMethod "$base/v1/champions/$ChampionId.json" -UseBasicParsing
$path = ($champ.skins | Where-Object id -eq $id).uncenteredSplashPath
if (-not $path) { throw "skin $id not found" }
Invoke-WebRequest ($base + '/' + $path.Replace('/lol-game-data/assets/', '').ToLower()) -OutFile $img -UseBasicParsing
Add-Type -AssemblyName System.Drawing
$i = [Drawing.Image]::FromFile($img); "splash: $($i.Width)x$($i.Height)"; $i.Dispose()

# Windows Spotlight / tips overlay off so the art is clean
$cdm = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
foreach ($v in 'RotatingLockScreenEnabled', 'RotatingLockScreenOverlayEnabled', 'SubscribedContent-338387Enabled') {
    Set-ItemProperty $cdm $v 0 -Type DWord
}

# WinRT: Windows.System.UserProfile.LockScreen.SetImageFileAsync
Add-Type -AssemblyName System.Runtime.WindowsRuntime
$asTask = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' } | Select-Object -First 1
$asTaskAction = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncAction' } | Select-Object -First 1
[void][Windows.Storage.StorageFile, Windows.Storage, ContentType = WindowsRuntime]
[void][Windows.System.UserProfile.LockScreen, Windows.System.UserProfile, ContentType = WindowsRuntime]
$fileTask = $asTask.MakeGenericMethod([Windows.Storage.StorageFile]).Invoke($null, @([Windows.Storage.StorageFile]::GetFileFromPathAsync($img)))
$file = $fileTask.GetAwaiter().GetResult()
$asTaskAction.Invoke($null, @([Windows.System.UserProfile.LockScreen]::SetImageFileAsync($file))).GetAwaiter().GetResult()
"lock screen -> $img"
