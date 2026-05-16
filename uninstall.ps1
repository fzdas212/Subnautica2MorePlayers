param(
    [string]$GameRoot = "D:\SteamLibrary\steamapps\common\Subnautica2",
    [switch]$RemoveUE4SSIfNoOtherMods
)

$ErrorActionPreference = "Stop"

$modName = "Subnautica2MorePlayers8"
$shippingDir = Join-Path $GameRoot "Subnautica2\Binaries\Win64"
$modTarget = Join-Path $shippingDir "ue4ss\Mods\$modName"
$modsTxt = Join-Path $shippingDir "ue4ss\Mods\mods.txt"
$manifestPath = Join-Path $modTarget "install_manifest.json"
$localGameIni = Join-Path $env:LOCALAPPDATA "Subnautica2\Saved\Config\Windows\Game.ini"

function Remove-GameIniMarkerBlock {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return }
    $text = Get-Content -LiteralPath $Path -Raw
    $updated = [regex]::Replace($text, '(?ms)^\s*; BEGIN Subnautica2MorePlayers8.*?^\s*; END Subnautica2MorePlayers8\r?\n?', '')
    if ([string]::IsNullOrWhiteSpace($updated)) {
        Remove-Item -LiteralPath $Path -Force
    } else {
        Set-Content -LiteralPath $Path -Value ($updated.TrimEnd() + "`r`n") -Encoding UTF8
    }
}

function Restore-ManifestBackups {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return }
    $manifest = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    if ($manifest.Backups -eq $null) { return }
    foreach ($backup in @($manifest.Backups)) {
        $source = [string]$backup.Source
        if ([string]::IsNullOrWhiteSpace($source)) { continue }
        if ($backup.PSObject.Properties.Name -contains "WasMissing" -and $backup.WasMissing -eq $true) {
            if (Test-Path -LiteralPath $source) {
                Remove-GameIniMarkerBlock -Path $source
            }
            continue
        }
        $backupPath = [string]$backup.Backup
        if (-not [string]::IsNullOrWhiteSpace($backupPath) -and (Test-Path -LiteralPath $backupPath)) {
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $source) | Out-Null
            Copy-Item -LiteralPath $backupPath -Destination $source -Recurse -Force
        }
    }
}

if (Test-Path -LiteralPath $modsTxt) {
    $lines = @(Get-Content -LiteralPath $modsTxt | Where-Object { $_ -notmatch "^\s*$([regex]::Escape($modName))\s*:" })
    $lines | Set-Content -LiteralPath $modsTxt -Encoding ASCII
}

Restore-ManifestBackups -Path $manifestPath
Remove-GameIniMarkerBlock -Path $localGameIni

if (Test-Path -LiteralPath $modsTxt) {
    $lines = @(Get-Content -LiteralPath $modsTxt | Where-Object { $_ -notmatch "^\s*$([regex]::Escape($modName))\s*:" })
    $lines | Set-Content -LiteralPath $modsTxt -Encoding ASCII
}

if (Test-Path -LiteralPath $modTarget) {
    Remove-Item -LiteralPath $modTarget -Recurse -Force
}

if ($RemoveUE4SSIfNoOtherMods) {
    $modsDir = Join-Path $shippingDir "ue4ss\Mods"
    $otherMods = @()
    if (Test-Path -LiteralPath $modsDir) {
        $otherMods = @(Get-ChildItem -LiteralPath $modsDir -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne "shared" })
    }
    if ($otherMods.Count -eq 0) {
        $dwmapi = Join-Path $shippingDir "dwmapi.dll"
        $ue4ss = Join-Path $shippingDir "ue4ss"
        if (Test-Path -LiteralPath $dwmapi) { Remove-Item -LiteralPath $dwmapi -Force }
        if (Test-Path -LiteralPath $ue4ss) { Remove-Item -LiteralPath $ue4ss -Recurse -Force }
        Write-Host "Removed UE4SS because no other mod directories were found."
    }
}

Write-Host "Uninstalled $modName"
