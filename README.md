# 深海迷航2多人联机mod

Steam 版 **Subnautica 2** 的 UE4SS mod。目标是在不绕过 Steam/EOS 正版认证、不永久修改游戏 EXE 的前提下，把官方多人上限从 4 人提高到当前配置的 64 人。

当前版本：`0.3.9-64-official-smoketest-server-console`

当前目标人数：`64`

## 当前验证状态

已验证：

- UE4SS 可在当前游戏版本加载。
- mod 可构建、安装、卸载、校验。
- UI 可显示 `1/64`。
- 用户已反馈 8 人路线通过，第 5 人可以加入。
- 本机已验证图形化 CMD listen host 能进入 `L_Main` 并监听 UDP 7777。

未验证：

- 64 名真实客户端同时加入。
- 8 人以上的长时间世界同步、存档和重连。
- IP:Port 路线下第 5 人以上加入和同步。
- 真正无图形 dedicated server。

## 支持的游戏版本

当前 native patch 只针对以下 Steam 版构建启用：

- Build label: `34_SHIPPING_RELEASEHOTFIXLIVE_CL-113109_B-13`
- Build timestamp: `2026-05-10T04:15:22`
- EXE SHA256: `E9D32E1693BEDBD4CB6BA6D7DB5FF9BB6EE34FA36AEF73F154B3CDC6B64D2CF4`

如果游戏更新导致 EXE hash 不匹配，native patch 会自动禁用，避免对未知版本硬打偏移。

## 最简单安装

普通玩家不需要安装 Visual Studio、CMake、Python、Git 或 SDK。

1. 完全退出 Subnautica 2。
2. 获取完整的 `Subnautica2MorePlayers8` 文件夹。
3. 双击 `Install-OneClick.cmd`。
4. 从 Steam 正常启动 Subnautica 2。
5. 房主创建多人房间，顶部人数显示应为 `1/64`。

如果游戏不在默认路径，可用 PowerShell 手动指定：

```powershell
.\Install-OneClick.ps1 -GameRoot "D:\SteamLibrary\steamapps\common\Subnautica2"
```

## 谁需要安装

建议房主和所有加入玩家都安装同一版本。

原因：

- 房主必须修改真实 lobby/session capacity。
- 客户端也可能经过本地 UI、join validation、session cache 或 SDK 返回值检查。
- 虽然用户已反馈第 5 人可加入，但 64 人目标仍没有全量实测，统一安装是风险最低的测试方式。

## 卸载

完全退出游戏后双击：

```text
Uninstall-OneClick.cmd
```

或手动运行：

```powershell
.\uninstall.ps1 -GameRoot "D:\SteamLibrary\steamapps\common\Subnautica2"
```

卸载脚本会删除 mod，并恢复安装时写入的可回滚配置块。

## 构建和安装

```powershell
cd C:\tmp\Subnautica2MorePlayers-github
.\build.ps1
.\install.ps1 -GameRoot "D:\SteamLibrary\steamapps\common\Subnautica2"
.\tools\verify_install.ps1 -GameRoot "D:\SteamLibrary\steamapps\common\Subnautica2"
```

## 主要 patch 点

- `EOS_Lobby_CreateLobby`：将 `MaxLobbyMembers` 改为 `MaxPlayers`。
- `EOS_LobbyModification_SetMaxMembers`：将 `MaxMembers` 改为 `MaxPlayers`。
- EOS lobby/session copied info 和 attribute 中偏低的人数上限会被修正。
- 如果当前构建导入 Steam lobby API，会尝试修正 Steam lobby member limit。
- `/Script/Subnautica2.SN2InGameFriendScreenViewModel:AssemblePlayercountString`：修正顶部好友/房间人数显示。
- 已知 hash 下的 `AGameSession::ApproveLogin -> Server full.` 分支会被运行时 patch。
- `%LOCALAPPDATA%\Subnautica2\Saved\Config\Windows\Game.ini` 会写入 mod-owned、可卸载的 GameSession 覆盖项。

## 生产低日志配置

默认配置尽量减少性能开销：

- `LogLevel=Warn`
- `EnableTraceFiles=false`
- `HookProfile=ProductionLean`
- `EnableUnsafeObjectReflection=false`
- `NativePatchLogAllCalls=false`

调试失败加入时再临时提高日志等级。

## 图形化 CMD listen host

这是实验性服务端方向，不是 dedicated server。

启动服务端：

```text
Start-GraphicalServerConsole.cmd
```

它会通过 Steam 启动真实游戏客户端小窗口，并让游戏自带 `UWESmoketest` 执行：

```text
open L_Main?listen?bIsLanMatch
```

本机已验证：

- 进入 `L_Main`。
- UDP `0.0.0.0:7777` 监听。
- 日志出现 `GameNetDriver` 和 `IpNetDriver listening on port 7777`。
- 300 秒监控内无新崩溃。

客户端直连测试：

```text
Join-ExperimentalServer.cmd
```

输入主机 IP 后，脚本会通过 Steam 启动客户端，并让游戏自带 `UWESmoketest` 执行：

```text
open <主机IP>:7777
```

LAN 测试通常只需要同网段 IP。公网测试需要路由器转发 UDP 7777 并放行 Windows 防火墙。

## 日志收集

如果第 5 人或更高人数加入失败，房主和失败玩家都应立即运行：

```text
Collect-MorePlayers8Logs.cmd
```

重点文件：

- `Subnautica2.log`
- `MorePlayers8.log`
- `native_eos_patch.log`
- UE4SS 日志
- 崩溃 dump 或断连时间点附近日志

## 重要说明

UI 显示 `1/64` 只是必要条件，不代表 64 人完整成功。真正通过标准必须包括真实玩家加入、出生、移动、交互、世界同步、保存、重连和长时间稳定性。
