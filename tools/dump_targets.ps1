param(
    [string]$GameRoot = "D:\SteamLibrary\steamapps\common\Subnautica2",
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = "Stop"

$reportDir = Join-Path $ProjectRoot "docs"
$out = Join-Path $reportDir "static_scan_targets.txt"
$keywords = "MaxPlayers|MaxPlayer|PlayerLimit|PlayerCap|MaxConnections|NumPublicConnections|NumPrivateConnections|MaxPartySize|PartySize|LobbySize|SessionSettings|CreateSession|UpdateSession|JoinSession|FindSessions|FriendCode|Coop|Multiplayer|OnlineSession|GameInstance|GameMode|GameState|PlayerController|PlayerState|Subsystem|Lobby|Invite|Presence|NetDriver"
$paths = @(
    (Join-Path $GameRoot "Manifest_UFSFiles_Win64.txt"),
    (Join-Path $GameRoot "Manifest_NonUFSFiles_Win64.txt"),
    (Join-Path $GameRoot "Subnautica2\Content\Paks\Subnautica2-Windows.pak"),
    (Join-Path $GameRoot "Subnautica2\Binaries\Win64\Subnautica2-Win64-Shipping.exe")
)

New-Item -ItemType Directory -Force -Path $reportDir | Out-Null
"Static scan generated at $(Get-Date -Format o)" | Set-Content -LiteralPath $out -Encoding UTF8
foreach ($path in $paths) {
    if (Test-Path -LiteralPath $path) {
        "`n## $path" | Add-Content -LiteralPath $out -Encoding UTF8
        rg -a -i -n $keywords $path 2>$null | Select-Object -First 300 | Add-Content -LiteralPath $out -Encoding UTF8
    }
}

Write-Host "Wrote $out"
