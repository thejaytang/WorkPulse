# WorkPulse 团队重新审查统一决策 V1

日期：2026-08-12  
参与角色：产品、UI/UX、技术实现、用户需求、质疑智能体

## 1. 总结论

WorkPulse 当前只能称为 **Menu Bar / Notch Local Technical Preview**。当前 ZIP 不包含可安装的 Widget `.appex`，通知与顶部 Alert 也没有完成可靠投递闭环，因此不能称为完整伴生应用或 Pilot。

产品范围立即收缩到三件事：

1. 在顶部常驻区用 3 秒可读的方式显示 Codex quota。
2. 提供可独立控制的一次性低额度提醒，并在顶部不可见时回退到系统通知。
3. 首发只实现 Small Quota 与 Small Pinned 两个真实可安装 Widget。

Daily Brief、Needs You、Medium Now & Next、Large Brief 在真实数据源和用户验证完成前均为 No-Go。

## 2. 对质疑智能体意见的决策

| 质疑 | 决策 | 调整 |
|---|---|---|
| 自动检查只验证字段存在，未验证信息价值 | Adopt | 增加真实运行截图、3 秒扫读任务和状态语义验收 |
| Resident 缺少 quota bucket 身份 | Adopt | 多 bucket 时显示短身份，如 `7 天 · 55% 剩余`；单 bucket 时允许省略 |
| Overlay 请求后立即算 presented，可能吞掉通知 fallback | Adopt | presented 必须由真实可见/投递回执确认；失败或超时进入通知 fallback |
| Resident 与 Alert 共用开关 | Adopt | 拆成常驻、顶部提醒、系统通知三个独立偏好 |
| 当前 Widget 对用户不可用 | Adopt | 在 `.appex`、App Group、Widget Gallery 真机验证前不得宣称已交付 |
| stale 仍突出精确额度 | Adopt | stale 降低强调并显示快照年龄；reset 已过期时不再用当前值口吻 |
| Expanded 混入固定入口 | Adopt | Quota Expanded 只显示 bucket、剩余、reset、观察时间、来源和刷新 |
| 四个 Widget 同时开发 | Adopt | 首发仅 Small Quota 与 Small Pinned |

## 3. 三个系统表面的最终职责

### 顶部常驻区

- 核心任务：不打开任何页面即可判断“还剩多少、何时恢复”。
- 多 bucket 文案：`7 天 · 55% 剩余` / `周二 09:58 重置`。
- 单 bucket 文案：`Codex 55% 剩余` / `周二 09:58 重置`。
- stale：显示“快照可能过期”与快照年龄，不继续用绿色实时状态。
- 展开态只服务 quota 上下文，不混入固定入口、Needs You 或能力说明。

### Widget

- Small Quota：桌面 glance，但需用 7 天 diary 验证它相对顶部常驻区是否具有增量价值。
- Small Pinned：固定某个日常任务或对话的快捷入口；不承诺自动同步任务状态。
- Widget Gallery 看不到组件即视为未交付。

### 系统通知与顶部 Alert

- 普通刷新不提醒。
- 只有真实阈值 crossing 或可信事件触发一次性提醒。
- 顶部 Alert 适用于用户正在使用内建显示屏且确实可见的场景。
- 不可见、全屏受限、用户离开或投递失败时回退系统通知。
- 通知授权不等于通知已展示，必须区分 scheduled、presented、opened。

## 4. 优先级

### P0

1. Resident 多 bucket 短身份与 stale 语义。
2. 拆分常驻、Alert、Notification 三个偏好。
3. 修复真实 presented/fallback 投递合同。
4. 清理 Quota Expanded 信息结构。
5. 建立完整 Xcode host + Widget extension + App Group 构建链路。

### P1

1. 交付 Small Quota 与 Small Pinned 的可安装版本。
2. 完成浅色、深色、多显示器、全屏、大字号、VoiceOver 的运行态验证。
3. 低额度提醒改为严格 crossing，并验证去重和重置。

### P2 / Experiment

1. 用 7 天 diary 判断 Small Quota 是否因与 Resident 重复而应删除。
2. 验证用户是否真的需要 Daily Brief，而不是只需要固定 Gmail 审查入口。
3. Needs You 只有在存在可靠实时事件源后再进入设计。

## 5. 发布 Gate

- Gate A：用户能在 3 秒内正确说出剩余额度、重置时间和所属窗口。
- Gate B：顶部 Alert 不可见时 100% 进入通知 fallback，且没有重复提醒。
- Gate C：Widget 在全新用户账户的 Widget Gallery 可找到、添加、刷新和 deep link。
- Gate D：stale、offline、demo、live 四种状态不会互相伪装。
- Gate E：所有用户可见表面均通过浅/深色、内建/外接屏、全屏、键盘与 VoiceOver 实测。

任何 Gate 未通过，都只能称为 Technical Preview。
