# WorkPulse 第四轮技术审查

> 角色：macOS / Apple 平台架构审查  
> 审查日期：2026-08-11  
> 审查对象：`PRD_V3.md`、`workpulse_mac_desktop_demo.html`、当前项目文件  
> 资料范围：截至审查日可访问的 Apple Developer 与 OpenAI 官方文档

## 1. 结论

`PRD_V3.md` 已经可以作为 **Phase 0 spike brief**，但当前目录还不能编译原生 MVP。项目中只有 PRD、HTML 原型与图片资产，没有 Xcode project、Swift target、entitlements、Widget Extension、测试 target 或签名配置。

技术上应把 WorkPulse 拆成两层：

1. **Stable native shell**：`MenuBarExtra`、主窗口、本地事件库、App Group 脱敏快照、Small / Medium Widget、本地通知、WorkPulse 自有 deep link、手动 Pinned URL。
2. **Experimental source layer**：Codex `app-server` quota、thread / turn / approval 事件、跨客户端观察与外部上下文返回。

只有 Gate A、B、C 同时通过，才能把 Experimental source layer 接入 Pilot。Gate D 只决定 `NSPanel` 刘海 overlay 是否启用，不应阻止无刘海版本。

当前最重要的产品技术修正有四项：

- HTML 中的“固定对话 · Scheduled · Gmail 状态”不能作为 P0 真数据。P0 只能稳定实现用户手动保存的名称与 URL。
- HTML Medium Widget 上的“实时”与 WidgetKit 的系统调度机制冲突，必须在原生实现中改为时间或 freshness。
- “打开当前线程”“返回原审批位置”只能对通过 Gate B 的 target 出现；其余只能打开 WorkPulse detail 或保存的 HTTPS URL。
- Codex `app-server` 命令本身仍是 **experimental**，即使 `experimentalApi=false` 也不等于 production-stable。

## 2. Supported / Prototype-only / Unsupported 矩阵

本表使用三种结论：

- **Supported**：Apple / OpenAI 官方公开能力足以实现；约束写在备注中。
- **Prototype-only**：有实现路径，但行为、兼容性或上游接口不够稳定，只能进入 spike / Pilot。
- **Unsupported**：当前没有公开支持路径，不能作为产品承诺。

| 能力 | 判定 | 原生实现与边界 |
|---|---|---|
| macOS 主应用与设置页 | Supported | SwiftUI `App`、`WindowGroup`、`Settings`，deployment target macOS 14 |
| Menu Bar 常驻入口 | Supported | `MenuBarExtra` + `.menuBarExtraStyle(.window)`；P0 保留主窗口，不做纯 menu-only app |
| Small / Medium / Large / Extra Large Widget | Supported | WidgetKit 支持 Mac 的四种 system family；P0 只编译 Small / Medium |
| Widget 配置与本地安全交互 | Supported | macOS 14 使用 `AppIntentConfiguration`、`AppIntentTimelineProvider`、`Button(intent:)`、`Link` |
| Widget 秒级刷新或持续运行 | Unsupported | Widget extension 非常驻，timeline 与 reload 由系统预算控制 |
| reset 倒计时 | Supported | 在 timeline entry 中使用动态日期；percentage 只随新快照更新 |
| App Group 脱敏快照 | Supported | Host 与 Widget Extension 使用同一 App Group；原子替换 snapshot |
| SQLite WAL 事件库 | Supported | 主应用独占写；Widget 不打开数据库 |
| macOS 本地通知 | Supported | UserNotifications；需用户授权；本地通知不需要 APNs entitlement |
| 通知动作与 pending replacement | Supported | `UNNotificationCategory` / `UNNotificationAction`；banner 最多展示前两个 action；相同 request identifier 替换 pending request |
| Focus 下保证通知出现 | Unsupported | Focus、系统设置和用户授权拥有最终控制权 |
| WorkPulse 自有 deep link | Supported | 注册 `workpulse://`，通过 `.onOpenURL` 路由到 Inbox / Usage / Event detail；校验所有参数 |
| 打开用户手动保存的 HTTPS URL | Supported | `NSWorkspace.shared.open`；只承诺交给系统打开，不承诺进入 ChatGPT 原生 app |
| 任意 ChatGPT / Codex desktop thread 精确 deep link | Unsupported as promise | 官方文档未公开稳定通用 scheme；只能通过 Gate B 逐类验证 |
| WorkPulse-owned App Server thread detail | Supported | 打开 WorkPulse 自己保存的 detail scene，不依赖外部 app |
| 自定义刘海 Resident / Alert / Expanded | Prototype-only | `NSPanel` 普通浮层；不是系统 Dynamic Island，也不是 Live Activity |
| 所有 Spaces / 全屏 / Stage Manager 可靠覆盖 | Prototype-only | 使用 `collectionBehavior` 只能提供行为提示，仍需真机矩阵；默认全屏 suppress |
| Mac-only ActivityKit Dynamic Island | Unsupported | Mac 不能启动自己的 Mac-only Live Activity；配对设备显示不适合作为 P0 架构 |
| 自动识别所有屏幕共享 | Unsupported | 不申请 Screen Recording；P0 只做显式 Privacy Mode |
| Codex `app-server` `stdio` | Prototype-only | Foundation `Process` + JSONL；命令本身 experimental，不支持生产稳定承诺 |
| App Server rate limits / usage | Prototype-only | `account/rateLimits/read`、`account/rateLimits/updated`、`account/usage/read`；只对支持的认证模式有效 |
| App Server 当前连接自有 thread 事件 | Prototype-only | start / resume 后的订阅流可验证；WorkPulse companion 模式不得主动 resume 外部 thread |
| 跨 ChatGPT Desktop / Codex Desktop 实时观察 | Prototype-only | `thread/status/changed` 只对 loaded thread；独立进程能否看到另一客户端 runtime 必须由 Gate A 决定 |
| `needs_input` | Prototype-only | `tool/requestUserInput` 属 experimental API，需要单独 opt-in 与 capability gate |
| Codex `notify` 作为完成事件源 | Prototype-only | 目前外部 `notify` 只支持 `agent-turn-complete`，且 payload 可含用户输入和最后回复；不得静默覆盖配置 |
| ChatGPT Projects / Chats 自动枚举 | Unsupported | 没有公开第三方 companion API；P0 仅手动 pin |
| ChatGPT Scheduled 自动枚举与健康状态 | Unsupported | 官方提供 ChatGPT 内管理界面，但未提供第三方枚举 / 运行状态 API |
| Scheduled task 固定在同一 chat | Supported in ChatGPT, not WorkPulse API | ChatGPT 官方支持 scheduled task 返回同一 chat；WorkPulse 只能手动保存入口，不能读取运行状态 |
| Gmail Scheduled 对话卡片 | Prototype-only as a manual card | 可以保存“每日 Gmail 审查”名称、URL、用户自填时间；不得显示自动邮件数、最近成功或下次运行 |
| 复用 ChatGPT Gmail plugin / connector 凭证 | Unsupported | WorkPulse 不能读取或复用 ChatGPT connector OAuth；若未来直接接 Gmail API，是独立 OAuth 产品范围 |
| 本地确定性 Daily Brief | Supported | 只汇总 WorkPulse EventStore 已有事件，条目必须可追溯 |

官方依据：

- [WidgetKit](https://developer.apple.com/documentation/widgetkit/)
- [WidgetKit refresh budget and timelines](https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date/)
- [WidgetFamily.systemExtraLarge](https://developer.apple.com/documentation/widgetkit/widgetfamily/systemextralarge)
- [Widget interactivity](https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities)
- [MenuBarExtra](https://developer.apple.com/documentation/swiftui/menubarextra)
- [NSScreen safeAreaInsets](https://developer.apple.com/documentation/appkit/nsscreen/safeareainsets)
- [UserNotifications authorization](https://developer.apple.com/documentation/usernotifications/asking-permission-to-use-notifications)
- [Notification request identifier replacement](https://developer.apple.com/documentation/usernotifications/unnotificationrequest/identifier)
- [App Groups](https://developer.apple.com/documentation/xcode/configuring-app-groups)
- [Custom URL schemes](https://developer.apple.com/documentation/xcode/defining-a-custom-url-scheme-for-your-app)
- [Codex App Server](https://learn.chatgpt.com/docs/app-server)
- [Codex notifications](https://learn.chatgpt.com/docs/config-file/config-advanced#notifications)
- [ChatGPT Scheduled tasks](https://learn.chatgpt.com/docs/automations)
- [ChatGPT Notifications / Activity](https://learn.chatgpt.com/docs/notifications)

## 3. 对 PRD_V3 与 HTML 原型的具体修正

### 3.1 `PRD_V3.md` 仍需修正

1. `running_quiet` 出现在 freshness 规则，但没有进入 8.1 的工作状态枚举。建议删除，或把它定义为 presentation hint，而不是新业务状态。
2. Widget Initial loading 写“正在同步”不准确。Widget Extension 只读取 snapshot，不负责同步。建议改为“等待 WorkPulse 连接”或“暂无可用快照”。
3. 11.3 仍写“VoiceOver 读取时暂停”，但 24、37 节已经改成“Accessibility / keyboard focus 位于 Alert 内”。实现应以后者为准；系统没有可靠的通用 API 告知某段内容正在被 VoiceOver 朗读。
4. “CPU / energy 诊断”表述过强。应用内可显示内存、adapter 重启、解析错误、队列长度与最近连接；energy impact 应作为 Instruments / Xcode Organizer QA 结果，不应伪装为精确实时用户指标。
5. “Source conflict 显示官方 UI 数值”无法自动完成，因为 WorkPulse 没有 API 读取 ChatGPT UI 当前显示值。应改为“记录用户报告或测试样本中的差异”。
6. App Group 在 macOS 14 可以共享数据，但 Apple 对非 sandbox app group container 的额外 SIP 保护说明是 macOS 15+。因此 P0 不应把 App Group 当作凭证保险箱；继续只写 generic snapshot 是正确策略。
7. Developer ID Host 非 sandbox 与 Widget Extension 的 entitlement 需要写成两个明确 target 配置，不能只写“Widget extension 只具 App Group”。建议 Widget Extension 同时启用 App Sandbox 与 App Group，且不授予 network client。
8. P0 不应默认包含 `CodexNotifyAdapter`。它只产生完成事件，并可能携带 `input-messages` 与 `last-assistant-message`。除非用户显式启用并接受 broker 配置，否则保持 spike-only。
9. `experimentalApi=false` 表示留在 app-server 内的非 experimental method surface，不表示 `codex app-server` 命令已经 production stable。UI 的 Technical Preview 标签必须覆盖 quota 与 thread 能力本身。
10. `thread/list` 的默认 `sourceKinds` 只有 `cli` 与 `vscode`。Phase 0 必须显式传入被测 source kinds，并把未识别来源显示为 unsupported，而不是推断为 Desktop。

### 3.2 `workpulse_mac_desktop_demo.html` 与 V3 的冲突

HTML 可以继续作为视觉演示，但原生实现不可照抄以下数据语义：

| HTML 表达 | 问题 | 原生 MVP 应改为 |
|---|---|---|
| “固定对话 · Scheduled” | P0 无 Scheduled 枚举 API | “手动固定”或“Design concept” |
| “上次审查 08:00 已完成” | 无可信运行结果来源 | 用户自填备注，或完全隐藏 |
| “需要处理 3 封邮件” | WorkPulse 不拥有 Gmail 数据源 | 删除；除非未来独立 Gmail OAuth adapter |
| “下次审查 16:00 今天” | 无 Scheduled source 时不能称同步状态 | 仅显示“用户设定 16:00”，标记 Manual |
| “今日配额 6/8 小时深度工作、75%” | 不是 App Server rate-limit schema | 使用具体 `limitId`、window、derived remaining 与 reset |
| Medium Widget “实时” | WidgetKit 不是实时表面 | “更新于 10:24”或 Fresh / Cached |
| “打开当前线程” | 未证明 external deep link | “打开 WorkPulse 详情”；Gate B 后才显示“打开任务” |
| “打开后返回原审批位置” | 对任意 Desktop thread 过度承诺 | 仅 verified target 使用；否则进入 fallback detail |
| Fixed 240×240 / 520×240 Widget | HTML 舞台尺寸不是 macOS Widget contract | 原生视图读取 `widgetFamily` 与 content margins，自适应布局 |

另外，HTML 的 `.widget` 用 click listener 模拟整卡交互，但 `<article>` 本身没有原生键盘语义。这个问题不用修改 HTML；SwiftUI Widget 应直接使用 `Link` 或 `Button(intent:)`，不要复刻 DOM 交互。

## 4. 可编译原生 MVP 目录与模块规范

建议创建一个 Xcode workspace，包含一个应用 target、一个 Widget Extension target、一个本地 Swift package 与测试 targets：

```text
WorkPulse/
├── WorkPulse.xcworkspace
├── WorkPulse.xcodeproj
├── Config/
│   ├── WorkPulse.entitlements
│   ├── WorkPulseWidgets.entitlements
│   ├── Debug.xcconfig
│   ├── Release.xcconfig
│   └── PrivacyInfo.xcprivacy
├── Packages/
│   └── WorkPulseCore/
│       ├── Package.swift
│       ├── Sources/
│       │   ├── WorkPulseDomain/
│       │   │   ├── Event.swift
│       │   │   ├── DeliveryRecord.swift
│       │   │   ├── SourceCapability.swift
│       │   │   ├── Freshness.swift
│       │   │   └── OpenTarget.swift
│       │   ├── WorkPulseAdapters/
│       │   │   ├── SourceAdapter.swift
│       │   │   ├── ManualLinkAdapter.swift
│       │   │   └── AppServer/
│       │   │       ├── AppServerProcess.swift
│       │   │       ├── JSONLFramer.swift
│       │   │       ├── RPCClient.swift
│       │   │       ├── SchemaRegistry.swift
│       │   │       ├── CapabilityProbe.swift
│       │   │       ├── QuotaService.swift
│       │   │       ├── ThreadObserver.swift
│       │   │       └── ReconnectController.swift
│       │   ├── WorkPulseStore/
│       │   │   ├── SQLiteDatabase.swift
│       │   │   ├── EventRepository.swift
│       │   │   ├── DeliveryLedger.swift
│       │   │   └── Migrations/
│       │   └── WorkPulseSnapshot/
│       │       ├── WidgetSnapshot.swift
│       │       ├── SnapshotRedactor.swift
│       │       └── SnapshotFileStore.swift
│       └── Tests/
├── WorkPulseApp/
│   ├── WorkPulseApp.swift
│   ├── AppModel.swift
│   ├── Features/
│   │   ├── Inbox/
│   │   ├── Usage/
│   │   ├── Pinned/
│   │   ├── Settings/
│   │   └── Diagnostics/
│   ├── Surfaces/
│   │   ├── MenuBar/
│   │   ├── Overlay/
│   │   │   ├── OverlayCoordinator.swift
│   │   │   ├── OverlayPanel.swift
│   │   │   └── ScreenPlacementPolicy.swift
│   │   └── Notifications/
│   │       ├── NotificationCoordinator.swift
│   │       └── NotificationDelegate.swift
│   ├── Routing/
│   │   ├── EventNormalizer.swift
│   │   ├── RoutingPolicy.swift
│   │   ├── SurfaceOwnershipMachine.swift
│   │   └── DeepLinkRouter.swift
│   └── Resources/
├── WorkPulseWidgets/
│   ├── WorkPulseWidgetsBundle.swift
│   ├── QuotaPulseWidget.swift
│   ├── NowNextWidget.swift
│   ├── WidgetProvider.swift
│   └── WidgetViews/
├── WorkPulseTests/
│   ├── AppServerContractTests.swift
│   ├── JSONLFramerTests.swift
│   ├── NormalizerTests.swift
│   ├── DedupeTests.swift
│   ├── SurfaceOwnershipTests.swift
│   ├── SnapshotPrivacyTests.swift
│   └── DeepLinkRouterTests.swift
├── WorkPulseUITests/
│   ├── MenuBarKeyboardTests.swift
│   ├── PrivacyModeTests.swift
│   └── OpenTargetTests.swift
└── TestFixtures/
    └── AppServer/
        ├── current-version/
        ├── previous-version/
        ├── malformed-jsonl/
        └── unknown-methods/
```

### 4.1 Target 与依赖规则

| Target / module | 可依赖 | 禁止依赖 |
|---|---|---|
| `WorkPulseApp` | Domain、Adapters、Store、Snapshot、AppKit、UserNotifications | Widget target |
| `WorkPulseWidgets` | Domain 中的只读 DTO、Snapshot、WidgetKit、AppIntents | Adapters、SQLite、AppKit overlay、Codex Process |
| `WorkPulseDomain` | Foundation | SwiftUI、AppKit、SQLite、OpenAI transport |
| `WorkPulseAdapters` | Domain、Foundation | SwiftUI、WidgetKit |
| `WorkPulseStore` | Domain、SQLite3 | UI frameworks |
| `WorkPulseSnapshot` | Domain、Foundation | SQLite writer、Codex transport |

Phase 0 尽量不引入第三方运行时依赖。SQLite 使用系统 `SQLite3`，日志使用 `os.Logger`，测试 fixture 使用本地 JSONL。

### 4.2 Build settings

- Deployment target：macOS 14.0。
- Swift：当前 Xcode 默认稳定版本；开启 complete concurrency checking 作为 Warning，逐步收敛到 Swift 6 strict。
- Architecture：先测试 `arm64`，代码不应无理由排除 `x86_64`；是否正式支持 Intel 由 Codex CLI 支持矩阵与 Gate C 决定。
- `LSUIElement`：Phase 0 建议 `false`。WorkPulse 有主窗口与诊断页，保留 Dock 入口更可靠。以后若改成纯菜单栏 app，再单独验证 MenuBarExtra 被移除后的生命周期。
- 自有 URL type：`workpulse`，只处理只读导航，不允许 URL 触发审批、删除、命令或配置写入。

## 5. Entitlement、权限与分发规范

### 5.1 Host target

Phase 0 `WorkPulseApp.entitlements`：

```xml
<key>com.apple.security.application-groups</key>
<array>
    <string>group.com.example.workpulse</string>
</array>
```

说明：

- Host 暂不设置 `com.apple.security.app-sandbox`。
- 不申请 Full Disk Access、Accessibility、Screen Recording、Camera、Microphone、Location、Apple Events、Push Notifications 或 Time Sensitive Notifications。
- Hardened Runtime 通过 Signing & Capabilities 开启；不添加 JIT、Disable Library Validation、Allow Unsigned Executable Memory 等 exception。
- 本地通知只需要运行时授权，不需要 APNs entitlement。
- 自定义 `workpulse://` 使用 Info.plist 的 `CFBundleURLTypes`，不需要 Associated Domains。

### 5.2 Widget target

建议 `WorkPulseWidgets.entitlements`：

```xml
<key>com.apple.security.app-sandbox</key>
<true/>
<key>com.apple.security.application-groups</key>
<array>
    <string>group.com.example.workpulse</string>
</array>
```

Widget 不直接联网，因此不添加 `com.apple.security.network.client`。Host 与 extension 必须由同一 Team ID 签名并声明完全相同的 App Group。

### 5.3 分发

Pilot：

- Developer ID Application 签名。
- Hardened Runtime。
- Secure timestamp。
- 使用 `notarytool` notarize。
- Staple app / DMG ticket。
- 在干净用户账号验证 Gatekeeper 首次启动。

Apple 明确要求直接分发使用 Developer ID 与 notarization；Mac App Store 要求 App Sandbox。当前 App Server 子进程架构不应承诺直接迁移 MAS，因为 `Process` 创建的 child 会继承 parent sandbox，可能无法访问 Codex 状态与所需资源。

依据：

- [Notarizing macOS software](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
- [Hardened Runtime](https://developer.apple.com/documentation/security/hardened-runtime)
- [App Sandbox](https://developer.apple.com/documentation/security/app-sandbox)
- [Foundation Process](https://developer.apple.com/documentation/foundation/process)

## 6. AppServerStdioAdapter contract

### 6.1 Transport contract

只允许：

```text
codex app-server --listen stdio://
```

实现规则：

- 使用 `Process.executableURL` 和参数数组，不通过 shell。
- stdout 是 JSONL protocol channel；stderr 是独立有界 ring buffer。
- 单行上限建议 4 MiB，累计未完成 buffer 上限 8 MiB；超限进入 protocol degraded 并终止当前 child。
- 请求使用单调递增 `Int64` 或 UUID id；pending request 有 deadline。
- EOF / child exit 时原子取消所有 pending continuation。
- unknown fields 容忍；unknown notification method 计数并忽略。
- malformed 单行隔离；短时间连续 3 条 malformed 或 framing 失步时重建连接。
- 不把原始 stdout / stderr、prompt、assistant delta 写入持久日志。

官方协议为省略 `jsonrpc: "2.0"` header 的双向 JSON-RPC，stdio 为 newline-delimited JSON；schema 由当前 Codex 版本生成，因此版本绑定：[Codex App Server protocol](https://learn.chatgpt.com/docs/app-server#protocol)。

### 6.2 Initialization contract

连接状态机：

```text
stopped
→ discoveringExecutable
→ spawning
→ initializing
→ accountChecking
→ probingCapabilities
→ ready
↘ degraded
↘ backingOff
↘ unsupportedVersion
```

每条 transport connection：

1. 只发送一次 `initialize`。
2. `clientInfo.name = "workpulse"`，title 与 version 使用真实构建信息。
3. 默认 `experimentalApi=false`。
4. `optOutNotificationMethods` 排除不需要的高敏感 / 高频 delta，例如 `item/agentMessage/delta`。
5. initialize 成功后发送 `initialized` notification。
6. 执行 `account/read`，不主动触发 login。
7. 分项执行 rate limit、thread list、loaded list、approval event smoke test。

企业分发前应按官方要求联系 OpenAI，确认 `clientInfo.name` 的 known-client / compliance logging 要求。

### 6.3 Auth contract

- 首选 Codex-managed `chatgpt` auth；Codex 自己负责 OAuth、token 持久化与刷新。
- WorkPulse 不读取 `auth.json`、Keychain token 或浏览器 cookie。
- `account/login/start` 只能由用户显式操作触发。
- 不使用 experimental `chatgptAuthTokens`。
- WorkPulse 的“断开连接”只停止 adapter，不调用 `account/logout`，避免影响其他 Codex 客户端。
- API-key-only 与 Bedrock auth 不保证 `account/usage/read`；UI 按 capability 显示 unsupported。

### 6.4 Quota contract

P0 quota 数据：

- `account/rateLimits/read`
- `account/rateLimits/updated`
- `rateLimitsByLimitId` 优先；`rateLimits` 是 backward-compatible 单 bucket view。
- `usedPercent`、`windowDurationMins`、`resetsAt` 都按 optional 解码。
- `remaining = clamp(100 - usedPercent, 0...100)`，显示 Derived。
- `rateLimitReachedType` 才能作为服务端分类的 reached state；`usedPercent == 100` 不能单独证明某个 turn blocked。
- `account/usage/read` 是 token activity summary，不是 quota 真值。
- WorkPulse 不调用 `account/rateLimitResetCredit/consume`。

刷新策略：连接成功、前台、wake、网络恢复时读一次；监听 updated；前台每 5 分钟、后台每 15 分钟可作为 Pilot fallback。该轮询频率是 WorkPulse 产品策略，不是 OpenAI SLA。

### 6.5 Thread ownership contract

```swift
enum ThreadOwnershipMode: Sendable {
    case ownedByWorkPulse
    case observedExternal
    case historicalOnly
    case unknown
}
```

- `thread/status/changed` 只对 loaded thread 发出。
- `thread/list` 默认 source kinds 只有 `cli` 与 `vscode`；必须显式声明被测集合。
- `thread/start` 会让当前 connection 自动订阅新 thread。
- `thread/resume` 会加载 thread；不是无副作用观察。
- companion 模式不得为了获取状态自动 resume 外部 thread。
- 首次 list / read 只建立 snapshot 与 watermark，不触发 completion notification。
- 只有当前 connection 已订阅且来源明示的 event 才能标 Live。

Gate A 失败时，不允许把 `historicalOnly` 包装成“正在运行”。可选 pivot 是让 WorkPulse 成为管理自己 threads 的轻量 client，但这需要新的产品授权。

### 6.6 Reconnect 与恢复

退避：`1, 2, 4, 8, 16, 30, 60` 秒加 jitter。连续 5 次失败或 10 分钟失败窗口后停止自动重启，显示手动重试。

断线：

- 2 秒内把 live state 转为 `unknown`，保留 `lastKnownState`。
- quota 转 cached，超过 `staleAt` 后 stale。
- 取消未投放的新提醒；不从 stale fact 生成新 Alert。
- 重连后重新 initialize、account read、capability probe、snapshot reconciliation。
- App Server 没有通用 replay cursor；使用本地 subscription watermark 与 stable object IDs 抑制历史重放。
- 断线前已经 scheduled 的系统通知按稳定 identifier 取消；仍需处理取消与系统展示的 race。

### 6.7 Executable 安全

- 首选用户确认的 Codex executable；显示 resolved path 与 `codex --version`。
- 解析 symlink；拒绝 binary 或其父目录 world-writable。
- 不提升权限，不打包、不复制、不重签 Codex。
- 不覆盖 `HOME`、`CODEX_HOME` 或用户 config。
- child 继承最小必要环境；不得把环境变量输出到 diagnostics。
- adapter 只调用 allowlist 中的 read / observe 方法。`thread/delete`、archive、metadata write、config write、turn start、rate reset consume 全部拒绝。

## 7. Stable native contracts

### 7.1 Widget Snapshot

```swift
struct WidgetSnapshot: Codable, Sendable {
    let schemaVersion: Int
    let generatedAt: Date
    let freshUntil: Date
    let privacyClass: PrivacyClass
    let quota: QuotaSnapshot?
    let nowNext: NowNextSnapshot?
    let sourceHealth: SourceHealthSummary
}
```

写入流程：

1. 主应用从 EventStore 生成 generic DTO。
2. 编码到 App Group 临时文件。
3. `fsync` 后原子 replace 正式 snapshot。
4. 调用 `WidgetCenter.shared.reloadTimelines`。
5. Widget 只读；解码失败显示 unavailable。

`reloadTimelines` 只是请求，WidgetKit 最终决定更新时间。Apple 说明常见 daily budget 约 40–70 次，约等于 15–60 分钟一次，timeline entry 建议至少相隔约 5 分钟。因此 Needs You 的实时提醒只能由 MenuBar / Overlay / Notification 承担。

### 7.2 MenuBarExtra

```swift
MenuBarExtra("WorkPulse", systemImage: menuIcon) {
    MenuBarRootView()
}
.menuBarExtraStyle(.window)
```

- 主应用状态由单一 `@MainActor AppModel` 投影。
- MenuBar 不直接访问 SQLite；通过 repository / observation 获得 view state。
- keyboard focus、`Esc`、第一条 Needs You navigation 在原生 UI test 验证。
- P0 不设置 `LSUIElement=true`，避免失去可靠主窗口入口。

### 7.3 Notifications

使用：

- `UNUserNotificationCenter.requestAuthorization(options: [.alert, .sound, .badge])`
- `UNNotificationCategory`
- `UNNotificationAction`
- 稳定 request ID：`workpulse.<source>.<object>.<eventType>`

Delivery ledger 区分：

```text
scheduledAt
presentedAt?     // 仅在 delegate 或 delivered query 可确认时
openedAt?
actionID?
```

“add request 成功”不能写成 delivered。Focus / permission denial 进入 MenuBar fallback。普通 P0 不请求 `.timeSensitive`。

### 7.4 NSPanel overlay

建议：

- `NSPanel` + `NSHostingView`
- style mask 包含 `.nonactivatingPanel`
- Resident / Alert 不成为 key window
- Expanded 使用独立可交互 panel 或明确切换为可 key 的 panel
- `NSScreen.safeAreaInsets`、`auxiliaryTopLeftArea`、`auxiliaryTopRightArea` 参与几何计算
- `collectionBehavior` 只作为行为配置，不当作兼容性保证

不要把 HTML 中 220–320pt 固定宽度直接映射到真实 notch。placement policy 应先取得目标屏的 safe rect，再把 panel 放在 housing 下方或两侧的无障碍区域。显示器断开时先关闭 panel，再在下一 run loop 重新选屏。

### 7.5 Deep Link

WorkPulse 自有 route：

```text
workpulse://inbox
workpulse://usage
workpulse://event/<opaque-local-id>
workpulse://pinned/<opaque-local-id>
```

规则：

- URL 只携带 opaque local ID，不携带 prompt、路径、标题或 token。
- route handler 从 EventStore 重新查询权限与状态。
- 外部 URL 不能触发写操作。
- Pinned URL 只允许 `https`，可选允许用户确认的其他 scheme；默认拒绝 `file`、`javascript`、`data`。
- `NSWorkspace.open` 成功仅代表系统接受打开请求，不代表用户已经到达准确 thread。只有 Gate B 验证成功的 target 才记 context-open success。

## 8. Gmail / Scheduled / 固定对话能力拆分

原型中的“每日 Gmail 审查”实际上包含四个独立能力，必须分别标注：

| 子能力 | P0 数据源 | P0 判定 |
|---|---|---|
| 固定一个对话入口 | 用户手动输入名称与 HTTPS URL | Supported |
| ChatGPT Scheduled 回到同一 chat | ChatGPT 官方产品内支持 | WorkPulse 无读取 API；只可手动保存入口 |
| 显示上次/下次运行与成功失败 | 无 | Unsupported，等待正式 adapter |
| 显示 Gmail 邮件数与摘要 | 无 | Unsupported，除非另建 Gmail OAuth adapter |

OpenAI 官方说明 Scheduled task 可以在现有 chat 中创建，并按计划返回同一 chat；也可以使用该 chat 可用的 plugins。但这描述的是 ChatGPT 产品行为，不是第三方 companion API。[Scheduled tasks](https://learn.chatgpt.com/docs/automations)

P0 卡片建议模型：

```swift
struct ManualPinnedTarget {
    let id: UUID
    var displayName: String
    var url: URL
    var privacyLabel: PrivacyLabel
    var userScheduleNote: String?
}
```

UI 必须显示 `Manual`，不得显示：

- “已同步”
- “上次成功”
- “3 封邮件待处理”
- “下次运行”
- “Scheduled healthy”

除非未来 adapter 返回这些字段及其 freshness。

## 9. Phase 0 Gates 与定量测试

### Gate A：跨客户端可见性

目的：证明独立 WorkPulse App Server 能在不 resume / 改变 ownership 的情况下观察目标 Desktop threads。

测试：

- ChatGPT / Codex Desktop、CLI、WorkPulse-owned 各 20 轮。
- 状态覆盖 running、waiting approval、waiting input、completed、failed、interrupted、notLoaded。
- 覆盖 app 前后台、sleep / wake、网络断开、独立 App Server 重启。

通过标准：

- 目标 external source 中 20/20 thread 能正确枚举，且 source kind 可解释。
- 关键 transition 召回率 ≥95%，误报率 = 0。
- p95 event-to-MenuBar latency ≤2 秒，仅对已确认订阅的 live source。
- 0 次 `thread/resume`、`thread/start` 或 metadata write。
- 初始同步与重连产生 0 条历史 completion Alert / Notification。
- 任何把 `notLoaded` 标记为 running 的情况即 Gate fail。

若 external Desktop runtime 只能看到历史或 `notLoaded`，Gate A fail；仅 WorkPulse-owned threads 通过不能算跨客户端通过。

### Gate B：上下文返回

测试集至少 30 个 target：

- 10 个 WorkPulse-owned event detail。
- 10 个用户保存的 HTTPS pinned targets。
- 10 个 external ChatGPT / Codex target，仅在发现候选 deep link 后测试。

通过标准：

- 所有标记为 `verifiedExact` 的 approval target 30/30 一次操作进入正确上下文。
- 错误 thread 次数 = 0；任何误开直接 fail。
- p95 open request ≤3 秒。
- 打开失败不写 acknowledged，并在 1 秒内显示 WorkPulse fallback detail。
- `NSWorkspace.open` 仅返回 accepted 时，不自动记为 exact success；必须通过 target-specific confirmation 或用户验证方案。

### Gate C：App Server 稳定性

测试版本：当前安装版本 + 前一 tested version；schema fixture 保存 hash。

故障注入：

- EOF、SIGTERM、child crash。
- malformed JSONL、超长行、unknown field、unknown method、missing required field。
- login absent、token refresh、网络离线、睡眠唤醒、账号切换。
- stdout / stderr burst。
- 连续 20 次重启与 24 小时 soak。

通过标准：

- crash-free = 100%。
- 断线后 ≤2 秒所有 live state 变 unknown。
- reconnect duplicate notification = 0。
- history replay alert = 0。
- 凭证、prompt、回复、文件路径持久化泄漏 = 0。
- 连续失败达到阈值后 100% 停止自动 restart storm。
- 24 小时无 zombie process；steady-state memory 不持续单调增长，终点相对稳定基线增长 <20%。
- schema 不兼容只关闭对应 capability，不使 MenuBar / Pinned / local store 不可用。

### Gate D：Overlay 兼容性

硬件/场景：

- 有刘海内屏、无刘海 Mac、单外屏、双外屏、镜像、clamshell。
- 菜单栏显示/自动隐藏、Spaces、Stage Manager、全屏视频、演示、屏幕锁定、热插拔。
- VoiceOver、键盘、Reduce Motion、Reduce Transparency、130% 文字。

通过标准：

- 摄像头 housing 遮挡 = 0。
- Alert 重复屏幕 = 0。
- Alert 生命周期跳屏 = 0。
- 抢夺其他应用 key / text-input focus = 0。
- 显示器断开后 ghost window = 0。
- keyboard / VoiceOver 核心操作完成率 = 100%。
- 任一 Sev-1 兼容问题使 Overlay 默认关闭；不阻止无 Overlay Pilot。

### Gate W：Widget / App Group 编译与刷新

这是原生 MVP 必加的工程 gate：

- Small / Medium 在 macOS 14、15、26 当前系统各至少一台真机验证。
- Snapshot 正常、缺失、旧版本、截断、隐私、stale、offline fixture 全覆盖。
- Widget Extension kill 后能重新读取 snapshot。
- 主应用写 snapshot 期间 Widget 读取 1,000 次，解码损坏 = 0。
- privacy snapshot 中标题、prompt、path、command、token 的匹配数 = 0。
- 不把 `reloadTimelines` 到达时间作为 hard SLA；记录 observed distribution。

### Gate N：Notification

- permission allowed / denied / notDetermined 全覆盖。
- 同 event 相同 identifier 重排 100 次，pending duplicate = 0。
- Alert escalation、snooze、resolve、cancel race 各 50 次。
- notification action 处理幂等，重复 callback 不产生重复 acknowledgement。
- permission denied 时 100% 从 MenuBar 可达，且不再次自动弹权限框。

## 10. 决策表

| A | B | C | D | 结论 |
|---|---|---|---|---|
| Pass | Pass | Pass | Pass | 可进入 Full Technical Pilot |
| Pass | Pass | Pass | Fail | 可进入无 Overlay Pilot |
| Pass | Fail | 任意 | 任意 | Needs You 完整闭环 No-Go；仅内部技术演示 |
| Fail | 任意 | 任意 | 任意 | 跨客户端 companion No-Go；除非重新批准 WorkPulse-owned client pivot |
| Pass | Pass | Fail | 任意 | 不进入 Pilot，继续 App Server spike |

无论 A–D 结果如何，Stable native shell 可以编译与内部测试；但若最终只剩 quota tracker，不应把它包装为完整 WorkPulse。

## 11. 原生 MVP 的最小实现顺序

1. 建 Xcode targets、entitlements、App Group 与签名。
2. 实现 Domain、SQLite migration、generic Snapshot 与 Snapshot privacy tests。
3. 编译 Small / Medium Widget、MenuBarExtra、主窗口与 WorkPulse 自有 deep link。
4. 实现本地 NotificationCoordinator 与 DeliveryLedger。
5. 用 fixture 完成 AppServer JSONL transport / schema / reconnect contract tests。
6. 接真实 `codex app-server`，依次执行 Gate C、A、B。
7. A/B/C 通过后才把 Needs You 与 quota 接入用户表面。
8. 最后实现 NSPanel overlay 并执行 Gate D；失败则保持 feature flag off。

## 12. 最终建议

V3 的核心技术决策可以保留：macOS 14、Developer ID notarized DMG、non-sandbox Host、sandboxed Widget Extension、App Group generic snapshot、SQLite WAL、MenuBar 为可靠入口、Overlay opt-in、App Server `stdio` 与 Technical Preview 标签。

在进入编码前，PRD 与原型必须共同接受一条约束：视觉 Demo 可以展示未来体验，但任何自动状态都必须带真实 source capability。尤其“Gmail Scheduled 固定对话”应在实现规范中拆成 Manual Pin、ChatGPT product behavior、Scheduled status API、Gmail data adapter 四项，避免开发团队把一个设计卡片误实现成不存在的集成。
