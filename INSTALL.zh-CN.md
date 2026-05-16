# Subnautica2MorePlayers8 极简安装说明

当前版本：`0.3.6-64-production`

当前配置目标是 `MaxPlayers=64`。你已反馈 8 人路径和第 5 人加入已经验证；64 人本身还需要继续实测。

## 最简单安装

普通玩家不需要安装 Visual Studio、CMake、Python、Git 或 SDK。

1. 完全退出 Subnautica 2。
2. 打开完整的 `Subnautica2MorePlayers8` 文件夹。
3. 双击 `Install-OneClick.cmd`。
4. 从 Steam 正常启动 Subnautica 2。
5. 房主创建多人房间，顶部人数应显示 `1/64`。

## 谁需要安装

64 目标测试阶段建议：房主和所有参与测试的玩家都安装同一个 `Z:\Subnautica2MorePlayers8` 包。

## 生产降噪

默认关闭了大部分诊断开销：trace 文件、参数探测、unsafe reflection、Lua 循环扫描、native per-call logging。

## 卸载

退出游戏后双击：

```text
Uninstall-OneClick.cmd
```

## 加入失败时收集日志

房主和失败玩家都立刻运行：

```text
Collect-MorePlayers8Logs.cmd
```
