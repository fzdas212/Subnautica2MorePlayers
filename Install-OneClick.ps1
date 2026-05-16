param(
    [string]$GameRoot = ""
)

$ErrorActionPreference = "Stop"
$ProjectRoot = $PSScriptRoot

function Find-Subnautica2 {
    param([string]$Preferred)

    if ($Preferred -and (Test-Path -LiteralPath (Join-Path $Preferred "Subnautica2\Binaries\Win64\Subnautica2-Win64-Shipping.exe"))) {
        return (Resolve-Path -LiteralPath $Preferred).Path
    }

    $default = "D:\SteamLibrary\steamapps\common\Subnautica2"
    if (Test-Path -LiteralPath (Join-Path $default "Subnautica2\Binaries\Win64\Subnautica2-Win64-Shipping.exe")) {
        return $default
    }

    $steamVdf = "C:\Program Files (x86)\Steam\steamapps\libraryfolders.vdf"
    if (Test-Path -LiteralPath $steamVdf) {
        $libraries = Select-String -LiteralPath $steamVdf -Pattern '"path"\s+"(.+)"' | ForEach-Object {
            $_.Matches[0].Groups[1].Value -replace "\\\\", "\"
        }
        foreach ($lib in $libraries) {
            $candidate = Join-Path $lib "steamapps\common\Subnautica2"
            if (Test-Path -LiteralPath (Join-Path $candidate "Subnautica2\Binaries\Win64\Subnautica2-Win64-Shipping.exe")) {
                return $candidate
            }
        }
    }

    throw "Could not find Subnautica 2. Run from PowerShell with: .\Install-OneClick.ps1 -GameRoot `"D:\SteamLibrary\steamapps\common\Subnautica2`""
}

Write-Host "Subnautica2MorePlayers8 one-click installer"
Write-Host "Project: $ProjectRoot"

$resolvedGameRoot = Find-Subnautica2 -Preferred $GameRoot
Write-Host "Game root: $resolvedGameRoot"

$runningGame = Get-Process -Name "Subnautica2","Subnautica2-Win64-Shipping" -ErrorAction SilentlyContinue | Where-Object {
    try {
        $_.Path -and $_.Path.StartsWith($resolvedGameRoot, [System.StringComparison]::OrdinalIgnoreCase)
    } catch {
        $true
    }
}
if ($runningGame) {
    $names = ($runningGame | Select-Object -ExpandProperty ProcessName -Unique) -join ", "
    throw "Subnautica 2 is still running ($names). Exit the game completely, wait a few seconds, then run Install-OneClick.cmd again."
}

$dist = Join-Path $ProjectRoot "dist\Subnautica2MorePlayers8"
if (-not (Test-Path -LiteralPath (Join-Path $dist "scripts\main.lua"))) {
    throw "Prebuilt mod files are missing: $dist. Use the full project folder or run build.ps1 first."
}
if (-not (Test-Path -LiteralPath (Join-Path $ProjectRoot "tools\UE4SS-dev\dwmapi.dll"))) {
    throw "Bundled UE4SS files are missing: tools\UE4SS-dev"
}

try {
    & (Join-Path $ProjectRoot "install.ps1") -GameRoot $resolvedGameRoot -ProjectRoot $ProjectRoot
} catch {
    throw "install.ps1 failed: $($_.Exception.Message)"
}
if (-not $?) {
    throw "install.ps1 failed."
}

$verifyJson = & (Join-Path $ProjectRoot "tools\verify_install.ps1") -GameRoot $resolvedGameRoot
Write-Host $verifyJson
$verify = $verifyJson | ConvertFrom-Json
$failed = @()
$verify.PSObject.Properties | ForEach-Object {
    if ($_.Value -ne $true) {
        $failed += $_.Name
    }
}
if ($failed.Count -gt 0) {
    throw "Install verification failed: $($failed -join ', ')"
}

$modPath = Join-Path $resolvedGameRoot "Subnautica2\Binaries\Win64\ue4ss\Mods\Subnautica2MorePlayers8"
Write-Host ""
Write-Host "Installed successfully."
Write-Host "Mod path: $modPath"
$installedConfig = Join-Path $modPath "MorePlayers8.json"
$installedMaxPlayers = 64
if (Test-Path -LiteralPath $installedConfig) {
    try {
        $installedMaxPlayers = [int]((Get-Content -LiteralPath $installedConfig -Raw | ConvertFrom-Json).MaxPlayers)
    } catch {
        $installedMaxPlayers = 64
    }
}
Write-Host "Next: start Subnautica 2 from Steam, create a multiplayer lobby, confirm the top player count shows 1/$installedMaxPlayers."
