# Crash Dump Analysis

## 2026-05-18 19:30 WER dump

Dump:

`C:\Users\fzc\AppData\Local\CrashDumps\Subnautica2-Win64-Shipping.exe.10848.dmp`

Related log:

`%LOCALAPPDATA%\Subnautica2\Saved\Logs\Subnautica2.log`

Findings:

- No new UE crash folder was written under `%LOCALAPPDATA%\Subnautica2\Saved\Crashes`.
- A Windows WER dump was written at `2026-05-18 19:30:39`.
- The game log reaches `L_ClientLobby` and `Engine is initialized` at about `2026-05-18 19:30:29`.
- The crash occurs roughly 10 seconds after the frontend lobby loads.
- This is before the default `ServerAutoHostDelayMs=20000` API automation would call `UiLaunchGame`.
- Minidump parsing shows the exception thread RIP at:
  `fmodstudio.dll + 0x9031e`
- The crash stack contains FMOD/game window/UI frames and does not show `MorePlayers8Native.dll` as the active instruction pointer.

Interpretation:

- This dump does not prove that the in-game API auto-host call caused the crash.
- The timing and instruction pointer point at the FMOD Studio audio path.
- The launch used `-NoSound`, which may still load FMOD Studio but leave parts of the audio path in an unstable state for this build.
- The default graphical server console has therefore been changed to stop passing `-NoSound`.

Changed after this analysis:

- `Start-GraphicalServerConsole.cmd` now launches the small graphical client without `-NoSound`.
- `tools\Start-ExperimentalServer.ps1 -Monitor` now checks both:
  - UE crash folders under `%LOCALAPPDATA%\Subnautica2\Saved\Crashes`
  - WER dumps under `%LOCALAPPDATA%\CrashDumps\Subnautica2-Win64-Shipping.exe*.dmp`

Still unverified:

- The graphical server path has not yet proven `ProcessServerTravel` into `L_Main`.
- UDP `7777` / `GameNetDriver` listen evidence has not yet been observed in this service-mode flow.
- Direct IP:port join is not verified.
- This remains a graphical client host experiment, not a true dedicated/headless server.
