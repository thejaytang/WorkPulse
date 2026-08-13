# WorkPulse V8 视觉与交互审查

> 审查时间：2026-08-11 13:57–13:59 CEST  
> 当前证据：本轮重新载入的 Web Mac 桌面模拟器；Native Shell 因 macOS 锁屏无法取得本轮运行态截图或 VoiceOver tree。旧 `output/native` 不作为 V8 回归证据。

## 总体结论

Web 桌面模拟器的 Light / Dark、固定入口、Daily Brief 与 Notch Alert 视觉层级清楚，桌面空间感和 Graphite + Mint 语言一致。本轮已关闭 Notch Alert 的 false affordance：模拟提醒从“打开审批 / 前往审批”改为“查看提醒 / 打开 WorkPulse”，且交互反馈明确不会执行审批或声称精确返回。

Native Shell 的源码、编译和确定性契约已通过，但在取得当前版本截图、键盘路径和 VoiceOver tree 前，不能据 Web 截图宣称原生 UI/UX 已验收。

## 流程证据

### Step 1：Light Manual Pinned Routine

健康度：**Pass（Web visual）**

![Light Manual Pinned Routine](output/audit-v8/01-desktop-manual-light.png)

- 固定例程与 quota 的层级分开，Manual 状态明确写“未同步状态”。
- 主操作“打开固定入口”与手动入口职责一致。
- 大面积浅色桌面保留了足够对比，卡片没有裁切。
- 限制：无法从截图验证键盘焦点、130% 字号和 Reduce Transparency。

### Step 2：Dark Daily Brief

健康度：**Conditional Pass（simulation only）**

![Dark Daily Brief](output/audit-v8/02-daily-brief-dark.png)

- Daily Brief 把 Needs You、Completed、Scheduled concept 与 Quota 分区，适合 Large Widget 的扫读距离。
- 顶部常驻 “Design simulation · 非实时数据”，Scheduled 卡也明确 “DESIGN CONCEPT”。
- 风险：内容仍是演示 fixture，不能作为 Gmail、Scheduled 或真实 Daily Brief 已接入的证据。
- 原生 Widget 源码现在已有 Large Daily Brief，但仍不是已安装 `.appex`。

### Step 3：Dark Privacy Notch Alert

健康度：**Pass（truth copy）；No-Go（production delivery）**

![Dark Privacy Notch Alert](output/audit-v8/03-alert-privacy-dark.png)

- Privacy Mode 使用通用标题，不出现具体项目、线程或邮件名称。
- Primary CTA 为“查看提醒”，不会暗示模拟器能批准、拒绝或精确返回来源。
- Resident/Alert 与 Medium Widget 的同时出现能解释“常驻状态”和“一次提醒”的区别。
- 风险：Notch 仍是 Web 视觉设计；Native `NSPanel`、多显示器、全屏、clamshell 和通知 fallback 未实现。

## 最高优先级遗留

1. 解锁 Mac 后，使用最新归档取得 Native Menu Bar、Needs You Inbox/Detail、quota 两 bucket、unavailable、Light/Dark/Privacy 截图与 VoiceOver tree。
2. 在完整 Xcode 工程中把四个 Widget 变为真实 Extension，完成 App Group host-write / extension-read。
3. 对 Native Needs You 做键盘箭头导航、默认焦点、VoiceOver announcement 与 130% 字号验证。
4. Notch Alert 和 macOS Notification 只能在 Gate A–D 通过后启用；当前 production capability registry 必须保持为空。

