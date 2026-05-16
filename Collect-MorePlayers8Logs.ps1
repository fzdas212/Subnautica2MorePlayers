param(
    [string]$GameRoot = "D:\SteamLibrary\steamapps\common\Subnautica2"
)

$ErrorActionPreference = "Stop"

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$desktop = [Environment]::GetFolderPath("Desktop")
$outDir = Join-Path $desktop "Subnautica2MorePlayers8-Logs-$stamp"
$zipPath = "$outDir.zip"

New-Item -ItemType Directory -Force -Path $outDir | Out-Null

function Copy-IfExists {
    param(
        [string]$Path,
        [string]$DestinationName
    )

    if (Test-Path -LiteralPath $Path) {
        $dest = Join-Path $outDir $DestinationName
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dest) | Out-Null
        Copy-Item -LiteralPath $Path -Destination $dest -Recurse -Force
        Write-Host "Copied: $Path"
    } else {
        Write-Host "Missing: $Path"
    }
}

$savedLogs = Join-Path $env:LOCALAPPDATA "Subnautica2\Saved\Logs"
$shippingDir = Join-Path $GameRoot "Subnautica2\Binaries\Win64"
$modDir = Join-Path $shippingDir "ue4ss\Mods\Subnautica2MorePlayers8"
$modLogs = Join-Path $modDir "Logs"
$ue4ssLog = Join-Path $shippingDir "ue4ss\UE4SS.log"

Copy-IfExists $savedLogs "SavedLogs"
Copy-IfExists $modLogs "ModLogs"
Copy-IfExists $ue4ssLog "UE4SS\UE4SS.log"
Copy-IfExists (Join-Path $modDir "MorePlayers8.json") "InstalledMod\MorePlayers8.json"
Copy-IfExists (Join-Path $modDir "install_manifest.json") "InstalledMod\install_manifest.json"

$crashDumps = Get-ChildItem -LiteralPath (Join-Path $shippingDir "ue4ss") -Filter "crash_*.dmp" -File -ErrorAction SilentlyContinue
if ($crashDumps) {
    $dumpDest = Join-Path $outDir "CrashDumps"
    New-Item -ItemType Directory -Force -Path $dumpDest | Out-Null
    $crashDumps | Sort-Object LastWriteTime -Descending | Select-Object -First 5 | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination $dumpDest -Force
        Write-Host "Copied crash dump: $($_.FullName)"
    }
}

$systemInfo = [ordered]@{
    CollectedAt = (Get-Date).ToString("o")
    UserName = $env:USERNAME
    ComputerName = $env:COMPUTERNAME
    GameRoot = $GameRoot
    ShippingExe = Join-Path $shippingDir "Subnautica2-Win64-Shipping.exe"
    ShippingExeSha256 = $null
    Processes = @(Get-Process -Name "Subnautica2","Subnautica2-Win64-Shipping" -ErrorAction SilentlyContinue | Select-Object ProcessName, Id, Path)
}

if (Test-Path -LiteralPath $systemInfo.ShippingExe) {
    $systemInfo.ShippingExeSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $systemInfo.ShippingExe).Hash
}

$systemInfo | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $outDir "collection_info.json") -Encoding UTF8

if (Test-Path -LiteralPath $zipPath) {
    Remove-Item -LiteralPath $zipPath -Force
}
Compress-Archive -LiteralPath $outDir -DestinationPath $zipPath -Force

Write-Host ""
Write-Host "Log folder created:"
Write-Host $outDir
Write-Host ""
Write-Host "Zip created:"
Write-Host $zipPath
