# Subnautica2MorePlayers8 Current Progress

Last updated: 2026-05-16 20:59 CST

## Live Checkpoint - 2026-05-16 21:40 CST

Current active request: keep live progress in this file while continuing the deep blocker investigation.

State carried forward:

- The project is still failed/unfinished for the actual goal.
- UI `1/8` and EOS lobby capacity `8` are already verified, but that is not enough.
- The real blocker from the last 5-player test is Unreal listen-server admission: `PreLogin failure: Server full.`
- The current installed build should be treated as a hardened diagnostic build until a real fifth client proves otherwise.

This pass will focus on:

1. Inspecting current Lua/native code for incomplete admission/session capacity handling.
2. Making Steam hook misses non-fatal if not already true.
3. Adding a reversible config/INI-side session capacity override if it can be done safely.
4. Rebuilding, reinstalling, verifying, and refreshing `Z:\Subnautica2MorePlayers8`.
5. Recording exact next-test requirements instead of claiming success.

## Live Checkpoint - 2026-05-16 21:52 CST

Code hardening in progress:

- Lua version bumped to `0.3.2-session-admission-ini-hardening`.
- Admission GameSession patch now also considers safe max/default fields such as `MaxSpectators`, `MaxSplitscreens`, `MaxPublicConnections`, `MaxPrivateConnections`, and `TotalPlayerSlots`.
- Admission object patch now also invokes the conservative direct capacity patcher for the same object, while preserving the rule that `-1` connection counters are not blindly changed unless the field name is max/limit/capacity-like.
- `install.ps1` now writes a reversible local UE config override to `%LOCALAPPDATA%\Subnautica2\Saved\Config\Windows\Game.ini`:
  - `/Script/Engine.GameSession MaxPlayers=8`
  - `/Script/EngineSettings.GameSessionSettings MaxPlayers=8`
  - `/Script/Subnautica2.SN2GameSession MaxPlayers=8 MaxPartySize=8`
- `uninstall.ps1` now restores/removes the marked Game.ini block through the install manifest.

This is still not a success claim. The next real test must prove whether player 5 still gets `PreLogin failure: Server full`.

## Live Checkpoint - 2026-05-16 21:58 CST

Build/install verification after the hardening edits:

- `.\build.ps1` passed.
- `.\install.ps1 -GameRoot "D:\SteamLibrary\steamapps\common\Subnautica2"` passed.
- `.\tools\verify_install.ps1 -GameRoot "D:\SteamLibrary\steamapps\common\Subnautica2"` passed all checks.
- Installed Lua reports `0.3.2-session-admission-ini-hardening`.
- Local `%LOCALAPPDATA%\Subnautica2\Saved\Config\Windows\Game.ini` now contains the marked Subnautica2MorePlayers8 session override.

Still unresolved:

- No real fifth-client test has been run after `0.3.2`.
- If the next test still logs `PreLogin failure: Server full`, the likely next route is a hash-gated native Unreal admission patch around `AGameSession::ApproveLogin` / `AtCapacity` or the Subnautica override calling it.

## Live Checkpoint - 2026-05-16 22:05 CST

Continuing the deep blocker pass.

Immediate focus:

- Trace the exact native source of the literal `Server full.` in the shipping executable.
- Determine whether the rejection comes from stock `AGameSession::ApproveLogin`/`AtCapacity`, an override, or a UWE/Sonar wrapper.
- Keep the current runtime Lua/EOS patch as installed, but do not assume it fixed player 5 until tested.
- Refresh the uncompressed `Z:\Subnautica2MorePlayers8` package only after docs/scripts reflect the current state.

## Live Checkpoint - 2026-05-16 22:12 CST

Binary scan status:

- A raw `rg -a` scan of the shipping EXE confirms nearby Unreal engine symbols/strings for `UGameSessionSettings`, `MaxPlayers`, `MaxSpectators`, `GameSession`, and NetDriver names.
- The raw output is too noisy to identify a stable patch point.
- Next step is a PE-aware scan:
  - locate ASCII/UTF-16 occurrences of `Server full`, `AtCapacity`, `ApproveLogin`, and `MaxPlayers`;
  - map file offsets to RVAs;
  - search `.text` for references to those RVAs;
  - only consider a native patch if it is tied to the known EXE hash and can fail closed.

## Live Checkpoint - 2026-05-16 22:20 CST

PE-aware scan results:

- `Server full.` has exactly one UTF-16 occurrence:
  - file offset `0xA37B010`
  - RVA `0xA37C010`
  - VA `0x14A37C010`
- `ApproveLogin` has one UTF-16 occurrence nearby:
  - file offset `0xA37AF90`
  - RVA `0xA37BF90`
- `.text` has RIP-relative references to `Server full.` around:
  - file offset `0x3FBBDE2`
  - RVA `0x3FBC7E2`

Next check:

- Disassemble the function around RVA `0x3FBC7E2`.
- If it matches stock `AGameSession::ApproveLogin` returning `Server full.` only when `AtCapacity(false)` is true, prefer a hook/patch that only suppresses this exact known-hash branch and logs it.

## Live Checkpoint - 2026-05-16 22:45 CST

Native admission patch implemented and locally verified:

- Disassembly confirmed the `Server full.` failure comes from a stock Unreal `ApproveLogin` path:
  - virtual call at `[vtable + 0x778]` returns `AL=true` for capacity/full;
  - `test al, al`;
  - conditional branch falls through to load UTF-16 `Server full.`;
  - returned error string is later logged by `PreLogin failure: Server full.`
- Added a known-hash runtime memory patch in `MorePlayers8Native.dll`:
  - target RVA: `0x03FBC7E3`
  - expected bytes: `74 0C 48 8D 15 24 F8 3B 06 E9 B4 00 00 00`
  - patched bytes: `EB 0C 48 8D 15 24 F8 3B 06 E9 B4 00 00 00`
  - effect: force this exact `ApproveLogin -> Server full.` branch to skip the error string.
- Safety gates:
  - `NativePatchRequireKnownHash=true`;
  - shipping EXE SHA256 must match `E9D32E1693BEDBD4CB6BA6D7DB5FF9BB6EE34FA36AEF73F154B3CDC6B64D2CF4`;
  - target bytes must exactly match before patching;
  - `MaxPlayers` must be greater than 4;
  - `EnableJoinValidationPatch=true`;
  - config key: `EnableNativeUnrealServerFullAdmissionPatch`.
- Rebuilt, reinstalled, verified install, and short-launched.
- Latest native log confirms:
  - `Unreal Server full admission patch active`
  - `Patch status unrealServerFullAdmission=true`
  - `Native capacity/admission patch install result=true`

This is still not a real 5-player success. It only proves that the previously observed `Server full.` branch is now patched in the process.

## Live Checkpoint - 2026-05-16 22:55 CST

Packaging/docs checkpoint:

- README updated to 0.3.2 status.
- `INSTALL.zh-CN.md` and `安装说明.md` rewritten as readable UTF-8 Chinese.
- `Uninstall-OneClick.ps1` no longer depends on `$LASTEXITCODE` after invoking a PowerShell script.
- Uncompressed package refreshed at `Z:\Subnautica2MorePlayers8`.
- `Z:\Subnautica2MorePlayers8\dist\Subnautica2MorePlayers8\scripts\main.lua` reports `0.3.2-session-admission-ini-hardening`.
- Dist/Z/installed native DLL SHA256 match:
  - `3FABB0756FCC012BC54AA229E3C387E8802DF78A31F8F19883456C98FDE603E7`

Next user-side test:

1. Host and all clients install `Z:\Subnautica2MorePlayers8`.
2. Host creates lobby and confirms `1/8`.
3. Confirm host native log includes `unrealServerFullAdmission=true`.
4. Re-test player 5.
5. If player 5 fails, collect host and player-5 logs immediately.
6. If player 5 joins, proceed to players 6-8 and then world sync validation.

## Live Checkpoint - 2026-05-16 21:09 CST

Current turn resumed after context handoff. The project remains failed/unfinished for the real goal.

The active blocker is not the top UI anymore: the user confirmed the UI can show `1/8`. The last real player-5 test still failed with Unreal listen-server admission:

- Host accepted the connection far enough to log `Login request`.
- Host then logged `PreLogin failure: Server full.`
- Join result became `PreLoginFailure`.

Immediate technical focus:

1. Persist all ongoing findings in this file before and after edits.
2. Inspect the current Lua direct session/admission patch and native hook code.
3. Finish any incomplete hash-gated native SDK capacity diagnostics, especially Steamworks lobby functions if present.
4. Build/install/verify a hardened diagnostic build.
5. Do not claim player 5-8 support until a real player-5 test no longer logs `Server full`, and then separately verify world sync.

## Live Checkpoint - 2026-05-16 21:16 CST

Log/code review notes:

- `admission_trace.txt` from the latest short launch only proves `GameSession.MaxPlayers` and `GameSession.MaxPartySize` were swept to 8 on a local session object.
- That short launch did not include a real fifth client, so it does not prove the `Server full` blocker is fixed.
- `AuthorityGameMode.GameSession` direct field reads in Lua can show UE4SS wrapper/userdata values when unsafe reflection is disabled. Future logs must distinguish wrapper values from numeric values so we do not overinterpret them.
- Native Steamworks hook support was started but not completed. Finish it to log/patch `SteamAPI_ISteamMatchmaking_CreateLobby`, `SetLobbyMemberLimit`, and `GetLobbyMemberLimit` if the shipping build uses Steam lobby calls in addition to EOS/Sonar.
- The most important unresolved path remains Unreal admission: `GameModeBase::PreLogin -> GameSession::ApproveLogin/AtCapacity` or a Subnautica/Sonar override around it.

## Live Checkpoint - 2026-05-16 21:22 CST

Code changes completed in this pass:

- Finished config read for `EnableNativeSteamLobbyCapacityPatch`.
- Added hash-gated Steamworks IAT/delay-IAT diagnostics and hooks for:
  - `SteamAPI_ISteamMatchmaking_CreateLobby`
  - `SteamAPI_ISteamMatchmaking_SetLobbyMemberLimit`
  - `SteamAPI_ISteamMatchmaking_GetLobbyMemberLimit`
- Generalized delay import original export resolution so Steam hooks do not incorrectly use the EOS export resolver.
- Build passed with `.\build.ps1`.

Important: this is diagnostic/hardening for possible Steam lobby capacity residue. It is not evidence that the player-5 `Server full` admission blocker is solved.

## Live Checkpoint - 2026-05-16 21:33 CST

Additional log timeline clarification:

- The real 5-player failure at `2026-05-16 20:35 CST` happened before the `0.3.0-admission-gamesession-patch` short launch.
- In that 20:35 test, four players reached `Join request` and `BP_SN2PlayerState` creation. The fifth player logged `Login request` and then `PreLogin failure: Server full.`
- The `0.3.0`/`0.3.1` admission patches have not yet been tested with a real fifth client.
- Current installed build is now `0.3.1-session-admission-hardening` after a successful `build.ps1`, `install.ps1`, and `verify_install.ps1`.

Next code adjustment:

- Treat Steamworks lobby hook misses as non-fatal diagnostics because the active build clearly uses EOS/Sonar and the main EXE may not import those Steam matchmaking entrypoints directly.
- Keep focusing on `GameSession`/`PreLogin` admission. If the next real 5-player test still logs `Server full`, the likely next route is a hash-gated native patch of the Unreal `ApproveLogin`/`AtCapacity` path rather than more lobby/UI work.

## Current User Goal

Treat the project as unfinished until real clients prove that player 5-8 can join and synchronize the world. Do not claim success based only on UI or lobby capacity.

Current request: inspect the game/project deeply and harden every locally discoverable layer that can still block the fifth player.

## Fixed Facts

- Project path: `C:\tmp\Subnautica2MorePlayers8`
- Game root: `D:\SteamLibrary\steamapps\common\Subnautica2`
- Installed mod path: `D:\SteamLibrary\steamapps\common\Subnautica2\Subnautica2\Binaries\Win64\ue4ss\Mods\Subnautica2MorePlayers8`
- Shared uncompressed installer path: `Z:\Subnautica2MorePlayers8`
- Game build: `34_SHIPPING_RELEASEHOTFIXLIVE_CL-113109_B-13`
- Build timestamp: `2026-05-10T04:15:22`
- Shipping EXE SHA256: `E9D32E1693BEDBD4CB6BA6D7DB5FF9BB6EE34FA36AEF73F154B3CDC6B64D2CF4`

## Verified So Far

- UE4SS dev build loads with UE 5.6 override.
- The mod loads.
- `build.ps1`, `install.ps1`, and `tools\verify_install.ps1` have passed in the current project state before this phase.
- Native EOS hook is hash-gated and active on the known EXE hash.
- Real EOS lobby capacity has been patched from 4 to 8:
  - `EOS_Lobby_CreateLobby MaxLobbyMembers 4 -> 8`
  - `EOS_LobbyModification_SetMaxMembers 4 -> 8`
  - `EOS_LobbyDetails_CopyInfo MaxMembers=8 AvailableSlots=7`
- Top lobby UI source is `/Script/Subnautica2.SN2InGameFriendScreenViewModel:AssemblePlayercountString`.
- User confirmed top UI now displays `1/8`.
- Current Lua build is `0.3.0-admission-gamesession-patch`.
- Current short-start validation showed `GameSession.MaxPlayers` and `GameSession.MaxPartySize` are kept at 8 by the admission sweep.

## Still Not Verified

- Player 5 join acceptance after the latest admission patch.
- Player 6-8 join acceptance.
- Player 5-8 spawn, PlayerController, PlayerState, pawn, inventory, and world replication.
- Save/rejoin behavior for player 5-8.
- Whether host-only install is enough.

## Latest Real Failure Evidence

The last real 5-player test failed. Host log showed player 5 reached EOS P2P and Unreal `GameNetDriver`, then was rejected by Unreal admission:

- `Login request: ...`
- `PreLogin failure: Server full.`
- `Result=PreLoginFailure`

This means EOS lobby/UI are no longer the proven active blocker. The blocker was Unreal listen-server admission.

## Important Additional Evidence

Old `LogOnlineSession` dumps showed:

- `NumOpenPrivateConnections: 4`
- `NumOpenPublicConnections: -1`
- `NumPublicConnections: 0`
- `NumPrivateConnections: 4`

This may be a separate Unreal OnlineSession/CommonSession capacity layer that remains at 4 even when EOS lobby and `GameSession.MaxPlayers` are 8.

## Current Code Safety Constraints

- Keep `EnableUnsafeObjectReflection=false` by default.
- Do not restore broad UObject reflection/name/class/property scans in production.
- Do not restore broad UMG text hooks.
- Do not bypass Steam/EOS authentication.
- Do not use unknown EXEs, cheat loaders, or binary patches unless hash-gated, backed up, and reversible.
- Do not claim 8-player success without real test evidence.

## Current Work In Progress

1. Re-scan existing logs, project code, game strings, UE4SS output, and capacity traces.
2. Harden Lua admission/session patch without unsafe reflection:
   - Patch known direct capacity fields on hook context/args using safe direct access.
   - Include `NumPrivateConnections`, `NumPublicConnections`, `NumOpenPrivateConnections`, and `NumOpenPublicConnections` candidates.
   - Add targeted handling for `GameSession:AtCapacity` and `GameSession:ApproveLogin` if UE4SS can hook them later.
3. Consider native EOS hook expansion for logging `EOS_Sessions_RegisterPlayers`, `EOS_Sessions_JoinSession`, and `EOS_Sessions_UpdateSession`, mainly for diagnostics.
4. Build, install, verify install, and short-launch to confirm no startup crash and logs show the new patch layer.
5. Refresh `Z:\Subnautica2MorePlayers8` uncompressed installer.
6. Update:
   - `docs\discovery_report.md`
   - `docs\test_report.md`
   - this file

## Next Real Test Pass Criteria

The next 5-player test must check host and player-5 logs immediately after the attempt.

Pass for the current blocker:

- Host log must not contain `PreLogin failure: Server full.`
- Player 5 must reach `Join succeeded`.

If player 5 joins but world sync fails, the next target becomes spawn/PlayerState/pawn/world replication instead of lobby/session capacity.

## Latest Status At End Of File - 2026-05-16 22:58 CST

This is the latest checkpoint for future context recovery.

Current build:

- Lua: `0.3.2-session-admission-ini-hardening`
- Native DLL SHA256: `3FABB0756FCC012BC54AA229E3C387E8802DF78A31F8F19883456C98FDE603E7`
- Installed and verified at `D:\SteamLibrary\steamapps\common\Subnautica2\Subnautica2\Binaries\Win64\ue4ss\Mods\Subnautica2MorePlayers8`
- Uncompressed player package refreshed at `Z:\Subnautica2MorePlayers8`

New key patch in this phase:

- Known-hash native runtime patch for `AGameSession::ApproveLogin -> Server full.`
- Target RVA: `0x03FBC7E3`
- Original bytes: `74 0C 48 8D 15 24 F8 3B 06 E9 B4 00 00 00`
- Patched bytes: `EB 0C 48 8D 15 24 F8 3B 06 E9 B4 00 00 00`
- Latest short launch log confirmed `unrealServerFullAdmission=true`.

Still not proven:

- Real player 5 joining after this patch.
- Players 6-8 joining.
- World spawn/replication/sync for players 5-8.
- Host-only install.

Next test:

- Host and all clients install from `Z:\Subnautica2MorePlayers8`.
- Host confirms `native_eos_patch.log` contains `unrealServerFullAdmission=true`.
- Re-test player 5.
- If it fails, collect host and player-5 logs with `Collect-MorePlayers8Logs.cmd`.

## 2026-05-16 23:18 CST - User requested 1024-player target

The active target has changed from 8 to 1024 players. This is a diagnostic/experimental configuration change, not a verified 1024-player production result.

Required code/config changes now in progress:

- Change `MorePlayers8.json` default `MaxPlayers` to `1024`.
- Raise Lua and native safety clamps from `32` to `1024`.
- Update build validation to allow `1024`.
- Remove the install-time hard-coded `Game.ini` override of `8`; it must read the built config value.
- Update EOS/native capacity option validation so copied/later capacity values of `1024` are not rejected as implausible.
- Build, install, verify, and refresh the uncompressed player package at `Z:\Subnautica2MorePlayers8`.

Validation boundary:

- Local build/install/verify can prove the package is configured for `1024`.
- It cannot prove 1024 clients can join or sync.
- The known real multiplayer blocker remains the fifth-player disconnect until a new live test shows otherwise.

## 2026-05-16 23:28 CST - 1024 build/install verification

Completed:

- `MorePlayers8.json` now has `MaxPlayers=1024`.
- Lua version is `0.3.3-1024-diagnostic`.
- Lua and native clamps now allow up to `1024`.
- `build.ps1` accepts `1..1024`.
- `install.ps1` reads the built config and writes that same value into `Game.ini`.
- `tools\verify_install.ps1` checks installed config validity and `Game.ini` consistency.
- Local `.\build.ps1` passed.
- Local `.\install.ps1 -GameRoot "D:\SteamLibrary\steamapps\common\Subnautica2"` passed.
- Local `.\tools\verify_install.ps1 -GameRoot "D:\SteamLibrary\steamapps\common\Subnautica2"` passed all checks.
- Installed native DLL SHA256: `2CBC491F5EFCA1E39C8B730BA41E2F9791931BA0D948AAA6D652A7CC3D61429D`.
- Installed config path:
  `D:\SteamLibrary\steamapps\common\Subnautica2\Subnautica2\Binaries\Win64\ue4ss\Mods\Subnautica2MorePlayers8\MorePlayers8.json`
  contains `MaxPlayers=1024`.
- `%LOCALAPPDATA%\Subnautica2\Saved\Config\Windows\Game.ini` contains the marked override block with `MaxPlayers=1024`, `MaxSpectators=1024`, `MaxSplitscreens=1024`, and `MaxPartySize=1024`.

Still pending:

- Start game and confirm runtime logs show `maxPlayers=1024` and native patches active.
- Confirm host UI shows `1/1024`.
- Re-test real player 5.
- Do not claim 1024-player success.

## 2026-05-16 23:31 CST - Z package refreshed

Completed:

- Removed and recreated `Z:\Subnautica2MorePlayers8`.
- Copied updated root scripts/docs, `dist`, `src`, selected tools, and bundled `tools\UE4SS-dev`.
- Verified `Z:\Subnautica2MorePlayers8\dist\Subnautica2MorePlayers8\MorePlayers8.json` contains `MaxPlayers=1024`.
- Verified Z package Lua version is `0.3.3-1024-diagnostic`.
- Verified Z package native DLL SHA256 is `2CBC491F5EFCA1E39C8B730BA41E2F9791931BA0D948AAA6D652A7CC3D61429D`.
- Ran `Z:\Subnautica2MorePlayers8\tools\verify_install.ps1 -GameRoot "D:\SteamLibrary\steamapps\common\Subnautica2"` and all checks passed.

Current deliverable:

- Uncompressed player package: `Z:\Subnautica2MorePlayers8`
- Local installed mod: `D:\SteamLibrary\steamapps\common\Subnautica2\Subnautica2\Binaries\Win64\ue4ss\Mods\Subnautica2MorePlayers8`
- Configured target: `MaxPlayers=1024`

Still not verified:

- Runtime game launch after the 1024 change.
- Host UI `1/1024`.
- EOS/Steam accepting actual 1024-member lobby values at runtime.
- Real player 5 joining after the native admission patch.
- Any world sync above 4 players.

## 2026-05-16 23:45 CST - User requested 32-player target

The active target has changed from the previous 1024 diagnostic value to `MaxPlayers=32`.

Completed in source before rebuild:

- `MorePlayers8.json` changed to `MaxPlayers=32`.
- Lua version changed to `0.3.4-32-target`.
- Lua and native defaults/clamps changed to `32`.
- `build.ps1`, `install.ps1`, and `tools\verify_install.ps1` now validate `1..32`.
- One-click installer fallback display changed to `32`.
- README, `INSTALL.zh-CN.md`, `安装说明.md`, and latest test instructions now describe `1/32`.
- Discovery and test reports now record the 32 target as current, with 1024 kept only as historical diagnostic context.

Still pending:

- Rebuild.
- Install locally.
- Verify installed config and `Game.ini` show `32`.
- Refresh `Z:\Subnautica2MorePlayers8`.
- Runtime game launch and `1/32` UI confirmation.
- Real player 5 test.

## 2026-05-17 00:05 CST - User requested 1024 production profile

The active target has changed from 32 back to `MaxPlayers=1024`.

User-provided live validation now recorded:

- 8-player path has been validated.
- Player 5 can join.

Production changes completed in source before rebuild:

- `MorePlayers8.json` changed to `MaxPlayers=1024`.
- Lua version changed to `0.3.5-1024-production`.
- Lua and native defaults/clamps changed to `1024`.
- `build.ps1`, `install.ps1`, and `tools\verify_install.ps1` now validate `1..1024`.
- One-click installer fallback display changed to `1024`.
- In-game player count should display `1/1024` through `SN2InGameFriendScreenViewModel:AssemblePlayercountString`.
- Runtime diagnostics reduced:
  - `LogLevel=Warn`
  - `EnableTraceFiles=false`
  - `EnableSafeParamProbe=false`
  - `HookProfile=ProductionLean`
  - Lua admission/session polling disabled
  - unsafe reflection, discovery scans, object dumps, and UI sweeps remain disabled
  - native per-call logging remains disabled

Still pending:

- Rebuild.
- Install locally.
- Verify installed config and `Game.ini` show `1024`.
- Refresh `Z:\Subnautica2MorePlayers8`.
- Runtime game launch and UI `1/1024` confirmation.
- Real 1024-player capacity/sync test.

## 2026-05-17 00:12 CST - 1024 production build installed and Z package refreshed

Completed:

- `.\build.ps1` passed.
- `.\install.ps1 -GameRoot "D:\SteamLibrary\steamapps\common\Subnautica2"` passed.
- `.\tools\verify_install.ps1 -GameRoot "D:\SteamLibrary\steamapps\common\Subnautica2"` passed all checks.
- Installed `MorePlayers8.json` has `MaxPlayers=1024`, `LogLevel=Warn`, `EnableTraceFiles=false`, `HookProfile=ProductionLean`, and `EnableSafeParamProbe=false`.
- `%LOCALAPPDATA%\Subnautica2\Saved\Config\Windows\Game.ini` override block has `MaxPlayers=1024`, `MaxSpectators=1024`, `MaxSplitscreens=1024`, and `MaxPartySize=1024`.
- Installed native DLL SHA256: `7E570AC2E38A109526F53CD08BC09E81131CD9761873068DB971927075C2FBE9`.
- Recreated uncompressed package at `Z:\Subnautica2MorePlayers8`.
- Verified Z package config has `MaxPlayers=1024`.
- Verified Z package Lua version is `0.3.5-1024-production`.
- Verified Z package native DLL SHA256 is `7E570AC2E38A109526F53CD08BC09E81131CD9761873068DB971927075C2FBE9`.
- Ran `Z:\Subnautica2MorePlayers8\tools\verify_install.ps1 -GameRoot "D:\SteamLibrary\steamapps\common\Subnautica2"` and all checks passed.

Current deliverable:

- Uncompressed player package: `Z:\Subnautica2MorePlayers8`
- Local installed mod: `D:\SteamLibrary\steamapps\common\Subnautica2\Subnautica2\Binaries\Win64\ue4ss\Mods\Subnautica2MorePlayers8`
- Configured target: `MaxPlayers=1024`
- Runtime profile: production-lean, reduced logging/tracing

Still not verified:

- Runtime game launch after production profile.
- Host UI `1/1024`.
- Real 1024-player capacity/sync test.

## 2026-05-17 - Fix EOS create failure and settle on 64

User observed host creation failure with UI error `创建游戏进程失败，请检查网络连接`.

Root cause confirmed from `native_eos_patch.log`:

- The 1024 build patched `EOS_Lobby_CreateLobby MaxLobbyMembers 4 -> 1024`.
- EOS callback returned `result=10`.
- The game retried lobby creation and failed each time.

Conclusion:

- 1024 cannot be passed directly into EOS lobby creation on this path.
- The production target is now `MaxPlayers=64`, matching the practical EOS lobby cap target.

Completed:

- `MorePlayers8.json` changed to `MaxPlayers=64`.
- Lua version changed to `0.3.6-64-production`.
- Lua/native defaults and clamps changed to `64`.
- `build.ps1`, `install.ps1`, and `tools\verify_install.ps1` validate `1..64`.
- UI player-count hook will display `1/64`.
- Native import-table candidate logging is now suppressed unless `NativePatchLogAllCalls=true`.
- Built successfully.
- Installed locally successfully.
- Local `verify_install.ps1` passed all checks.
- Local `Game.ini` override now has `MaxPlayers=64`, `MaxSpectators=64`, `MaxSplitscreens=64`, and `MaxPartySize=64`.
- Installed native DLL SHA256: `A103ED0471F92ADCFB907D09B38BF23026BF9F02CB530D8150027FD18D168B48`.
- Recreated `Z:\Subnautica2MorePlayers8`.
- Verified Z package config has `MaxPlayers=64`.
- Verified Z package Lua version is `0.3.6-64-production`.
- Verified Z package native DLL SHA256 is `A103ED0471F92ADCFB907D09B38BF23026BF9F02CB530D8150027FD18D168B48`.
- Ran Z package `verify_install.ps1`; all checks passed.

Current deliverable:

- `Z:\Subnautica2MorePlayers8`
- Real target: 64 players
- UI target: 64 players
- Production profile remains reduced logging/tracing.

Next validation:

- Start game.
- Create host lobby.
- Confirm creation succeeds.
- Confirm top UI shows `1/64`.
- Confirm `native_eos_patch.log` has `afterMaxLobbyMembers=64` and callback success.

## 2026-05-17 - Handoff document added

Created `docs\handoff.md` as the current handoff source of truth for another engineer.

It records:

- current deliverables and paths
- current version `0.3.6-64-production`
- game build/hash
- config and runtime profile
- Lua/native patch responsibilities
- the 1024 EOS failure and why the target is now 64
- verified and unverified items
- build/install/verify commands
- logs to check
- next test plan
- risks and debugging cautions

## 2026-05-18 - Experimental server framework added

User requested exploring a server-side mod direction:

- Prefer de-graphical/low-graphics game startup for hosting.
- If graphical-less hosting cannot work, explore IP:Port join fallback.
- Do not bypass Steam/EOS authentication.

Implemented as an experiment harness, not a validated dedicated server:

- Added `MorePlayers8.Server.example.json`.
- Added root launch wrappers:
  - `Start-ExperimentalServer.cmd`
  - `Join-ExperimentalServer.cmd`
- Added tools:
  - `tools\Start-ExperimentalServer.ps1`
  - `tools\Join-ExperimentalServer.ps1`
  - `tools\New-MorePlayers8FirewallRule.ps1`
- Added `docs\server_mod_plan.md`.
- Added default-off config keys to `MorePlayers8.json` and dist config:
  - `ServerMode`
  - `EnableServerAutomation`
  - `ServerListenPort`
  - `ServerTravelUrl`
  - `ServerAutoHostDelayMs`
  - `EnableDirectConnectAutomation`
  - `DirectConnectAddress`
  - `DirectConnectDelayMs`
  - `PreferEOSLobby`
  - `EnableIpPortFallback`
- Added Lua support for default-off server/direct automation:
  - logs server controls on startup
  - if `EnableServerAutomation=true` and `ServerTravelUrl` is set, schedules `servertravel <url>` and `open <url>` fallback
  - if `EnableDirectConnectAutomation=true`, schedules `open <DirectConnectAddress>`
  - records commands in `capacity_trace.txt`

Validation completed:

- PowerShell syntax parse passed for new scripts.
- JSON parse passed for root/dist/server example configs.
- `build.ps1` completed successfully.
- New native DLL SHA256:
  `ECDF449F75EF023376C97CBD0AFC466C2C8960E4EF2C3B1CADB69638747571F8`

Default behavior:

- `Start-ExperimentalServer.ps1` still prefers EOS lobby/session flow.
- `-IpPortFallback` only marks that IP:Port fallback is being tested; it does not disable platform authentication.

Not validated:

- Actual game launch through `Start-ExperimentalServer.ps1`.
- `-nullrhi`.
- `GameNetDriver` listen socket.
- Direct `open IP:Port` join.
- Any true headless/dedicated server behavior.

## 2026-05-18 - Experimental server validation pass started

Current user request: continue until validation is complete, and keep the project files updated so another engineer can resume without chat history.

Scope of this pass:

- Validate the already-added experimental server/client scripts.
- Re-run build, install, and install verification from the active GitHub working tree.
- Launch the game through `tools\Start-ExperimentalServer.ps1` in low-graphics mode and inspect whether UE4SS/mod logs are produced.
- Check for any evidence of a real `GameNetDriver` listen socket or UDP 7777 binding.
- Try `-NullRHI` only after the low-graphics launch path has evidence.

Important boundary:

- This local machine can verify launch/config/log/port behavior.
- It cannot by itself prove 64 real remote clients, 64-player world sync, or a production headless server unless logs and real clients demonstrate those facts.

## 2026-05-18 - Build/install validation for server pass

Completed:

- PowerShell syntax parse passed for:
  - `tools\Start-ExperimentalServer.ps1`
  - `tools\Join-ExperimentalServer.ps1`
  - `tools\New-MorePlayers8FirewallRule.ps1`
  - `Package-Release.ps1`
  - `install.ps1`
  - `uninstall.ps1`
  - `build.ps1`
- JSON parse passed for:
  - `MorePlayers8.json`
  - `MorePlayers8.Server.example.json`
  - `dist\Subnautica2MorePlayers8\MorePlayers8.json`
  - `dist\Subnautica2MorePlayers8\build_manifest.json`
- `.\build.ps1` passed.
- `.\install.ps1 -GameRoot "D:\SteamLibrary\steamapps\common\Subnautica2"` passed.
- `.\tools\verify_install.ps1 -GameRoot "D:\SteamLibrary\steamapps\common\Subnautica2"` passed all checks.
- Shipping EXE SHA256 remains:
  `E9D32E1693BEDBD4CB6BA6D7DB5FF9BB6EE34FA36AEF73F154B3CDC6B64D2CF4`
- Rebuilt dist native DLL SHA256:
  `EDA562ADD523706CD5795FECA626233BB99C825EC2C1D53E7633BC9278780E51`

Next step:

- Launch through `tools\Start-ExperimentalServer.ps1 -Windowed -NoSound -Restart`, then inspect process/log/UDP evidence.

## 2026-05-18 - Low-graphics experimental launch result

Command run:

```powershell
.\tools\Start-ExperimentalServer.ps1 -GameRoot "D:\SteamLibrary\steamapps\common\Subnautica2" -Port 7777 -MaxPlayers 64 -Windowed -NoSound -Restart
```

Observed:

- Game wrapper and shipping process started.
- UE4SS/mod loaded.
- `MorePlayers8.log` reports:
  - `Loaded version=0.3.6-64-production MaxPlayers=64`
  - `ServerMode=ExperimentalListenHost`
  - `EnableServerAutomation=false`
  - `PreferEOSLobby=true`
  - `Port=7777`
- Native patch loaded and is active:
  - `unrealServerFullAdmission=true`
  - `lobbyCreate=true`
  - `lobbySetMax=true`
  - `sessionCreateModification=true`
  - `sessionSetMax=true`
- Game log command line includes `-Port=7777`.
- Game log loaded client lobby only:
  - `Browse: /Game/Maps/L_ClientLobby?Name=Player`
  - `Game class is 'BP_ClientLobbyGameMode_C'`
- EOS platform config says `IsServer=false`.
- No `Get-NetUDPEndpoint -LocalPort 7777` result.
- No `netstat -ano -p udp` entry for `:7777`.
- No host-side `GameNetDriver` listen/accept evidence.

Conclusion:

- Low-graphics launch validates game/mod startup through the new script.
- It does not validate a listen server or dedicated/headless server.
- At this point the script starts an ordinary client lobby with server-oriented config, not an actual server world.

Next step:

- Test `-NullRHI -NoSound` startup and compare whether UE4SS/mod still load and whether any listen evidence appears.

## 2026-05-18 - NullRHI experimental launch result

Command run:

```powershell
.\tools\Start-ExperimentalServer.ps1 -GameRoot "D:\SteamLibrary\steamapps\common\Subnautica2" -Port 7777 -MaxPlayers 64 -NullRHI -NoSound -Restart
```

Observed:

- Game wrapper and shipping process started and stayed alive for the observation window.
- UE4SS/mod loaded.
- `MorePlayers8.log` reports:
  - `Loaded version=0.3.6-64-production MaxPlayers=64`
  - `ServerMode=ExperimentalListenHost`
  - `EnableServerAutomation=false`
  - `Port=7777`
- Native patch loaded and reports `unrealServerFullAdmission=true` and EOS capacity hooks active.
- Game log command line includes `-nullrhi -nosound -Port=7777`.
- Game log still reports EOS platform `IsServer=false`.
- Game log loaded client lobby only:
  - `Browse: /Game/Maps/L_ClientLobby?Name=Player`
  - `Game class is 'BP_ClientLobbyGameMode_C'`
- No UDP 7777 endpoint was found.
- No `GameNetDriver` listen/accept evidence was found.

Conclusion:

- `-NullRHI` does not crash immediately and does not prevent mod load on this machine.
- It still does not produce a verified server/listen world by itself.

Next step:

- Search packaged game strings/logs for map/travel candidates, then try an explicit `?listen` travel URL.

## 2026-05-18 - Unsafe travel route rejected and replaced by API route

User reported the explicit `?listen` experiment crashed. This route is now considered unsafe for the server-mod direction.

Evidence from the unsafe route:

- `capacity_trace.txt` shows Lua attempted:
  - `servertravel /Game/Maps/L_ClientLobby?listen&Port=7777`
  - `open /Game/Maps/L_ClientLobby?listen&Port=7777`
- `MorePlayers8.log` shows both Engine and PlayerController console execution returned `false`.
- Game did not create a UDP 7777 listener.

Code changes made:

- Added `EnableServerApiAutomation`.
- Added `EnableUnsafeTravelAutomation`, default `false`.
- `Start-ExperimentalServer.ps1` no longer passes `TravelUrl` on the command line unless `-EnableUnsafeTravelAutomation` is explicitly set.
- Lua now refuses `servertravel/open` automation unless `EnableUnsafeTravelAutomation=true`.
- Lua now has a safer official API route that attempts game-owned UWE/Sonar calls:
  - `UWEMultiplayerHostedSessionViewModel:TriggerHostGameRequest`
  - `UWEServerLobbyComponent:StartNewGame`
  - `UWELobbyGameMode:StartNewServerGame`

Validation after code change:

- PowerShell syntax parse passed.
- JSON parse passed.
- `.\build.ps1` passed.
- `.\install.ps1 -GameRoot "D:\SteamLibrary\steamapps\common\Subnautica2"` passed.
- `.\tools\verify_install.ps1 -GameRoot "D:\SteamLibrary\steamapps\common\Subnautica2"` passed.
- Rebuilt native DLL SHA256:
  `CD5A624B27211D88B6E09F7714E0B4506A1A400D90819446C43AC7AF26C2D03F`

## 2026-05-18 - Graphical official API host attempt result

Command run:

```powershell
.\tools\Start-ExperimentalServer.ps1 -GameRoot "D:\SteamLibrary\steamapps\common\Subnautica2" -Port 7777 -MaxPlayers 64 -Windowed -NoSound -EnableApiAutoHost -Restart
```

Observed:

- Game process stayed alive during the observation window.
- No new crash directory was created.
- No raw `TravelUrl` was passed on the command line.
- Lua `EnableServerApiAutomation=true` triggered official UWE/Sonar host API attempts.
- Host hook evidence:
  - `/Script/UWESonar.UWEMultiplayerHostedSessionViewModel:TriggerHostGameRequest` fired.
- Native EOS evidence:
  - `EOS_Lobby_CreateLobby ... beforeMaxLobbyMembers=4 afterMaxLobbyMembers=64 ... changed=true`
  - `EOS_Lobby_CreateLobby callback result=0`
- This proves the API automation reached the official lobby creation layer.

New blocker:

- Game log reports:
  - `CanServerTravel: FURL L_Main?listen?game=EGameModeAliasAsEnum::Survival blocked, contains : or \`
- No UDP 7777 listener was found.
- No `GameNetDriver` listen/accept evidence was found.

Interpretation:

- The graphical API route is safer and reaches the official EOS lobby path.
- It still does not complete server/world travel.
- The likely cause is that the ViewModel is being triggered before the normal create-game UI has initialized all fields, causing the game to generate an invalid `game=` URL value from the enum name `EGameModeAliasAsEnum::Survival`.

Next step:

- Locate the create-game/ViewModel initialization fields or methods that the normal UI sets before `TriggerHostGameRequest`.
- Avoid repeated auto-host attempts once a lobby creation starts.
- If the required fields cannot be safely initialized without UI state, document the current mode as semi-automatic: script launches a low-graphics graphical host, but the user must create the lobby through the normal UI.

## 2026-05-18 - Crash and graphical server console hardening

User reported a crash and requested a fully graphical CMD-window server using in-game APIs.

Crash analysis:

- Latest crash directory inspected:
  `%LOCALAPPDATA%\Subnautica2\Saved\Crashes\UECC-Windows-E68FA0FF4A9BE096C6DA3790B50493C4_0000`
- `CrashContext.runtime-xml` reports:
  - `EXCEPTION_ACCESS_VIOLATION reading address 0x0000000000000018`
  - stack is inside UE4SS Lua UObject member access
  - trigger chain includes `RegisterStaticConstructObjectPostCallback`
- Conclusion:
  - crash is consistent with unsafe UObject access during object construction callbacks;
  - not an EOS/Steam authentication failure;
  - not proof that 64-player lobby patch is broken;
  - keep `EnableUnsafeObjectReflection=false` and `EnableObjectWatchers=false` in production.

Server automation changes made:

- Added safer config keys:
  - `ServerApiMode`
  - `EnableRawHostViewModelApi`
  - `ServerApiMaxAttempts`
- Default API automation now uses `ServerApiMode=UiLaunchGame`, which looks for `WBP_LoadGamePanel1_C` / `WBP_LoadGamePanel_C` and calls `LaunchGame`.
- Raw `UWEMultiplayerHostedSessionViewModel:TriggerHostGameRequest` automation is now behind `ServerApiMode=RawHostViewModel` plus `EnableRawHostViewModelApi=true`.
- API auto-host now attempts only once by default to avoid repeated EOS lobby creation and repeated invalid travel failures.
- Added `Start-GraphicalServerConsole.cmd`.
- Added `-Monitor` mode to `tools\Start-ExperimentalServer.ps1` to print live evidence:
  - game running
  - EOS lobby capacity
  - EOS callback success
  - travel success
  - invalid travel
  - UDP port
  - NetDriver/PostLogin evidence
  - recent crash evidence

Important boundary:

- This is still not a verified headless/dedicated server.
- It is a graphical low-resource host console around the official client and official UI/session path.
- If the UI save panel is not present or no save is selected, `UiLaunchGame` will refuse/skip instead of forcing the broken raw ViewModel path.

Validation note:

- A 45-second launch using the old direct shipping-exe path exited normally during startup:
  - no new crash directory;
  - no UE4SS/mod load in the new log;
  - game log ended with `EngineExit()`.
- A follow-up wrapper launch also exited early. Game log shows:
  - `STEAM: Game restarting within Steam client, exiting`
  - `SteamAPI failed to initialize`
  - `EOS API failed to initialize`
- `tools\Start-ExperimentalServer.ps1` was changed to launch through Steam by default:
  `steam.exe -applaunch 1962700 ...`
- `-UseWrapperExe` and `-UseShippingExe` remain available only for debugging.

## 2026-05-18 - WER dump analysis and graphical console change

User reported another crash while testing the graphical server direction.

New dump inspected:

- `C:\Users\fzc\AppData\Local\CrashDumps\Subnautica2-Win64-Shipping.exe.10848.dmp`
- Time: `2026-05-18 19:30:39`
- No matching new UE crash folder exists under `%LOCALAPPDATA%\Subnautica2\Saved\Crashes`.

Minidump findings:

- Exception thread RIP: `fmodstudio.dll + 0x9031e`.
- Game log reaches `L_ClientLobby` and `Engine is initialized` at about `19:30:29`.
- Crash occurs about 10 seconds after frontend load, before the default API automation delay of 20 seconds.
- This dump does not support blaming `UiLaunchGame` or raw host ViewModel API automation.
- The active crash address is FMOD Studio, so the low-resource `-NoSound` startup flag is now treated as suspicious for this build.

Changes made:

- `Start-GraphicalServerConsole.cmd` no longer passes `-NoSound` by default.
- `tools\Start-ExperimentalServer.ps1 -Monitor` now checks both UE crash folders and WER dumps under `%LOCALAPPDATA%\CrashDumps`.
- Added `docs\crash_dump_analysis.md`.

Current service-mode status:

- Still not verified as a headless/dedicated server.
- Still no proven `ProcessServerTravel` into `L_Main` from the automated service flow.
- Still no UDP `7777` / `GameNetDriver` listen evidence in the service-mode flow.
- Next validation must launch through Steam without `-NoSound`, wait past the API auto-host delay, then inspect EOS lobby, travel, NetDriver, and WER crash evidence.

## 2026-05-18 - Direct server lobby API route added

Current user request: after a crash, stop relying on unsafe travel or raw ViewModel calls and call the game's own API from a graphical CMD-window server console.

New discovery from shipping EXE strings:

- `UWEServerLobbyComponent.cpp` contains a server load path.
- Relevant native strings:
  - `Server travel to level %s with options %s`
  - `Savegame slot %s not found`
  - `?LaunchType=LoadGame?SaveSlotName=%s`
- This is more direct than `WBP_LoadGamePanel1_C:LaunchGame("")` and avoids the bad raw ViewModel URL:
  `L_Main?listen?game=EGameModeAliasAsEnum::Survival`.

Code changes now in progress:

- Lua version bumped to `0.3.7-64-server-lobby-loadgame`.
- Added `ServerApiMode=ServerLobbyLoadGame`.
- Added config keys:
  - `ServerSaveSlotName`
  - `ServerAllowNewGameFallback`
- `Start-ExperimentalServer.ps1` now auto-detects the newest local `savegame_*.sav` and writes its base name, for example `savegame_1`, into `ServerSaveSlotName`.
- `Start-GraphicalServerConsole.cmd` now defaults to:
  `UWEServerLobbyComponent:LoadGame(ServerSaveSlotName)`.
- New-game fallback is deliberately disabled by default to avoid creating or overwriting saves during automation.

Validation boundary:

- This still must be built, installed, launched, and monitored.
- Success requires game log evidence of server load/travel into `L_Main`, EOS lobby success, and eventually `GameNetDriver` or `PostLogin`.
- Until those appear, this remains an experimental graphical host console, not a proven dedicated/headless server.

## 2026-05-18 - First ServerLobbyLoadGame validation failed but did not crash

Validation command:

```powershell
.\tools\Start-ExperimentalServer.ps1 -GameRoot "D:\SteamLibrary\steamapps\common\Subnautica2" -Windowed -EnableApiAutoHost -ServerApiMode ServerLobbyLoadGame -ServerApiMaxAttempts 1 -Monitor -Restart
```

Observed:

- Game launched through Steam and stayed running for 180 seconds.
- No recent crash dump was detected.
- Mod loaded as `0.3.7-64-server-lobby-loadgame`.
- Launcher auto-detected `ServerSaveSlotName=savegame_1`.
- Lua attempted:
  `UWEServerLobbyComponent:LoadGame("savegame_1")`.
- The first component returned by UE4SS was a nullptr wrapper:
  `Tried calling a member function but the UObject instance is nullptr`.
- No EOS lobby creation, `L_Main` travel, UDP 7777, or NetDriver evidence appeared.

Code adjustment after this failure:

- Lua version bumped to `0.3.8-64-server-lobby-loadgame-retry`.
- `ServerLobbyLoadGame` now enumerates all `UWEServerLobbyComponent` candidates with `FindAllOf` plus `FindFirstOf` instead of trusting the first wrapper.
- Each candidate is attempted and logged.
- Added `ServerApiRetryIntervalMs`.
- Default graphical console now tries up to 8 times with 15 second intervals.

This remains unfinished until a retry run proves a callable component and real travel/listen evidence.

## 2026-05-18 - Switch server console to built-in UWESmoketest path

User reported a crash and requested a graphical CMD-window server that calls game APIs directly.

New evidence:

- The game ships official smoketest files under `Subnautica2\Content\Smoketest`.
- `smoketest-listenserver-host.json` uses the official QA listen-host path:
  `open L_Main?listen?bIsLanMatch`
- Shipping EXE strings show `UWESmoketest` supports server-specific actions:
  - `ServerLobbyLoadGame`
  - `ServerLobbyStartNewGame`
  - `CheckConnected`
  - `CheckLevel`

Implementation change:

- `tools\Start-ExperimentalServer.ps1` now supports:
  - `OfficialSmokeTestLoadGame`
  - `OfficialSmokeTestLanListen`
- `Start-GraphicalServerConsole.cmd` now defaults to `OfficialSmokeTestLanListen`.
- The launcher writes a temporary game smoketest file:
  `Subnautica2\Content\Smoketest\smoketest-moreplayers8-server.json`
- Lua version is now `0.3.9-64-official-smoketest-server-console`.
- Lua does not try to call `UWEServerLobbyComponent` when the selected mode is handled by command-line smoketest.

Why:

- Direct Lua `UWEServerLobbyComponent:LoadGame(savegame_1)` kept failing because no callable component instance exists at main-menu automation time.
- The smoketest subsystem runs after the game world/player controller exists and is part of the shipped game, so it is a better API layer for a graphical CMD-controlled server.

Still unverified:

- `OfficialSmokeTestLanListen` has not yet been fully validated in this run.
- IP/port client join has not yet been validated.
- 5+ player sync through the CMD server console has not yet been validated.

## 2026-05-18 - Continue validation after crash report

Current user request:

- Treat the previous crash as unresolved.
- Build a graphical CMD-window server route that calls shipped in-game APIs.
- Continue until validation is complete, without claiming a true dedicated/headless server unless the evidence proves it.

Current route under validation:

- `Start-GraphicalServerConsole.cmd`
- `tools\Start-ExperimentalServer.ps1`
- `ServerApiMode=OfficialSmokeTestLanListen`
- Shipped game subsystem: `UWESmoketest`
- Generated smoketest file:
  `D:\SteamLibrary\steamapps\common\Subnautica2\Subnautica2\Content\Smoketest\smoketest-moreplayers8-server.json`
- Expected in-game action:
  `open L_Main?listen?bIsLanMatch`

Immediate checks:

- Re-run PowerShell syntax validation.
- Re-run `build.ps1`, `install.ps1`, and `tools\verify_install.ps1`.
- Launch with `-Monitor -MonitorSeconds 300 -Restart`.
- Required minimum evidence:
  - game still running at monitor end;
  - `UWESmoketest` starts;
  - `L_Main` is loaded;
  - UDP `7777` is open;
  - `GameNetDriver` listen evidence appears;
  - no new UE/WER crash dump;
  - no `FPlatformMisc::RequestExit(0)` caused by smoketest completion.

## 2026-05-18 - OfficialSmokeTestLanListen 300-second validation passed

Validation command:

```powershell
cd C:\tmp\Subnautica2MorePlayers-github
.\tools\Start-ExperimentalServer.ps1 -GameRoot "D:\SteamLibrary\steamapps\common\Subnautica2" -Windowed -ServerApiMode OfficialSmokeTestLanListen -Monitor -MonitorSeconds 300 -Restart
```

Observed:

- Game process remained running at the end of the 300-second monitor.
- Window title:
  `Subnautica 2 - Build 113109`
- Process:
  `Subnautica2-Win64-Shipping.exe`, PID `38792` during this validation.
- `UWESmoketest` started from:
  `smoketest-moreplayers8-server.json`
- The generated smoketest executed:
  `open L_Main?listen?bIsLanMatch`
- Game log entered:
  `/Game/Maps/Main/L_Main?listen?bIsLanMatch`
- Game log created:
  `GameNetDriver` using `UWEReplicationGraph`
- Game log reported:
  `IpNetDriver listening on port 7777`
- `Get-NetUDPEndpoint -LocalPort 7777` showed:
  `0.0.0.0:7777`, owning process `38792`.
- `CheckLevel` succeeded with:
  `Level Name is L_Main`.
- No `PreLogin failure: Server full` was seen in the monitored evidence.
- No recent UE crash folder or WER dump was detected.
- No smoketest completion `RequestExit(0)` was observed; the trailing `Wait 86400` kept the listen host alive.

Important boundary:

- This proves a graphical CMD-controlled LAN listen host can be started locally through the shipped game `UWESmoketest` path.
- This does not prove a true headless/dedicated server.
- This does not yet prove a real remote client can join through IP:Port, or that 5+ players sync through this server-console route.

Follow-up implemented:

- `tools\Join-ExperimentalServer.ps1` now launches through Steam by default instead of directly launching the shipping EXE.
- The client script now writes:
  `Subnautica2\Content\Smoketest\smoketest-moreplayers8-client.json`
- The generated client smoketest executes:
  `open <host>:7777`
- Lua direct-connect automation is disabled for that client path to avoid a duplicate second `open` while `UWESmoketest` is already connecting.

## 2026-05-18 - Package refreshed after server-console validation

Completed:

- Rebuilt with `.\build.ps1`.
- Reinstalled with:
  `.\install.ps1 -GameRoot "D:\SteamLibrary\steamapps\common\Subnautica2"`.
- Re-ran:
  `.\tools\verify_install.ps1 -GameRoot "D:\SteamLibrary\steamapps\common\Subnautica2"`.
- Install verification passed all checks.
- Refreshed uncompressed package:
  `Z:\Subnautica2MorePlayers8`.
- Verified the Z package `README.md` contains the current Chinese server-console status.
- Verified the Z package client script uses Steam `-applaunch 1962700` and generates `smoketest-moreplayers8-client.json`.
- Created desktop zip:
  `C:\Users\fzc\Desktop\Subnautica2MorePlayers8-v0.3.9-64-server-console.zip`
- Desktop zip hash is intentionally reported in the final assistant response instead of embedded here, because embedding the hash changes the archive content.

## 2026-05-18 - Direct-connect CMD UNC/path fix

User-side failure:

```text
UNC 路径不受支持。默认值设为 Windows 目录。
Join-ExperimentalServer.ps1 : 无法将参数绑定到参数“Address”，因为该参数为空字符串。
```

Root cause:

- `Join-ExperimentalServer.cmd` was run from a UNC share path.
- `cmd.exe` cannot use a UNC path as the current working directory.
- The batch file also used `%MP8_ADDRESS%` inside a parenthesized `if (...)` block immediately after `set /p`; without delayed expansion, `%MP8_ADDRESS%` was expanded before the prompt ran, so PowerShell received `-Address ""`.

Fix:

- `Join-ExperimentalServer.cmd` now uses `pushd "%~dp0"` so Windows maps the UNC share to a temporary drive for the script lifetime.
- The batch flow no longer uses the prompt variable inside the same parenthesized block.
- Running with no arguments prompts for the host address.
- Running with a bare address now works:
  `Join-ExperimentalServer.cmd 192.168.1.3`
- Running with explicit PowerShell-style options still works when the first argument starts with `-`.

## 2026-05-18 - IP listen host remote join succeeded; UI count source fixed

New user report:

- Remote client can join the host game through the server-console/IP route.
- The visible player count still shows `0/64`.

Host-side log evidence:

- `NotifyAcceptingConnection accepted from: 192.168.1.16:55670`
- `Login request: ?Name=...`
- `Join request: /Game/Maps/L_ClientLobby?...`
- `Join succeeded: 十年老兵`
- A second `BP_SN2PlayerState` was created and added to `USN2TeamViewModel`.

Interpretation:

- IP/Port listen host admission works for at least one remote client.
- The `0/64` UI is not proof of no players; it is caused by this route not having a normal default EOS/Sonar session/lobby object.
- The existing UI patch only changed the denominator from `4` to `64`; it preserved the numerator reported by the empty session source.

Fix implemented:

- Lua version bumped to `0.3.10-64-listen-ui-count`.
- `rewrite_player_count_text()` now asks `detect_actual_player_count()` for a live count.
- Detection priority:
  - `SN2GameState.PlayerArray`
  - `GameState.PlayerArray`
  - `GameStateBase.PlayerArray`
  - fallback `FindAllOf(BP_SN2PlayerState_C)`
  - fallback `FindAllOf(SN2PlayerState)`
  - fallback `FindAllOf(PlayerState)`
- If the actual count is higher than the session-derived numerator, the UI text uses the actual count.
- Expected result after host restart and client join:
  `2/64` instead of `0/64` for host + one remote player.

Still to validate:

- Restart host with the rebuilt mod.
- One remote client joins.
- Open the friend/player list and verify it shows `2/64`.
- Test disconnect/rejoin updates.
