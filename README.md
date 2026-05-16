# Subnautica2MorePlayers8

这是一个面向 Steam 版 **Subnautica 2** 的 UE4SS mod，用于把官方多人联机人数上限从 4 人提高到更高人数。

当前版本：`0.3.6-64-production`

当前目标人数：`64`

请注意：这个项目不是破解补丁，不绕过 Steam/EOS 正版认证，也不替换官方多人联机系统。它只在官方联机链路上修改 lobby/session/admission 相关的人数上限参数。

## 当前验证状态

已验证：

- UI 已可显示 `1/64`。
- 8 人路径已测试过。
- 第 5 名玩家加入成功，用户已实测反馈通过。

未验证：

- 64 人全部真实客户端同时加入。
- 64 人状态下的长时间世界同步。
- 64 人状态下的保存、重进、基地交互、载具交互和远距离同步稳定性。

因此当前不能宣称“64 人完整生产验证通过”。它是以 64 为目标的生产低日志版本，仍需要继续多人实测。

## 支持的游戏版本

当前只针对下面这个 Steam 版游戏构建做了 native patch 版本保护：

- Build label: `34_SHIPPING_RELEASEHOTFIXLIVE_CL-113109_B-13`
- Build timestamp: `2026-05-10T04:15:22`
- EXE SHA256: `E9D32E1693BEDBD4CB6BA6D7DB5FF9BB6EE34FA36AEF73F154B3CDC6B64D2CF4`

如果游戏更新导致 EXE hash 不匹配，native patch 会自动禁用，避免对未知版本硬打偏移。

## 最简单安装方法

普通玩家不需要安装 Visual Studio、CMake、Python、Git 或 SDK。

1. 完全退出 Subnautica 2。
2. 下载或复制完整的 `Subnautica2MorePlayers8` 文件夹。
3. 双击运行 `Install-OneClick.cmd`。
4. 从 Steam 正常启动 Subnautica 2。
5. 房主创建多人房间，顶部人数显示应为 `1/64`。

如果游戏不在默认路径，使用 PowerShell 手动指定路径：

```powershell
.\Install-OneClick.ps1 -GameRoot "D:\SteamLibrary\steamapps\common\Subnautica2"
```

## 谁需要安装

建议房主和所有加入的玩家都安装同一个版本。

原因：

- 房主需要修改真实 lobby/session capacity。
- 加入方也可能经过本地 UI、join validation、session cache 或 SDK 返回值检查。
- 只让房主安装时，第 5 人已实测可以进，但更高人数仍可能在客户端侧遇到拒绝或断连。

所以 64 人目标测试阶段，统一安装是最稳妥的方案。

## 卸载方法

完全退出游戏后双击：

```text
Uninstall-OneClick.cmd
```

或手动运行：

```powershell
.\uninstall.ps1 -GameRoot "D:\SteamLibrary\steamapps\common\Subnautica2"
```

卸载脚本会删除 mod，并恢复安装时备份过的文件。

## 构建方法

开发者重新构建：

```powershell
cd C:\tmp\Subnautica2MorePlayers8
.\build.ps1
```

安装到本机游戏：

```powershell
.\install.ps1 -GameRoot "D:\SteamLibrary\steamapps\common\Subnautica2"
```

验证安装：

```powershell
.\tools\verify_install.ps1 -GameRoot "D:\SteamLibrary\steamapps\common\Subnautica2"
```

## 当前修改内容

主要 patch 点：

- `EOS_Lobby_CreateLobby`：把 `MaxLobbyMembers` 改为配置中的 `MaxPlayers`。
- `EOS_LobbyModification_SetMaxMembers`：把 `MaxMembers` 改为配置中的 `MaxPlayers`。
- EOS copied lobby/session info 中偏低的人数上限会被修正。
- 如果当前构建走 Steam lobby API，会尝试修正 Steam lobby member limit。
- `/Script/Subnautica2.SN2InGameFriendScreenViewModel:AssemblePlayercountString`：修正顶部好友/房间人数显示来源，使其显示 `1/64`。
- 已知 hash 下的 `AGameSession::ApproveLogin -> Server full.` native 分支会在运行时被 patch。
- `%LOCALAPPDATA%\Subnautica2\Saved\Config\Windows\Game.ini` 会写入可回滚的 mod-owned `GameSession` 覆盖项。

## 生产低日志配置

当前默认是降噪配置，减少性能开销：

- `LogLevel=Warn`
- `EnableTraceFiles=false`
- `EnableSafeParamProbe=false`
- `HookProfile=ProductionLean`
- `EnableUnsafeObjectReflection=false`
- `NativePatchLogAllCalls=false`

基础错误日志仍会保留，方便排查加入失败。

## 加入失败时如何收集日志

如果第 5 人或更高人数加入失败，房主和失败玩家都应立刻运行：

```text
Collect-MorePlayers8Logs.cmd
```

重点需要检查：

- 房主日志
- 失败玩家日志
- `MorePlayers8.log`
- `native_eos_patch.log`
- UE4SS 日志
- 游戏崩溃或断连时间点附近的日志

## 端口转发 / LAN / 公网

当前 mod 复用官方 Steam/EOS 联机机制。

- 不默认开启自定义公网监听端口。
- 不需要额外 LAN server。
- 不提供绕过认证的直连模式。
- 公网联机仍优先使用官方好友、邀请或房间机制。

如果官方联机机制本身因为 NAT、防火墙或平台服务失败而无法连接，本 mod 不会单独解决那类网络问题。

## 重要说明

UI 显示 `1/64` 只是必要条件，不代表 64 人完整成功。

真正通过标准应包括：

- 多名玩家实际加入。
- 第 5 人以后不再被 full / capacity / disconnect 拒绝。
- 玩家能生成、移动、交互。
- 世界状态能同步。
- 保存和重进正常。
- 长时间游玩不出现人数相关崩溃。

目前已知最可靠的结论是：8 人路径和第 5 人加入已通过实测；64 人完整压力测试还没有完成。
