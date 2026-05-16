# Subnautica2MorePlayers8 最新测试说明

当前版本：`0.3.4-32-target`

当前目标配置：`MaxPlayers=32`

这不是已经验证通过的 32 人版本。上一轮真实失败点是第 5 人加入时被房主侧 Unreal `PreLogin failure: Server full.` 拒绝。当前版本把已知 lobby/session/admission/UI 补丁目标改为 32，并保留已定位的 native `ApproveLogin -> Server full.` 运行时补丁。

## 下一轮测试重点

1. 房主和所有参与测试的客户端都安装 `Z:\Subnautica2MorePlayers8` 里的同一版。
2. 房主创建房间，确认 UI 是 `1/32`。
3. 房主确认 `native_eos_patch.log` 里有：
   - `maxPlayers=32`
   - capacity 调用被改成 `32`
   - `unrealServerFullAdmission=true`
4. 玩家 2-4 加入并正常进世界。
5. 玩家 5 加入。这仍然是当前最关键测试点。
6. 如果玩家 5 断开，不要立刻关游戏；房主和玩家 5 都运行 `Collect-MorePlayers8Logs.cmd`。
7. 如果玩家 5 成功进世界，再继续逐个增加玩家，并验证出生、移动、交互、互相可见、世界同步、保存和重连。

## 判定

- 如果仍出现 `PreLogin failure: Server full.`：native admission patch 没覆盖当前运行路径，继续查 admission path。
- 如果不再出现这条，但玩家 5 仍断开：按新的 host/client 日志定位下一层阻止点。
- 如果玩家 5 成功进世界：下一目标是 6 人以上，以及 PlayerController、PlayerState、Pawn、存档、带宽、relevancy、世界同步。
- 只有真实客户端加入并同步世界后，才能说通过。UI 显示 `1/32` 不算通过。
