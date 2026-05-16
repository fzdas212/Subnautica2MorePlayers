param(
    [string]$GameRoot = "D:\SteamLibrary\steamapps\common\Subnautica2"
)

$ErrorActionPreference = "Stop"
$modName = "Subnautica2MorePlayers8"
$shippingDir = Join-Path $GameRoot "Subnautica2\Binaries\Win64"
$checks = [ordered]@{
    ShippingExe = Test-Path -LiteralPath (Join-Path $shippingDir "Subnautica2-Win64-Shipping.exe")
    UE4SSDwmapi = Test-Path -LiteralPath (Join-Path $shippingDir "dwmapi.dll")
    UE4SSDll = Test-Path -LiteralPath (Join-Path $shippingDir "ue4ss\UE4SS.dll")
    ModFolder = Test-Path -LiteralPath (Join-Path $shippingDir "ue4ss\Mods\$modName")
    ModMainLua = Test-Path -LiteralPath (Join-Path $shippingDir "ue4ss\Mods\$modName\scripts\main.lua")
    ModConfig = Test-Path -LiteralPath (Join-Path $shippingDir "ue4ss\Mods\$modName\MorePlayers8.json")
    ModConfigMaxPlayersValid = $false
    GameIniMaxPlayersMatchesConfig = $false
    ModsTxtEnabled = $false
}

$modConfigPath = Join-Path $shippingDir "ue4ss\Mods\$modName\MorePlayers8.json"
$configuredMaxPlayers = $null
if (Test-Path -LiteralPath $modConfigPath) {
    try {
        $configuredMaxPlayers = [int]((Get-Content -LiteralPath $modConfigPath -Raw | ConvertFrom-Json).MaxPlayers)
        $checks.ModConfigMaxPlayersValid = ($configuredMaxPlayers -ge 1 -and $configuredMaxPlayers -le 64)
    } catch {
        $checks.ModConfigMaxPlayersValid = $false
    }
}

$localGameIni = Join-Path $env:LOCALAPPDATA "Subnautica2\Saved\Config\Windows\Game.ini"
if ($configuredMaxPlayers -ne $null -and (Test-Path -LiteralPath $localGameIni)) {
    $text = Get-Content -LiteralPath $localGameIni -Raw
    $checks.GameIniMaxPlayersMatchesConfig = [bool]($text -match "(?ms)^; BEGIN Subnautica2MorePlayers8.*?MaxPlayers=$configuredMaxPlayers.*?^; END Subnautica2MorePlayers8")
}

$modsTxt = Join-Path $shippingDir "ue4ss\Mods\mods.txt"
if (Test-Path -LiteralPath $modsTxt) {
    $checks.ModsTxtEnabled = [bool](Select-String -LiteralPath $modsTxt -Pattern "^\s*$([regex]::Escape($modName))\s*:\s*1" -Quiet)
}

$checks | ConvertTo-Json -Depth 4
