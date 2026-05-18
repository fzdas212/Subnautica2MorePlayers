param(
    [string]$GameRoot = "D:\SteamLibrary\steamapps\common\Subnautica2",
    [int]$Port = 7777,
    [string]$RuleName = "Subnautica2MorePlayers8 Experimental Server"
)

$ErrorActionPreference = "Stop"

$shippingExe = Join-Path $GameRoot "Subnautica2\Binaries\Win64\Subnautica2-Win64-Shipping.exe"
if (-not (Test-Path -LiteralPath $shippingExe)) {
    throw "Could not find shipping exe: $shippingExe"
}
if ($Port -lt 1 -or $Port -gt 65535) {
    throw "Port must be between 1 and 65535."
}

$existing = Get-NetFirewallRule -DisplayName $RuleName -ErrorAction SilentlyContinue
if ($existing) {
    $existing | Remove-NetFirewallRule
}

New-NetFirewallRule `
    -DisplayName $RuleName `
    -Direction Inbound `
    -Action Allow `
    -Program $shippingExe `
    -Protocol UDP `
    -LocalPort $Port `
    -Profile Private,Domain | Out-Null

Write-Host "Created inbound UDP firewall rule:"
Write-Host "  Name: $RuleName"
Write-Host "  Program: $shippingExe"
Write-Host "  Port: UDP $Port"
Write-Host "  Profile: Private, Domain"
