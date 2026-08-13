# WorkPulse V8 UI/UX 最终审查

> 源码冻结：2026-08-11 15:00:20 CEST；post-final copy delta：15:02:58 CEST；single-window delta：15:04:38 CEST；最终证据核对：15:06:11 CEST  
> Native artifact：`native/WorkPulseNative/build/WorkPulse-local-dev.zip`，post-final delta gate 生成于 15:05:15 CEST  
> SHA-256：`15fdcfbdc73c82d18d8ad1cd1ab2f8eab34a7f4f17b42e0831736d6a6ce8324c`  
> 审查范围：Menu Bar → Needs You Inbox → Detail → CTA、Small/Medium/Large Widget、Notification/Notch、浅色/深色、键盘与 VoiceOver。

## 1. 最终结论

### 分层判定

- **Native Shell 工程 dogfood：Go。** 最新源码可编译，核心语义通过 189 项确定性检查；Menu Bar、Inbox、Detail、本地 CTA、fixture、Privacy、quota 状态和事件持久化已形成可运行的工程闭环。
- **面向用户的 Native Shell UI/UX 内测：No-Go。** 当前没有与 15:04:38 post-final delta UI 源码对应的 Native 截图、键盘操作录像或 VoiceOver 证据，无法证明真实窗口中没有裁切、焦点、朗读或主题回归。
- **包含 Widget、Notification 或 Notch 的产品内测：No-Go。** Widget 仍是 SwiftPM 编译目标而非可安装 Xcode Extension；Native Notification 与 Notch 没有运行实现。Web 证据只证明交互概念与文案，不是 macOS 平台验收。

### 核心判断

15:05 post-final delta 快照中，未发现新的 source-level 状态真实性 P0。此前的主要问题已经关闭：

- fixture 与 live 已分离；Menu Bar、quota 与 VoiceOver 均明确标“模拟 / 非实时”；
- CTA 已从“处理审批 / 补充输入”改为“查看审批边界 / 查看输入边界 / 查看恢复说明”等本地说明；
- stale、offline、sourceConflict 只使用非高强调 bordered CTA；
- local seen、source acknowledgment、snooze、user disposition 与 source resolved 已分离；
- demo/fixture quota 和 fixture Needs You 不发布到 Widget；
- Large Brief 不再把 stale quota 当作当前值显示。
- Inbox 空态已按来源状态拆分：demo-empty 显示“暂无模拟事件”，真实来源不可用显示“Needs You 尚未连接”；不再把两者误写成 live-zero。
- 主场景已由 `WindowGroup` 收敛为单实例 `Window(id: "main")`，冷启动与 warm deep link 复用同一主窗口，不再产生重复 Dashboard 的 source-level false affordance。

## 2. P0

### P0-01：最新 Native Shell 缺少运行态 UI/UX 证据

`output/native` 四张截图生成于 12:35，早于 Needs You、持久化 ledger、事件 CTA、Small Pinned、Large Brief、键盘导航、最新 quota 状态、15:02:58 空态文案与 15:04:38 single-window 修订。它们只能证明旧版 Dashboard 的主题与 Privacy，不可作为 V8 验收。

当前无法验证：

- 390pt Menu Bar popover 加入最多 3 条 Needs You 后是否裁切 routine、quota、Privacy 或 Settings；
- 760 × 520 Dashboard 的 250pt Inbox + Detail 在中文长文案下是否溢出；
- stale、offline、sourceConflict、confirmation dialog、loading、empty 和 unknown event 的真实布局；
- 方向键是否在真实 focus chain 中工作；
- VoiceOver 是否按预期朗读、是否重复朗读图标和文案；
- 当前浅色与深色下的选中态、warning、disabled CTA 和 scrollbar 对比度。

关闭标准：

- **AC-V8-01**：使用 15:05:15 authoritative ZIP 或同 SHA build，补 Menu Bar 模拟 Needs You、Inbox + approval、input、stale、offline、sourceConflict、demo-empty、unavailable、loading、confirmation dialog 的浅/深色截图。
- **AC-V8-02**：补一段键盘 smoke evidence：打开 Inbox → 上/下选择 → Return 进入/触发本地说明 → Tab 到“稍后 1 小时” → Escape/返回；焦点环始终可见。
- **AC-V8-03**：补一段 VoiceOver smoke evidence：至少覆盖 unread、seenPending、stale、offline、sourceConflict、snoozed 和 userHandled；朗读中必须包含“模拟 / 非实时”和“来源未验证”。
- **AC-V8-04**：在 100% 与 130% 字号、Increase Contrast、Differentiate Without Color 下，无裁切、重叠或仅靠颜色表达状态。

### P0-02：Widget、Notification、Notch 尚无 Native 端到端实现证据

此项只阻断“包含这些表面”的内测，不阻断纯 Native Shell 工程 dogfood。

- Widget：Small Quota、Small Pinned、Medium Now & Next、Large Daily Brief 已编译并通过 type-check，但不是 Xcode Widget Extension target；App Group、Gallery、桌面渲染、点击 deep link 和时间线刷新未验证。
- Notification：有 `DeliveryPolicy`、single-owner ledger 与 fallback transfer 测试，但没有可审查的 `UNUserNotificationCenter` scheduling、category/action、permission denied、Focus 或点击回到 Event Detail 的 Native 实现。
- Notch：Native 设置明确为 disabled placeholder；只有 Web Design simulation，未验证有/无刘海、全屏、外接屏、多显示器或 reduced motion。

关闭标准：

- **AC-V8-05**：建立 signed Xcode host + Widget Extension + App Group，在真机 Widget Gallery 和桌面逐一验证四个 Widget；fixture/demo 数据不得进入 external snapshot。
- **AC-V8-06**：Native 通知对每个 event type 使用 generic、event-specific CTA；同一 `eventID` 只保留一个通知，点击打开同一 Detail，稍后不等于 resolved。
- **AC-V8-07**：Notification permission denied、App foreground、Focus、notification click、snooze callback 与 unknown/removed event 均有运行证据。
- **AC-V8-08**：如继续 Notch，分别验证 no-notch、built-in notch、外接屏、全屏和多显示器；否则从 Pilot scope 明确删除，而不是保留可操作开关。

## 3. P1

### P1-01：键盘实现只有方向选择，没有完整快捷路径

源码已有 `.onMoveCommand`，上下左右会改变 selected event；系统 Button 提供基本 Tab/Return。但尚未看到 `⌘⇧I` 打开 Inbox、明确的初始焦点、列表到 Detail 的焦点迁移、焦点恢复或 Menu Bar Escape 行为测试。

验收：新增全局“打开 Needs You Inbox”命令与快捷键；deep link、Menu Bar 和快捷键进入时都把焦点放在选中事件行，返回后恢复来源焦点。

### P1-02：VoiceOver contract 部分实现，但缺少状态变化 announcement

事件行、数量、routine 和 quota 已提供 accessibility label；fixture copy 也包含“模拟 / 非实时”。尚未看到 snooze、用户移除、source conflict 或存储失败后的 announcement，也没有 Settings icon、主题图标 Picker 和 Detail actions 的完整运行朗读证据。

验收：对 snooze、userHandled、恢复失败和 deep-link missing event 发布一次简短 announcement；避免同时朗读可视状态和重复图标名称。

### P1-03：Inbox 缺少相对时间与 severity 排序证据

事件行当前显示 type + freshness，但没有“2 分钟前”；ledger 默认按 `lastObservedAt` 排序，没有明确 severity-first 规则。高风险失败可能被更新更晚的低风险事件挤出 Menu Bar 前三条。

验收：列表行加入相对时间；排序固定为 actionable severity → freshness validity → lastObservedAt，sourceConflict/stale 不应抢占 fresh blocking event 的首位。

### P1-04：空闲 Menu Bar 没有独立 Needs You 安静态

Needs You 为空时该 section 完全消失，用户只能从 routine/quota 推断没有提醒。建议保留一行低密度“Needs You · 当前安静”，或在应用菜单中提供稳定 Inbox 入口，避免只有发生事件时才可发现功能。

### P1-05：Large Brief 的产品信息密度仍需真 Widget 调整

源码已经正确处理 stale quota、generic routine 和缺失 Needs You，但在真实 systemLarge 尺寸中，三行 Link、两行 detail、footer 与 Dynamic Type 可能过密。Gallery placeholder 也应明确是示例，不能让 `Widget Gallery` quota 被误认为实时值。

## 4. 逐项验收证据

| 项目 | 当前证据 | 结论 |
|---|---|---|
| Menu Bar → Inbox → Detail | SwiftUI source；deep link；fixture；EventLedger；189 checks | Source Pass，Runtime 未验证 |
| Event-specific CTA | `EventCTA` 全类型本地说明；Detail bordered action；本地反馈不承诺外部操作 | Pass |
| unread / seen / ack / resolved | `markSeen` 只改 local disposition 并清 owner；source `acknowledge` 独立；CoreVerify | Pass |
| Snooze / userHandled | 过期 snooze transfer/release/retry；确认 dialog；user disposition 与 source resolution 分离 | Pass |
| Empty / loading / stale / offline / conflict / missing | SwiftUI 状态分支与 deterministic fixtures；demo-empty“暂无模拟事件”与 unavailable“Needs You 尚未连接”已互斥 | Source Pass，Runtime 未验证 |
| Privacy | generic Widget snapshot；fixture 不外发；Web Privacy Alert；旧 Native Privacy 图 | Contract Pass，V8 Native 未验证 |
| Small Quota | Widget source compile/type-check；live provenance gate | Source Pass，真 Widget 未验证 |
| Small Pinned | Widget source compile/type-check；generic title + Manual copy | Source Pass，真 Widget 未验证 |
| Medium Now & Next | independent `NeedsYouSummary` freshness；manual routine fallback | Source Pass，真 Widget 未验证 |
| Large Daily Brief | stale quota fallback；generic rows；Web dark concept screenshot | Source Pass，真 Widget 未验证 |
| Notification fallback | `DeliveryPolicy`、single owner、fallback transfer；Web generic notification | Model Pass，Native 未实现 |
| Notch semantics | Web Alert “查看提醒”、Expanded “打开 WorkPulse”；Native toggle disabled | Web concept Pass，Native 未实现 |
| Light / Dark | 旧 Native 四图；V8 Web Manual Light、Brief Dark、Privacy Alert Dark | 视觉方向 Pass，当前 Native 未验证 |
| Keyboard | `.onMoveCommand` + SwiftUI buttons | Partial |
| VoiceOver | 多个 accessibility labels；无运行证据或 announcement | Partial |
| Build / deterministic QA | 15:05:15 post-final delta ZIP；SHA 匹配；189 checks；Widget compile；Web 18 checks；live 2-bucket probe | Pass |

## 5. 本轮截图审查

### 可作为 V8 设计模拟证据

- `output/audit-v8/01-desktop-manual-light.png`：Manual、通用标题、非实时 badge、中性 quota 点在浅色下清楚。
- `output/audit-v8/02-daily-brief-dark.png`：Large Brief 的分区与层级清楚，顶部持续显示 Design simulation；隐私关闭时可展示演示标题。
- `output/audit-v8/03-alert-privacy-dark.png`：Privacy 下 Alert 使用 generic title，CTA 为“查看提醒”；Medium Widget 也使用 generic copy。

### 不可作为 V8 Native 验收证据

- `output/native/native-*.jpeg`：时间早于 V8 实现，未包含 Needs You Inbox/Detail、新 Widget、最新 quota 状态、键盘或 VoiceOver。
- 所有 `output/audit-v8`：来自 Web desktop simulator，只验证概念、信息层级和文案，不验证 AppKit/SwiftUI、WidgetKit、Notification Center 或多显示器行为。

## 6. 无法验证项

1. 最新 Native Menu Bar、Inbox 与 Detail 的真实视觉结果；
2. VoiceOver、Keyboard Full Keyboard Access、130% 字号与 Increase Contrast；
3. 真 Widget Gallery、App Group snapshot、timeline reload 与 widget deep link；
4. Native notification permission、Focus、foreground/background、action callback；
5. Native Notch 在 no-notch/fullscreen/external display/multi-display 下的行为；
6. Developer ID、Hardened Runtime、notarization 与跨设备分发；
7. 真实 source event、exact return、source acknowledgment 与跨客户端 task visibility。

## 7. Go / No-Go 决策

| 目标 | 决策 | 条件 |
|---|---|---|
| 开发者在本机继续 dogfood Native Shell | **Go** | 明确 fixture/Technical Preview，不声称 Widget、Notification、Notch 已上线 |
| 小范围用户测试 Menu Bar + Inbox + Detail | **No-Go** | 先关闭 P0-01，补当前 Native GUI、Keyboard、VoiceOver 证据 |
| 用户测试 Small/Medium/Large Widget | **No-Go** | 先关闭 P0-02 的 Xcode Extension + App Group + 真机 Widget Gate |
| 用户测试 Notification / Notch | **No-Go** | 先完成 Native 实现与平台矩阵；Web simulation 不计通过 |
| 对外分发或 Pilot | **No-Go** | 另需 Developer ID、notarization、真实 source Gate A/B 与 Safety Stop 监控 |

最终建议：冻结当前源码作为 **Native Shell engineering baseline**。下一轮不要继续扩功能，优先补最新 Native 视觉、键盘、VoiceOver 与真 Widget/Notification 平台证据；这些证据通过后，再决定是否进入小范围用户内测。
