param(
    [string]$GameRoot = "",
    [switch]$RemoveUE4SSIfNoOtherMods
)

$ErrorActionPreference = "Stop"
$ProjectRoot = $PSScriptRoot

function Find-Subnautica2 {
    param([string]$Preferred)

    if ($Preferred -and (Test-Path -LiteralPath (Join-Path $Preferred "Subnautica2\Binaries\Win64"))) {
        return (Resolve-Path -LiteralPath $Preferred).Path
    }

    $default = "D:\SteamLibrary\steamapps\common\Subnautica2"
    if (Test-Path -LiteralPath (Join-Path $default "Subnautica2\Binaries\Win64")) {
        return $default
    }

    $steamVdf = "C:\Program Files (x86)\Steam\steamapps\libraryfolders.vdf"
    if (Test-Path -LiteralPath $steamVdf) {
        $libraries = Select-String -LiteralPath $steamVdf -Pattern '"path"\s+"(.+)"' | ForEach-Object {
            $_.Matches[0].Groups[1].Value -replace "\\\\", "\"
        }
        foreach ($lib in $libraries) {
            $candidate = Join-Path $lib "steamapps\common\Subnautica2"
            if (Test-Path -LiteralPath (Join-Path $candidate "Subnautica2\Binaries\Win64")) {
                return $candidate
            }
        }
    }

    throw "Could not find Subnautica 2. Run from PowerShell with: .\Uninstall-OneClick.ps1 -GameRoot `"D:\SteamLibrary\steamapps\common\Subnautica2`""
}

Write-Host "Subnautica2MorePlayers8 one-click uninstaller"
$resolvedGameRoot = Find-Subnautica2 -Preferred $GameRoot
Write-Host "Game root: $resolvedGameRoot"

try {
    if ($RemoveUE4SSIfNoOtherMods) {
        & (Join-Path $ProjectRoot "uninstall.ps1") -GameRoot $resolvedGameRoot -RemoveUE4SSIfNoOtherMods
    } else {
        & (Join-Path $ProjectRoot "uninstall.ps1") -GameRoot $resolvedGameRoot
    }
} catch {
    throw "uninstall.ps1 failed: $($_.Exception.Message)"
}

Write-Host "Uninstalled successfully."
