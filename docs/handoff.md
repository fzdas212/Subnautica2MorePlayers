# Subnautica2MorePlayers8 Handoff

Last updated: 2026-05-17 Asia/Shanghai

This document is the handoff state for the next engineer. Treat this file and `docs/current_progress.md` as the source of truth instead of relying on chat history.

## Current Deliverable

- Project root: `C:\tmp\Subnautica2MorePlayers8`
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
  `A103ED0471F92ADCFB907D09B38BF23026BF9F02CB530D8150027FD18D168B48`

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
  `创建游戏进程失败，请检查网络连接`

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

## Build / Install / Verify

Build:

```powershell
cd C:\tmp\Subnautica2MorePlayers8
.\build.ps1
```

Install:

```powershell
cd C:\tmp\Subnautica2MorePlayers8
.\install.ps1 -GameRoot "D:\SteamLibrary\steamapps\common\Subnautica2"
```

Verify:

```powershell
cd C:\tmp\Subnautica2MorePlayers8
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
