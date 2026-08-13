# WorkPulse 第五轮技术审查：Native MVP 可运行性与 Phase 0 实现规范

> 审查日期：2026-08-11  
> 审查对象：`native/WorkPulseNative` 当前源码与已有构建产物  
> 审查方式：只读源码审查、SwiftPM 构建与验证、现有 `.app` 严格签名检查、Apple / OpenAI 官方文档复核  
> 状态定义：**Supported**、**Supported with constraint**、**Prototype-only**、**Unsupported**

## 1. 结论先行

当前目录已经从“只有原型”进入“可编译 SwiftPM 原生 shell”阶段，但还没有形成可安装、可签名、可加载 Widget 的 macOS 应用工程。

已验证事实：

- `swift build --package-path native/WorkPulseNative` 成功，`WorkPulseMenuBar` 与 `WorkPulseCoreVerify` 均可编译。
- `WorkPulseCoreVerify` 当前通过 **22 checks**。覆盖基础 quota、generic snapshot、manual capability、少量 deep link、JSONL 分帧、固定退避、delivery policy 与 snapshot round-trip。
- 当前机器只有 Command Line Tools，`xcodebuild -version` 明确失败；`/Applications` 下未发现 Xcode。因此本机目前不能创建、编译或安装 Widget Extension，也不能完成 App Group、target signing 与 Xcode UI test。
- `native/WorkPulseNative/build/WorkPulse.app` 是手工拼装产物。其可执行文件只有 ad-hoc signature，`TeamIdentifier` 缺失，`Info.plist` 未绑定；`codesign --verify --deep --strict` 失败。因此它不能被视为合格 Pilot 构建。
- `WidgetExtension/WorkPulseWidget.swift` 不属于 `Package.swift` 的任何 target，当前不会被 `swift build` 编译；它仍读取演示 placeholder，而不是 App Group snapshot。
- 当前没有 `.testTarget`，22 项检查是自定义 executable harness，不是 XCTest suite。
- 当前没有 App Server `Process`、RPC envelope、pending request、handshake、auth/capability probe 或 reconnect supervisor。现有 `JSONLFramer` 和 `ReconnectPolicy` 只是 transport 的两个局部 primitive。

因此第五轮的建议是：

1. 保留 SwiftPM 作为可测试的 `WorkPulseCore` 与 App Server adapter package。
2. 立即创建真实 Xcode host app + Widget Extension，而不是继续增强手工 `.app` 打包脚本。
3. P0 的稳定产品面先完成 MenuBar、WorkPulse-owned deep link、generic App Group snapshot 和 local notification。
4. Codex `app-server` 只进入 **Technical Preview / Phase 0 spike**。官方文档明确写明 app-server command 与 WebSocket transport 仍是 experimental，不能作为 production-stable contract。
5. ChatGPT Projects、Scheduled 和 Gmail 运行状态继续保持 manual pin / unavailable。当前公开 App Server schema 没有这些云端对象的第三方管理或观察接口。

## 2. 当前实现可行性矩阵

| 能力 | 平台可行性 | 当前源码状态 | P0 判定与边界 |
|---|---|---|---|
| `WorkPulseCore` models、delivery、snapshot | Supported | 可编译，22 checks 的一部分 | 可进入 P0，但应迁移到 XCTest 并补异常、并发、schema tests |
| SwiftUI 主窗口与 `MenuBarExtra` | Supported | 已编译 | P0 可用；`MenuBarExtra` 不需要特殊 entitlement，当前 deployment target macOS 14 足够 |
| SwiftPM 直接运行 GUI executable | Supported with constraint | 可编译，未做本轮 GUI 自动化 | 适合开发 shell，不等于可分发 app；应用生命周期、URL registration、Widget 均应由 Xcode host target 验证 |
| 手工 `build/WorkPulse.app` | Supported with constraint | 当前 artifact 严格签名失败 | 仅本地临时演示；不得作为 Pilot artifact 或“已签名应用” |
| WorkPulse-owned `workpulse://` | Supported with constraint | URL type 与 `.onOpenURL` 已加入；router 不严格 | Xcode app 中可实现。必须先修复 UUID、path segment、query/fragment 校验，并做 LaunchServices 端到端测试 |
| 打开用户保存的 HTTPS URL | Supported with constraint | 已实现 `NSWorkspace.open` | 只承诺把 URL 交给系统；不承诺进入 ChatGPT desktop 的精确 thread/context |
| 任意 ChatGPT / Codex external deep link | Unsupported as a promise | 未实现 | 没有可依赖的公开通用 deep-link contract；只能作为逐目标验证的 Gate B |
| Small / Medium Widget | Supported with constraint | 只有未编译 scaffold | 必须使用 Xcode Widget Extension target、签名、App Group；WidgetKit refresh 由系统调度，不是实时表面 |
| App Group generic snapshot | Supported with constraint | `SnapshotStore` 存在；没有 App Group container / entitlement | Host 与 extension 同 Team、同 group entitlement；Widget 只读 generic DTO，不读取主数据库和 App Server |
| Widget 点击进入 WorkPulse detail | Supported with constraint | Widget 未设置 `widgetURL` / `Link` | 使用 WorkPulse-owned URL；Small 整卡一个 `widgetURL`，Medium 最多使用有限 `Link` |
| Local notification | Supported with constraint | 尚未实现 | `UserNotifications` + 用户授权；本地通知不需要 APNs entitlement，拒绝授权时回退 MenuBar/Inbox |
| `JSONLFramer` primitive | Supported | 已实现部分 framing | 可保留，但必须增加 EOF、whitespace、UTF-8 boundary、malformed、oversize 与大 chunk tests |
| `ReconnectPolicy` primitive | Supported | 只有无 jitter 的指数 delay | 不足以驱动进程恢复；需要 attempt budget、jitter、stable-reset、manual stop 与 restart-storm protection |
| Codex App Server `stdio` | Prototype-only | 未接入 | 官方 default transport 是 JSONL over stdio；适合 Phase 0。app-server command 仍 experimental，不能做 production SLA |
| Codex App Server WebSocket / Unix socket | Prototype-only | 未接入 | P0 不使用。WebSocket 官方标注 experimental/unsupported；本地 companion 无需开放 listener |
| `account/rateLimits/read/updated` | Prototype-only | 当前 quota 是 demo | 当前公开 App Server 有该方法与多 bucket；仍受 app-server experimental、auth mode、schema/version 约束 |
| `account/usage/read` | Prototype-only | 未实现 | 仅支持 Codex-services-backed auth；官方明确 API-key-only 与 Bedrock auth 不支持 |
| `thread/list/read` 与 turn/item events | Prototype-only | 未实现 | 可做本 App Server 可见数据的 spike；不能由此推断能观察另一个 ChatGPT desktop runtime |
| 跨客户端实时观察 | Prototype-only | 未验证 | 必须通过 Gate A；独立 app-server process 的 visibility / ownership 是产品成立条件，不是已知事实 |
| ChatGPT Projects 自动枚举 | Unsupported | 仅手动链接 | 官方 Projects 文档是产品 UI 能力，不是第三方 companion API；Codex CLI 也不暴露 ChatGPT Projects view |
| ChatGPT Scheduled 自动枚举、next run、health | Unsupported | demo routine 可模拟 | 官方文档要求在 ChatGPT web/desktop 的 Scheduled 管理；公开 App Server API overview 未提供 Scheduled contract |
| Gmail “需要处理几封”、last/next run | Unsupported without a new adapter | 当前仅演示 | WorkPulse 不能复用 ChatGPT connector 凭证；必须独立 Gmail OAuth/public API，或保持 manual card |

## 3. SwiftPM、Xcode、签名与公开 API 的责任边界

### 3.1 SwiftPM 当前能完成

- 编译与测试纯 Swift module，例如 models、routing、redaction、JSONL/RPC、dedupe、reconnect 和 adapter normalization。
- 编译 SwiftUI/AppKit executable，供开发阶段快速验证 MenuBar shell。
- 生成 `WorkPulseCoreVerify` 或更合适的 XCTest test target。

SwiftPM 成功只能证明源代码可编译，不证明以下能力：

- `.app` bundle 的 LaunchServices 注册与生命周期正确。
- host / extension bundle hierarchy 正确。
- Widget 能出现在 gallery、桌面与 Notification Center。
- App Group container 可读写。
- entitlement、Team ID、Hardened Runtime、Developer ID、notarization 正确。

### 3.2 必须进入 Xcode project 的项目

| 项目 | 必需 framework / 配置 | 最低系统 | 签名 / entitlement / permission |
|---|---|---:|---|
| Host app | SwiftUI、AppKit | 当前项目 macOS 14 | Development signing；Pilot 用 Developer ID + Hardened Runtime + notarization |
| Menu bar | SwiftUI `MenuBarExtra` | API 自 macOS 13；项目维持 14 | 无专用 entitlement；当前保留 `LSUIElement=false` 便于主窗口与诊断 |
| Widget | WidgetKit、SwiftUI | 项目维持 macOS 14 | 独立 Widget Extension target、bundle id、同一 signing Team |
| Shared snapshot | Foundation | macOS 14 | Host 与 Widget 都声明同一个 `com.apple.security.application-groups` |
| Custom scheme | SwiftUI `.onOpenURL` + `CFBundleURLTypes` | macOS 14 | 无 entitlement；需要真实 app bundle 被 LaunchServices 注册 |
| Local notifications | UserNotifications | macOS 10.14+，项目 14 | 运行时 `requestAuthorization`；local 不需要 APNs entitlement |
| Remote push | UserNotifications / APNs | 非 P0 | Push capability、签名、服务端与 APNs，P0 不加入 |

本地开发不要求上架 Mac App Store。可先使用 Xcode Development signing 在本机运行；给其他用户分发时使用 Developer ID 与 notarization。Mac App Store 另行评估，因为 App Store 要求 App Sandbox，而从 sandboxed host 启动并控制外部 `codex` executable 的架构不应预设可行。

### 3.3 依赖 OpenAI 公开接口的项目

- `account/rateLimits/read`、`account/rateLimits/updated`、`account/usage/read`、thread/turn/item API 是当前官方 App Server 文档公开的 contract。
- 但官方同时明确说明 app-server command 不支持 production workloads。因此这些能力在 WorkPulse 中必须统一标注 **Technical Preview**，而不是把个别非-experimental method 称为 production stable。
- App Server schema 是 Codex-version-specific。每个被支持的 Codex 版本必须执行 `codex app-server generate-json-schema`，记录 Codex version 与 schema hash，并以 fixture contract tests 验证。
- 当前官方 App Server API overview 没有 ChatGPT Projects 或 Scheduled 的 enum/observe/manage method。产品文档说明这些功能存在，并不构成第三方 API。

## 4. 当前代码中的阻塞与必须修正项

### P0-Blocker 1：没有真实 Xcode host / Widget target

`Package.swift` 只有 library 与两个 executable target。`WidgetExtension/WorkPulseWidget.swift` 明确在 package 外，因此不会编译。必须创建：

```text
native/WorkPulseNative/
├── WorkPulse.xcodeproj
├── Config/
│   ├── WorkPulseApp.entitlements
│   └── WorkPulseWidgets.entitlements
├── WorkPulseApp/                 # Xcode application target
├── WorkPulseWidgets/             # Xcode widget extension target
├── Package.swift                 # shared core + adapter + tests
├── Sources/
│   ├── WorkPulseCore/
│   └── WorkPulseAppServer/
└── Tests/
    ├── WorkPulseCoreTests/
    └── WorkPulseAppServerTests/
```

Widget target 只依赖 snapshot DTO/store，不依赖 `Process`、AppKit overlay、SQLite writer 或 App Server。

### P0-Blocker 2：当前 `.app` 不是合格 bundle

`scripts/package_app.sh` 有四个明确边界：

1. 硬编码 `arm64-apple-macosx/debug/WorkPulseMenuBar`，不能自然支持 Intel、universal 或 Release build layout。
2. 只复制 binary 与 plist，没有 extension embedding、entitlements、resources sealing 或 bundle signing。
3. 没有 Hardened Runtime、Developer ID、timestamp、notarization。
4. 已有 artifact 的 strict code-sign verification 失败。

脚本可以保留为开发便利工具，但不能继续承担 Pilot packaging。

### P0-Blocker 3：deep-link parser 会接受歧义输入

当前 `DeepLinkRouter` 有这些问题：

- `workpulse://routine/not-a-uuid` 会被解析为 `.routine(nil)`，而不是拒绝。
- 多余 path segment 会被忽略。
- host route 与 path-only route 的 UUID 位置不一致。
- query、fragment 没有白名单或拒绝策略。
- route 只改变一条 feedback 文本，没有真正选择 Inbox、Usage 或 routine detail scene。

P0 只允许只读导航：

```text
workpulse://inbox
workpulse://usage
workpulse://routine/<UUID>
workpulse://event/<UUID>
```

实现规则：scheme/host 精确匹配；segment 数量精确；UUID 必须有效；拒绝 user/password、port、未知 query、fragment 和额外 segment；URL 永远不能触发审批、删除、执行命令、写配置或连接账号。Router 输出 typed route，由单一 `NavigationCoordinator` 打开对应 scene。

WorkPulse-owned link 可以做到“进入 WorkPulse 自己的精确详情”。它不能证明或替代 ChatGPT desktop 的 external deep link。

### P0-Blocker 4：Widget 仍是演示数据

当前 provider 的 `getTimeline` 固定返回 placeholder，并请求 30 分钟后 refresh。正式实现必须：

1. 从 `FileManager.containerURL(forSecurityApplicationGroupIdentifier:)` 获取共享目录。
2. 读取 `WidgetSnapshot.currentSchemaVersion` 的 generic JSON。
3. 对 missing、corrupt、unsupported schema、fresh、cached、stale、offline 分别渲染。
4. app 写入后调用 `WidgetCenter.shared.reloadTimelines(ofKind:)`，但 UI 和 PRD 不承诺立即刷新。
5. timeline 使用可预测的 reset/next event 日期；百分比和 task state 只能在新 snapshot 后更新。
6. `widgetURL` / `Link` 只打开 WorkPulse-owned route。

### P0-Blocker 5：没有正式 test target

`WorkPulseCoreVerify` 可作为 smoke test，但不能代替 XCTest、CI 与 fixtures。下一步先增加 `.testTarget`，再把 22 checks 迁移为独立 test cases。任何 App Server 合并都必须有 recorded JSONL fixtures，不能只连接 live account 手工测试。

## 5. App Server stdio 最小实现规范

### 5.1 模块与 ownership

```text
WorkPulseAppServer/
├── AppServerExecutableResolver.swift
├── AppServerProcess.swift
├── JSONLFramer.swift
├── RPCEnvelope.swift
├── RPCClient.swift              # actor；唯一 stdin writer 与 pending owner
├── AppServerSession.swift       # initialize / initialized / account / probe
├── AppServerSupervisor.swift    # spawn、EOF、backoff、manual stop
├── CapabilityRegistry.swift
├── RateLimitAdapter.swift
├── ThreadObserver.swift
└── EventNormalizer.swift
```

- 一个 WorkPulse instance 只拥有一个 child app-server 与一个 `RPCClient` actor。
- 使用 `Process.executableURL` 与 arguments array，禁止通过 shell 拼接命令。
- P0 只用默认 `stdio://`。stdout 是协议 channel；stderr 放入内存有界 ring buffer，并在展示/导出前脱敏。
- WorkPulse 不读取、打印或复制 Codex token。默认复用 app-server 自己的 current auth；只执行 `account/read`，不自动 login/logout。
- 环境变量不写入日志。诊断只记录 executable path、Codex version、schema hash、auth mode 类别、state、错误类别和时间。

### 5.2 JSONL framing contract

官方 stdio transport 是 newline-delimited JSON，且 wire message 省略 `"jsonrpc":"2.0"`。最小 parser 必须：

1. 接收任意 `Data` chunk，不能假设一次 read 等于一行或一个 UTF-8 scalar。
2. 按 byte `0x0A` 切分；移除一个结尾 `0x0D`；空白-only line 应忽略或计为可诊断噪声，不能交给 JSON decoder。
3. complete line 上限 4 MiB，unfinished buffer 上限 8 MiB；超限终止本 session 并进入 protocol degraded。
4. EOF 时若仍有非空 incomplete bytes，记录 `truncatedFrame`，不得把它当完整 JSON。
5. 每个 complete line 单独 decode；单条 malformed 不污染下一个 frame。连续 malformed 达阈值时重启 session。
6. buffer overflow 不能在清理之前泄露原始 payload 到日志。

当前 `JSONLFramer` 已实现 chunk buffer、LF/CRLF、line/buffer 上限，但缺少 `finish()` / EOF、whitespace-only、错误计数与 decoder integration。其 `append` 在解析 chunk 前检查累计 buffer 上限，单次包含大量合法短行的大 chunk 也会整体拒绝；应明确这是安全策略，或改成增量扫描后再执行 unfinished-buffer limit。

### 5.3 RPC envelope 与 lifecycle

解码后按形状分类：

- response：有 `id`，且恰有 `result` 或 `error`。
- server request：有 `method` 与 `id`。
- notification：有 `method`，无 `id`。
- 其他形状：invalid envelope。

每个 transport connection：

1. spawn 后发送一次 `initialize`，使用真实 `clientInfo`。
2. 等待 initialize response，再发送一次 `initialized` notification。
3. 默认 `experimentalApi=false`，并 opt out 不需要的敏感/高频 delta。
4. 执行 `account/read`，然后只做 side-effect-free capability probes。
5. 每个 request 有唯一 `Int64` id、deadline 与 pending continuation。
6. response 可乱序；必须按 id resolve。unknown/duplicate id 记录计数但不能 crash。
7. EOF、child exit、manual stop 时一次性取消全部 pending，并保证 continuation 只 resume 一次。
8. P0 自动重试仅限 read；任何 write / approval / consume credit 不自动 replay。

### 5.4 Capability model

当前 `RoutineCapability { manualPin, verifiedAdapter, unavailable }` 能区分 UI 演示状态，但不足以表达 App Server contract。建议增加：

```swift
enum CapabilityAvailability: String, Codable {
    case availableInCurrentSchema
    case requiresExperimentalOptIn
    case unavailableForAuth
    case unavailableForVersion
    case notObserved
}

struct CapabilityEvidence: Codable {
    let name: String
    let availability: CapabilityAvailability
    let observedAt: Date
    let codexVersion: String
    let schemaHash: String
    let authMode: String?
    let reasonCode: String?
}
```

“available in current schema”只表示当前生成 schema / probe 可用，不得在 UI 中翻译成“production stable”。capability 通过 versioned schema 和安全 read probe 得出，不通过故意调用未知或有副作用的方法猜测。

最少 capability：`accountRead`、`rateLimitsRead`、`rateLimitsUpdated`、`usageRead`、`threadList`、`threadRead`、`threadStatusChanged`、`turnCompleted`、`approvalRequests`、`userInputRequests`。对每项分别降级，不使用一个全局 Bool。

### 5.5 Reconnect、reconcile 与 degraded mode

建议默认 policy：`0.5s, 1s, 2s, 4s, 8s, 16s, 30s`，每次 full jitter `0.8...1.2`，上限 30 秒；10 分钟内最多 8 次自动 spawn。ready 稳定 60 秒后 attempt 清零。manual stop、app termination、unsupported schema 不自动重连。

恢复过程：

```text
running
→ EOF/exit
→ pending 全部失败
→ live event 在 2 秒内转 unknown，保存 lastKnownState
→ backingOff
→ spawn + initialize + capability probe
→ read-only reconcile
→ ready / degraded / unsupportedVersion
```

关键 ownership 原则：

- WorkPulse 不通过自动 `thread/resume` 去“订阅”其他客户端 thread，因为 resume 会改变 App Server loaded/ownership state。
- 对 WorkPulse 自己创建或显式管理的 thread，可记录 ownership 并使用相应 lifecycle。
- 对外部 persisted thread 只用 `thread/list/read` 与当前可观察 event；跨客户端 runtime 可见性由 Gate A 决定。
- reconnect 后不重放旧 notification。以 `(sourceInstance, threadId, turnId, itemId, eventKind, transition)` 生成 dedupe key，并用 source watermark / terminal-state monotonic rule reconcile。

必须支持的降级：

| 失败 | UI / 数据行为 | 恢复 |
|---|---|---|
| 找不到 `codex` | source=`unsupported`，保留 manual pin | 用户在 Diagnostics 选择/修复 executable 后重试 |
| initialize / schema incompatible | App Server source disabled，generic local surfaces 可用 | 停止自动重试；升级/降级 Codex 或 adapter |
| 未登录 / auth 不支持 | quota/usage=`unsupportedForAuth` | 引导用户在 Codex 官方流程登录，不在 WorkPulse 收 token |
| rate-limit method 缺失 | 只隐藏 quota，不关闭 MenuBar / manual pin | capability re-probe |
| child crash / EOF | live state=`unknown`，保留 last known + timestamp | 有界 backoff 重连、read-only reconcile |
| malformed / oversized JSONL | protocol degraded，不持久化原始行 | 达阈值重建 child；Diagnostics 只记类别与计数 |
| Widget snapshot missing/corrupt | generic unavailable / stale UI | host 下次写入原子替换并 request reload |
| notification denied | 不反复请求；使用 MenuBar / Inbox | Settings 显示系统状态与打开系统设置入口 |

## 6. Source adapter 与 normalized event 最小 contract

为了防止 UI 直接依赖 App Server schema，P0 应固定以下边界：

```swift
protocol SourceAdapter: Sendable {
    var sourceID: String { get }
    func start(_ sink: @escaping @Sendable (SourceEmission) async -> Void) async
    func currentCapabilities() async -> [CapabilityEvidence]
    func stop() async
}

struct SourceEmission: Sendable {
    let sourceEventID: String?
    let observedAt: Date
    let payload: SourcePayload
    let freshness: DataFreshness
}
```

Normalizer 必须输出 WorkPulse-owned IDs、source provenance、`observedAt`、`occurredAt?`、freshness、privacy class、open target 和 dedupe key。UI 不得读取 raw App Server DTO。manual adapter 永远不产生 running/completed/last run/next run；没有可信 source 时保持 `manual` 或 `unsupported`。

## 7. 测试矩阵

### 7.1 当前已跑

| 层 | 结果 | 证据 |
|---|---|---|
| SwiftPM all targets | Pass | `swift build` 完成并链接 `WorkPulseMenuBar` |
| Core smoke harness | Pass | `WorkPulseCore verification passed: 22 checks` |
| Full Xcode / Widget | Blocked | 当前 active developer directory 是 Command Line Tools，没有 Xcode |
| Existing `.app` strict signature | Fail | `code has no resources but signature indicates they must be present` |

### 7.2 合并 App Server 前必须新增

| 测试组 | 必测案例 | 通过标准 |
|---|---|---|
| JSONL framing | 在每个 byte boundary 切分；多行同 chunk；CRLF；UTF-8 多字节切分；空/空白行；4 MiB 边界；8 MiB；EOF incomplete；malformed 后恢复 | fixture 100% 预期；无 crash、无跨 frame 污染 |
| RPC | response 乱序；server request；notification；duplicate/unknown id；timeout；EOF 同时存在多个 pending | continuation 恰好完成一次；pending 最终为 0 |
| Handshake | initialize 前 request；initialize error；initialized 次数；experimental false；unknown capability | 每 connection 只初始化一次；失败不进入 ready |
| Reconnect | exit code、signal、EOF、快速 crash loop、manual stop、sleep/wake、stable reset | 10 分钟不超过 8 次 spawn；manual stop 零重启；无 restart storm |
| Capability | method 缺失、auth mode 不支持、optional/null fields、multi-bucket、schema hash 变化 | 每项独立降级；无伪数值；unknown fields 不 crash |
| Rate limit | single/multi bucket、`usedPercent` 越界、reset timestamp、updated notification、stale transition | source、更新时间、freshness 始终可见；remaining clamp |
| Deep link unit | 四种合法 route；坏 UUID；额外 segment；大小写；percent encoding；query/fragment；external scheme | 合法精确路由；非法 100% reject；无写操作 |
| Snapshot | 1,000 次并发原子写读；missing、truncated、corrupt、future schema；privacy scan | 0 partial decode；external snapshot 敏感标题 0 |
| Delivery/dedupe | 同 event 重放、reconnect reconcile、overlay/notification ownership、ack/resolved | 每个 transition 只交付一次；无 overlay+notification 双发 |

### 7.3 Xcode / 真机必须新增

| 测试 | 通过标准 |
|---|---|
| Debug + Release host/extension build | 两个 configuration 都成功，无 missing entitlement |
| Signing | host 与 extension Team 一致；`codesign --verify --deep --strict` pass |
| App Group | host 写 1,000 次，extension test reader 0 partial/corrupt；不存在敏感标题 |
| Widget gallery | 首次启动 host 后 Small/Medium 可添加；placeholder/snapshot/timeline 均渲染 |
| Widget route | Small/Medium 每个入口都打开正确 WorkPulse scene；错误 detail 计数为 0 |
| URL scheme | 安装/首次启动后从 Finder/Terminal/notification/widget 冷启动与热启动路由均正确 |
| Notifications | authorized、denied、notDetermined、Focus、app foreground/background | denied 时仍能从 MenuBar/Inbox 获取状态；不承诺绕过 Focus |
| Distribution | Developer ID + Hardened Runtime + notarization + staple | 干净用户账号首次启动通过 Gatekeeper |

## 8. Phase 0 Gate A-D 决策表

| Gate | 目标 | 量化通过标准 | 失败决策 |
|---|---|---|---|
| Gate A：可见性 / ownership | 判断独立 WorkPulse app-server 是否能看到目标客户端 task 状态 | 对预先标注的 50 个状态转换，supported source recall ≥95%、false positive=0；必须能区分 owned、persisted-not-loaded、unobservable | 不发布“跨客户端 companion”；只保留 manual pin + local shell，不能显示 live task state |
| Gate B：Context return | 提醒后进入正确 WorkPulse-owned 或经官方验证的上下文 | 100 次 supported target 点击，正确上下文 100%，错误 thread 0；unsupported target 100% 使用 WorkPulse detail/fallback | 隐藏“打开任务”；只显示“查看 WorkPulse 详情”或保存的 URL |
| Gate C：Protocol / lifecycle | 证明 stdio adapter 在受支持 Codex versions 上可恢复 | current + previous supported Codex schema fixtures 全过；100 次 child kill 后 ≥99 次在 30 秒内恢复 ready/degraded；pending leak=0；10 分钟 spawn≤8 | App Server 功能不上 Pilot；quota/thread 标记 unavailable，稳定 native shell 不受影响 |
| Gate D：Xcode surfaces / distribution | 证明 Widget、App Group、deep link、notification 与签名是真实能力 | Release host+extension build pass；strict codesign pass；notarization pass；App Group 1,000 次 0 partial；所有合法 deep links 100% 正确，非法 100% reject | 不宣称“原生 Widget app”；先发 MenuBar development build，或延后 Pilot |

生产 Gate 另设：即使 A-D 全部通过，App Server 能力仍只能是 Technical Preview，直到 OpenAI 官方取消 app-server command 的 experimental / unsupported-for-production 限制，或 WorkPulse 迁移到新的 production-supported public API。

## 9. 建议执行顺序

1. 安装并选择完整 Xcode，创建 host + Widget Extension，配置两个 bundle id 与 shared App Group。
2. 增加 XCTest targets，把 22 checks 迁移并补 deep-link、snapshot 和 JSONL tests。
3. 修复 typed deep-link router，并完成 valid signed app 的冷/热启动端到端验证。
4. Widget 改读 generic App Group snapshot，移除正式 timeline 中的 demo data。
5. 实现 stdio `AppServerProcess` + `RPCClient` + handshake，先只做 `account/read` 和 `account/rateLimits/read`。
6. 生成并固定当前 Codex version schema；建立 capability evidence 与 degraded state。
7. 最后做 thread visibility / ownership Gate A。不要在验证前实现 approval UI 或自动 `thread/resume`。

## 10. 官方依据

- Apple：[WidgetKit](https://developer.apple.com/documentation/widgetkit/)
- Apple：[Creating a widget extension](https://developer.apple.com/documentation/widgetkit/creating-a-widget-extension)
- Apple：[Keeping a widget up to date](https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date/)
- Apple：[Widget timeline](https://developer.apple.com/documentation/widgetkit/timeline)
- Apple：[MenuBarExtra](https://developer.apple.com/documentation/swiftui/menubarextra)
- Apple：[Configuring App Groups](https://developer.apple.com/documentation/xcode/configuring-app-groups)
- Apple：[Adding capabilities to your app](https://developer.apple.com/documentation/xcode/adding-capabilities-to-your-app)
- Apple：[Defining a custom URL scheme](https://developer.apple.com/documentation/xcode/defining-a-custom-url-scheme-for-your-app)
- Apple：[Asking permission to use notifications](https://developer.apple.com/documentation/usernotifications/asking-permission-to-use-notifications)
- Apple：[Creating a standalone Swift package](https://developer.apple.com/documentation/xcode/creating-a-standalone-swift-package-with-xcode)
- OpenAI：[Codex App Server](https://learn.chatgpt.com/docs/app-server)
- OpenAI：[Projects and chats](https://learn.chatgpt.com/docs/projects)
- OpenAI：[Scheduled tasks](https://learn.chatgpt.com/docs/automations)
- OpenAI：[Notifications](https://learn.chatgpt.com/docs/notifications)

## 11. 事实与推断声明

- “SwiftPM build 成功”“22 checks 通过”“无完整 Xcode”“已有 app strict signing 失败”是本机实测事实。
- Widget、App Group、MenuBarExtra、notification、custom scheme 的边界来自 Apple 官方公开文档。
- App Server transport、schema、rate limits、usage、thread API 与 production 限制来自当前 OpenAI 官方文档。
- “独立 WorkPulse 能否观察另一个 ChatGPT desktop runtime”仍是未证实推断，因此保留 Gate A。
- “当前没有 Projects / Scheduled companion API”是对当前公开 App Server/API 文档的审查结论，不表示 OpenAI 内部没有接口；若未来官方公开 contract，应重新审查 capability 与产品承诺。
