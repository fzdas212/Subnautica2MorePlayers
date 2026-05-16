param(
    [string]$GameRoot = "D:\SteamLibrary\steamapps\common\Subnautica2",
    [string]$ProjectRoot = $PSScriptRoot
)

$ErrorActionPreference = "Stop"

$modName = "Subnautica2MorePlayers8"
$shippingDir = Join-Path $GameRoot "Subnautica2\Binaries\Win64"
$shippingExe = Join-Path $shippingDir "Subnautica2-Win64-Shipping.exe"
$ue4ssSource = Join-Path $ProjectRoot "tools\UE4SS-dev"
$distMod = Join-Path $ProjectRoot "dist\$modName"
$modTarget = Join-Path $shippingDir "ue4ss\Mods\$modName"
$backupRoot = Join-Path $GameRoot "_Subnautica2MorePlayers8_Backups"
$localConfigDir = Join-Path $env:LOCALAPPDATA "Subnautica2\Saved\Config\Windows"
$localGameIni = Join-Path $localConfigDir "Game.ini"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backupDir = Join-Path $backupRoot $timestamp

if (-not (Test-Path -LiteralPath $shippingExe)) {
    throw "Could not find shipping exe: $shippingExe"
}
$runningGame = Get-Process -Name "Subnautica2","Subnautica2-Win64-Shipping" -ErrorAction SilentlyContinue | Where-Object {
    try {
        $_.Path -and $_.Path.StartsWith($GameRoot, [System.StringComparison]::OrdinalIgnoreCase)
    } catch {
        $true
    }
}
if ($runningGame) {
    $names = ($runningGame | Select-Object -ExpandProperty ProcessName -Unique) -join ", "
    throw "Subnautica 2 is still running ($names). Exit the game completely before installing."
}
if (-not (Test-Path -LiteralPath $ue4ssSource)) {
    throw "UE4SS dev files are missing. Expected: $ue4ssSource"
}
if (-not (Test-Path -LiteralPath $distMod)) {
    & (Join-Path $ProjectRoot "build.ps1") -ProjectRoot $ProjectRoot
}

$distConfig = Join-Path $distMod "MorePlayers8.json"
if (-not (Test-Path -LiteralPath $distConfig)) {
    throw "Missing built mod config: $distConfig"
}
$modConfig = Get-Content -LiteralPath $distConfig -Raw | ConvertFrom-Json
$targetMaxPlayers = [int]$modConfig.MaxPlayers
if ($targetMaxPlayers -lt 1 -or $targetMaxPlayers -gt 64) {
    throw "MorePlayers8.json MaxPlayers must be between 1 and 64. Current value: $targetMaxPlayers"
}

New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
$manifest = [ordered]@{
    ModName = $modName
    InstalledAt = (Get-Date).ToString("o")
    GameRoot = $GameRoot
    ShippingExe = $shippingExe
    ShippingExeSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $shippingExe).Hash
    MaxPlayers = $targetMaxPlayers
    Backups = @()
    InstalledFiles = @()
}

function Backup-IfExists {
    param([string]$Path)
    if (Test-Path -LiteralPath $Path) {
        $resolved = (Resolve-Path -LiteralPath $Path).Path
        if ($resolved.StartsWith($shippingDir, [System.StringComparison]::OrdinalIgnoreCase)) {
            $relative = $resolved.Substring($shippingDir.Length).TrimStart("\")
        } else {
            $safeName = ($resolved -replace '^[A-Za-z]:\\?', '') -replace '[\\/:*?"<>|]', '_'
            $relative = Join-Path "_external" $safeName
        }
        $dest = Join-Path $backupDir $relative
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dest) | Out-Null
        Copy-Item -LiteralPath $Path -Destination $dest -Recurse -Force
        $script:manifest.Backups += [ordered]@{ Source = $Path; Backup = $dest }
    }
}

function Set-GameIniSessionOverride {
    param([string]$Path, [int]$MaxPlayers)

    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Path) | Out-Null
    if (Test-Path -LiteralPath $Path) {
        Backup-IfExists $Path
        $text = Get-Content -LiteralPath $Path -Raw
    } else {
        $text = ""
        $script:manifest.Backups += [ordered]@{ Source = $Path; Backup = $null; WasMissing = $true }
    }

    $begin = "; BEGIN Subnautica2MorePlayers8"
    $end = "; END Subnautica2MorePlayers8"
    $block = @"
$begin
[/Script/Engine.GameSession]
MaxPlayers=$MaxPlayers
MaxSpectators=$MaxPlayers
MaxSplitscreens=$MaxPlayers

[/Script/EngineSettings.GameSessionSettings]
MaxPlayers=$MaxPlayers

[/Script/Subnautica2.SN2GameSession]
MaxPlayers=$MaxPlayers
MaxPartySize=$MaxPlayers
$end
"@

    if ($text -match '(?ms)^; BEGIN Subnautica2MorePlayers8.*?^; END Subnautica2MorePlayers8\r?\n?') {
        $text = [regex]::Replace($text, '(?ms)^; BEGIN Subnautica2MorePlayers8.*?^; END Subnautica2MorePlayers8\r?\n?', $block.TrimEnd() + "`r`n")
    } elseif ([string]::IsNullOrWhiteSpace($text)) {
        $text = $block.TrimEnd() + "`r`n"
    } else {
        $text = $text.TrimEnd() + "`r`n`r`n" + $block.TrimEnd() + "`r`n"
    }

    Set-Content -LiteralPath $Path -Value $text -Encoding UTF8
    $script:manifest.InstalledFiles += $Path
}

Backup-IfExists (Join-Path $shippingDir "dwmapi.dll")
Backup-IfExists (Join-Path $shippingDir "ue4ss\Mods\mods.txt")
Backup-IfExists $modTarget

$sourceDwmapi = Join-Path $ue4ssSource "dwmapi.dll"
Copy-Item -LiteralPath $sourceDwmapi -Destination (Join-Path $shippingDir "dwmapi.dll") -Force
$manifest.InstalledFiles += (Join-Path $shippingDir "dwmapi.dll")

$ue4ssTarget = Join-Path $shippingDir "ue4ss"
New-Item -ItemType Directory -Force -Path $ue4ssTarget | Out-Null
foreach ($name in @("UE4SS.dll","UE4SS.pdb","UE4SS-settings.ini","Changelog.md","LICENSE","README.md")) {
    $srcPath = Join-Path $ue4ssSource "ue4ss\$name"
    if (Test-Path -LiteralPath $srcPath) {
        Copy-Item -LiteralPath $srcPath -Destination (Join-Path $ue4ssTarget $name) -Force
    }
}

$ue4ssSettings = Join-Path $ue4ssTarget "UE4SS-settings.ini"
if (Test-Path -LiteralPath $ue4ssSettings) {
    $settingsText = Get-Content -LiteralPath $ue4ssSettings -Raw
    $overrideText = "[EngineVersionOverride]`r`nMajorVersion = 5`r`nMinorVersion = 6`r`nDebugBuild = false`r`n"
    if ($settingsText -match '(?ms)^\[EngineVersionOverride\].*?(?=^\[|\z)') {
        $settingsText = [regex]::Replace($settingsText, '(?ms)^\[EngineVersionOverride\].*?(?=^\[|\z)', $overrideText)
    } else {
        $settingsText = $settingsText.TrimEnd() + "`r`n`r`n" + $overrideText
    }
    Set-Content -LiteralPath $ue4ssSettings -Value $settingsText -Encoding UTF8
}
foreach ($dirName in @("UE4SS_Signatures","VTableLayoutTemplates","MemberVarLayoutTemplates","Default_UVTD_Configs")) {
    $srcDir = Join-Path $ue4ssSource "ue4ss\$dirName"
    if (Test-Path -LiteralPath $srcDir) {
        Copy-Item -LiteralPath $srcDir -Destination $ue4ssTarget -Recurse -Force
    }
}
New-Item -ItemType Directory -Force -Path (Join-Path $ue4ssTarget "Mods") | Out-Null
$sharedSource = Join-Path $ue4ssSource "ue4ss\Mods\shared"
if (Test-Path -LiteralPath $sharedSource) {
    Copy-Item -LiteralPath $sharedSource -Destination (Join-Path $ue4ssTarget "Mods") -Recurse -Force
}
$manifest.InstalledFiles += (Join-Path $shippingDir "ue4ss")

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $modTarget) | Out-Null
Copy-Item -LiteralPath $distMod -Destination (Split-Path -Parent $modTarget) -Recurse -Force
$manifest.InstalledFiles += $modTarget

$modsTxt = Join-Path $shippingDir "ue4ss\Mods\mods.txt"
if (-not (Test-Path -LiteralPath $modsTxt)) {
    New-Item -ItemType File -Force -Path $modsTxt | Out-Null
}
$modsLines = @(Get-Content -LiteralPath $modsTxt -ErrorAction SilentlyContinue)
$modsLines = @($modsLines | Where-Object { $_ -notmatch "^\s*$([regex]::Escape($modName))\s*:" })
$modsLines += "$modName : 1"
$modsLines | Set-Content -LiteralPath $modsTxt -Encoding ASCII

Set-GameIniSessionOverride -Path $localGameIni -MaxPlayers $targetMaxPlayers

$installManifestPath = Join-Path $modTarget "install_manifest.json"
$manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $installManifestPath -Encoding UTF8

Write-Host "Installed $modName to $modTarget"
Write-Host "Updated local Game.ini session override: $localGameIni"
Write-Host "Configured MaxPlayers: $targetMaxPlayers"
Write-Host "Game exe SHA256: $($manifest.ShippingExeSha256)"
