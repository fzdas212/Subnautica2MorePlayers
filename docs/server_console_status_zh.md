# Subnautica2MorePlayers8 图形化 CMD 服务端状态

更新日期：2026-05-18

## 当前结论

- 这不是无图形 dedicated server。
- 当前已验证的是“图形化 CMD 控制台启动的 listen host”：脚本通过 Steam 启动真实 Subnautica 2 客户端小窗口，并让游戏自带 `UWESmoketest` 执行 listen-host 流程。
- 当前服务端路线没有绕过 Steam/EOS 认证，没有修改游戏 EXE 文件。
- 64 人普通联机 mod 仍保留原来的 EOS/session/admission 补丁。

## 已验证的服务端证据

验证命令：

```powershell
cd C:\tmp\Subnautica2MorePlayers-github
.\tools\Start-ExperimentalServer.ps1 -GameRoot "D:\SteamLibrary\steamapps\common\Subnautica2" -Windowed -ServerApiMode OfficialSmokeTestLanListen -Monitor -MonitorSeconds 300 -Restart
```

结果：

- 游戏进程 300 秒监控结束时仍在运行。
- `UWESmoketest` 已从命令行启动。
- 执行了游戏自带步骤：`open L_Main?listen?bIsLanMatch`。
- 成功加载 `/Game/Maps/Main/L_Main`。
- `CheckLevel` 成功：当前关卡是 `L_Main`。
- UDP `0.0.0.0:7777` 正在监听，所属进程为 `Subnautica2-Win64-Shipping.exe`。
- 游戏日志出现 `GameNetDriver` 和 `IpNetDriver listening on port 7777`。
- 没有新的 UE 崩溃目录或 WER dump。
- 已通过在 smoketest 末尾加入 `Wait 86400` 避免完成后自动 `RequestExit(0)`。

关键日志：

```text
LogUWESmoketest: Starting smoketest from commandline with file smoketest-moreplayers8-server.json
LogUWESmoketest: Executing Console command: open L_Main?listen?bIsLanMatch
LogNet: Browse: /Game/Maps/Main/L_Main?listen?bIsLanMatch
LogNet: Created socket for bind address: 0.0.0.0:7777
LogNet: Name:GameNetDriver ... IpNetDriver listening on port 7777
LogUWESmoketest: CheckLevel succeeded: Level Name is L_Main
```

## 入口脚本

服务端：

```text
Start-GraphicalServerConsole.cmd
```

默认行为：

- 通过 Steam 启动游戏。
- 小窗口运行。
- 创建 `Subnautica2\Content\Smoketest\smoketest-moreplayers8-server.json`。
- 让游戏自带 `UWESmoketest` 进入 `L_Main?listen?bIsLanMatch`。
- CMD 持续监控进程、UDP 端口、NetDriver、崩溃和 `Server full`。

客户端直连测试：

```text
Join-ExperimentalServer.cmd
```

默认行为：

- 提示输入主机 IP。
- 通过 Steam 启动游戏。
- 创建 `smoketest-moreplayers8-client.json`。
- 让游戏自带 `UWESmoketest` 执行 `open <主机IP>:7777`。

## 仍未验证

- 另一台真实客户端通过 `Join-ExperimentalServer.cmd` 加入该 listen host。
- 第 5 人以上通过该 IP:Port 路线加入。
- 多人出生、移动、交互、存档、重连和长时间同步。
- 公网 NAT/端口转发场景。
- 真正 headless/dedicated server。

## 网络说明

- LAN 同网段测试优先使用主机局域网 IP 和 UDP 7777。
- 公网测试需要路由器转发 UDP 7777 到主机，并放行 Windows 防火墙。
- 可用脚本创建防火墙规则：

```powershell
.\tools\New-MorePlayers8FirewallRule.ps1 -GameRoot "D:\SteamLibrary\steamapps\common\Subnautica2" -Port 7777
```

## 风险

- `OfficialSmokeTestLanListen` 是游戏自带 QA/自动化路径，不是官方对玩家公开的 dedicated server。
- 它可能不创建 EOS 好友码大厅，因此监控里的 `eosLobby=false` 在这个路线下不是失败。
- 如果客户端直连失败，下一步要收集主机和客户端的 `Subnautica2.log`、`MorePlayers8.log`、`native_eos_patch.log`。
