# WorkPulse V8 技术终审

> 终审时间：2026-08-11 15:00 后，Europe/Oslo  
> 最终源码冻结：15:05 后单实例 `Window` 修复快照  
> 审查范围：`native/WorkPulseNative`、`workpulse_mac_desktop_demo.html`、`scripts/verify_html_demo.mjs`、最终 ZIP  
> 审查原则：通过的工程 primitive 与尚未成立的真实产品能力分开判断；本轮未修改产品源码

## 0. 最终结论

当前产物可以准确称为：

> **WorkPulse MenuBar Local Developer Technical Preview**，或“MenuBar-only 本地开发 MVP slice”。

它已经不是纯视觉稿：Swift 原生菜单栏应用可以编译；本机可只读获取 Codex rate limits；严格的 WorkPulse-owned deep link、可恢复的本地事件 ledger、Widget generic snapshot contract、外部提醒 payload contract 与一组经过验证的事件不变量已经存在。

它仍然不能称为：

- 完整 **WorkPulse local MVP**：没有可安装 Widget `.appex`、App Group entitlement、真实通知、真实 Needs You source adapter 或可用刘海 overlay。
- **Pilot build**：最终 ZIP 是 ad-hoc 签名、无 Team Identifier、无 Developer ID、Hardened Runtime / notarization 证据，也没有完整 Xcode host + extension 工程。
- production-ready ChatGPT / Codex companion：Gate A、B、C 均未通过，OpenAI 官方仍将 app-server command 与 WebSocket transport标为 experimental、unsupported for production workloads。

因此发布判断为：

| 使用范围 | 结论 |
|---|---|
| 开发者本人本机试用 MenuBar、手动入口、quota Technical Preview、fixture Needs You | **GO with explicit constraints** |
| 宣称“原生 Widget 已完成” | **NO-GO** |
| 宣称“实时观察 ChatGPT / Codex Desktop 任务” | **NO-GO** |
| 给外部用户分发 Pilot | **NO-GO** |
| production / 商业化 | **NO-GO** |

## 1. 最终独立复跑证据

终审使用新的 SwiftPM scratch directory，不复用预审二进制。

| 检查 | 最终结果 | 证据边界 |
|---|---|---|
| SwiftPM 全量 build | **Pass** | `WorkPulseCore`、`WorkPulseMenuBar`、`WorkPulseWidgetCompile`、`WorkPulseCoreVerify`、`WorkPulseAppServerProbe` 均编译链接 |
| CoreVerify | **Pass，189 checks** | 自定义 executable smoke/contract harness，不是 XCTest |
| Widget 独立 typecheck | **Pass** | 证明源码与当前 SDK 类型兼容，不产生 `.appex` |
| Web gate | **Pass，18 checks** | 静态源码断言与内联 JS syntax gate，不是浏览器视觉/交互 E2E |
| `Info.plist` lint | **Pass** | URL scheme 等 plist 语法有效 |
| 真实 App Server probe | **Pass** | 当前机器 `initialize` + `account/rateLimits/read` 返回 2 buckets，数值未输出 |
| 最终 ZIP 独立解包 | **Pass** | 未从 convenience `.app` 复用签名结论 |
| `codesign --verify --deep --strict` | **Pass** | 仅说明 bundle 内部 ad-hoc signature 自洽 |
| Cold `workpulse://inbox` | **Partial pass** | 进程启动并保持 1 个 layer-0 WorkPulse 主窗口 |
| Warm `workpulse://usage` | **Partial pass** | 同一进程仍为 1 个主窗口，旧版重复窗口问题已关闭 |

最终 artifact：

```text
native/WorkPulseNative/build/WorkPulse-local-dev.zip
mtime: 2026-08-11 15:05:15 CEST
SHA-256: 15fdcfbdc73c82d18d8ad1cd1ab2f8eab34a7f4f17b42e0831736d6a6ce8324c
architecture: arm64 thin
Signature: adhoc
TeamIdentifier: not set
embedded entitlements: none
Widget .appex: none
```

终审环境：macOS 26.5.1、arm64、Swift 6.3.2、Codex CLI `0.147.0-alpha.6.5`。机器只有 Command Line Tools；`xcodebuild` 明确不可用，因此本轮不能进行 Xcode archive、Widget Extension、entitlement、gallery、Developer ID 或 notarization 验证。

## 2. 功能可行性矩阵

| 能力 | 分类 | 当前实现与边界 |
|---|---|---|
| SwiftUI `MenuBarExtra` + 单实例主窗口 | **Supported** | 源码和最终 bundle 可运行；项目最低 macOS 14，高于 `MenuBarExtra` 的平台起点 |
| WorkPulse-owned strict URL parser | **Supported** | 只接受 inbox、usage、已规范 UUID 的 routine/event；拒绝 query、fragment、额外 path 与未知目标 |
| WorkPulse-owned cold/warm 单窗口 | **Supported with constraint** | 最终包实测 cold/warm 均保持 1 个主窗口；测试宿主 frontmost 为 `loginwindow`，focus 与 route UI state 未能外部认证 |
| 用户保存的 HTTPS 固定入口 | **Supported with constraint** | 验证本机 routine UUID 后交给 `NSWorkspace`；系统接受打开请求不等于到达正确对话 |
| Event normalization / dedupe / local ledger primitives | **Supported with constraint** | 189 checks 覆盖关键不变量；尚无真实 source adapter，不得展示为 live ChatGPT event |
| EventLedger JSON atomic persistence | **Supported with constraint** | schema + monotonic revision + fail-closed equal/older writes；适合当前单宿主低规模，不是 tamper-evident forensic ledger |
| Generic Widget snapshot contract | **Supported with constraint** | schema v3、atomic write、durable revision、typed quota provenance、generic privacy；最终 app 没有 App Group entitlement |
| Small / Medium / Large Widget Swift source | **Prototype-only** | SwiftPM compile/link 和 typecheck 通过；产物是 executable，不是 Xcode Widget Extension 或 `.appex` |
| Codex rate-limit one-shot reader | **Prototype-only** | 当前机器真实读取成功；依赖 experimental app-server 和当前 schema/version/auth 环境 |
| Needs You fixture Inbox | **Prototype-only** | 可测试本地交互、持久化和提醒不变量；明确是 fixture，不产生真实通知或 Widget count |
| Generic overlay / notification payload contract | **Prototype-only** | 只产生“查看提醒 / 打开 WorkPulse”的 generic DTO；没有接 Apple notification 或 `NSPanel` |
| 真实 Codex / ChatGPT Needs You discovery | **Unsupported in current artifact** | 没有 source adapter；Gate A 未执行 |
| 任意 ChatGPT / Codex Desktop exact thread deep link | **Unsupported as promise** | 没有官方稳定的通用 deep-link contract；Gate B 未通过 |
| ChatGPT Projects / Scheduled / Gmail 自动状态 | **Unsupported in current artifact** | 当前公开 App Server contract 没有这些云端产品对象的 companion observe/manage API；只能 manual pin |
| macOS local notification | **Not implemented** | 没有 `UNUserNotificationCenter`、delegate、authorization、schedule/cancel 或 action callback integration |
| 刘海“灵动岛” overlay | **Not implemented** | 没有 `NSPanel` / `NSWindow` overlay、多显示器或全屏逻辑；macOS 没有可直接调用的 Dynamic Island API |
| Developer ID / notarized Pilot | **Not built** | ad-hoc signature 不能替代 Developer ID、Hardened Runtime 与 notarization |

## 3. EventObservation、monotonic state 与 dedupe 复核

### 3.1 已关闭的关键 blocker

最终实现和 189 checks 已确认：

1. **Transition dedupe**：同 source identity + transition digest 的精确重放返回 duplicate，不重复插入或主动提醒。
2. **Out-of-order fail-closed**：较旧 `observedAt` transition 返回 out-of-order，不回退 freshness。
3. **Caller eventID collision**：相同 UUID 指向不同 source identity 时返回 identity collision，不覆盖原记录。
4. **Resolution-cycle identity**：source object、resolution cycle、schema revision 均参与规范化 identity，允许同一对象的新 action-needed cycle 形成新事件。
5. **Fixture isolation**：fixture、initial reconcile、stale/offline/sourceConflict 不能获得主动 delivery owner。
6. **Single active owner**：仅 overlay / notification 可 claim；MenuBar / Widget 为 passive surface；transfer、release、reclaim 和 owner revoke 有审计记录。
7. **Seen 与 acknowledgement 分离**：打开详情只产生 local seen，不声称 source acknowledgement；explicit acknowledgement 另行记录。
8. **Snooze expiry**：snooze 保持 source lifecycle active；到期可重新 claim；claim 不提前消费 snooze；调度失败可 transfer/release/reclaim；只有成功 `markPresented` 才消费过期 snooze。
9. **Callback idempotency**：相同 callback payload 重试返回首次结果且不重复 side effect；相同 callback UUID 的不同 payload 返回 identity collision。
10. **Terminal monotonicity**：resolved / invalidated replay 不会重新激活。
11. **Capability registry**：empty-default deny；grant 绑定 adapter、scope、event type、expiry；registry revision 必须递增；replace/revoke/renew/expiry reconcile 会清除不再授权的 active owner并审计。
12. **Durability**：callback receipts、audit、registry 与 ledger 可序列化；宿主恢复期间关闭事件动作；宿主 revision 与 store 比较阻止旧快照或同 revision 不同内容覆盖新状态。

定向 edge probe 在最终源码上再次得到：

```text
eventID cross-source collision: identityCollision, record count remains 1
menuBar active-owner claim: false
expired snooze visible: true
expired snooze active-delivery eligible: true
out-of-order freshness remains: fresh
callback payload collision: identityCollision
conflicting callback side effect: not applied
```

### 3.2 仍然只是 primitive 的部分

- 没有真实 adapter 生成 `EventObservation`，production registry 也没有任何经 Gate A 写入的真实 grant。
- 没有 Apple notification delegate 将 `UNNotificationResponse` 规范化为稳定 callback ID；当前 idempotency 只证明 reducer contract。
- 没有 source-confirmed resolve/retract pipeline；fixture UI 的“已处理”只改变本地 disposition，文案已正确说明不改变原任务。
- JSON audit 是 typed local evidence，不具备签名、hash chain 或防本机篡改保证，不能称合规审计日志。
- 当前是单 app-host JSON store，不是 SQLite multi-writer repository；Pilot 仍需 crash injection、磁盘满、权限错误、截断恢复和 retention/compaction 策略。

因此真实 Needs You 仍受 Gate A、B、C 约束，不能因 reducer 完整而提前开放。

## 4. Callback 与 delivery ledger 边界

当前 callback contract 的正确语义是：

- `openRequested` 只记录“请求打开”，不自动 seen、acknowledged 或 resolved。
- `seen` 是本地 UI evidence，不冒充 source acknowledgement。
- `acknowledged`、`snoozed`、`userHandled` 为不同 typed callback。
- 重复 callback 返回第一次 outcome；payload collision fail-closed。
- 失败调度可释放 owner，避免 expired snooze generation 被永久卡住。

尚缺的端到端链路：

```text
UNNotificationRequest / NSPanel presentation
  -> platform identifier
  -> stable EventCallback envelope
  -> persisted receipt
  -> UI/state mutation
  -> cancel/resolve race reconciliation
```

Apple 的 action callback 需要在 app launch 完成前配置 `UNUserNotificationCenterDelegate`。当前源码完全没有该 integration，所以不得把 callback reducer test 计为 Gate N pass。[UNUserNotificationCenterDelegate](https://developer.apple.com/documentation/usernotifications/unusernotificationcenterdelegate)

## 5. Deep-link cold / warm 复核

### 已确认

- `Info.plist` 注册 `workpulse` scheme。
- parser 严格拒绝 malformed、额外 path、query、fragment 与未知 UUID。
- unknown routine/event fail-closed，不执行外部动作。
- 最终主 scene 从多实例 `WindowGroup` 改为单实例 `Window`。
- 对最终签名 ZIP 的实际复测：cold inbox 创建 1 个 760×520 `WorkPulse` 主窗口；warm usage 后仍为 1 个，未再出现重复窗口。

### 仍未确认

- 测试宿主的 `NSWorkspace.frontmostApplication` 始终为 `com.apple.loginwindow`，因此无法用本轮环境证明窗口获得真实用户焦点。
- 没有可观察 route state 的 native UI test hook，不能从窗口计数证明 inbox / usage 页面内容准确切换。
- routine HTTPS 只证明 `NSWorkspace` 接受请求；没有 target-specific arrival confirmation。
- custom URL scheme 可被其他 app 注册，Apple 明确说明多 app 声明同一 scheme 时目标未定义；Pilot 应评估 universal links 或至少保留严格 action allowlist。[Defining a custom URL scheme](https://developer.apple.com/documentation/xcode/defining-a-custom-url-scheme-for-your-app)

所以重复窗口 blocker 已关闭，但 PRD Gate B 要求的 30/30 exact-context、0 wrong target、p95 和 fallback 测试并未执行，Gate B 仍为 **Not passed**。

## 6. Widget / App Group 复核

源码层已确认：

- `WidgetSnapshot` schema v3，包含 durable revision、generic privacy、manual routine capability、typed quota provenance 与独立 optional `NeedsYouSummary`。
- manual routine 自动清除伪 last/next/attention 字段。
- 只有 `.liveCodexAppServer` quota 可发布；demo、deterministic fixture、unavailable 均被拒绝。
- 当前 Host 明确传 `needsYou: nil`，不会把 fixture count 伪装成“0 条实时提醒”。
- Host 复用单一 `SnapshotStore` actor，并以严格 Task chain 保持 UI 因果写序；`writeNext` 从 durable revision 递增，不依赖 wall-clock 判断新旧。
- 写入使用 atomic replacement；成功后调用 `WidgetCenter.shared.reloadAllTimelines()`。
- Widget 对 missing、corrupt、unsupported schema 与 stale 内容有不同降级展示。
- Small 使用单一 `widgetURL`；Medium / Large 使用 `Link`，符合 Apple 对 Widget family interaction 的规则。[Creating a widget extension](https://developer.apple.com/documentation/widgetkit/creating-a-widget-extension)

但最终包没有 `.appex`、App Group entitlement 或 TeamIdentifier，`containerURL(forSecurityApplicationGroupIdentifier:)` 在该 local-dev bundle 中不能建立真实 Host–Widget 通路。Apple 要求相关 target 具备同一开发团队与 App Groups entitlement；当前源码 scaffold 不满足安装条件。[Configuring App Groups](https://developer.apple.com/documentation/xcode/configuring-app-groups)

另外，`reloadAllTimelines()` 是刷新请求，不是即时刷新 SLA。Widget extension 不持续运行，刷新受系统 budget 与 timeline 决策控制；Apple 给出的常见 budget 约为每日 40–70 次，timeline entries 通常至少约 5 分钟间隔。因此 Needs You 的实时交付不能依赖 Widget。[Keeping a widget up to date](https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date)

Gate W 仍需完整 Xcode host + extension、真实 App Group、gallery、kill/reload、1,000 次并发读写、macOS 14/15/26 真机矩阵后才可通过。

## 7. Codex App Server 复核

### 当前实测成立

- 最终 reader 使用官方默认族的 `--listen stdio://` JSONL transport。
- 发送 `initialize`，再发送 `initialized`，然后只读 `account/rateLimits/read`。
- 当前 Codex `0.147.0-alpha.6.5` 生成 schema允许 `initialized` 仅含 method；源码同时显式发送空 params。
- 支持 `rateLimitsByLimitId` multi-bucket 与 backward-compatible `rateLimits` single view。
- 8 秒 timeout；stderr 被 drain 且不持久化；probe 输出只报告 bucket count，不输出额度值。
- 当前本机真实 probe 返回 2 buckets。

这些事实与官方 App Server 文档公开的 stdio JSONL、initialize lifecycle、rate-limit schema 一致。[Codex App Server](https://learn.chatgpt.com/docs/app-server)

### 未达到 production / Gate C

- reader 是 one-shot subprocess，不是长驻 session supervisor。
- 没有 subscription、pending request table、server-request response、reconnect/reconcile、auth change、sleep/wake 或 multi-account lifecycle。
- `RPCEnvelopeClassifier`、`JSONLFramer`、session transition 与 reconnect policy 是经过测试的局部 primitive，但没有组合成运行中的 adapter。
- 没有 current + previous supported Codex schema matrix、schema hash registry、24 小时 soak、20 次重启、child crash、stdout/stderr burst、zombie/memory test。
- 没有证明独立 WorkPulse app-server 可以观察 ChatGPT / Codex Desktop 另一个 runtime 的 live threads。
- 依赖当前用户 Codex authentication/state；这次 probe 成功不能外推到未登录、企业策略、多账号或 App Sandbox。

OpenAI 当前文档明确说明 app-server command 与 WebSocket transport仍为 experimental、unsupported for production workloads。即使 Gate A–C 后续通过，相关能力仍应标 **Technical Preview**，直到 OpenAI 提供 production-supported contract 或产品迁移到其他官方接口。[Codex App Server](https://learn.chatgpt.com/docs/app-server)

## 8. Apple API 与分发边界

| Surface | Apple framework / requirement | 当前状态 |
|---|---|---|
| Menu Bar | SwiftUI `MenuBarExtra` | 已实现；Apple 将其定义为系统菜单栏中的 persistent control。[MenuBarExtra](https://developer.apple.com/documentation/swiftui/menubarextra) |
| Main window | SwiftUI single-instance `Window` | 已实现；cold/warm 窗口数实测稳定为 1 |
| Widget | WidgetKit + Xcode Widget Extension target | 只有 Swift source scaffold；无 `.appex` |
| Shared snapshot | App Groups entitlement + same-team signing | DTO/store 已实现；最终包无 entitlement/TeamIdentifier |
| Notification | UserNotifications authorization、request、delegate、actions | 未实现 |
| Notch overlay | 自定义 AppKit `NSPanel` / `NSWindow` | 未实现；不是 Apple Dynamic Island API。[NSPanel](https://developer.apple.com/documentation/appkit/nspanel) |
| Custom URL | `CFBundleURLTypes` + strict validation | 已实现 parser和 bundle registration；scheme collision 仍存在 |
| Direct distribution | Developer ID、Hardened Runtime、notarization | 未完成；当前仅 ad-hoc |

Apple 对直接分发的 notarization流程要求 Developer ID，并要求分发目标采用相应签名与 Hardened Runtime；ad-hoc `codesign --verify` 通过不满足该要求。[Notarizing macOS software before distribution](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)

因此用户本人从 Xcode / 本地 archive 试用不要求上架 Mac App Store；但把 ZIP 交给外部 Pilot 用户属于另一条分发门，必须先完成 Developer ID 与 notarization。

## 9. 最终 Gate A–D 与补充 Gate

| Gate | 最终状态 | 本轮证据 | 进入下一阶段前的通过条件 |
|---|---|---|---|
| **A：跨客户端可见性** | **Not passed / 未执行** | 无真实 event source adapter；只有 fixture event engine 和 rate-limit read | 对 Desktop / CLI / WorkPulse-owned 各 20 轮，关键 transition recall ≥95%、false positive=0、0 resume/write、0 history replay alert |
| **B：Context return** | **Not passed / partial spike** | strict parser + cold/warm 单窗口通过；focus、route UI state、exact external arrival 未认证 | PRD 30/30 verifiedExact、wrong target=0、p95≤3s、失败 fallback 不误 ack |
| **C：App Server lifecycle** | **Not passed / one-shot only** | 当前版本真实 initialize + rateLimits pass | current + previous schema fixtures、24h soak、故障注入、≤2s unknown、无 restart storm/zombie/leak |
| **D：Overlay compatibility** | **Not passed / 未实现** | 无 `NSPanel` overlay 代码 | 完成 notch/no-notch、多屏、Spaces、全屏、Stage Manager、Accessibility matrix；任何 Sev-1 默认关闭 |
| **W：Widget/App Group** | **Not passed** | source compile/typecheck 与 snapshot contract pass；无 Xcode target/appex/entitlement | Release host+extension、真实 App Group、gallery、kill/reload、并发与真机矩阵 |
| **N：Notification** | **Not passed** | callback reducer pass；无 Apple integration | permission 三态、identifier dedupe、action callback、snooze/resolve/cancel race、denied fallback |

最终 Gate 决策：

- A/B/C 任一未通过都不能进入完整 Needs You Pilot；当前三者均未通过。
- D 失败只意味着 no-overlay，不应阻止未来无刘海 Pilot；但当前根本没有 overlay artifact。
- W/N 未通过意味着当前也不能称完整的原生 multi-surface local MVP。

## 10. 下一阶段最小关闭清单

按阻塞价值排序：

1. 建真实只读 `SourceAdapter`，只输出 normalized `EventObservation`，执行 Gate A；Gate A 前 production registry 保持 empty-default。
2. 把 App Server primitive 组合成 versioned stdio supervisor，完成 auth、unknown、reconnect、initial reconcile、schema capability 与 24h Gate C。
3. 为 WorkPulse-owned route 增加可观察 native UI test state，完成 focus、cold/warm、unknown event、saved HTTPS 和 exact target Gate B。
4. 建完整 Xcode app + Widget Extension targets，配置相同 Team 与 App Group entitlement；完成 Gate W。
5. 接 `UNUserNotificationCenter`，在 launch 前设置 delegate；以 notification identifier 构造稳定 callback envelope并完成 Gate N。
6. 只在 A/B/C/W/N 通过后评估 `NSPanel` overlay；Overlay 继续 opt-in、feature flag、默认关闭，执行 Gate D。
7. 新增 XCTest / UI test / CI；当前 189-check executable 保留为快速 contract smoke，但不作为唯一发布门。
8. 用 Release configuration、Developer ID、Hardened Runtime、notarization 和外部干净机器安装测试生成真正 Pilot artifact。

## 11. 最终交付边界

最准确的一句话是：

> V8 已形成一个可编译、可本机读取 Codex quota、拥有严格本地事件状态机与可验证 local-dev archive 的 **MenuBar Technical Preview**；它证明了 WorkPulse 的核心安全 primitive 可实现，但没有证明 ChatGPT / Codex Desktop 的实时 Needs You 数据源、系统通知、可安装 Widget、刘海 overlay 或 production App Server，因此不是完整 local MVP，也不是 Pilot build。

### 官方参考

- OpenAI：[Codex App Server](https://learn.chatgpt.com/docs/app-server)
- Apple：[MenuBarExtra](https://developer.apple.com/documentation/swiftui/menubarextra)
- Apple：[Creating a widget extension](https://developer.apple.com/documentation/widgetkit/creating-a-widget-extension)
- Apple：[Keeping a widget up to date](https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date)
- Apple：[Configuring App Groups](https://developer.apple.com/documentation/xcode/configuring-app-groups)
- Apple：[Defining a custom URL scheme](https://developer.apple.com/documentation/xcode/defining-a-custom-url-scheme-for-your-app)
- Apple：[UNUserNotificationCenterDelegate](https://developer.apple.com/documentation/usernotifications/unusernotificationcenterdelegate)
- Apple：[NSPanel](https://developer.apple.com/documentation/appkit/nspanel)
- Apple：[Notarizing macOS software before distribution](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)

