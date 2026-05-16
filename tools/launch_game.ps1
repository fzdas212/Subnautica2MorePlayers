param(
    [switch]$Restart,
    [int]$AppId = 1962700
)

$ErrorActionPreference = "Stop"

if ($Restart) {
    Get-Process | Where-Object {
        $_.ProcessName -match '^Subnautica2($|-Win64-Shipping$)'
    } | Stop-Process -Force
    Start-Sleep -Seconds 3
}

Start-Process "steam://rungameid/$AppId"
Write-Host "Launched Steam AppID $AppId via steam://rungameid/$AppId"
