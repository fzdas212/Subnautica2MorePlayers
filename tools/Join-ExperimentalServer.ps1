param(
    [string]$GameRoot = "D:\SteamLibrary\steamapps\common\Subnautica2",
    [Parameter(Mandatory = $true)]
    [string]$Address,
    [int]$Port = 7777,
    [switch]$Restart,
    [switch]$NullRHI,
    [switch]$NoSound,
    [switch]$Windowed,
    [switch]$UseShippingExe,
    [switch]$UseWrapperExe
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $GameRoot)) {
    $detected = & (Join-Path $PSScriptRoot "detect_game.ps1") | ConvertFrom-Json
    if ($detected.GameRootExists) {
        $GameRoot = $detected.GameRoot
    }
}

$shippingDir = Join-Path $GameRoot "Subnautica2\Binaries\Win64"
$shippingExe = Join-Path $shippingDir "Subnautica2-Win64-Shipping.exe"
$wrapperExe = Join-Path $GameRoot "Subnautica2.exe"
$steamExe = $null
$steamReg = Get-ItemProperty -Path "HKCU:\Software\Valve\Steam" -ErrorAction SilentlyContinue
if ($steamReg -and $steamReg.SteamExe) {
    $steamExe = $steamReg.SteamExe -replace "/", "\"
}
if (-not $steamExe -or -not (Test-Path -LiteralPath $steamExe)) {
    $steamReg = Get-ItemProperty -Path "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam" -ErrorAction SilentlyContinue
    if ($steamReg -and $steamReg.InstallPath) {
        $steamExe = Join-Path $steamReg.InstallPath "steam.exe"
    }
}
$modDir = Join-Path $shippingDir "ue4ss\Mods\Subnautica2MorePlayers8"
$configPath = Join-Path $modDir "MorePlayers8.json"
$smoketestDir = Join-Path $GameRoot "Subnautica2\Content\Smoketest"
$clientSmokeTestName = "smoketest-moreplayers8-client.json"
$clientSmokeTestPath = Join-Path $smoketestDir $clientSmokeTestName

if (-not (Test-Path -LiteralPath $shippingExe)) {
    throw "Could not find shipping exe: $shippingExe"
}
if (-not (Test-Path -LiteralPath $wrapperExe)) {
    throw "Could not find game launcher exe: $wrapperExe"
}
if (-not $steamExe -or -not (Test-Path -LiteralPath $steamExe)) {
    throw "Could not find Steam executable. Start Steam first or verify its registry install path."
}
if (-not (Test-Path -LiteralPath $configPath)) {
    throw "Subnautica2MorePlayers8 is not installed. Run install.ps1 first. Missing: $configPath"
}

if ($Restart) {
    Get-Process -Name "Subnautica2","Subnautica2-Win64-Shipping" -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Seconds 3
}

function Set-JsonProperty {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Object,
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        [object]$Value
    )

    if ($Object.PSObject.Properties[$Name]) {
        $Object.$Name = $Value
    } else {
        $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value
    }
}

$target = "${Address}:${Port}"
$cfg = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
Set-JsonProperty $cfg "ServerMode" "ExperimentalDirectClient"
Set-JsonProperty $cfg "EnableDirectConnectAutomation" $false
Set-JsonProperty $cfg "DirectConnectAddress" $target
Set-JsonProperty $cfg "DirectConnectDelayMs" 15000
Set-JsonProperty $cfg "EnableIpPortFallback" $true
Set-JsonProperty $cfg "LogLevel" "Info"
Set-JsonProperty $cfg "EnableTraceFiles" $true
$cfg | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $configPath -Encoding UTF8

New-Item -ItemType Directory -Force -Path $smoketestDir | Out-Null
$smokeSteps = @(
    [ordered]@{ Action = "Wait"; Arg = "8" },
    [ordered]@{ Action = "ConsoleCommand"; Arg = "open $target" },
    [ordered]@{ Action = "Wait"; Arg = "30" },
    [ordered]@{ Action = "CheckConnected" },
    [ordered]@{ Action = "Wait"; Arg = "30" },
    [ordered]@{ Action = "CheckLevel"; Arg = "L_Main" },
    [ordered]@{ Action = "Message"; Arg = "MorePlayers8 client connected to $target" },
    [ordered]@{ Action = "Wait"; Arg = "86400" }
)
[ordered]@{ Steps = $smokeSteps } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $clientSmokeTestPath -Encoding UTF8

$argsList = @("-log", "-nosteamcontroller", "-smoketest=$clientSmokeTestName")
if ($NullRHI) { $argsList += "-nullrhi" }
if ($NoSound) { $argsList += "-nosound" }
if ($Windowed) { $argsList += @("-windowed", "-ResX=640", "-ResY=360") }

Write-Host "Starting Subnautica 2 experimental direct-connect client."
Write-Host "Target: $target"
Write-Host "Smoketest file: $clientSmokeTestPath"
Write-Host "Args: $($argsList -join ' ')"

if ($UseShippingExe) {
    $launchExe = $shippingExe
    $launchCwd = $shippingDir
    $launchArgs = $argsList
} elseif ($UseWrapperExe) {
    $launchExe = $wrapperExe
    $launchCwd = $GameRoot
    $launchArgs = $argsList
} else {
    $launchExe = $steamExe
    $launchCwd = Split-Path -Parent $steamExe
    $launchArgs = @("-applaunch", "1962700") + $argsList
}

Write-Host "EXE: $launchExe"
Write-Host "Launch args: $($launchArgs -join ' ')"
Start-Process -FilePath $launchExe -WorkingDirectory $launchCwd -ArgumentList $launchArgs
