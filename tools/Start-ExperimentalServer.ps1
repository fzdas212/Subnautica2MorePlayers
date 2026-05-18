param(
    [string]$GameRoot = "D:\SteamLibrary\steamapps\common\Subnautica2",
    [int]$Port = 7777,
    [int]$MaxPlayers = 64,
    [string]$TravelUrl = "",
    [switch]$NullRHI,
    [switch]$NoSound,
    [switch]$Windowed,
    [switch]$IpPortFallback,
    [switch]$EnableLuaAutoHost,
    [switch]$EnableApiAutoHost,
    [ValidateSet("ServerLobbyLoadGame", "UiLaunchGame", "RawHostViewModel", "OfficialSmokeTestLoadGame", "OfficialSmokeTestLanListen")]
    [string]$ServerApiMode = "OfficialSmokeTestLanListen",
    [switch]$EnableRawHostViewModelApi,
    [int]$ServerApiMaxAttempts = 8,
    [int]$ServerApiRetryIntervalMs = 15000,
    [string]$ServerCheckpointName = "",
    [string]$ServerSaveSlotName = "",
    [switch]$ServerAllowNewGameFallback,
    [switch]$EnableUnsafeTravelAutomation,
    [switch]$UseShippingExe,
    [switch]$UseWrapperExe,
    [switch]$Monitor,
    [int]$MonitorSeconds = 0,
    [switch]$Restart,
    [switch]$OpenFirewall
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
$morePlayersSmokeTestName = "smoketest-moreplayers8-server.json"
$morePlayersSmokeTestPath = Join-Path $smoketestDir $morePlayersSmokeTestName

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
if ($MaxPlayers -lt 1 -or $MaxPlayers -gt 64) {
    throw "MaxPlayers must be between 1 and 64 for the current EOS-safe build."
}

if (-not $ServerSaveSlotName) {
    $saveDir = Join-Path $env:LOCALAPPDATA "Subnautica2\Saved\SaveGames"
    $latestSave = Get-ChildItem -LiteralPath $saveDir -Filter "savegame_*.sav" -File -ErrorAction SilentlyContinue |
        Where-Object { $_.BaseName -match '^savegame_\d+$' } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    if ($latestSave) {
        $ServerSaveSlotName = $latestSave.BaseName
    }
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

$cfg = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
Set-JsonProperty $cfg "MaxPlayers" $MaxPlayers
Set-JsonProperty $cfg "ServerMode" "ExperimentalListenHost"
Set-JsonProperty $cfg "ServerListenPort" $Port
Set-JsonProperty $cfg "ServerTravelUrl" $TravelUrl
Set-JsonProperty $cfg "EnableServerAutomation" ([bool]$EnableLuaAutoHost)
$usesOfficialSmokeTest = $ServerApiMode -in @("OfficialSmokeTestLoadGame", "OfficialSmokeTestLanListen")
Set-JsonProperty $cfg "EnableServerApiAutomation" ([bool]$EnableApiAutoHost -and -not $usesOfficialSmokeTest)
Set-JsonProperty $cfg "ServerApiMode" $ServerApiMode
Set-JsonProperty $cfg "EnableRawHostViewModelApi" ([bool]$EnableRawHostViewModelApi)
Set-JsonProperty $cfg "ServerApiMaxAttempts" $ServerApiMaxAttempts
Set-JsonProperty $cfg "ServerApiRetryIntervalMs" $ServerApiRetryIntervalMs
Set-JsonProperty $cfg "ServerCheckpointName" $ServerCheckpointName
Set-JsonProperty $cfg "ServerSaveSlotName" $ServerSaveSlotName
Set-JsonProperty $cfg "ServerAllowNewGameFallback" ([bool]$ServerAllowNewGameFallback)
Set-JsonProperty $cfg "EnableUnsafeTravelAutomation" ([bool]$EnableUnsafeTravelAutomation)
Set-JsonProperty $cfg "PreferEOSLobby" (-not [bool]$IpPortFallback)
Set-JsonProperty $cfg "EnableIpPortFallback" ([bool]$IpPortFallback)
Set-JsonProperty $cfg "LogLevel" "Info"
Set-JsonProperty $cfg "EnableTraceFiles" $true
Set-JsonProperty $cfg "HookProfile" "Production"
Set-JsonProperty $cfg "EnableAdmissionGameSessionPatch" $true
Set-JsonProperty $cfg "EnableDirectSessionCapacityPatch" $true
Set-JsonProperty $cfg "EnableAdmissionReturnPatch" $true
Set-JsonProperty $cfg "RetryUnavailableHooks" $true
$cfg | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $configPath -Encoding UTF8

if ($usesOfficialSmokeTest) {
    New-Item -ItemType Directory -Force -Path $smoketestDir | Out-Null
    if ($ServerApiMode -eq "OfficialSmokeTestLoadGame") {
        if (-not $ServerSaveSlotName) {
            throw "OfficialSmokeTestLoadGame requires a save slot. Create a multiplayer save or pass -ServerSaveSlotName savegame_N."
        }
        $smokeSteps = @(
            [ordered]@{ Action = "Wait"; Arg = "8" },
            [ordered]@{ Action = "ServerLobbyLoadGame"; Arg = $ServerSaveSlotName },
            [ordered]@{ Action = "Wait"; Arg = "20" },
            [ordered]@{ Action = "CheckLevel"; Arg = "L_Main" },
            [ordered]@{ Action = "Message"; Arg = "MorePlayers8 official ServerLobbyLoadGame reached L_Main" },
            [ordered]@{ Action = "Wait"; Arg = "86400" }
        )
    } else {
        $smokeSteps = @(
            [ordered]@{ Action = "Wait"; Arg = "5" },
            [ordered]@{ Action = "ConsoleCommand"; Arg = "open L_Main?listen?bIsLanMatch" },
            [ordered]@{ Action = "Wait"; Arg = "20" },
            [ordered]@{ Action = "CheckLevel"; Arg = "L_Main" },
            [ordered]@{ Action = "Message"; Arg = "MorePlayers8 LAN listen server reached L_Main" },
            [ordered]@{ Action = "Wait"; Arg = "86400" }
        )
    }
    [ordered]@{ Steps = $smokeSteps } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $morePlayersSmokeTestPath -Encoding UTF8
}

if ($OpenFirewall) {
    & (Join-Path $PSScriptRoot "New-MorePlayers8FirewallRule.ps1") -Port $Port -GameRoot $GameRoot
}

$argsList = @(
    "-log",
    "-nosteamcontroller",
    "-Port=$Port",
    "-ini:Engine:[/Script/Engine.GameSession]:MaxPlayers=$MaxPlayers",
    "-ini:Engine:[/Script/Engine.GameSession]:MaxSpectators=$MaxPlayers"
)
if ($NullRHI) { $argsList += "-nullrhi" }
if ($NoSound) { $argsList += "-nosound" }
if ($Windowed) { $argsList += @("-windowed", "-ResX=640", "-ResY=360") }
if ($usesOfficialSmokeTest) { $argsList += "-smoketest=$morePlayersSmokeTestName" }
if ($TravelUrl -and $EnableUnsafeTravelAutomation) {
    $argsList += $TravelUrl
} elseif ($TravelUrl) {
    Write-Warning "TravelUrl is configured but will not be passed on the command line unless -EnableUnsafeTravelAutomation is set."
}

$logDir = Join-Path $modDir "Logs"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$launchRecord = [ordered]@{
    StartedAt = (Get-Date).ToString("o")
    GameRoot = $GameRoot
    ShippingExe = $shippingExe
    WrapperExe = $wrapperExe
    SteamExe = $steamExe
    UseShippingExe = [bool]$UseShippingExe
    UseWrapperExe = [bool]$UseWrapperExe
    Port = $Port
    MaxPlayers = $MaxPlayers
    NullRHI = [bool]$NullRHI
    NoSound = [bool]$NoSound
    IpPortFallback = [bool]$IpPortFallback
    EnableLuaAutoHost = [bool]$EnableLuaAutoHost
    EnableApiAutoHost = [bool]$EnableApiAutoHost
    ServerApiMode = $ServerApiMode
    EnableRawHostViewModelApi = [bool]$EnableRawHostViewModelApi
    ServerApiMaxAttempts = $ServerApiMaxAttempts
    ServerApiRetryIntervalMs = $ServerApiRetryIntervalMs
    ServerCheckpointName = $ServerCheckpointName
    ServerSaveSlotName = $ServerSaveSlotName
    OfficialSmokeTest = [bool]$usesOfficialSmokeTest
    OfficialSmokeTestPath = if ($usesOfficialSmokeTest) { $morePlayersSmokeTestPath } else { "" }
    ServerAllowNewGameFallback = [bool]$ServerAllowNewGameFallback
    EnableUnsafeTravelAutomation = [bool]$EnableUnsafeTravelAutomation
    Monitor = [bool]$Monitor
    MonitorSeconds = $MonitorSeconds
    TravelUrl = $TravelUrl
    Arguments = $argsList
}
$launchRecord | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $logDir "experimental_server_launch.json") -Encoding UTF8
$launchStartedAt = Get-Date

Write-Host "Starting experimental Subnautica 2 graphical host process."
Write-Host "This uses the normal game executable and optional in-game UWE/Sonar API automation."
Write-Host "This is not a verified dedicated/headless server path."
if ($usesOfficialSmokeTest) {
    Write-Host "Server API mode: game built-in UWESmoketest ($ServerApiMode)"
    Write-Host "Smoketest file: $morePlayersSmokeTestPath"
}
if ($EnableApiAutoHost -and $ServerApiMode -eq "ServerLobbyLoadGame") {
    if ($ServerSaveSlotName) {
        Write-Host "Server API mode: UWEServerLobbyComponent.LoadGame('$ServerSaveSlotName')"
    } else {
        Write-Warning "Server API mode is ServerLobbyLoadGame but no save slot was found. Create/select a multiplayer save or pass -ServerSaveSlotName savegame_N."
    }
}
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
Write-Host "Args: $($launchArgs -join ' ')"

Start-Process -FilePath $launchExe -WorkingDirectory $launchCwd -ArgumentList $launchArgs

if ($Monitor) {
    Write-Host ""
    if ($MonitorSeconds -gt 0) {
        Write-Host "Monitoring server evidence for $MonitorSeconds seconds."
    } else {
        Write-Host "Monitoring server evidence. Press Ctrl+C to stop this monitor; it will not close the game."
    }
    Write-Host "Success requires official session creation and real world travel/listen evidence."

    $gameLog = Join-Path $env:LOCALAPPDATA "Subnautica2\Saved\Logs\Subnautica2.log"
    $modLog = Join-Path $logDir "MorePlayers8.log"
    $nativeLog = Join-Path $logDir "native_eos_patch.log"
    $ueCrashDir = Join-Path $env:LOCALAPPDATA "Subnautica2\Saved\Crashes"
    $werCrashDir = Join-Path $env:LOCALAPPDATA "CrashDumps"
    $lastStatus = ""
    $lastCrashPath = ""
    $monitorStartedAt = Get-Date

    while ($true) {
        Start-Sleep -Seconds 2
        $gameProcess = Get-Process -Name "Subnautica2-Win64-Shipping" -ErrorAction SilentlyContinue | Select-Object -First 1
        $status = [ordered]@{
            Time = (Get-Date).ToString("HH:mm:ss")
            GameRunning = [bool]$gameProcess
            UdpPort = [bool](Get-NetUDPEndpoint -LocalPort $Port -ErrorAction SilentlyContinue)
            EOSLobby64 = $false
            EOSCallbackOk = $false
            TravelOk = $false
            InvalidTravel = $false
            NetDriver = $false
            PreLoginFull = $false
            SmokeTestStarted = $false
            SmokeTestSucceeded = $false
            SmokeTestFailed = $false
            Crash = $false
            CrashPath = ""
        }

        if (Test-Path -LiteralPath $nativeLog) {
            $tail = Get-Content -LiteralPath $nativeLog -Tail 120 -ErrorAction SilentlyContinue
            $status["EOSLobby64"] = [bool]($tail | Select-String -SimpleMatch "afterMaxLobbyMembers=$MaxPlayers")
            $status["EOSCallbackOk"] = [bool]($tail | Select-String -SimpleMatch "EOS_Lobby_CreateLobby callback result=0")
        }
        if (Test-Path -LiteralPath $gameLog) {
            $tail = Get-Content -LiteralPath $gameLog -Tail 500 -ErrorAction SilentlyContinue
            $status["TravelOk"] = [bool]($tail | Select-String -Pattern "ProcessServerTravel|Server switch level|Browse: /Game/Maps/Main/L_Main|Server travel to level|Loading server game")
            $status["InvalidTravel"] = [bool]($tail | Select-String -SimpleMatch "CanServerTravel: FURL")
            $status["NetDriver"] = [bool]($tail | Select-String -Pattern "GameNetDriver|NotifyAcceptingConnection|NotifyAcceptingChannel|PostLogin")
            $status["PreLoginFull"] = [bool]($tail | Select-String -SimpleMatch "PreLogin failure: Server full")
            $status["SmokeTestStarted"] = [bool]($tail | Select-String -Pattern "Starting smoketest|Starting smoke.?test|Advancing to step|Executing step")
            $status["SmokeTestSucceeded"] = [bool]($tail | Select-String -Pattern "Smoketest succeeded|Smoke.?test succeeded|CheckLevel succeeded|MorePlayers8 .* reached L_Main")
            $status["SmokeTestFailed"] = [bool]($tail | Select-String -Pattern "Smoketest failed|Smoke.?test failed|Level Name is .*, but we expected|Step action type .* not supported|Player controller does not have ServerLobbyComponent")
        }
        $latestUECrash = Get-ChildItem -Force $ueCrashDir -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -ge $launchStartedAt.AddSeconds(-5) } |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
        $latestWERDump = Get-ChildItem -Force $werCrashDir -Filter "Subnautica2-Win64-Shipping.exe*.dmp" -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -ge $launchStartedAt.AddSeconds(-5) } |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
        if ($latestUECrash -or $latestWERDump) {
            $status["Crash"] = $true
            if ($latestWERDump) {
                $status["CrashPath"] = $latestWERDump.FullName
            } else {
                $status["CrashPath"] = $latestUECrash.FullName
            }
        }

        $line = "[$($status["Time"])] running=$($status["GameRunning"]) smokeStarted=$($status["SmokeTestStarted"]) smokeOk=$($status["SmokeTestSucceeded"]) smokeFail=$($status["SmokeTestFailed"]) eosLobby=$($status["EOSLobby64"]) eosOk=$($status["EOSCallbackOk"]) travel=$($status["TravelOk"]) invalidTravel=$($status["InvalidTravel"]) udp$Port=$($status["UdpPort"]) netDriver=$($status["NetDriver"]) preLoginFull=$($status["PreLoginFull"]) crashRecent=$($status["Crash"])"
        if ($line -ne $lastStatus) {
            Write-Host $line
            $lastStatus = $line
        }
        if ($status["CrashPath"] -and $status["CrashPath"] -ne $lastCrashPath) {
            Write-Warning "Crash evidence captured: $($status["CrashPath"])"
            $lastCrashPath = $status["CrashPath"]
        }
        if ($MonitorSeconds -gt 0 -and ((Get-Date) - $monitorStartedAt).TotalSeconds -ge $MonitorSeconds) {
            Write-Host "Monitor finished after $MonitorSeconds seconds; game process is left running for manual inspection."
            break
        }
    }
}
