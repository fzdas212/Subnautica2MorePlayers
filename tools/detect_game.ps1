param(
    [string]$GameRoot = "D:\SteamLibrary\steamapps\common\Subnautica2"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $GameRoot)) {
    $steamVdf = "C:\Program Files (x86)\Steam\steamapps\libraryfolders.vdf"
    if (Test-Path -LiteralPath $steamVdf) {
        $libraries = Select-String -LiteralPath $steamVdf -Pattern '"path"\s+"(.+)"' | ForEach-Object {
            $_.Matches[0].Groups[1].Value -replace "\\\\", "\"
        }
        foreach ($lib in $libraries) {
            $candidate = Join-Path $lib "steamapps\common\Subnautica2"
            if (Test-Path -LiteralPath $candidate) {
                $GameRoot = $candidate
                break
            }
        }
    }
}

$shippingExe = Join-Path $GameRoot "Subnautica2\Binaries\Win64\Subnautica2-Win64-Shipping.exe"
$result = [ordered]@{
    GameRoot = $GameRoot
    GameRootExists = Test-Path -LiteralPath $GameRoot
    ShippingExe = $shippingExe
    ShippingExeExists = Test-Path -LiteralPath $shippingExe
    UE4SSInstalled = Test-Path -LiteralPath (Join-Path (Split-Path -Parent $shippingExe) "ue4ss")
    VersionJson = $null
    VersionText = $null
    ShippingExeSha256 = $null
}

if (Test-Path -LiteralPath (Join-Path $GameRoot "version.json")) {
    $version = Get-Content -LiteralPath (Join-Path $GameRoot "version.json") -Raw | ConvertFrom-Json
    $result.VersionJson = [ordered]@{
        branch = $version.branch
        changelist = $version.changelist
        build_number = $version.build_number
        build_server_label = $version.build_server_label
        timestamp = $version.timestamp
    }
}
if (Test-Path -LiteralPath (Join-Path $GameRoot "version.txt")) {
    $result.VersionText = [string](Get-Content -LiteralPath (Join-Path $GameRoot "version.txt") -Raw)
}
if (Test-Path -LiteralPath $shippingExe) {
    $result.ShippingExeSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $shippingExe).Hash
}

$result | ConvertTo-Json -Depth 4
