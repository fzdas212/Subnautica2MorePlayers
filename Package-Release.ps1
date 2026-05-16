param(
    [string]$ProjectRoot = $PSScriptRoot,
    [string]$Version = "0.3.6-64-production"
)

$ErrorActionPreference = "Stop"

$releaseRoot = Join-Path $ProjectRoot "release"
$stagingRoot = Join-Path $releaseRoot ("_staging_" + (Get-Date -Format "yyyyMMddHHmmss"))
$packageDir = Join-Path $stagingRoot "Subnautica2MorePlayers8"
$zipPath = Join-Path $releaseRoot "Subnautica2MorePlayers8-v$Version-oneclick.zip"
if (Test-Path -LiteralPath $zipPath) {
    $stamp = Get-Date -Format "yyyyMMddHHmmss"
    $zipPath = Join-Path $releaseRoot "Subnautica2MorePlayers8-v$Version-oneclick-$stamp.zip"
}
$modDist = Join-Path $ProjectRoot "dist\Subnautica2MorePlayers8"
$ue4ssSource = Join-Path $ProjectRoot "tools\UE4SS-dev"

if (-not (Test-Path -LiteralPath (Join-Path $modDist "scripts\main.lua"))) {
    throw "Missing built mod dist. Run build.ps1 first."
}
if (-not (Test-Path -LiteralPath (Join-Path $modDist "native\MorePlayers8Native.dll"))) {
    throw "Missing prebuilt native DLL. Run build.ps1 first."
}
if (-not (Test-Path -LiteralPath (Join-Path $ue4ssSource "dwmapi.dll"))) {
    throw "Missing bundled UE4SS files: $ue4ssSource"
}

New-Item -ItemType Directory -Force -Path $releaseRoot | Out-Null
New-Item -ItemType Directory -Force -Path $packageDir | Out-Null

foreach ($file in @(
    "Install-OneClick.cmd",
    "Install-OneClick.ps1",
    "Uninstall-OneClick.cmd",
    "Uninstall-OneClick.ps1",
    "Collect-MorePlayers8Logs.cmd",
    "Collect-MorePlayers8Logs.ps1",
    "install.ps1",
    "uninstall.ps1",
    "README.md",
    "INSTALL.zh-CN.md",
    "安装说明.md"
)) {
    Copy-Item -LiteralPath (Join-Path $ProjectRoot $file) -Destination (Join-Path $packageDir $file) -Force
}

$distTarget = Join-Path $packageDir "dist\Subnautica2MorePlayers8"
New-Item -ItemType Directory -Force -Path (Join-Path $distTarget "scripts") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $distTarget "native") | Out-Null
Copy-Item -LiteralPath (Join-Path $modDist "enabled.txt") -Destination (Join-Path $distTarget "enabled.txt") -Force
Copy-Item -LiteralPath (Join-Path $modDist "MorePlayers8.json") -Destination (Join-Path $distTarget "MorePlayers8.json") -Force
Copy-Item -LiteralPath (Join-Path $modDist "build_manifest.json") -Destination (Join-Path $distTarget "build_manifest.json") -Force
Copy-Item -LiteralPath (Join-Path $modDist "scripts\main.lua") -Destination (Join-Path $distTarget "scripts\main.lua") -Force
Copy-Item -LiteralPath (Join-Path $modDist "native\MorePlayers8Native.dll") -Destination (Join-Path $distTarget "native\MorePlayers8Native.dll") -Force

New-Item -ItemType Directory -Force -Path (Join-Path $packageDir "tools") | Out-Null
foreach ($file in @("detect_game.ps1", "verify_install.ps1")) {
    Copy-Item -LiteralPath (Join-Path $ProjectRoot "tools\$file") -Destination (Join-Path $packageDir "tools\$file") -Force
}

New-Item -ItemType Directory -Force -Path (Join-Path $packageDir "docs") | Out-Null
foreach ($file in @("discovery_report.md", "test_report.md", "current_progress.md", "latest_test_instructions_zh-CN.md")) {
    $docPath = Join-Path $ProjectRoot "docs\$file"
    if (Test-Path -LiteralPath $docPath) {
        Copy-Item -LiteralPath $docPath -Destination (Join-Path $packageDir "docs\$file") -Force
    }
}

$ue4ssTarget = Join-Path $packageDir "tools\UE4SS-dev"
New-Item -ItemType Directory -Force -Path (Join-Path $ue4ssTarget "ue4ss") | Out-Null
Copy-Item -LiteralPath (Join-Path $ue4ssSource "dwmapi.dll") -Destination (Join-Path $ue4ssTarget "dwmapi.dll") -Force
foreach ($name in @("UE4SS.dll", "UE4SS-settings.ini", "Changelog.md", "LICENSE", "README.md")) {
    Copy-Item -LiteralPath (Join-Path $ue4ssSource "ue4ss\$name") -Destination (Join-Path $ue4ssTarget "ue4ss\$name") -Force
}
foreach ($dir in @("UE4SS_Signatures", "VTableLayoutTemplates", "MemberVarLayoutTemplates", "Default_UVTD_Configs")) {
    Copy-Item -LiteralPath (Join-Path $ue4ssSource "ue4ss\$dir") -Destination (Join-Path $ue4ssTarget "ue4ss") -Recurse -Force
}
$shared = Join-Path $ue4ssSource "ue4ss\Mods\shared"
if (Test-Path -LiteralPath $shared) {
    New-Item -ItemType Directory -Force -Path (Join-Path $ue4ssTarget "ue4ss\Mods") | Out-Null
    Copy-Item -LiteralPath $shared -Destination (Join-Path $ue4ssTarget "ue4ss\Mods") -Recurse -Force
}

Compress-Archive -LiteralPath $packageDir -DestinationPath $zipPath -Force
$hash = Get-FileHash -Algorithm SHA256 -LiteralPath $zipPath
Write-Host "Created $zipPath"
Write-Host "SHA256: $($hash.Hash)"
