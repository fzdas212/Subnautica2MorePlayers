# Subnautica2MorePlayers8 Handoff

Last updated: 2026-05-18 Asia/Shanghai

This document is the handoff state for the next engineer. Treat this file and `docs/current_progress.md` as the source of truth instead of relying on chat history.

## Current Deliverable

- Project root: `C:\tmp\Subnautica2MorePlayers-github`
- Game root: `D:\SteamLibrary\steamapps\common\Subnautica2`
- Installed mod:
  `D:\SteamLibrary\steamapps\common\Subnautica2\Subnautica2\Binaries\Win64\ue4ss\Mods\Subnautica2MorePlayers8`
- Uncompressed package for players:
  `Z:\Subnautica2MorePlayers8`
- Desktop zip package:
  `C:\Users\fzc\Desktop\Subnautica2MorePlayers8-v0.3.6-64-production.zip`
  - Note: verify or recreate this zip if files changed after it was created.

## Current Version

- Mod version: `0.3.6-64-production`
- Real target cap: `64`
- UI target cap: `64`
- Main config: `MorePlayers8.json`
- Native DLL SHA256:
  `ECDF449F75EF023376C97CBD0AFC466C2C8960E4EF2C3B1CADB69638747571F8`
- Experimental server framework:
  - added, not validated as a working headless/dedicated server
  - see `docs/server_mod_plan.md`

## Supported Game Build

- Build label: `34_SHIPPING_RELEASEHOTFIXLIVE_CL-113109_B-13`
- Build timestamp: `2026-05-10T04:15:22`
- Shipping EXE:
  `D:\SteamLibrary\steamapps\common\Subnautica2\Subnautica2\Binaries\Win64\Subnautica2-Win64-Shipping.exe`
- Shipping EXE SHA256:
  `E9D32E1693BEDBD4CB6BA6D7DB5FF9BB6EE34FA36AEF73F154B3CDC6B64D2CF4`

Native patching is hash-gated. If the EXE hash changes, do not force native patches without re-finding signatures/offsets.

## Current Configuration

`MorePlayers8.json` is set for production-lean runtime:

- `MaxPlayers=64`
- `LogLevel=Warn`
- `EnableTraceFiles=false`
- `HookProfile=ProductionLean`
- `EnableSafeParamProbe=false`
- `EnableUnsafeObjectReflection=false`
- `EnableTargetedUIPatch=true`
- `EnableTargetedUISweeps=false`
- `EnableNativeEOSCapacityPatch=true`
- `NativePatchRequireKnownHash=true`
- `EnableNativeUnrealServerFullAdmissionPatch=true`
- `NativePatchLogAllCalls=false`
- Lua-side admission/session polling is disabled:
  - `EnableAdmissionGameSessionPatch=false`
  - `EnableDirectSessionCapacityPatch=false`
  - `EnableAdmissionReturnPatch=false`

This is intended to reduce performance overhead after the 8-player path was validated.

## What Is Patched

Lua:

- `src\MorePlayers8\scripts\main.lua`
- Version string: `0.3.6-64-production`
- Config clamp: `MaxPlayers` is clamped to `64`.
- UI source patch:
  `/Script/Subnautica2.SN2InGameFriendScreenViewModel:AssemblePlayercountString`
- The ViewModel return string rewrites lower denominators to configured `MaxPlayers`, so expected lobby UI is `1/64`.
- `ProductionLean` hook profile only keeps:
  - `join`
  - `ui-playercount`

Native:

- `src\MorePlayers8\native\MorePlayers8Native.cpp`
- Default/clamp: `64`.
- Hooks EOS lobby/session capacity APIs:
  - `EOS_Lobby_CreateLobby`
  - `EOS_LobbyModification_SetMaxMembers`
  - `EOS_Sessions_CreateSessionModification`
  - `EOS_SessionModification_SetMaxPlayers`
  - related copied info / attributes where safe
- Attempts Steam lobby APIs if present, but this game path appears EOS-based.
- Patches known `AGameSession::ApproveLogin -> Server full.` branch:
  - RVA: `0x03FBC7E3`
  - Original bytes: `74 0C 48 8D 15 24 F8 3B 06 E9 B4 00 00 00`
  - Patched bytes: `EB 0C 48 8D 15 24 F8 3B 06 E9 B4 00 00 00`
  - Runtime memory patch only; game EXE file is not permanently modified.

## Important Lessons / Pitfalls

Do not set EOS lobby creation to `1024`.

Observed failure:

- Build `0.3.5-1024-production` patched:
  `EOS_Lobby_CreateLobby MaxLobbyMembers 4 -> 1024`
- EOS callback returned:
  `result=10`
- Game UI showed:
  `鍒涘缓娓告垙杩涚▼澶辫触锛岃妫€鏌ョ綉缁滆繛鎺

Interpretation:

- EOS rejected `MaxLobbyMembers=1024`.
- This failure happens before the game world/session starts.
- It is not a UI-only issue.
- Current practical EOS lobby target is `64`.

If someone wants UI to display a different marketing number while real EOS stays 64, that must be implemented explicitly as a separate `DisplayMaxPlayers` value. Do not overload `MaxPlayers` for both real capacity and UI.

## Verified

User-reported live validation:

- 8-player path has been validated.
- Player 5 can join.

Local technical verification:

- UE4SS loads on current game build.
- Build/install/verify scripts pass.
- Installed config and `%LOCALAPPDATA%\Subnautica2\Saved\Config\Windows\Game.ini` both show `64`.
- `Z:\Subnautica2MorePlayers8` package was refreshed and verified.
- Native DLL currently hashes to:
  `A103ED0471F92ADCFB907D09B38BF23026BF9F02CB530D8150027FD18D168B48`

## Not Verified

- 64 real clients joining.
- World spawn/sync above 8 players.
- Long-session stability above 8 players.
- Host-only install for all cases.
- Game update compatibility after EXE hash changes.
- Experimental `-nullrhi` / low-graphics server launch.
- IP:Port direct join.
- Any true dedicated-server or headless production hosting path.

## Experimental Server Framework

Added on 2026-05-18:

- `MorePlayers8.Server.example.json`
- `Start-ExperimentalServer.cmd`
- `Join-ExperimentalServer.cmd`
- `tools\Start-ExperimentalServer.ps1`
- `tools\Join-ExperimentalServer.ps1`
- `tools\New-MorePlayers8FirewallRule.ps1`
- `docs\server_mod_plan.md`

This is a test harness, not a proven server implementation.

The intended validation path is:

1. Run a normal low-graphics listen host with `-Windowed`. Avoid `-NoSound` by default because the 2026-05-18 WER dump points at `fmodstudio.dll`.
2. Check that UE4SS and the mod load.
3. Check whether a multiplayer world can tick without interactive UI hosting.
4. Try `-NullRHI` only after the low-graphics path is understood.
5. If a `GameNetDriver` listen socket exists, test `Join-ExperimentalServer.ps1 -Address <host-ip> -Port 7777`.
6. If direct `open IP:Port` is rejected, do not claim fallback support; stay on EOS lobby route.

The new Lua automation is default-off:

- `EnableServerAutomation=false`
- `EnableDirectConnectAutomation=false`

It only attempts `servertravel/open` console commands when explicitly enabled by config/script.

## Build / Install / Verify

Build:

```powershell
cd C:\tmp\Subnautica2MorePlayers-github
.\build.ps1
```

Install:

```powershell
cd C:\tmp\Subnautica2MorePlayers-github
.\install.ps1 -GameRoot "D:\SteamLibrary\steamapps\common\Subnautica2"
```

Verify:

```powershell
cd C:\tmp\Subnautica2MorePlayers-github
.\tools\verify_install.ps1 -GameRoot "D:\SteamLibrary\steamapps\common\Subnautica2"
```

Refresh player package:

```powershell
# Use the existing manual copy flow from recent history or Package-Release.ps1.
# Current handoff package is already at Z:\Subnautica2MorePlayers8.
```

Create desktop zip:

```powershell
Compress-Archive -LiteralPath "Z:\Subnautica2MorePlayers8" -DestinationPath "$env:USERPROFILE\Desktop\Subnautica2MorePlayers8-v0.3.6-64-production.zip" -Force
```

## Logs To Check

Mod logs:

```text
D:\SteamLibrary\steamapps\common\Subnautica2\Subnautica2\Binaries\Win64\ue4ss\Mods\Subnautica2MorePlayers8\Logs
```

Game logs:

```text
%LOCALAPPDATA%\Subnautica2\Saved\Logs
```

Useful files:

- `native_eos_patch.log`
- `MorePlayers8.log`
- `Subnautica2.log`

Expected after host creation in current 64 build:

- `EOS_Lobby_CreateLobby ... afterMaxLobbyMembers=64 ... changed=true`
- callback should not be the repeated `result=10` failure seen with 1024
- native patch status should include `unrealServerFullAdmission=true`
- top lobby UI should show `1/64`

## Next Test Plan

1. Install `Z:\Subnautica2MorePlayers8` on host and all testers.
2. Host creates a lobby.
3. Confirm lobby creation succeeds.
4. Confirm UI shows `1/64`.
5. Confirm `native_eos_patch.log` shows `afterMaxLobbyMembers=64`.
6. Add players gradually:
   - 1-8: already broadly validated, re-check with current 64 production build.
   - 9-16: first new risk band.
   - 17-32: second risk band.
   - 33-64: final target band.
7. For each band verify:
   - join succeeds
   - spawn succeeds
   - movement replicates
   - other players are visible
   - inventory/interactions replicate
   - save/rejoin works for at least one player above 8

If a failure occurs, collect logs immediately with:

```text
Collect-MorePlayers8Logs.cmd
```

Run it on both host and the failing client.

## Current Risk Assessment

- EOS lobby cap should be more realistic at 64 than 1024.
- The game may still contain world/gameplay assumptions above 8.
- The production-lean profile reduces overhead but also reduces diagnostic detail; temporarily enable trace/log options only when actively debugging.
- Do not re-enable unsafe UObject reflection unless investigating in a controlled crash-tolerant run.

## 2026-05-18 Server Console Handoff Update

The service/server direction is still unfinished.

Latest crash evidence:

- Crash folder:
  `%LOCALAPPDATA%\Subnautica2\Saved\Crashes\UECC-Windows-E68FA0FF4A9BE096C6DA3790B50493C4_0000`
- Crash:
  `EXCEPTION_ACCESS_VIOLATION reading address 0x0000000000000018`
- Stack:
  UE4SS Lua UObject member access during `RegisterStaticConstructObjectPostCallback`.
- Engineering conclusion:
  do not use broad object construction watchers or unsafe UObject reflection in production.

Experimental server changes:

- `Start-GraphicalServerConsole.cmd` added.
- `tools\Start-ExperimentalServer.ps1` gained:
  - `-Monitor`
  - `-ServerApiMode UiLaunchGame|RawHostViewModel`
  - `-EnableRawHostViewModelApi`
  - `-ServerApiMaxAttempts`
- Lua config gained:
  - `ServerApiMode`
  - `EnableRawHostViewModelApi`
  - `ServerApiMaxAttempts`
- Default server API automation is now `UiLaunchGame` and attempts only once.
- Raw `TriggerHostGameRequest` is deliberately gated because it produced:
  `CanServerTravel: FURL L_Main?listen?game=EGameModeAliasAsEnum::Survival blocked, contains : or \`

Current recommended test command:

```powershell
cd C:\tmp\Subnautica2MorePlayers-github
.\Start-GraphicalServerConsole.cmd -GameRoot "D:\SteamLibrary\steamapps\common\Subnautica2" -Restart
```

Pass criteria are printed by the monitor. The key evidence is not just process startup; it must show EOS create success, valid travel into `L_Main`, and eventually NetDriver/PostLogin evidence.

## 2026-05-18 Direct API Update

The next engineer should prefer `ServerLobbyLoadGame` over `UiLaunchGame`.

Why:

- Shipping EXE strings identify `UWEServerLobbyComponent.cpp` as the owner of the official server load path.
- It logs `Server travel to level %s with options %s`.
- It emits URL options like `?LaunchType=LoadGame?SaveSlotName=%s`.
- This is a better target than calling `WBP_LoadGamePanel1_C:LaunchGame("")`, which can return successfully without a selected save.

Current implementation:

- Lua version: `0.3.8-64-server-lobby-loadgame-retry`.
- Default graphical console mode:
  `ServerApiMode=ServerLobbyLoadGame`.
- Launcher auto-detects the newest local save file such as `savegame_1.sav` and writes:
  `ServerSaveSlotName=savegame_1`.
- Lua calls:
  `UWEServerLobbyComponent:LoadGame(ServerSaveSlotName)`.
- If that fails, Lua tries `ContinueFromLatestSave`.
- `StartNewGame` fallback is disabled unless `ServerAllowNewGameFallback=true`.
- The first validation found a nullptr `UWEServerLobbyComponent`; current code enumerates all candidates and retries up to 8 times.

Still required:

- Build/install/verify.
- Launch through Steam with `Start-GraphicalServerConsole.cmd -Restart`.
- Confirm the monitor shows valid travel/listen evidence.
- If it still does not travel, collect `Subnautica2.log`, `MorePlayers8.log`, `capacity_trace.txt`, and `native_eos_patch.log`.

## 2026-05-18 Handoff Update - UWESmoketest server console

The current server-console branch has moved away from direct Lua calls to `UWEServerLobbyComponent`.

Reason:

- `FindAllOf("UWEServerLobbyComponent")` / `FindFirstOf("UWEServerLobbyComponent")` did not produce a callable live component at main-menu time.
- Calls to `LoadGame` and `ContinueFromLatestSave` returned `UObject instance is nullptr`.

New route:

- Use the shipped `UWESmoketest` subsystem from command line.
- Default console mode is now:
  `OfficialSmokeTestLanListen`
- The launcher creates:
  `D:\SteamLibrary\steamapps\common\Subnautica2\Subnautica2\Content\Smoketest\smoketest-moreplayers8-server.json`
- Default generated steps:
  - wait 5 seconds
  - `ConsoleCommand`: `open L_Main?listen?bIsLanMatch`
  - wait 20 seconds
  - `CheckLevel`: `L_Main`
  - `Message`: `MorePlayers8 LAN listen server reached L_Main`

Files changed:

- `src\MorePlayers8\scripts\main.lua`
- `tools\Start-ExperimentalServer.ps1`
- `Start-GraphicalServerConsole.cmd`
- `MorePlayers8.json`
- `MorePlayers8.Server.example.json`
- `uninstall.ps1`
- `docs\server_console_status_zh.md`

Validation still required:

```powershell
cd C:\tmp\Subnautica2MorePlayers-github
.\build.ps1
.\install.ps1 -GameRoot "D:\SteamLibrary\steamapps\common\Subnautica2"
.\tools\verify_install.ps1 -GameRoot "D:\SteamLibrary\steamapps\common\Subnautica2"
.\Start-GraphicalServerConsole.cmd -GameRoot "D:\SteamLibrary\steamapps\common\Subnautica2" -Restart
```

Success requires the monitor to show smoketest started, travel to `L_Main`, UDP/listen or NetDriver evidence, and no recent crash dump. Do not claim a dedicated/headless server unless that separate route is later proven.

## 2026-05-18 Handoff Update - Server console validation passed locally

This is the latest state.

Current mod version:

- Lua: `0.3.9-64-official-smoketest-server-console`
- Current real target: `64`
- Current server-console mode:
  `OfficialSmokeTestLanListen`

Local validation command:

```powershell
cd C:\tmp\Subnautica2MorePlayers-github
.\tools\Start-ExperimentalServer.ps1 -GameRoot "D:\SteamLibrary\steamapps\common\Subnautica2" -Windowed -ServerApiMode OfficialSmokeTestLanListen -Monitor -MonitorSeconds 300 -Restart
```

Confirmed:

- Game launched through Steam.
- Game process stayed alive through the 300-second monitor.
- `UWESmoketest` started.
- Generated server smoketest executed:
  `open L_Main?listen?bIsLanMatch`
- Game loaded:
  `/Game/Maps/Main/L_Main`
- `GameNetDriver` initialized.
- UDP `0.0.0.0:7777` was listening.
- `CheckLevel` succeeded for `L_Main`.
- No new UE/WER crash dump was detected.
- No `RequestExit(0)` occurred after smoketest success because the generated file ends with `Wait 86400`.

Still not proven:

- Client join through IP:Port.
- 5+ players through the CMD listen-host route.
- World sync through the CMD listen-host route.
- True headless/dedicated server.

Client helper changed:

- `tools\Join-ExperimentalServer.ps1` now launches through Steam by default.
- It generates:
  `Subnautica2\Content\Smoketest\smoketest-moreplayers8-client.json`
- The generated client step is:
  `open <host>:7777`
- Direct shipping EXE launch is now a debug-only option via `-UseShippingExe`.

Recommended next real-machine validation:

1. Keep the server running with `Start-GraphicalServerConsole.cmd`.
2. On another Steam account/machine, install the same package.
3. Run `Join-ExperimentalServer.cmd`.
4. Enter the host LAN IP.
5. Confirm client reaches `L_Main`.
6. Confirm host log has a login/PostLogin path and no `Server full`.
7. Repeat with 5+ clients before claiming server-console multiplayer support.

Package state after this validation:

- Uncompressed package refreshed:
  `Z:\Subnautica2MorePlayers8`
- Desktop zip:
  `C:\Users\fzc\Desktop\Subnautica2MorePlayers8-v0.3.9-64-server-console.zip`
- Desktop zip hash is reported outside this file to avoid changing the archive content when the hash line changes.

## 2026-05-18 Handoff Update - Join CMD UNC fix

User reported that `Join-ExperimentalServer.cmd` failed when launched from a UNC share:

```text
UNC 路径不受支持。默认值设为 Windows 目录。
无法将参数绑定到参数“Address”，因为该参数为空字符串。
```

Fix applied:

- `Join-ExperimentalServer.cmd` now runs `pushd "%~dp0"` before invoking PowerShell.
- This lets Windows map UNC paths to a temporary drive letter for the command session.
- The prompted IP address is no longer expanded inside the same parenthesized `if` block that calls `set /p`, so it is not passed as an empty string.
- Supported usage:
  - double-click and enter the IP when prompted;
  - `Join-ExperimentalServer.cmd 192.168.1.3`;
  - `Join-ExperimentalServer.cmd -Address 192.168.1.3 -Port 7777`.

## 2026-05-18 Handoff Update - Listen host UI count

User verified a remote client can join the graphical CMD/IP listen host. Host log shows:

- `NotifyAcceptedConnection`
- `Login request`
- `Join request`
- `Join succeeded`
- second `BP_SN2PlayerState` added to the team view model

Remaining issue:

- Friend/player UI still displayed `0/64`.

Cause:

- The IP listen-host route does not create/populate the normal default Sonar/EOS session object used by `SN2InGameFriendScreenViewModel:AssemblePlayercountString`.
- The previous patch only fixed the denominator; it preserved the empty-session numerator.

Fix:

- Lua version is now `0.3.10-64-listen-ui-count`.
- Player count text rewriting now uses live world count from `GameState.PlayerArray` or `PlayerState` instances when that count is higher than the session-derived number.

Next validation:

- Build/install.
- Restart host.
- Have one remote client join.
- Open the player/friend list and confirm it shows `2/64`.
