# WorkPulse 第六轮技术终检（V6.1 delta）

> 审查日期：2026-08-11  
> V6.1 稳定快照时间：约 13:16 Europe/Oslo  
> 审查对象：`native/WorkPulseNative` 最新源码、`build/WorkPulse-local-dev.zip`、Widget scaffold  
> 审查方式：只读源码审查；构建、typecheck、真实只读 App Server probe、ZIP 解包后签名验证  
> 本轮未修改产品源码，仅更新本审查文件

## 0. V6.1 delta 结论

V6.1 没有改变 V6 的产品级判定：当前仍可称 **MenuBar-only local developer MVP / Technical Preview**，仍不能称完整 WorkPulse local MVP 或 Pilot build。

本次定向复核确认：

| V6.1 增量 | 复核结果 | 边界 |
|---|---|---|
| external snapshot 隔离模拟 Verified 状态与 demo quota | **Closed at source level** | publisher 固定使用 `manualRoutine`；只有 `quotaConnectionState == .live` 才写 quota。启动/demo/unavailable 状态均写 `quota=nil` |
| routine UUID 持久化 | **Closed for current single-routine model** | 使用 `UserDefaults.standard` 保存 UUID；清除 defaults 或未来迁移到多实体 store 仍需 migration 规则 |
| 拒绝未知 routine/event | **Closed at entity-validation level** | routine 仅接受当前持久化 ID；当前没有可信 event store，因此所有 event route 均拒绝。真实 scene navigation 仍未实现 |
| snapshot 写入错误不再使用 `try?` | **Partially closed** | `SnapshotStore.write` 异常进入 `widgetSnapshotError`；但 App Group container 为 nil 时仍直接 return，且该错误状态尚未显示在 UI/Diagnostics |
| 写入后请求 Widget 刷新 | **Closed at source level** | 成功写入后调用 `WidgetCenter.shared.reloadAllTimelines()`；这是 refresh hint，不保证即时刷新 |
| Widget 构建验证 | **Strengthened** | `WorkPulseWidgetCompile` 已由 SwiftPM 实际编译并链接成 Mach-O executable；这仍不是 Xcode Widget Extension、`.appex` 或可安装 Widget |

本次稳定快照复跑结果：SwiftPM 全量 build Pass，包含 `WorkPulseWidgetCompile` 编译与链接；`WorkPulseCoreVerify` Pass，**51 checks**；独立 Widget typecheck Pass；`package_app.sh` Pass；ZIP 独立解包后 `codesign --verify --deep --strict` Pass。ZIP 仍为 arm64、ad-hoc、`TeamIdentifier=not set`，且不包含 Widget `.appex`。

## 1. 最终判定

当前实现已经可以称为：

> **MenuBar-only local developer MVP / Technical Preview**

其准确范围是：Apple Silicon Mac 上可本地构建和解压运行的 SwiftUI 主应用，包含 `MenuBarExtra`、手动 HTTPS 固定入口、严格 WorkPulse-owned URL parser，以及用户主动触发的本机 Codex rate-limit 只读读取。

当前实现还不能称为：

- 完整的 **WorkPulse local MVP**，因为产品定义中的 Small / Medium Widget 尚未成为 `.appex`，通知、真实 Needs You、详情导航也未形成端到端能力。
- **Pilot build**，因为没有完整 Xcode host/extension 工程、App Group entitlement、Developer ID、Hardened Runtime、notarization、正式 Widget、XCTest/UITest 与分发验证。
- production-ready Codex companion，因为 OpenAI 官方仍把 app-server command 标为 experimental、unsupported for production workloads。

本轮最重要的交付结论是：

| 对象 | 判定 | 可使用的称呼 |
|---|---|---|
| SwiftPM 源码与 executables | Pass | 可编译 native MVP slice |
| `WorkPulseCoreVerify` | Pass，51 checks | core smoke verification |
| 真实 Codex rate-limit probe | Pass，当前账号返回 2 buckets，数值未输出 | read-only Technical Preview spike |
| Widget Swift 源码 | Typecheck Pass；SwiftPM compile/link Pass | Xcode Widget scaffold，不是可安装 Widget |
| `WorkPulse-local-dev.zip` | 解包后 strict codesign Pass | local development archive |
| `build/WorkPulse.app` convenience copy | File Provider 可再次附加 Finder xattr，不能作为签名 source of truth | 仅本机便利副本 |
| Pilot artifact | Fail / Not built | 不得称 Pilot、Developer ID 或 notarized build |

## 2. 本轮实测证据

### 2.1 SwiftPM 与核心逻辑

- `swift build --package-path native/WorkPulseNative`：Pass。
- 成功构建：`WorkPulseCore`、`WorkPulseMenuBar`、`WorkPulseWidgetCompile`、`WorkPulseCoreVerify`、`WorkPulseAppServerProbe`。
- `WorkPulseCoreVerify`：`WorkPulseCore verification passed: 51 checks`。
- 当前没有 `.testTarget`，51 checks 仍是自定义 executable harness，不是 XCTest。

51 checks 已覆盖：

- quota clamp / freshness；
- external snapshot generic redaction；
- manual capability 强制清除伪 last/next/attention 状态；
- strict deep-link UUID、额外路径、query、fragment 拒绝；
- JSONL partial、CRLF、whitespace、EOF truncation、oversize；
- multi-bucket rate-limit fixture；
- RPC response/server-request/notification classifier；
- session transition 的少量合法/非法路径；
- delivery surface 去重；
- atomic snapshot round-trip；
- Widget schema、capability、source provenance 与 routine freshness；
- manual snapshot 自动字段抑制；
- host / Widget ISO8601 codec round-trip。

### 2.2 真实 App Server probe

在允许访问用户正常 Codex state directory 的非 sandbox 环境中，最新 probe 实测：

```text
WorkPulse App Server probe passed: initialize + rateLimits; buckets=2; values redacted
```

这证明当前机器、当前 ChatGPT 内嵌 Codex 版本与当前账号上：

- `codex app-server --stdio` 能启动；
- `initialize` 与 `account/rateLimits/read` 能完成；
- 8 秒 timeout 没有误杀本次正常读取；
- parser 能读取 `rateLimitsByLimitId`；
- probe 输出不暴露具体额度值。

但它不证明：

- previous / next Codex version 兼容；
- 长驻 session、reconnect、notification subscription 可用；
- ChatGPT desktop 的其他 thread runtime 对独立进程可见；
- App Server 已具有 production support。

在受限 sandbox 内，app-server 因无法初始化 `~/.codex` state runtime 而退出；在正常非-sandbox host 环境中 probe 通过。这与当前“Developer ID direct distribution、Host 暂不 App Sandbox”的架构相符，也再次说明不能直接承诺 Mac App Store sandbox 版本。

### 2.3 Widget 源码

使用与 `WorkPulseCore` 一致的 SDK/module 对 `WidgetExtension/WorkPulseWidget.swift` 执行 `swiftc -typecheck`：Pass。V6.1 又把同一源码加入 SwiftPM `WorkPulseWidgetCompile` executable target；全量 build 已实际完成 Widget 源码的 compile 与 link，产物是 Mach-O arm64 executable。

这比单纯 typecheck 更强，可以证明当前 SDK 下的 source/module/link compatibility；但 SwiftPM executable target 不具备 Xcode Widget Extension 的 product type、extension `Info.plist`、entitlements、embedding 与签名关系，不能据此声称生成了 `.appex`。

本轮确认以下第五轮问题已经修复：

- Widget `JSONDecoder.dateDecodingStrategy = .iso8601`，与 `SnapshotStore` 的 ISO8601 encoder 一致。
- Small Quota Widget 使用 `.widgetURL(workpulse://usage)`，不再在 Small family 中使用仅适合 Medium+ 分区的 `Link`。
- Medium Widget 使用两个 `Link`，分别进入 Inbox 和固定例程。
- Host 已增加 App Group container publisher，在启动、demo mode 改变、quota 成功或失败后写入 `widget.json`。
- `WidgetSnapshot` 已加入 routine capability、source label、observed time、freshness 与 field support 派生结果。
- manual routine 在 model 层强制清除 last run、next run、attention 与自动状态，减少伪状态进入 Widget 的风险。

但这仍然只是 source scaffold。当前目录没有：

- `.xcodeproj` / `.xcworkspace`；
- Widget Extension target；
- `.entitlements`；
- 已注册的 App Group capability；
- host 内嵌的 `Contents/PlugIns/*.appex`；
- Xcode preview、gallery、桌面真机测试。

### 2.4 local development archive

最新 `package_app.sh` 改为在 `/tmp` staging：

1. 构建 MenuBar executable；
2. 在非 File Provider staging 中创建 bundle；
3. 清理 xattr；
4. ad-hoc signing；
5. `codesign --verify --deep --strict`；
6. 生成 `build/WorkPulse-local-dev.zip`；
7. 再解包一次并 strict verify；
8. 最后生成便利 `build/WorkPulse.app` 副本。

本轮独立解包 ZIP 到 `/tmp` 后复验：

```text
WorkPulse.app: valid on disk
WorkPulse.app: satisfies its Designated Requirement
Signature=adhoc
TeamIdentifier=not set
```

因此：ZIP 内的 local-development bundle 内部签名有效。

但 ZIP 内容只有：

- `Contents/MacOS/WorkPulseMenuBar`
- `Contents/Info.plist`
- `_CodeSignature`
- 空 Resources

没有 Widget `.appex`。此外它是 arm64 thin binary，不是 universal build。

桌面目录由 File Provider 管理，便利 `.app` 副本可能在复制后重新获得 `com.apple.FinderInfo`，导致对该副本直接 strict verify 失败。正确的 source of truth 是已在 staging 与解包测试中通过验证的 ZIP，而不是之后被 File Provider 修改元数据的 convenience copy。

## 3. 已关闭的第五轮 blocker

| 第五轮 blocker | V6 状态 | 终检结论 |
|---|---|---|
| Deep link 接受坏 UUID / 多余路径 / query | Closed at parser level | typed router 严格拒绝；仍缺真实 scene navigation 与 LaunchServices E2E |
| JSONL 无 EOF `finish()` | Closed | clean EOF 与 truncated frame 已区分并有 tests |
| Whitespace JSONL 进入 decoder | Closed | space/tab/CR-only 被忽略 |
| 无 RPC envelope classifier | Closed as primitive | response、server request、notification 可分类；尚未形成通用 RPC client |
| 无 session state | Closed as transition primitive | 有状态枚举与 transition guard；尚无 persistent supervisor |
| 无读取 timeout | Closed for one-shot probe | 8 秒 timer 会终止 child，仍需 deterministic timeout test |
| quota 只有 demo | Closed for explicit read action | 真实只读 probe 已通过；启动时 app 内保留明确标记的 demo，external snapshot 已隔离 |
| Widget 默认 decoder 与 ISO8601 不一致 | Closed | Widget 使用 `.iso8601` |
| Small Widget 使用 `Link` | Closed | 改用 `.widgetURL` |
| Host 不写 App Group snapshot | Closed at source level | 已有 publisher；但当前 bundle没有 entitlement/container，尚不能 E2E |
| 手工 bundle 没有可靠内部签名 | Closed for ZIP local-dev archive | staging + ad-hoc sign + 解包 strict verify 通过 |
| demo quota / 模拟 Verified 状态进入 external snapshot | Closed at source level | external publisher 只写 manual routine；quota 仅允许 `.live` |
| routine UUID 每次启动变化 | Closed for current model | UUID 已持久化到 `UserDefaults.standard` |
| unknown routine/event 仍触发占位动作 | Closed at entity-validation level | 未知 routine 被拒绝；无可信 event store 时 event 一律拒绝 |
| Widget 写入后没有 reload hint | Closed at source level | 成功写入后调用 `reloadAllTimelines()` |

## 4. 剩余 blocker

### B0：没有真正的 Widget Extension 与 App Group entitlement

这是当前不能称“完整 WorkPulse local MVP”的首要 blocker。

源码 typecheck 不等于 Widget 可安装。必须在完整 Xcode 中完成：

- macOS App target；
- Widget Extension target；
- host/extension 独立 bundle ID；
- 同一 Team 与同一 `group.com.workpulse.prototype` entitlement；
- extension embedding；
- host/extension Release signing；
- Widget gallery 与桌面真机验证。

当前机器仍只有 Command Line Tools，`xcodebuild -version` 失败，不能关闭该 blocker。Apple 官方要求通过 Widget Extension target 把 Widget 加入 app，并用 App Group 共享 container。[Creating a widget extension](https://developer.apple.com/documentation/widgetkit/creating-a-widget-extension) [Developing a WidgetKit strategy](https://developer.apple.com/documentation/widgetkit/developing-a-widgetkit-strategy)

### B0：ZIP 没有 Widget，App Group publisher 在当前 artifact 中不可用

`WorkPulse-local-dev.zip` 没有 `PlugIns/*.appex`，也没有 App Group entitlement。因此当前已打包 artifact 中：

- `containerURL(forSecurityApplicationGroupIdentifier:)` 预期返回 nil；
- host 不会生成共享 `widget.json`；
- 用户无法在 Widget gallery 找到 WorkPulse；
- Small / Medium Widget 不属于当前 artifact。

所以不能以 Widget scaffold 的存在把 ZIP 描述成“小组件应用”。

### B0：WorkPulse-owned deep link 仍没有真实导航

Parser 已严格，但 `handleDeepLink` 目前只更新 feedback：

```text
已收到 ... 导航请求 · 当前为占位视图
```

它没有选择 Inbox、Usage、Routine detail 或 Event detail scene。因此：

- 可以称“URL parsing 已完成”；
- 可以称“当前 routine/event entity validation 已完成”；
- 不能称“上下文返回已完成”；
- Widget 点击进入正确详情的 Gate B 尚未开始。

V6.1 已把当前单一 routine UUID 持久化到 `UserDefaults.standard`，并在 handler 中拒绝未知 routine ID；当前没有可信 event store，因此 event route 一律拒绝。UUID 重启稳定性与 semantic validation 已不再是本 blocker，剩余 blocker 是缺少真实 `NavigationCoordinator`、目标 scene 与 cold/warm LaunchServices E2E。

### B0：Pilot 签名与分发完全未完成

当前 ZIP 是 ad-hoc signature：

- `TeamIdentifier=not set`；
- 不是 Developer ID Application；
- 没有 secure timestamp；
- 没有 notarization / staple；
- 没有 Hardened Runtime 的正式验证；
- 没有干净用户账号 Gatekeeper 首启验证。

因此 ZIP 的正确名称是 `local-dev`，不能改称 Pilot build。用户本机开发不需要上架 App Store；给其他用户 Pilot 分发时才需要 Developer ID 与 notarization。

### B1：App Server 仍是 one-shot reader，不是 production session

当前 `CodexRateLimitReader` 对 local developer MVP 足够，但不是第五轮定义的完整 adapter：

- `RPCEnvelopeClassifier` 未用于 live reader；reader 仍按 raw dictionary 与整数 id 解析。
- `AppServerSessionState` 只是 transition function，没有 supervisor、pending request actor、reconnect 或 capability evidence。
- 所有 request 一次写入 stdin；当前 Codex 接受，但未做不同版本 handshake fixture。
- stderr pipe 未异步 drain；诊断量大时存在 pipe backpressure 风险。
- EOF 时 reader 直接报 `serverExited`，没有调用 framer `finish()` 区分 truncated protocol frame。
- parser 只接受 `rateLimitsByLimitId`；官方说明它是“when present”，应兼容 backward-compatible `rateLimits` single-bucket view。
- executable resolver 依赖固定 ChatGPT bundle/Homebrew path，没有 user-selected path、version allowlist 或 schema hash。
- 没有 sleep/wake、process kill、timeout、schema change 的 deterministic integration tests。

这些不阻止“当前机器上的 one-shot quota Technical Preview”，但阻止 Pilot 稳定性承诺。

OpenAI 官方明确说明 app-server command 与 WebSocket transport仍是 experimental、unsupported for production workloads；stdio 是默认 JSONL transport。[Codex App Server](https://learn.chatgpt.com/docs/app-server)

### B1：snapshot 失败可观察性仍只部分完成

V6.1 已移除 `try?`：`SnapshotStore.write` 的 encode、directory 与 disk 错误会写入 `widgetSnapshotError`，成功后会清空错误并调用 `WidgetCenter.shared.reloadAllTimelines()`。

仍有两个缺口：

- `containerURL(forSecurityApplicationGroupIdentifier:) == nil` 时函数直接 return，没有设置错误；这正是当前无 entitlement artifact 的预期路径。
- `widgetSnapshotError` 是 model state，但当前 Settings、Dashboard 与日志均未呈现它，因此用户和测试仍看不到失败。

因此“写错误不再被语言层静默吞掉”已关闭，但 Pilot 需要的 Diagnostics 仍未关闭。建议记录最近成功写入时间、失败类别与 App Group availability，并显示在技术诊断页；不得记录 snapshot 内容。

成功写入后的 refresh hint 已完成。`reloadAllTimelines()` 合法，但 Apple 仍不保证即时刷新；Widget UI 必须继续以 snapshot freshness 为准。[Keeping a widget up to date](https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date/)

### B1：测试仍不是可进入 Pilot 的测试体系

需要新增：

- XCTest `.testTarget`；
- fake app-server process fixtures；
- 8 秒 timeout 的可控 clock/process test；
- single-bucket rate-limit fallback；
- stderr flood / malformed / truncated EOF；
- 100 次 child-kill reconnect；
- App Group host-write / extension-read；
- Widget gallery、deep-link cold/warm launch；
- Developer ID / notarization CI or release checklist。

## 5. 当前功能边界

| 功能 | 当前真实程度 | 对外文案 |
|---|---|---|
| MenuBarExtra / 主窗口 /设置 | 可编译，未做本轮 GUI 自动化 | Local developer MVP |
| 手动 HTTPS 固定入口 | 已实现，只保证交给系统打开 | Manual Pin；不承诺到达指定 ChatGPT thread |
| WorkPulse URL parser | 严格 unit-level | Navigation parser ready；detail navigation pending |
| Codex quota | 当前机器真实 probe 通过 | Technical Preview；用户主动读取；显示 source/freshness |
| Codex remaining percent | 从官方 `usedPercent` 派生 | “根据来源用量换算”，不是额外官方字段 |
| Widget Small / Medium | 源码 typecheck；SwiftPM compile/link | Xcode scaffold only；当前 ZIP 不包含，也不是 `.appex` |
| App Group snapshot | host/reader 源码存在 | Not installed / not entitled in current artifact |
| Notifications | 未实现 | Unsupported in current artifact |
| Needs You live events | 演示状态与 delivery primitive | Not implemented |
| Gmail / Scheduled health | 无可信 adapter | Manual only；不得展示真实 last/next/count |
| ChatGPT Projects / arbitrary thread monitoring | 无公开 companion API / 未通过 Gate A | Unsupported |

## 6. 进入“完整 local MVP”的最小关闭清单

必须同时满足：

1. 安装完整 Xcode，创建 host + Widget Extension。
2. 配置和验证 App Group entitlement。
3. 把 Small / Medium 编译进 `.appex` 并嵌入 app。
4. 实现真实 NavigationCoordinator 与目标 scene；保留当前持久化 routine ID，并补 migration 规则。
5. 对 App Group container 不可用也记录失败，并把 snapshot 状态呈现在 Diagnostics。
6. Xcode 真机验证 widget gallery、Small/Medium、冷/热 deep link 与 reload/freshness 行为。
7. 至少把 51 checks 迁移到 XCTest，并增加 host-write / extension-read integration test。

完成以上后，可称“WorkPulse local MVP”，但仍应给 App Server 标 **Technical Preview**。

## 7. 进入 Pilot build 的额外关闭清单

在完整 local MVP 之上还必须：

1. Developer ID Application 签名，host/extension 同 Team。
2. Hardened Runtime、timestamp、notarization、staple。
3. 干净账号与另一台 Mac Gatekeeper 验证。
4. arm64 支持声明；若要支持 Intel，生成和验证 universal binary。
5. Gate A 跨客户端 visibility 与 Gate B context return 达标。
6. Gate C versioned schema、timeout、EOF、reconnect、auth degraded tests 达标。
7. App Server 一直以 Technical Preview 呈现，或等待 OpenAI production-supported API。
8. 通知、隐私、generic external surfaces 与数据清除完成测试。

## 8. 最终 Go / No-Go

| 决策 | 结论 | 原因 |
|---|---|---|
| 继续 Phase 0 native implementation | **GO** | build、51 checks、Widget compile/link、真实 quota probe、local-dev ZIP 均有实证 |
| 给开发者本人试用 MenuBar-only slice | **GO with constraints** | 使用解包后的 local-dev ZIP；明确没有 Widget/通知/Needs You，quota 为 Technical Preview |
| 宣称“Widget local MVP 已完成” | **NO-GO** | 无 Xcode target、appex、entitlement、gallery / App Group E2E |
| 给外部用户发 Pilot | **NO-GO** | 无 Developer ID/notarization；核心 multi-surface 与 Gate A/B/C 未完成 |
| production commercialization | **NO-GO** | App Server production support 与产品核心可靠性均未成立 |

一句话结论：

> 当前是一个真实可编译、可本机读取 Codex quota、具有可靠 local-dev archive 的 MenuBar 技术 MVP；Widget 已升级为可 typecheck 且可经 SwiftPM 编译链接的 App Group scaffold，但尚未成为 Xcode `.appex` 产品 artifact，因此还不是完整 WorkPulse local MVP，更不是 Pilot build。

## 9. 官方依据

- Apple：[WidgetKit](https://developer.apple.com/documentation/widgetkit/)
- Apple：[Creating a widget extension](https://developer.apple.com/documentation/widgetkit/creating-a-widget-extension)
- Apple：[Developing a WidgetKit strategy](https://developer.apple.com/documentation/widgetkit/developing-a-widgetkit-strategy)
- Apple：[Keeping a widget up to date](https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date/)
- Apple：[Configuring App Groups](https://developer.apple.com/documentation/xcode/configuring-app-groups)
- Apple：[Defining a custom URL scheme](https://developer.apple.com/documentation/xcode/defining-a-custom-url-scheme-for-your-app)
- Apple：[Notarizing macOS software before distribution](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
- OpenAI：[Codex App Server](https://learn.chatgpt.com/docs/app-server)

## 10. 事实与推断声明

- build、51 checks、Widget typecheck 与 SwiftPM compile/link、ZIP 解包 strict verify 是 V6.1 实测事实；真实 probe 沿用 V6 稳定快照实测结果，本次 delta 未重复连接 App Server。
- convenience `.app` 的 Finder xattr 问题是当前 Desktop/File Provider 路径的实测结果；它不否定 ZIP staging artifact 的内部签名通过。
- Widget 可安装性、App Group 共享、LaunchServices route 与 Developer ID 分发尚未实测，因此保持 blocker。
- App Server 当前机器可用不代表跨版本或 production stability；官方 production 限制仍优先于本地一次成功。
