# Subnautica2MorePlayers8 极简安装说明

当前版本：`0.3.6-64-production`

当前配置目标：`MaxPlayers=64`

8 人路径和第 5 人加入已经过实测反馈；64 人完整加入和世界同步仍未完成实机验证。

## 安装

普通玩家不需要安装 Visual Studio、CMake、Python、Git 或 SDK。

1. 完全退出 Subnautica 2。
2. 打开完整的 `Subnautica2MorePlayers8` 文件夹。
3. 双击 `Install-OneClick.cmd`。
4. 从 Steam 正常启动 Subnautica 2。
5. 房主创建多人房间，顶部人数应显示 `1/64`。

## 谁需要安装

64 人目标测试阶段，建议房主和所有加入玩家都安装同一个版本。

只让房主安装时，第 5 人已实测可以加入；但更高人数仍可能遇到客户端侧检查、session cache 或 SDK 返回值导致的拒绝/断连。

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

然后把生成的日志包交给维护者分析。
