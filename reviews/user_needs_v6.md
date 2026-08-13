# WorkPulse V6.1 Truth / 需求 Delta Review

> 角色：用户研究与产品真实性终检  
> 日期：2026-08-11  
> 审查范围：[PRD_V4](../PRD_V4.md)、[CAPABILITY_AUDIT](../CAPABILITY_AUDIT.md)、最新 Native / Widget / Web copy、Manual / Verified truth model、[Native QA](../native-qa.md)  
> 审查方式：只读实现；本文件更新 V6 判断，不修改产品代码  
> 目标：确认 V6 七项 truth delta，并只保留仍阻断完整 10 天 Pilot 的最小集合。

## 0. 更新后的结论

**V6 指出的七类设计问题已经基本修复。Truth Gate 的静态设计前置条件现可判为 Pass；完整 10 天 field Pilot 仍为 No-Go，原因已收敛为运行时能力、分发载体和研究测量基础设施。**

需要明确区分两个产品状态：

| 状态 | 当前判断 | 可以做 | 不能声称 |
|---|---|---|---|
| 本机 developer MVP | **Go** | 本机运行 SwiftUI shell、Manual Pin、Privacy、模拟未来状态、用户主动读取 Codex quota、开发者受控演示 | 可分发 Pilot app、已安装 Widget、实时 Needs You、精确返回、Scheduled Health |
| 研究者在场的 formative lab | **Conditional Go** | 用 developer MVP 测 Manual / quota / truth copy 理解；研究者手工记录 | 10 天自然使用效果、通知负担、critical recall、exact-return rate |
| 完整 10 天 P0 Pilot | **No-Go** | 尚不可开始 | Needs You、exact return、Widget / Notification 的真实性和价值 Gate |
| Gmail / Scheduled Verified | **No-Go，但不阻塞 Codex P0** | Day 10 只测 Manual card 与理解 | last / next / paused / permission / latest result fidelity |

## 1. V6 七项 Delta 验证

### 1.1 Manual domain invariant：Pass

最新 `PinnedRoutine` 已将字段改为 `private(set)`，并按 capability 归一化：

- `manualPin` 强制 `state = manual`。
- 自动清空 `lastRunAt / nextRunAt`。
- 自动将 `attentionCount` 归零。
- 自动将 `fieldSupport` 归零。
- `WorkPulseCoreVerify` 已加入非法 Manual 输入测试，确认 completed、99 attention 和 run times 会被清除。

这意味着 Manual truth 不再只依赖 UI 调用方自律。虽然 discriminated union 仍是更强的长期方案，当前 initializer invariant 已足以满足单例程 P0 的静态 Truth Gate。

### 1.2 Widget schema v2 provenance / freshness：Pass with runtime gate

`WidgetSnapshot` v2 已加入：

- `routineCapability`。
- `routineSourceLabel`。
- `routineObservedAt`。
- `routineFreshness`。
- `DataFreshness.notLoaded / sourceConflict`。

Widget 对 stale routine 不再展示可信 Needs You 或 next run；Manual 显示“手动固定 · 未同步状态”。Quota Widget 也明确写“根据来源用量换算”和“来源显示重置”。

静态 schema 与 copy 可判 Pass。尚未通过的是 runtime gate：Widget 仍未成为已安装 Xcode Extension，App Group snapshot 尚未完成真机端到端测试。

### 1.3 模拟数据禁止外发：Pass

Host 写 external snapshot 时：

- routine 永远使用 `manualRoutine`，不写 `verifiedDemoRoutine`。
- quota 只有 `quotaConnectionState == live` 才写出。
- Widget 与 Notification contract 继续保持 generic。

Native 与 Web 也将“已验证连接”改为“交互演示 / 模拟数据 / 未连接真实来源”。这已满足 fixture 与 external surface 的隔离原则。

Pilot build 仍建议默认隐藏或编译关闭 `verifiedDemoEnabled`，避免参与者把模拟事件计入 diary；这属于研究数据洁净度要求，不再是 domain truth blocker。

### 1.4 Quota failure / multi-bucket：Pass with one external-detail caveat

最新实现已修复：

- 读取失败时清空旧百分比、bucket 与 selected ID，UI 显示“额度不可用”。
- 成功时保存并展示全部 buckets。
- 单值摘要明确显示 `当前显示 {limitID}`。
- remaining 标为“根据来源用量换算”。
- 读取成功文案带时间。
- fixture 与 live quota 分开。

该设计可支持本机 quota Technical Preview。

一个非阻断但应在 Widget Pilot 前补齐的细节：`QuotaSnapshot` 本身仍没有 `limitID`；Host 主窗口知道 selected bucket，写入 Widget 后只剩 source、window 和数值。如果未来 fallback 到非 `codex` bucket，Widget 无法显示 bucket 身份。进入 Widget field Pilot 前应把 selected bucket ID 放入 snapshot，或只在可证明是 `codex` bucket 时发布该 Widget 值。

### 1.5 Web 误导 copy：Pass with two stale echoes

已修复：

- Routine caption 不再承诺返回同一对话。
- open toast 改为“已收到导航请求；不计为精确返回”。
- Scheduled card 标为 `Design concept` 和“模拟排程”。
- quota 不再写未经验证的“健康”。
- 通知按钮改为“打开 WorkPulse”。
- Verified 模式改为“未来连接状态的交互演示”。

仍有两处应清理，但不阻断 developer MVP：

1. Menu popover 仍写“打开后回到准确的审批上下文”，而该 Web Demo 不能证明 external exact return。建议改成“打开 WorkPulse 查看返回路径”。
2. PRD 7.3 的 Notch Alert 示例仍统一写“打开审批”，与 5/7.2 已修好的 event-specific CTA 有一个旧回声。应统一为由事件类型生成。

### 1.6 事件类型 CTA：Pass

PRD 表面矩阵与 Needs You flow 已明确：approval、input、failure、quota block 使用不同 CTA，不再全部叫“打开审批”。打开失败仍需 1 秒内 fallback，且不自动 acknowledged / resolved。

当前仅有 PRD 7.3 的示例句需要同步，不影响核心合同判定。

### 1.7 10 天 Pilot 日程：Pass

PRD 已统一为 Day 1–10：

- Day 1 基线与隐私。
- Day 2–3 source truth、断连、stale、conflict。
- Day 4 Needs You。
- Day 5 exact return。
- Day 6 Manual。
- Day 7 Privacy。
- Day 8 quota。
- Day 9 fatigue。
- Day 10 conditional Scheduled / exit。

不存在 Day 0–10 的 11 个编号冲突。Scheduled adapter 不可信时，Day 10 只测 Manual card 的规则也保持正确。

## 2. 本机 Developer MVP 的准确边界

### 2.1 当前已经成立

- SwiftPM build 与本地 deterministic verification 通过，QA 当前记录 54 checks。
- App Server `initialize + rateLimits` 本机只读 probe 通过，返回两个 bucket 且值被脱敏记录。
- 本地开发 ZIP 经 ad-hoc strict signature 验证，可作为本机开发归档。
- Manual Pin 默认不制造自动状态。
- Privacy title / icon 与 generic external snapshot 已有验证。
- URL 缺失时 CTA 禁用；有效 URL 只承诺发送打开请求。
- 模拟 Verified 与真实 external snapshot 已隔离。
- Widget source 可 type-check。

### 2.2 Developer MVP 仍不是 Pilot build

- ad-hoc signature 没有 TeamIdentifier、Developer ID 或 notarization。
- 没有完整 Xcode host + Widget Extension target。
- App Group 只存在代码路径，没有安装后的 container / timeline E2E。
- Notification 尚没有真实 payload、permission、Focus、action callback 测试。
- `workpulse://` handler 仍是占位反馈，不是真实 scene navigation。
- Needs You 尚无真实 source pipeline。
- external exact return 尚未验证。

因此对外文案只能是“本机 developer MVP / Technical Preview”，不能写“Pilot-ready native app”。

## 3. 阻断完整 Pilot 的最小集合

以下五组是当前真正的硬阻塞。其他视觉优化、Overlay 与 Scheduled adapter 都不应混入这份最小集合。

### Blocker 1：Gate A / B / C 的真实结果

必须证明：

- Gate A：独立 WorkPulse source 能看到目标 Codex Desktop / CLI thread 的 critical transitions，且 approval ownership 可解释。
- Gate B：`verifiedExact` 有 target-specific confirmation；错误 target 为 0，不能用 `NSWorkspace.open` accepted 代替。
- Gate C：current + previous supported version fixtures、schema change、method missing、auth unsupported、reconnect degradation 均有确定行为。

Capability Audit 目前只证明 schema present 和 quota read，尚未证明上述三项。

### Blocker 2：真实 Needs You 事件闭环

必须存在可运行而非文档中的：

- `SourceAdapter` 与 capability evidence。
- Normalizer 与 source provenance。
- Event Store 与 monotonic state rule。
- Delivery ledger / single active owner / reconnect dedupe。
- `acknowledged` 与 `resolved` 分离。
- source disconnected、stale、notLoaded、sourceConflict 不产生 false active alert。

当前 `DeliveryPolicy` 只会计算一个 surface set，还没有 event ID、持久 owner、replay prevention 或 resolution state，因此不能测 critical recall 和 notification burden。

### Blocker 3：可分发的真实 macOS 表面

至少完成：

- 完整 Xcode app target 与 Widget Extension。
- App Group entitlement 与 1,000 次原子读写 / corrupt / future-schema E2E。
- Developer ID、Hardened Runtime、notarization 和干净机器安装。
- Notification authorization、denied、Focus、single owner、action callback。
- `workpulse://` 实际 scene navigation与 fallback。

如果这些尚未完成，可以做研究者在场的 native shell lab，但不能让 16 名用户自然使用 10 天后再把缺失表面解释成用户无需求。

### Blocker 4：Pilot telemetry 与独立 ground truth

必须将 V5 的设计变成可运行工具：

- 事件 envelope 与字段 allowlist exporter。
- 禁止自由文本、URL、标题、路径和 Gmail 内容的自动扫描。
- `source_event_observed`、`surface_presented`、`open_request_accepted`、`open_confirmed_exact`、`fallback_presented`、ack / resolved 等可计算事件。
- 独立 researcher ground-truth scenario sheet 和 join key。
- baseline manual polling 记录。
- 14 天删除、participant 提前删除与 schema-change pause rule。
- false high-risk alert / wrong target / privacy exposure 的自动 safety stop。

没有这些只能做定性 lab，不能声称 Truth / Value Gate 已量化通过。

### Blocker 5：Manual Pilot 任务可完成

PRD Day 6 要求建立、编辑、删除和理解测试。当前原生 UI 主要支持粘贴 URL，默认名称仍是硬编码，未看到完整的：

- 用户编辑例程名称。
- 移除本地入口。
- 清除 URL / 本地缓存。
- 删除确认文案“不会删除 ChatGPT 内容或 Scheduled task”。
- title opt-in 与 routine ID 绑定；当前是全局 UserDefaults。

若 P0 只允许一个 routine，全局开关可以作为 developer MVP 简化；进入 16 人 Pilot 前，至少要完成单例程的 add / edit / remove / privacy 流程，否则 Day 6 指标没有有效任务可测。

## 4. 不再阻断 Codex P0 的事项

以下项目可以继续后置，不应拖住最小 Pilot：

- Gmail / Scheduled adapter。Day 10 用 Manual truth test 即可，报告写 `Not tested`，不能写 Pass。
- Notch Overlay。Gate D 失败时使用 MenuBar + Widget + Notification。
- Daily Brief、Large / Extra Large Widget。
- 多 routine 管理。Pilot 可先限制为一个 routine，但文案和数据结构要诚实。
- 自定义主题与高级视觉 token。
- AI 生成摘要。

## 5. Pilot 启动判定

### 5.1 可立即开始：小规模 formative lab

建议 3–5 名参与者、研究者在场、60–90 分钟，只测试：

- Manual 与 Verified simulation 是否能区分。
- “发送打开请求”是否被理解为未确认。
- quota 多 bucket、Derived、freshness、unavailable copy。
- Privacy generic title。
- Web / Native surface preference。

该 lab 不计算 critical recall、polling reduction、notification fatigue、exact return 或 10 天留存。

### 5.2 完整 10 天 Pilot 启动条件

只有第 3 节五个 Blocker 全部关闭后开始。启动包应包含：

- 一个可 notarized 安装的 Pilot build。
- capability manifest，明确 live / manual / unsupported。
- Gate A / B / C 报告。
- telemetry schema 与隐私扫描结果。
- ground-truth task book。
- safety stop 与 feature flag 控制。
- Day 1–10 researcher script。

## 6. 仍需清理的最小文案清单

| 位置 | 当前风险 | 建议 |
|---|---|---|
| Web Menu popover | `打开后回到准确的审批上下文` 暗示 exact return 已成立 | `打开 WorkPulse 查看对应事件与安全返回路径` |
| PRD 7.3 Alert 示例 | 仍统一写 `打开审批` | `显示事件特定主操作` |
| Native simulation VoiceOver | status label 只读“需要处理 3 项”，可能漏掉模拟性质 | `模拟状态，需要处理 3 项` |
| Widget quota fallback | 若 selected bucket 不是 `codex`，snapshot 没有 bucket ID | 写入 bucket ID，或不向 Widget 发布 fallback bucket |
| Developer MVP 标题 | `原生 MVP` 可能被理解为已可分发 | 在 About / 数据来源增加 `本机开发版 · 非 Pilot build` |

## 7. V6.1 最终判断

V6.1 后，Manual / Verified、Widget provenance、fixture isolation、quota failure / multi-bucket、Web copy、event CTA 与 10 天日程不再是完整 Pilot 的主要阻塞。产品的静态 truth model 已达到可以继续实现的水平。

当前最诚实的状态是：

- **Developer MVP：Go。** 可在本机用于开发、演示与小规模研究者在场的理解测试。
- **Full 10-day Pilot：No-Go。** 仍需关闭 Gate A/B/C、真实 Needs You 闭环、可分发 macOS 表面、telemetry / ground truth 和 Manual add/edit/remove 五组最小阻塞。
- **Scheduled Verified：Unsupported，但不阻塞 Codex P0。**

下一轮不应再扩展功能或继续堆 copy。应把工程与研究资源集中在这五个 Blocker，并在全部关闭后重新运行一次 Truth Gate 决策。
