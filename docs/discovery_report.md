# Discovery Report

Updated: 2026-05-17 00:05 CST

## Current Target Change - 1024 Production Profile

The active configuration target is now `MaxPlayers=1024` in `0.3.5-1024-production`.

New user-provided live validation:

- The 8-player path has been validated by the user.
- Player 5 can join.

Still not validated:

- 1024-player lobby/service acceptance.
- 1024-player world spawn/replication/synchronization.

Production profile changes:

- `LogLevel=Warn`.
- `EnableTraceFiles=false`.
- `EnableSafeParamProbe=false`.
- `HookProfile=ProductionLean`.
- Lua-side repeated admission/session sweeps disabled.
- Unsafe reflection, object dumps, dynamic discovery, and UI sweeps remain disabled.
- Native per-call logging remains disabled through `NativePatchLogAllCalls=false`.
- Targeted ViewModel player-count hook remains enabled so the in-game UI should display `1/1024`.

## Current Target Change - 32 Target

The active configuration target is now `MaxPlayers=32` in `0.3.4-32-target`.

The prior `1024` target was diagnostic only and has been replaced because EOS lobby limits and practical host/world replication make 32 a more useful next validation target. This is still not a verified 32-player production result.

New implementation changes for the 32 target:

- Project default `MorePlayers8.json` changed to `MaxPlayers=32`.
- Lua config default and clamp changed to `32`.
- Native config default and clamp changed to `32`.
- `build.ps1`, `install.ps1`, and `tools\verify_install.ps1` now validate `1..32`.
- Player-facing docs now tell testers to expect `1/32`.
- The known native `ApproveLogin -> Server full.` runtime patch remains hash-gated and enabled for the current EXE hash.

## Current Target Change - 1024 Diagnostic

The active configuration target is now `MaxPlayers=1024` in `0.3.3-1024-diagnostic`.

This is a configuration/patch target change only. It does not mean 1024 clients have joined or synchronized world state. The previously verified runtime evidence remains:

- EOS lobby capacity path was proven up to `8`.
- Host UI was proven as `1/8`.
- The last real player-5 failure was `PreLogin failure: Server full.`
- The exact known-hash native `ApproveLogin -> Server full.` branch was patched in memory.

New implementation changes for the 1024 target:

- Lua config default and clamp raised to `1024`.
- Native config default and clamp raised to `1024`.
- EOS option plausibility check now accepts capacity values up to `1024`.
- EOS/Steam capacity hooks set lower positive capacity values to configured `MaxPlayers`.
- Capacity-related EOS string attributes containing lower numeric values are patched to the configured `MaxPlayers`.
- Install-time `Game.ini` override now reads `MaxPlayers` from the built mod config instead of hard-coding `8`.
- Targeted UI return patch rewrites any player-count denominator lower than configured `MaxPlayers`, not only `/4`.

## Game Installation

- Game root: `D:\SteamLibrary\steamapps\common\Subnautica2`
- Launcher exe: `D:\SteamLibrary\steamapps\common\Subnautica2\Subnautica2.exe`
- Shipping exe: `D:\SteamLibrary\steamapps\common\Subnautica2\Subnautica2\Binaries\Win64\Subnautica2-Win64-Shipping.exe`
- Shipping exe SHA256: `E9D32E1693BEDBD4CB6BA6D7DB5FF9BB6EE34FA36AEF73F154B3CDC6B64D2CF4`
- Launcher exe SHA256: `05CA83656D33AE5996FFFE515138D190B81A9DCF62358D33E2D821A3B53CCD07`
- Branch: `//Project/SN2-Release-Hotfix-Live`
- Changelist: `113109`
- Build label: `34_SHIPPING_RELEASEHOTFIXLIVE_CL-113109_B-13`
- Build timestamp: `2026-05-10T04:15:22`

## Structure

- UE project directory: `Subnautica2`
- Shipping binary directory: `Subnautica2\Binaries\Win64`
- Pak/IoStore directory: `Subnautica2\Content\Paks`
- Main IoStore container: `Subnautica2-Windows.ucas` / `Subnautica2-Windows.utoc`
- Main pak: `Subnautica2-Windows.pak`

## UE4SS

- Installed upstream UE4SS dev build from `UE4SS-RE/RE-UE4SS`, release tag `experimental-latest`.
- Asset: `zDEV-UE4SS_v3.0.1-949-gdd6777a8.zip`
- Download SHA256: `16CA445F59413F640EE75A8AD943A536E0EF72FFDBA1A4F2A35CB40C32210F6E`
- UE4SS loads with `[EngineVersionOverride] MajorVersion=5 MinorVersion=6 DebugBuild=false`.
- Installed mod path: `D:\SteamLibrary\steamapps\common\Subnautica2\Subnautica2\Binaries\Win64\ue4ss\Mods\Subnautica2MorePlayers8`

## Online / Multiplayer Evidence

Static manifest and pak string scans found:

- `OnlineSubsystemEOS`
- `OnlineSubsystemSteam`
- `SocketSubsystemEOS`
- `EOSVoiceChat`
- `SteamShared`
- `UWELobby`
- `UWENetworking`
- `L_ClientLobby`
- `WBP_CreateGameScreen`
- `WBP_ClientLobbyHUD`
- `WBP_MainLobbyScreen`
- `ST_LobbyUI`
- `ST_SessionUI`

Inference: this Steam build uses a UWE/Sonar lobby/session layer over EOS/Steam and Unreal networking.

## Why GameSession Patch Is Insufficient

Verified reflected runtime patches:

- Lobby `GameSession.MaxPlayers`: `4 -> 8`
- Lobby `GameSession.MaxPartySize`: `-1 -> 8`
- Main world `SN2GameSession.MaxPlayers`: `4 -> 8`
- Main world `SN2GameSession.MaxPartySize`: `-1 -> 8`

Observed result after these patches in earlier builds: visible lobby remained `1/4`.

Conclusion: Engine `GameSession` / `SN2GameSession` fields are auxiliary only. They may still matter for later login/world admission, but the lobby capacity and displayed count are controlled elsewhere.

## Sonar/EOS/GPP Capacity Path

Runtime and native evidence:

- Reflected host flow reaches `/Script/UWESonar.UWEOnlineSessionSubsystem:HostSessionAsync`.
- `UWEHostSessionRequest` is constructed during host creation.
- Native modules include `EOSSDK-Win64-Shipping.dll` and `steam_api64.dll`.
- Native IAT hooks for EOS are installed only when the known game hash matches.
- `EOS_Lobby_CreateLobby` is called with `MaxLobbyMembers=4`; the mod changes it to `8`.
- `EOS_LobbyModification_SetMaxMembers` is called with `MaxMembers=4`; the mod changes it to `8`.
- `EOS_LobbyDetails_CopyInfo` reports `MaxMembers=8` and `AvailableSlots=7` after lobby creation.

Representative verified log lines:

- `EOS_Lobby_CreateLobby api=10 beforeMaxLobbyMembers=4 afterMaxLobbyMembers=8 ... changed=true`
- `EOS_LobbyModification_SetMaxMembers api=1 before=4 after=8 changed=true`
- `EOS_LobbyDetails_CopyInfo ... beforeMaxMembers=8 afterMaxMembers=8 beforeAvailableSlots=7 afterAvailableSlots=7`

Conclusion: for the tested build/hash, the real EOS lobby member limit is patched to 8. This does not by itself prove player 5-8 can finish joining and synchronize the world.

## Source Of UI 1/4

The direct source of the top lobby player-count text has now been identified:

- Function: `/Script/Subnautica2.SN2InGameFriendScreenViewModel:AssemblePlayercountString`
- Observed return before patch: `1/4`
- Patched return: `1/8`
- Patch result: `setString=true`

The broad UMG `TextBlock:SetText` / `GetText` hooks are disabled because they caused instability. The current UI fix patches only the ViewModel return value and does not scan all loaded widgets during normal runtime.

User screenshot on 2026-05-16 confirms the top lobby UI displays `1/8`.

## Attempted Hooks

Useful hooks:

- `/Script/UWESonar.UWEMultiplayerHostedSessionViewModel:TriggerHostGameRequest`
- `/Script/UWESonar.UWEOnlineSessionSubsystem:HostSessionAsync`
- `/Script/UWELobby.UWELobbyGameMode:StartNewServerGame`
- `/Script/UWELobby.UWEServerLobbyComponent:StartNewGame`
- `/Script/UWELobby.UWEServerLobbyComponent:LoadGame`
- `/Script/Subnautica2.SN2InGameFriendScreenViewModel:AssemblePlayercountString`
- `/Script/Subnautica2.SN2InGameFriendScreenViewModel:GetCurrentSessionName`
- `/Script/Subnautica2.SN2FriendScreenViewModel:InitFriendCode`
- `/Script/Subnautica2.SN2FriendScreenViewModel:RequestFriendCode`
- `/Script/Subnautica2.SN2FriendScreenViewModel:OnFriendCodeReturned`

Disabled or unsafe hooks/probes:

- `/Script/UMG.TextBlock:SetText`
- `/Script/UMG.TextBlock:GetText`
- `/Script/CommonUI.CommonTextBlock:SetText`
- `/Script/CommonUI.CommonTextBlock:GetText`
- Broad `FindAllOf` widget sweeps during normal runtime
- Unsafe reflected UObject name/class/property inspection in hook callbacks

## Crash Dump Analysis

Analyzed dump:

- `D:\SteamLibrary\steamapps\common\Subnautica2\Subnautica2\Binaries\Win64\ue4ss\crash_2026_05_15_23_51_31.6512637.dmp`
- Dump SHA256: `402232311043B7500DAE0AC6447014A24D7B246E946B0B50F49BB5AF280F21DA`
- Report: `C:\tmp\Subnautica2MorePlayers8\docs\crash_2026_05_15_23_51_31.6512637.analysis.md`

Conclusion:

- Exception: `0xC0000005`
- Faulting module: `UE4SS.dll`
- Fault: `UE4SS.dll+0x229B27`
- Symbol/source: UE4SS Lua UObject name binding, `LuaUObject.hpp:534`
- Trigger class: unsafe calls like `GetFullName`, `GetFName`, `GetClass`, or related UObject name inspection on hook context/params.

Mitigation:

- `EnableUnsafeObjectReflection=false` by default.
- No global UMG text hooks.
- No broad widget sweeps in normal runtime.

## Current Blocker

Current stage no longer blocks on lobby UI or EOS lobby capacity for one host.

The 2026-05-16 20:35 CST five-player test identified the next blocker:

- Player 5 reaches EOS P2P and the Unreal `GameNetDriver`.
- Host accepts the socket/control connection.
- Host receives the UE login request.
- Host rejects during `PreLogin` with `Server full.`

Representative host evidence:

- `NotifyAcceptedConnection ... GameNetDriver ... IsServer: YES`
- `Login request: ?Name=... ?SonarPlayerId=... ?PlatformProvider=STEAM`
- `PreLogin failure: Server full.`
- `UNetConnection::SendCloseReason: Result=PreLoginFailure`

Conclusion: EOS lobby capacity is no longer the active rejection point. The next active rejection point is Unreal listen-server admission, most likely `AGameModeBase::PreLogin` -> `AGameSession::ApproveLogin` / `AtCapacity` using a `GameSession` object that was still effectively capped at 4.

## Native Unreal Admission Path

PE/disassembly pass on the known shipping EXE identified the exact `Server full.` branch:

- `Server full.` UTF-16 string:
  - file offset `0xA37B010`
  - RVA `0xA37C010`
- Nearby `ApproveLogin` string:
  - file offset `0xA37AF90`
  - RVA `0xA37BF90`
- `.text` reference / branch site:
  - RVA `0x03FBC7E3`

Relevant disassembly:

```text
0x03FBC7D6: call qword ptr [rax + 0x778]
0x03FBC7E1: test al, al
0x03FBC7E3: je 0x143fbc7f1
0x03FBC7E5: lea rdx, [rip + ...] ; Server full.
```

Interpretation:

- The virtual call is the `AtCapacity`-style capacity check used by `AGameSession::ApproveLogin`.
- If it returns true, the function loads `Server full.` and returns it to `PreLogin`.
- This matches the real five-player failure log: `PreLogin failure: Server full.`

Implemented patch in `0.3.2-session-admission-ini-hardening` and retained in `0.3.3-1024-diagnostic`:

- Runtime memory patch only; the shipping EXE file is not modified.
- Hash-gated to SHA256 `E9D32E1693BEDBD4CB6BA6D7DB5FF9BB6EE34FA36AEF73F154B3CDC6B64D2CF4`.
- Byte-gated at RVA `0x03FBC7E3`.
- Original bytes: `74 0C 48 8D 15 24 F8 3B 06 E9 B4 00 00 00`.
- Patched bytes: `EB 0C 48 8D 15 24 F8 3B 06 E9 B4 00 00 00`.
- Effect: skip only this exact `ApproveLogin -> Server full.` branch.
- Config key: `EnableNativeUnrealServerFullAdmissionPatch`.
- Additional safety: skipped if `MaxPlayers <= 4` or `EnableJoinValidationPatch=false`.

Latest short-launch log confirms:

- `Unreal Server full admission patch active`
- `Patch status unrealServerFullAdmission=true`
- `Native capacity/admission patch install result=true`

Remaining production blockers:

- Fifth client has not been re-tested after the native admission patch.
- Any client above 4 has not been proven to join after the latest patch.
- Server/world spawn systems above 4 players are unverified.
- Replication/world synchronization above 4 players is unverified.
- EOS/Steam service acceptance of a 1024-member lobby/session is unverified.
- Long-session stability above 4 players is unverified.

## Next Patch Target

Implemented next patch target in `0.3.0-admission-gamesession-patch`:

- Corrected the `RegisterInitGameStatePostHook` handling to treat the callback argument as `GameState`, not `GameMode`.
- Reads `GameState.AuthorityGameMode.GameSession` and patches direct `MaxPlayers` / `MaxPartySize` values to configured `MaxPlayers`.
- Adds a narrow repeating sweep over only `SN2GameSession` and `GameSession` instances.
- Adds `Logs\admission_trace.txt` with `ADMISSION_PROPERTY_PATCH`, `ADMISSION_INSTANCE_SWEEP`, and `ADMISSION_AUTHORITY_GAMESESSION` records.

Next highest-value work is real multi-client validation:

- Start with 2 real clients to verify lobby updates still work with the current EOS/UI patch.
- Test the fifth client specifically and confirm whether `PreLogin failure: Server full.` disappears.
- If the fifth client is rejected with a different reason, hook that next rejection path.
- If the fifth client joins but world sync fails, move investigation to `PlayerController`, `PlayerState`, pawn spawn, save metadata, relevancy, bandwidth, and NetDriver limits.

## 2026-05-18 Server Console Discovery

Shipped game assets include official smoketest flows under:

```text
D:\SteamLibrary\steamapps\common\Subnautica2\Subnautica2\Content\Smoketest
```

Relevant files:

- `smoketest-listenserver-host.json`
- `smoketest-listenserver-client.json`

The shipped host smoketest uses:

```text
open L_Main?listen?bIsLanMatch
```

The shipped client smoketest uses:

```text
open 127.0.0.1
```

This indicates the game already has an internal QA path for LAN listen-host validation. The current server-console implementation reuses that game-owned path instead of broad Lua UObject construction watchers or direct calls to nonexistent `UWEServerLobbyComponent` instances at main-menu time.

Generated host file:

```text
Subnautica2\Content\Smoketest\smoketest-moreplayers8-server.json
```

Generated client file:

```text
Subnautica2\Content\Smoketest\smoketest-moreplayers8-client.json
```

Local validation proved:

- `UWESmoketest` starts from command line.
- `open L_Main?listen?bIsLanMatch` reaches `/Game/Maps/Main/L_Main`.
- `GameNetDriver` is initialized.
- UDP `0.0.0.0:7777` is opened by the game process.
- `CheckLevel` succeeds for `L_Main`.

Interpretation:

- This is a valid graphical listen-host route.
- It is not a true headless/dedicated server.
- It likely does not create a normal EOS friend-code lobby, so IP:Port client validation is the next target for this route.
