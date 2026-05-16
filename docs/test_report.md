# Test Report

Updated: 2026-05-17 00:05 CST

## Completed

- Verified game root exists: `D:\SteamLibrary\steamapps\common\Subnautica2`
- Located launcher and shipping executable.
- Recorded game build metadata and hashes.
- Installed UE4SS dev build with UE 5.6 override.
- Verified UE4SS loads `Subnautica2MorePlayers8`.
- Verified `build.ps1`, `install.ps1`, and `tools\verify_install.ps1` pass.
- Analyzed `crash_2026_05_15_23_51_31.6512637.dmp`; crash source was UE4SS Lua UObject name binding from unsafe reflection.
- Disabled unsafe UObject reflection, global UMG text hooks, and broad widget sweeps for normal runtime.
- Verified native EOS patch installs on the known shipping EXE hash.
- Verified `EOS_Lobby_CreateLobby` receives `MaxLobbyMembers=4` and is patched to `8`.
- Verified `EOS_LobbyModification_SetMaxMembers` receives `MaxMembers=4` and is patched to `8`.
- Verified `EOS_LobbyDetails_CopyInfo` reports `MaxMembers=8` and `AvailableSlots=7` after host lobby creation.
- Identified top lobby count source as `/Script/Subnautica2.SN2InGameFriendScreenViewModel:AssemblePlayercountString`.
- Verified the ViewModel returns `1/4` before patch and is patched to `1/8`.
- User screenshot confirms the top lobby UI displays `1/8`.
- Host-side 5th player attempt now has a precise failure point in `Subnautica2.log`: the client reaches `GameNetDriver`, sends a UE login request, and is rejected by `PreLogin failure: Server full.`
- Identified and patched the exact known-hash native `ApproveLogin -> Server full.` branch in runtime memory.

## Latest Build

- Lua version after current target change: `0.3.5-1024-production`
- Default config:
  - `MaxPlayers=1024`
  - `HookProfile=Production`
  - `EnableNativeEOSCapacityPatch=true`
  - `NativePatchRequireKnownHash=true`
  - `EnableTargetedUIPatch=true`
  - `EnableTargetedUISweeps=false`
  - `EnableTargetedUIAllTextSweep=false`
  - `EnableUnsafeObjectReflection=false`
  - `LogLevel=Warn`
  - `EnableTraceFiles=false`
  - `HookProfile=ProductionLean`
  - `EnableSafeParamProbe=false`
  - `EnableAdmissionGameSessionPatch=false`
  - `EnableDirectSessionCapacityPatch=false`
  - `EnableNativeUnrealServerFullAdmissionPatch=true`
  - `EnableUIPatch=false`
  - `NativePatchLogAllCalls=false`

This is a 1024-player production-profile target. The 8-player path and player 5 joining have been reported as validated by the user; 1024-player capacity/world sync has not been validated.

## 1024 Production Update - 2026-05-17 00:05 CST

User-provided validation:

- 8-player test passed.
- Player 5 can join.

Code/config changes made before rebuilding:

- Project `MorePlayers8.json` changed to `MaxPlayers=1024`.
- Lua version changed to `0.3.5-1024-production`.
- Lua/native defaults and clamps changed to `1024`.
- `build.ps1`, `install.ps1`, and `tools\verify_install.ps1` validate `1..1024`.
- Player-facing docs now tell testers to expect `1/1024`.
- Production logging profile:
  - `LogLevel=Warn`
  - `EnableTraceFiles=false`
  - `EnableSafeParamProbe=false`
  - `HookProfile=ProductionLean`
  - Lua-side admission/session polling disabled
  - native per-call logging disabled

Pending verification for this section:

- Rebuild native DLL: passed.
- Install locally: passed.
- Verify installed config and `Game.ini` override show `1024`: passed.
- Refresh `Z:\Subnautica2MorePlayers8`: passed.
- Runtime game launch and `1/1024` UI confirmation.

## 32 Target Update - 2026-05-16 23:45 CST

Code/config changes made before rebuilding:

- Project `MorePlayers8.json` changed to `MaxPlayers=32`.
- Lua default and clamp changed to `32`.
- Native default and clamp changed to `32`.
- `build.ps1`, `install.ps1`, and `tools\verify_install.ps1` now validate `1..32`.
- One-click installer fallback display changed to `32`.
- README and Chinese install docs now describe the 32-player target.

Pending verification for this section:

- Rebuild native DLL.
- Install locally.
- Verify installed config and `Game.ini` override show `32`.
- Refresh `Z:\Subnautica2MorePlayers8`.

## 1024 Target Update - 2026-05-16 23:30 CST

Code/config changes made before rebuilding:

- Project `MorePlayers8.json` changed to `MaxPlayers=1024`.
- Lua clamp raised from `32` to `1024`.
- Native clamp raised from `32` to `1024`.
- `build.ps1` now accepts `MaxPlayers` from `1` through `1024`.
- `install.ps1` now reads the built config value and writes the same value into the reversible `Game.ini` override.
- `tools\verify_install.ps1` now checks installed config validity and confirms the `Game.ini` override matches the installed config.
- Targeted UI player-count rewrite now handles any denominator below the configured cap, not only `/4`.
- EOS capacity string metadata patch now writes the configured cap instead of only supporting `"4" -> "8"`.

Verification for this section:

- Rebuilt native DLL: passed.
- Installed locally: passed.
- Installed config and `Game.ini` override show `1024`: passed.
- `Z:\Subnautica2MorePlayers8` refresh: passed.

## Local Verification - 2026-05-16 23:28 CST

Commands run after the 1024 target pass:

- `.\build.ps1`: passed.
- `.\install.ps1 -GameRoot "D:\SteamLibrary\steamapps\common\Subnautica2"`: passed.
- `.\tools\verify_install.ps1 -GameRoot "D:\SteamLibrary\steamapps\common\Subnautica2"`: passed all checks.

Installed-state checks:

- Installed Lua version: `0.3.3-1024-diagnostic`.
- Installed native DLL SHA256: `2CBC491F5EFCA1E39C8B730BA41E2F9791931BA0D948AAA6D652A7CC3D61429D`.
- Installed `MorePlayers8.json` contains `MaxPlayers=1024`.
- Installed `install_manifest.json` records `MaxPlayers=1024`.
- `%LOCALAPPDATA%\Subnautica2\Saved\Config\Windows\Game.ini` contains the marked `Subnautica2MorePlayers8` session override block with `MaxPlayers=1024`, `MaxSpectators=1024`, `MaxSplitscreens=1024`, and `MaxPartySize=1024`.
- `tools\verify_install.ps1` reported `ModConfigMaxPlayersValid=true` and `GameIniMaxPlayersMatchesConfig=true`.

This verification is not a multiplayer pass. It proves only that the 1024-target build/install/config state is correct on disk.

## Shared Package - 2026-05-16

Uncompressed package refreshed at:

```text
Z:\Subnautica2MorePlayers8
```

Included:

- One-click install/uninstall scripts.
- Prebuilt `dist\Subnautica2MorePlayers8` with Lua `0.3.5-1024-production`.
- Prebuilt native DLL SHA256 `7E570AC2E38A109526F53CD08BC09E81131CD9761873068DB971927075C2FBE9`.
- `MorePlayers8.json` with `MaxPlayers=1024`.
- Bundled UE4SS dev files.
- Chinese install docs.
- `Collect-MorePlayers8Logs.cmd` for failed player-5 tests.

Validation after refresh:

- `Z:\Subnautica2MorePlayers8\dist\Subnautica2MorePlayers8\MorePlayers8.json` contains `MaxPlayers=1024`.
- `Z:\Subnautica2MorePlayers8\dist\Subnautica2MorePlayers8\scripts\main.lua` reports `0.3.5-1024-production`.
- `Z:\Subnautica2MorePlayers8\dist\Subnautica2MorePlayers8\native\MorePlayers8Native.dll` SHA256 is `7E570AC2E38A109526F53CD08BC09E81131CD9761873068DB971927075C2FBE9`.
- `Z:\Subnautica2MorePlayers8\tools\verify_install.ps1 -GameRoot "D:\SteamLibrary\steamapps\common\Subnautica2"` passed all checks against the local install.

## Verified Capacity Evidence

Real lobby capacity evidence from native logs:

- `EOS_Lobby_CreateLobby ... beforeMaxLobbyMembers=4 afterMaxLobbyMembers=8 changed=true`
- `EOS_LobbyModification_SetMaxMembers ... before=4 after=8 changed=true`
- `EOS_LobbyDetails_CopyInfo ... beforeMaxMembers=8 afterMaxMembers=8 beforeAvailableSlots=7 afterAvailableSlots=7`

UI evidence:

- `SN2InGameFriendScreenViewModel:AssemblePlayercountString`
- Before patch: `1/4`
- After patch: `1/8`
- Screenshot: visible top lobby UI shows `1/8`

## Not Verified

- Fifth-player join acceptance.
- Sixth, seventh, and eighth player join acceptance.
- Any player above 8.
- Player 5-8 spawn/pawn creation.
- Player 5-8 `PlayerController` / `PlayerState` behavior.
- Player 5-8 save/rejoin behavior.
- Player 5-8 world replication/synchronization.
- Whether non-host clients can safely remain unmodded.
- Whether long-session 8-player gameplay is stable.
- EOS/Steam acceptance and stability with `MaxPlayers=1024`.

## Host-Only 5-Player Attempt - 2026-05-16

Scenario:

- Host had the mod installed.
- Other clients were initially treated as host-only validation unless separately confirmed.
- Host UI reached `4/8` before the fifth player attempt.
- Fifth player reported: "You were disconnected from the game process" / `你与游戏进程断开连接`.

Evidence from host logs before manual host exit:

- `Subnautica2.log` at `2026-05-16 20:22:05` records `EOS_P2P_AcceptConnection` for a new remote peer on `SocketId=[GameNetDriver]` with `Result=[EOS_Success]`.
- `Subnautica2.log` at `2026-05-16 20:22:06` records `PeerConnection has successfully connected` and `Connection established` for that new peer.
- `MorePlayers8.log` shows the visible count had reached `4/8`, but no `5/8` UI update was recorded before host shutdown.
- The later `20:22:07` world teardown, `GameNetDriver` shutdown, and `ClosedLocally` lines were caused by the host manually exiting the game and are not treated as the root cause.

Current interpretation:

- The fifth player was not blocked at the EOS lobby capacity layer.
- The fifth player reached EOS P2P / `GameNetDriver` connection establishment on the host.
- The host rejected the fifth player during Unreal `PreLogin` with `Server full.`
- In this failed run, Unreal login did not complete for player 5, so no player 5 `PlayerController`, `PlayerState`, pawn spawn, or world replication was verified.

Instrumentation / patch gap found:

- Some join-related hooks (`PreLogin`, `PostLogin`, `RegisterPlayer`, `ApproveLogin`) were unavailable during early startup and were not retried in the previous build.
- The Lua script now retries join hook registration at startup +15s, +45s, and +90s so the next attempt has better host-side evidence.
- `RegisterInitGameStatePostHook` was previously treated as if it passed `GameMode`; UE4SS documentation and behavior indicate it passes `GameState`. The old code therefore did not reliably patch `AuthorityGameMode.GameSession` for the main listen-server world.
- Version `0.3.0-admission-gamesession-patch` added a narrow admission patch that reads `GameState.AuthorityGameMode.GameSession`, scans only `SN2GameSession` / `GameSession` instances, and keeps direct `MaxPlayers` / `MaxPartySize` fields at `8`.
- Version `0.3.2-session-admission-ini-hardening` adds a local `Game.ini` session override and a hash/byte-gated native patch for the exact `ApproveLogin -> Server full.` branch observed in the 5-player failure.

Next validation target:

- Host log must no longer contain `PreLogin failure: Server full.` for the fifth player.
- If player 5 still disconnects, the next failure line after `Login request` determines the next patch target.
- If player 5 reaches `Join succeeded`, validation moves to spawn, PlayerState/team view model, pawn, inventory, and world replication.

## Install Scope Guidance

Current conservative requirement: install the mod on the host and all clients.

Reason:

- The host-side EOS lobby member limit is confirmed patched to 8.
- The host-side UI now shows 1/8.
- Client-side join UI, join validation, world spawn, and replication paths for players 5-8 have not been tested.
- Until a controlled host-only test proves otherwise, all clients should run the same mod/config to avoid client-side 4-player assumptions.

Host-only may be possible if all remaining 4-player assumptions are server-side only, but this is not verified and should not be documented as production usage yet.

## 8-Player Validation Plan

Required setup:

- 1 host Steam account with the mod installed.
- 7 additional real Steam/EOS clients, each with the same mod installed for the first validation pass.
- Use the official friend-code/invite flow.
- Do not bypass Steam/EOS authentication.

Steps:

1. Host installs the mod and starts the game through Steam.
2. Host creates a multiplayer lobby.
3. Confirm host UI displays `1/8`.
4. Confirm host `native_eos_patch.log` contains `MaxLobbyMembers=8` and `AvailableSlots=7`.
5. Player 2 joins; verify lobby count updates and world sync.
6. Player 3 joins; verify lobby count updates and world sync.
7. Player 4 joins; verify lobby count updates and world sync.
8. Player 5 joins; this is the first critical test. If rejected, save host/client logs immediately.
9. Players 6-8 join one at a time, saving logs after each join.
10. All 8 players load into the world.
11. Verify each player can move, interact with world objects, see other players, and receive replicated state.
12. Host saves, at least one of players 5-8 disconnects/rejoins, and state is verified again.

Pass criteria:

- Lobby shows up to `8/8`.
- No player 5-8 join rejection.
- No host/client crash.
- Players 5-8 spawn correctly.
- Players 5-8 can see and be seen by other players.
- World interactions replicate for players 5-8.
- Save/rejoin works for at least one of players 5-8.

## Current Verdict

Configured for a 1024-player production-profile target, not 1024-player verified.

Verified:

- Real EOS lobby capacity is patched from 4 to 8 for the known game hash.
- Host lobby UI now displays `1/8`.
- Mod is buildable, installable, uninstallable, and hash-gated for native EOS patching.

Not verified:

- Actual 8-person join.
- Actual 1024-person join.
- Player 9+ world synchronization.
- Any world synchronization above 8.
- Whether only the host can install the mod.

Until real-client validation passes, do not claim this is a fully verified production mod.
