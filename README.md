# Subnautica2MorePlayers8

UE4SS-based Subnautica 2 Steam mod that raises the known lobby/session/admission capacity paths away from the official 4-player limit.

Current status: `0.3.6-64-production` targets `MaxPlayers=64` with reduced runtime diagnostics. The earlier 8-player path, including player 5 joining, has been reported as verified by live testing. The 64-player target itself still requires real-client validation.

## Supported Game Build

- Build label: `34_SHIPPING_RELEASEHOTFIXLIVE_CL-113109_B-13`
- Build timestamp: `2026-05-10T04:15:22`
- Shipping EXE SHA256: `E9D32E1693BEDBD4CB6BA6D7DB5FF9BB6EE34FA36AEF73F154B3CDC6B64D2CF4`

Native patches are hash-gated. If the shipping EXE hash changes, native patches disable instead of applying unknown offsets.

## What Is Patched

- `EOS_Lobby_CreateLobby`: `MaxLobbyMembers` is changed from the game's value to configured `MaxPlayers`.
- `EOS_LobbyModification_SetMaxMembers`: `MaxMembers` is changed to configured `MaxPlayers`.
- EOS copied lobby/session info and capacity-related metadata are corrected when they report a lower value.
- Steam lobby member-limit calls are patched if this build routes through Steam lobby APIs.
- Top lobby count source `/Script/Subnautica2.SN2InGameFriendScreenViewModel:AssemblePlayercountString` is patched to display the configured cap, so the lobby should show `1/64`.
- Known-hash native `AGameSession::ApproveLogin -> Server full.` branch is patched in memory at runtime.
- `%LOCALAPPDATA%\Subnautica2\Saved\Config\Windows\Game.ini` gets a reversible mod-owned `GameSession` override using the configured cap.

The mod does not bypass Steam/EOS authentication and does not replace the official multiplayer stack.

## Production Profile

- `LogLevel=Warn`
- `EnableTraceFiles=false`
- `EnableSafeParamProbe=false`
- `HookProfile=ProductionLean`
- `EnableUnsafeObjectReflection=false`
- No broad widget sweeps
- No Lua-side admission/session polling loops
- `NativePatchLogAllCalls=false`

Essential startup/error logging remains available in `MorePlayers8.log` and `native_eos_patch.log`.

## Simplest Install

1. Exit Subnautica 2 completely.
2. Open the full `Subnautica2MorePlayers8` folder.
3. Double-click `Install-OneClick.cmd`.
4. Start Subnautica 2 from Steam.
5. Host creates a multiplayer lobby and checks whether the top player count shows `1/64`.

Normal players do not need Visual Studio, CMake, Python, Git, or any SDK.

## Who Must Install It

For 64-target testing, install the same package on the host and every joining client.

## Build

```powershell
cd C:\tmp\Subnautica2MorePlayers8
.\build.ps1
```

## Install

```powershell
cd C:\tmp\Subnautica2MorePlayers8
.\install.ps1 -GameRoot "D:\SteamLibrary\steamapps\common\Subnautica2"
```

Installed mod path:

```text
D:\SteamLibrary\steamapps\common\Subnautica2\Subnautica2\Binaries\Win64\ue4ss\Mods\Subnautica2MorePlayers8
```

Current uncompressed player package:

```text
Z:\Subnautica2MorePlayers8
```

## Uninstall

```powershell
cd C:\tmp\Subnautica2MorePlayers8
.\uninstall.ps1 -GameRoot "D:\SteamLibrary\steamapps\common\Subnautica2"
```

Or double-click `Uninstall-OneClick.cmd`.

## Validation Boundary

- 8-player path and player 5 joining: reported verified by live testing.
- 64-player capacity and world synchronization: not verified yet.

UI showing `1/64` is necessary but not sufficient. Real pass requires players joining, spawning, moving, interacting, save/rejoin, and world replication.
