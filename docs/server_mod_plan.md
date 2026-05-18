# 实验性图形化服务器方向

状态：未完成。当前没有证据证明 Subnautica 2 Steam 客户端包可以作为真正 headless/dedicated server 运行。

## 当前结论

- `-Windowed` 可以启动游戏、加载 UE4SS 和 mod。`-NoSound` 在 2026-05-18 的 WER dump 中进入 FMOD 崩溃路径，默认不再使用。
- `-NullRHI` 可以启动并加载 mod，但仍进入客户端大厅，不会自动成为服务器。
- 仅传 `-Port=7777` 不会创建 UDP 7777 监听。
- 裸 `servertravel/open /Game/...?...listen` 已被标记为危险路线，默认禁用。
- 直接调用 `UWEMultiplayerHostedSessionViewModel:TriggerHostGameRequest` 能创建 EOS lobby，但在未初始化 UI 存档/模式状态时会生成非法 travel URL：
  `L_Main?listen?game=EGameModeAliasAsEnum::Survival`
- 正常 UI 开房日志中的合法 URL 形如：
  `L_Main?listen?game=Creative?SaveSlotDisplayName=...?...`
- 因此当前服务端方向只能做“图形化低资源主机控制台”，不能宣称无图形专用服务器。

## 崩溃分析

最近崩溃目录：

`%LOCALAPPDATA%\Subnautica2\Saved\Crashes\UECC-Windows-E68FA0FF4A9BE096C6DA3790B50493C4_0000`

`CrashContext.runtime-xml` 显示：

- `EXCEPTION_ACCESS_VIOLATION reading address 0x0000000000000018`
- 调用栈在 UE4SS Lua UObject 成员访问路径内
- 触发链包含 `RegisterStaticConstructObjectPostCallback`

结论：

- 这不是 EOS/Steam 认证崩溃。
- 这不是 64 人容量 patch 的直接崩溃。
- 风险点是 UE4SS Lua 在对象构造回调期间访问 UObject 成员。
- 生产配置必须保持：
  - `EnableUnsafeObjectReflection=false`
  - `EnableObjectWatchers=false`
  - 不启用大范围 UObject 构造扫描

## 当前可用脚本

图形化服务器控制台：

```powershell
.\Start-GraphicalServerConsole.cmd -GameRoot "D:\SteamLibrary\steamapps\common\Subnautica2" -Restart
```

它会：

- 启动真实游戏客户端小窗口。
- 默认通过 Steam `steam.exe -applaunch 1962700` 启动游戏；只有调试时才使用 `-UseWrapperExe` 或 `-UseShippingExe`。
- 写入服务器实验配置。
- 通过 `UiLaunchGame` 路径尝试调用大厅 UI 的 `LaunchGame`。
- 监控日志证据：
  - EOS lobby capacity 是否为 64
  - EOS create callback 是否成功
  - 是否完成 world travel
  - 是否出现非法 `CanServerTravel`
  - 是否出现 UDP 7777 / NetDriver / PostLogin 证据
  - 是否有最近崩溃

低图形启动，不自动开房：

```powershell
.\tools\Start-ExperimentalServer.ps1 -GameRoot "D:\SteamLibrary\steamapps\common\Subnautica2" -Windowed -Restart -Monitor
```

安全 API 自动开房：

```powershell
.\tools\Start-ExperimentalServer.ps1 -GameRoot "D:\SteamLibrary\steamapps\common\Subnautica2" -Windowed -EnableApiAutoHost -ServerApiMode UiLaunchGame -ServerApiMaxAttempts 1 -Monitor -Restart
```

不建议的危险模式，默认禁用：

```powershell
.\tools\Start-ExperimentalServer.ps1 -EnableApiAutoHost -ServerApiMode RawHostViewModel -EnableRawHostViewModelApi
```

只有在需要复现 `EGameModeAliasAsEnum::Survival` 错误时才使用。

## 验证标准

“脚本启动成功”不等于服务器成功。

最低成功标准：

- 游戏进程存活。
- UE4SS/mod 加载。
- EOS lobby 创建成功且容量为 64。
- 日志出现合法 `ProcessServerTravel` 或 `Server switch level`。
- 不出现 `CanServerTravel: FURL ... blocked`。
- 进入 `L_Main` 世界。
- 有 `GameNetDriver` / `PostLogin` / 客户端连接证据。

真正可称为服务端 mod 之前，还必须验证：

- 第 5 人以上可加入。
- 玩家出生、移动、交互、库存、载具、基地、存档同步正常。
- 长时间运行不崩溃。
- 主机端断线/退出行为明确。

## 当前阻塞点

没有发现官方 dedicated server target。

直接启动 `Subnautica2-Win64-Shipping.exe` 或根目录 wrapper 在一次验证中会触发：

`STEAM: Game restarting within Steam client, exiting`

随后进程会在 RHI 初始化后 `EngineExit()`。因此启动器默认改为通过 Steam `-applaunch 1962700` 启动，保持正版 Steam/EOS 链路。

当前 packaged client 的官方多人创建流程依赖 UI 选择存档、游戏模式、好友码/EOS lobby 和 Sonar/GPP 状态。绕过 UI 直接触发底层 ViewModel 会缺少初始化字段，从而生成非法 travel URL。

下一步若继续做自动化服务器，应优先分析：

- `/Game/Blueprints/UI/Lobby/Multiplayer/WBP_LoadGamePanel1.WBP_LoadGamePanel1_C:LaunchGame`
- `OnSaveSelected`
- `OnLoad`
- `OnNewGameClicked__DelegateSignature`
- `UWEServerLobbyComponent:LoadGame`
- `UWEServerLobbyComponent:StartNewGame`

目标是复用正常 UI 初始化链，而不是直接构造 Unreal listen URL。

## 2026-05-18 直接 API 路线更新

已从 shipping exe 字符串确认 `UWEServerLobbyComponent.cpp` 内部有官方服务端加载路径：

- `Server travel to level %s with options %s`
- `Savegame slot %s not found`
- `?LaunchType=LoadGame?SaveSlotName=%s`

因此当前优先路线改为：

```text
CMD 控制台 -> Steam 启动真实游戏客户端 -> UE4SS Lua -> UWEServerLobbyComponent:LoadGame(savegame_N)
```

当前默认命令：

```powershell
.\Start-GraphicalServerConsole.cmd -GameRoot "D:\SteamLibrary\steamapps\common\Subnautica2" -Restart
```

脚本会自动扫描 `%LOCALAPPDATA%\Subnautica2\Saved\SaveGames\savegame_*.sav`，选择最近修改的存档并写入 `ServerSaveSlotName`。如果要固定存档：

```powershell
.\Start-GraphicalServerConsole.cmd -GameRoot "D:\SteamLibrary\steamapps\common\Subnautica2" -ServerSaveSlotName savegame_1 -Restart
```

安全边界：

- 默认不创建新游戏。
- 默认不启用 `servertravel/open` 裸命令。
- 默认不使用 `-NoSound`。
- 默认不启用 broad UObject watcher / unsafe reflection。

尚未完成的验证：

- 是否成功进入 `L_Main`。
- 是否创建 EOS lobby 且容量为 64。
- 是否出现 `GameNetDriver` / UDP 7777 / `PostLogin` 证据。
- 是否有真实客户端能加入这个控制台启动的主机。
