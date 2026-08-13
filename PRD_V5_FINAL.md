# WorkPulse for macOS 产品需求文档 V6

> 日期：2026-08-13  
> 产品定位：macOS 上的 **AI 工作连续性层**  
> 当前可交付级别：build 23 已安装的无主窗口伴生应用 + 四种 Widget + Top Overlay + Notification  
> 发布判定：本机 dogfood **Go**；本机 1.0 待系统通知点击、Widget Gallery 与辅助功能三项人工 Gate；对外买断发布 **No-Go**

## 1. 产品结论

WorkPulse 不是 ChatGPT 的替代客户端，也不尝试绕过 ChatGPT 的权限或复用其私有会话。它解决四个高频问题：

1. 用户离开 ChatGPT / Codex 后，仍能知道是否有工作需要自己处理。
2. 用户可以从桌面长期保留一个固定对话或每日例程入口。
3. 用户可以查看有来源、窗口、reset 和 freshness 的 Codex quota。
4. 用户可以在 Widget、Menu Bar、Notch Overlay 与通知之间获得一致、克制且不重复的提醒。

本机运行不要求上架 App Store。开发者可以通过本地 Xcode 运行、ad-hoc 签名或 Developer ID 分发；只有公开商店分发才需要 App Store 流程。

## 2. 用户需求优先级

### Must

- 主动读取当前本机 Codex quota，并展示全部可见 limit bucket。
- 手动固定一个 ChatGPT HTTPS 对话入口，例如“每日 Gmail 审查”。
- Menu Bar 长期提供 quota、固定入口、连接状态、系统表面设置与 Needs You 入口，但不承载独立 Dashboard。
- Light / Dark 两种用户可选外观与 Privacy Mode。
- 所有外部表面默认 generic，不展示项目、线程、邮件标题或 Gmail 数量。
- source、freshness、observed time 与 capability 必须可解释。

### Should

- Small Quota Widget。
- Small Pinned Routine Widget。
- Medium 快速查看 Widget。
- Large 今日概览 Widget。
- Needs You 通过 Menu Bar 预览、顶部 Expanded 详情、稍后和“从本机列表移除”闭环，不创建独立页面。
- WorkPulse 自有 deep link 和安全 fallback。

### Later / Gated

- 真实 approval、needs input、work-loss risk、quota pause 事件。
- Scheduled 健康、Gmail 摘要和 exact return。

## 3. 形态、功能与交互矩阵

| 形态 | 生命周期 | P0 信息 | 主交互 | 当前状态 |
|---|---|---|---|---|
| Small Quota | 长期被动 | remaining、window、reset、source、freshness | 顶部显示 Usage | build 23 已签名注册；最终 Gallery/桌面/点击待当前产物复验 |
| Small Pinned | 长期被动 | generic routine title、Manual/Verified 边界 | 打开保存的 HTTPS 入口 | build 23 已签名注册；固定 URL 已验证，最终 Gallery 点击待当前产物复验 |
| Medium 快速查看 | 长期被动 | Quota、generic 运行任务计数、Pinned | 分区 deep link | build 23 已签名嵌入；多尺寸 GUI 矩阵待终验 |
| Large 今日概览 | 日次概览 | Quota、generic 任务计数、Pinned | 分项 deep link | build 23 已签名嵌入；不冒充 Daily Brief |
| Menu Bar | 长期常驻 | routine、quota、Needs You、设置 | 直接操作或唤起顶部层 | build 23 已安装运行 |
| Top Resident | 用户选择常驻 | quota-first + `●N` 任务指示 | 展开详情 | build 23 GUI/AX/hover/Esc 已验证 |
| Top Alert | 一次弹出 | 可信事件或低额度 | 点击进入顶部 Expanded | build 23 已实现；VoiceOver/Switch Control 实机待验 |
| Top Expanded | 用户主动展开 | 状态、来源、freshness、本地动作 | 刷新/打开/移除 | build 23 GUI/AX/hover/键盘已验证 |
| Notification | Top Overlay fallback | generic 事件、任务终态或低额度 | deep link 回流顶部层 | delivered 已验证；真实 click/open receipt 待解锁 |

原则：Widget 提供环境感知；Menu Bar 是可靠入口；Alert 只处理需要行动的事件；Notification 是 fallback，不能与 Overlay 同时重复投递。

## 4. Widget V5 规范

### 4.1 Small Quota

- 展示剩余百分比、额度窗口、来源显示的 reset、observed time 和 freshness。
- `workpulse://usage` 直接在顶部状态层展示 quota，不打开 Dashboard。
- 多 bucket 不合并为“今日总额度”。Widget 可展示一个已选择 bucket，主应用展示全部 bucket。
- 只有 typed provenance 为 `liveCodexAppServer` 的 quota 可以外发；demo、QA fixture、unavailable 一律不写 Widget。

### 4.2 Small Pinned Routine

- 展示 generic title“每日例程”和“手动入口 · 未同步运行状态”。
- 点击后校验本机 routine UUID；存在有效 HTTPS URL 时交给系统打开。
- “系统接受打开请求”不能写成“已返回正确对话”。

### 4.3 Medium 快速查看

- 只组合已支持的真实数据：quota、generic 运行任务计数与 Pinned routine。
- 运行任务只显示数量与 freshness，不输出任务名、prompt 或路径。
- 不将运行任务数写成 Needs You，`NeedsYouSummary` 未连接时不发布该模块。
- PINNED 展示 Manual/Verified routine 的真实能力边界。

### 4.4 Large 今日概览

- 汇总已支持的 quota、generic 运行任务计数与 Pinned routine，不冒充 Daily Brief。
- 默认不读取邮件正文、发件人或 Gmail 数量。
- Manual Gmail routine 只能称为固定入口，不能称为 Gmail 已同步或 Scheduled 正常运行。
- quota 快照过期时不再以当前值语气展示百分比或 reset，改为提示打开 WorkPulse 更新。
- 每个区域使用独立 deep link，不把整张卡片强制导向单一页面。

## 5. Notch 与通知交互

### 5.1 Resident

- 用户主动开启后常驻，只显示一项低密度状态。
- 多显示器时固定在带刘海的内建屏幕，不跟随鼠标或当前主屏；仅在合盖或内建屏幕不可用时降级到主显示器。
- 不显示未经授权的标题、路径或 prompt。
- 全屏、无刘海、外接显示器、clamshell 或 Overlay 不可达时自动降级，不影响 Menu Bar。

### 5.2 Alert

- 仅 `needsApproval`、`needsInput`、`workLossRiskFailure`、`quotaPaused` 可进入主动提醒候选。
- 必须同时满足：fresh、live verified transition、scope+event type+expiry grant、单一 active owner。
- 点击 Alert 进入顶部 Expanded；本地动作只允许“稍后 1 小时”与“从本机列表移除”，不声称 WorkPulse 已经批准、提交或重试。
- “稍后”只改变本地 disposition；到期后同一 event ID 可重新进入 Needs You。

### 5.3 Notification

- 仅在 Overlay 不可达且用户已授权通知时成为 active owner。
- title 固定为“WorkPulse 需要你的处理”。
- body 固定为“一个任务正在等待操作。打开 WorkPulse 查看。”
- deep link 只能指向规范化的本机 event UUID。
- 对已验证的实时 Codex quota，可按 10%/20%/30% 阈值提醒；每个 limit bucket 的 reset cycle 最多一次，用户可关闭。
- 任务终态通知标题只区分完成、取消、失败与中止，永远不包含任务名。
- 任务结果只在用户点击返回 WorkPulse 后从本机恢复；未授权显示时不持久化名称，Privacy Mode 会清除已缓存名称。

## 6. Needs You 状态合同

必须分离以下证据：

- Observed：来源事件被规范化并写入 ledger。
- Presented：唯一 active surface 实际呈现。
- Open requested：系统接受打开请求。
- Local seen：用户只在 WorkPulse 本地查看，不推进来源生命周期。
- Source acknowledged：来源适配器明确确认已接收或已处理；打开详情、稍后提醒都不能伪造此状态。
- Resolved：来源确认解决，或明确记录为 user disposition。

约束：

- terminal event 永不恢复为 active。
- fixture、initial reconcile、stale、offline、sourceConflict 不得主动投递。
- `eventID`、transition digest、active owner、callback ID 四层去重。
- 相同 callback UUID 但不同 payload 必须 fail closed。
- 旧 observedAt transition 不得回退当前 freshness。
- capability registry 使用 monotonic revision，可 replace、revoke、renew；撤销和到期会清除 active owner。
- expired snooze 只有在 `Presented` 成功后才消费；调度失败可 transfer、release 与 retry，不能因 claim 先行而丢失提醒。

## 7. 固定对话与每日 Gmail 审查

V5 推荐的第一阶段不是自动读取 Gmail，而是 Manual Pin：

1. 用户输入自定义名称与 ChatGPT HTTPS URL。
2. WorkPulse 仅保存本机入口，不读取该对话内容。
3. 桌面 Widget、Menu Bar 和 Daily Brief 均可提供 generic 入口。
4. 删除只删除 WorkPulse 本地记录，不删除 ChatGPT 内容或 Scheduled task。
5. 如果未来存在官方 verified adapter，再单独开启 last run、next run、attention 与 Gmail summary。

## 8. Privacy 与安全

- Widget 与 Notification 永远 generic。
- 应用内标题必须由用户逐项授权；Privacy Mode 立即覆盖该授权。
- ledger 不保存 raw source DTO、prompt、title、URL、path 或 Gmail 内容。
- source object、cycle 与 transition 使用本机 digest identity。
- telemetry 只允许 typed allowlist 字段，默认保留 14 天。
- 任一 privacy exposure、wrong target、false high-risk alert 或 incompatible schema 触发 Safety Stop。

## 9. 技术实现状态

### 已实现并验证

- 后台 `LSUIElement` 宿主、`MenuBarExtra`、Light/Dark、Privacy Mode；不存在 SwiftUI 主窗口、Dashboard 或 Settings scene。
- Manual Pinned Routine、HTTPS 校验与本机持久 UUID。
- Codex App Server 顺序 handshake、多个 rate-limit bucket、failure clear。
- WorkPulse deep-link router 直接路由到顶部状态层或固定 HTTPS 入口。
- Needs You Menu Bar preview + Top Expanded、本地 snooze 与 user handled。
- Event ledger transition/callback 幂等、capability lifecycle、原子持久化与 revision CAS。
- Widget snapshot v3、typed quota provenance、独立 Needs You summary、串行 publisher 与 durable revision。
- `WorkPulse.xcodeproj`、真实 Widget extension target、宿主 embed phase 与共享 App Group entitlement。
- Small Quota、Small Pinned、Medium 快速查看、Large 今日概览已嵌入团队签名 `.appex`；当前最终 build 23 的 Gallery、桌面与点击回流仍需重新取证，不能沿用旧 build 的画面。
- Resident/Alert/Expanded `NSPanel`、Alert hover pause、Expanded hover、键盘交互、VoiceOver/Switch Control 保护、Esc/点击外部关闭。
- macOS notification delegate、授权、generic event/task copy、deep link、低额度周期去重、delivered transport 与持久化 click receipt。
- Apple Development 团队签名 Host/Widget、共享 App Group schema 6、唯一 PlugInKit 注册、安装同源验证与故障注入自动回滚。
- build 23：260 项 CoreVerify，当前签名归档 SHA-256 `41fafea9e4e6c069b90a18a5190d29a81e5709b3342a7830fd2ffe38629635aa`；启动连续采样证明旧 live quota 会保持到新读取完成，不再出现空额度闪烁；generic task-terminal QA 通知已被真实 macOS Notification Center delivered。

### 尚未完成

- 解锁后从真实任务终态系统通知点击一次，核对 request/action/route/result/openedAt 回执和顶部层具体结果。
- 同一最终 build 23 的 VoiceOver、Switch Control 与 Full Keyboard Access 运行态 smoke；普通 AX、Tab、可见焦点、Resident/Expanded hover 与 Esc 已通过。
- 当前最终 build 23 的 Small Quota/Small Pinned Widget Gallery 搜索、添加、刷新与点击回流。
- Medium/Large Widget 在 Light/Dark、大字号和 Increase Contrast 下的完整矩阵；该两尺寸不列为首发核心闭环。
- Developer ID、Hardened Runtime、notarization、购买/恢复和发布更新链。
- Top Overlay 的 clamshell/全屏/Focus 完整 E2E 矩阵。
- 真实 Codex event adapter、cross-client ownership 与 exact return。
- Scheduled/Gmail 官方 adapter。

## 10. Release Gates

### Gate A：可观察性

- 每类真实事件至少 30 次触发、30 次 terminal、断连与 reconnect 覆盖。
- false high-risk event = 0。

### Gate B：返回与处置

- wrong target = 0。
- open requested、acknowledged、resolved 不混淆。
- callback retry 不重复副作用。

### Gate C：协议兼容

- 当前与上一版 App Server schema fixture 全部通过。
- JSONL framing、handshake、pending response、reconnect 与 capability renewal 有确定性测试。

### Gate D：Notch 真机

- 刘海/无刘海、内屏/外接屏、clamshell、Stage Manager、全屏矩阵通过。
- Overlay 失败能降级到 Notification 或 Menu Bar，且不重复投递。

### Gate W：Widget 真机

- `.appex` 嵌入、App Group entitlement 与 Gallery 安装通过。
- host-write/extension-read 连续 1,000 次无 corrupt/partial。
- 快速 live→unavailable、并发 publish、进程重启与时钟回拨不回退 durable state。
- Small/Medium/Large 在 Light/Dark、130% 字号、Increase Contrast 下无裁切。

## 11. V5 验收标准

- Manual Pin 不制造 last run、next run、邮件数或 Scheduled 状态。
- demo/fixture 状态在每个可见表面持续标记“模拟/非实时”。
- sourceConflict、stale、offline 不显示高强调外部动作。
- Needs You nil、fresh zero、stale、offline、conflict 文案可区分。
- 外部提醒 copy 不包含 thread、project、prompt、path、Gmail 或自定义 title。
- Widget 不消费 routine attention 作为 Needs You。
- 生产 capability registry 默认为空。
- 当前本机自动验证全部通过；Native visual/VoiceOver 必须使用同一最终 build 重新取证。

## 12. 发布建议

- **Go**：本机个人 dogfood，核心的 Manual Pin、Menu Bar、实时 quota、Small Quota/Small Pinned、顶部三态与任务数指示已可用。
- **Go with three manual Gates**：本机 1.0，完成 task-terminal 通知 click/open、当前 build 23 的 Small Quota/Small Pinned Gallery 闭环，以及 VoiceOver/Switch Control/Full Keyboard Access 实机验收。
- **No-Go**：对外一次买断发布，直到 Developer ID/notarization、购买恢复、更新和隐私支持链完成。
- **Gated**：真实 approval/needs-input、Scheduled/Gmail 自动状态与 exact return，在官方可信来源存在前不宣称支持。
