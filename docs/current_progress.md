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
