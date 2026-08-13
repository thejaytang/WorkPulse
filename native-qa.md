# WorkPulse Native QA

> 日期：2026-08-11  
> Artifact：`native/WorkPulseNative/build/WorkPulse-local-dev.zip`（已验证的本机开发归档；非 Pilot 分发包）
> 最新归档：2026-08-11 15:05:15 CEST  
> SHA-256：`15fdcfbdc73c82d18d8ad1cd1ab2f8eab34a7f4f17b42e0831736d6a6ce8324c`

## 已通过

| 检查 | 结果 | 证据 |
|---|---|---|
| SwiftPM 全量 build | Pass | `WorkPulseCore`、`WorkPulseMenuBar`、`WorkPulseWidgetCompile`、`WorkPulseCoreVerify`、`WorkPulseAppServerProbe` 均链接成功 |
| Core deterministic verification | Pass | 189 checks |
| App Server live probe | Pass | initialize + rateLimits，2 buckets，values redacted |
| Widget source compile + type-check | Pass | Small Quota、Small Pinned Routine、Medium Now & Next、Large Daily Brief 均作为 `WorkPulseWidgetCompile` 完成编译链接，并独立通过 `swiftc -typecheck -parse-as-library` |
| `Info.plist` 语法 | Pass | `plutil -lint` |
| Local archive strict signature | Pass | `/tmp` staging 完成 ad-hoc signature；ZIP 解包后 `codesign --verify --deep --strict` |
| Manual Pin 默认状态 | Pass | 不展示自动 last / next / 邮件数 |
| Verified Demo 门控 | Pass | 仅用户主动开启后展示演示状态 |
| Fixture provenance | Pass at source/build level | quota fixture 使用中性状态与“演示 · 非实时”可见 badge；Needs You fixture 使用“模拟 · 非实时”且不外发 |
| Privacy title + icon | Pass | generic title 与 generic / lock icon |
| Light / Dark | Pass at source/prior visual level | 两主题分支已编译，上一轮截图未见明显裁切；15:05 冻结版运行态仍因锁屏待补 |
| Missing URL | Pass | CTA 禁用并提示先设置 HTTPS link |
| WorkPulse deep link unit | Pass | inbox、usage、routine UUID、event UUID；坏 UUID / extra segment / query / fragment 拒绝 |
| JSONL framing | Pass | partial、CRLF、whitespace、oversize、EOF incomplete |
| RPC envelope / session state | Pass | response、server request、notification、ambiguous reject、合法状态转换 |
| Widget snapshot privacy | Pass | 应用内 title opt-in 不改变 external generic snapshot |
| Event truth primitives | Pass | observed/presented/open/local seen/source ack/resolved 分离；transition 与 callback 双层幂等；fixture suppression；default-empty、可轮换 capability registry；single owner；expired snooze transfer/release/retry；user disposition；telemetry allowlist；14-day retention；Safety Stop |
| Widget snapshot ordering + provenance | Pass | schema v3、durable revision CAS、串行 publisher、独立 `NeedsYouSummary`；只有 `.liveCodexAppServer` quota 可外发，fixture/demo 永不写入 Widget |
| Repeatable local preview gate | Pass | `scripts/verify_local_preview.sh --live-probe` 聚合 build、189 checks、Widget type-check、签名归档、plist、18 项 Web 检查与 2-bucket live probe |
| Deterministic visual fixtures | Pass at source/build level | Debug-only two-bucket 与 unavailable states 已编译；锁屏解除后补运行截图 |

## 视觉证据

- `output/native/native-manual-privacy-dark.jpeg`
- `output/native/native-verified-privacy-dark.jpeg`
- `output/native/native-verified-title-dark.jpeg`
- `output/native/native-verified-privacy-light.jpeg`
- `output/audit-v8/01-desktop-manual-light.png`
- `output/audit-v8/02-daily-brief-dark.png`
- `output/audit-v8/03-alert-privacy-dark.png`

`output/native` 截图来自 quota live button 接入前一轮；`output/audit-v8` 是本轮 Web 桌面模拟器证据，不替代 Native Shell 截图。最新 UI 的协议读取能力由 live probe 验证；锁屏解除后仍需补充当前 Native Shell 的 GUI 与 VoiceOver 证据。

## 已确认限制

- 当前无完整 Xcode，Widget Extension、App Group、Xcode UI test、Developer ID 和 notarization 未完成。
- 已验证 ZIP 没有 TeamIdentifier、Developer ID 或 notarization，因此仍只能作为本机开发演示，不能作为 Pilot 分发包。Desktop 上的 convenience `.app` 可能被 File Provider 重新附加 xattr，不作为签名证据。
- Widget scaffold 已进入 SwiftPM 编译验证 target，但不属于 Xcode App Extension target，不能称 Widget 已安装或完成 App Group 端到端验证。
- Codex App Server command 为 experimental；rate limits / thread 能力只能标 **Technical Preview**。
- 跨客户端 task visibility、approval ownership 与 external exact return 未通过 Gate A / B。
- Needs You Inbox / Detail 当前仅使用 fixture；生产 capability registry 默认为空，不会发送真实 Alert 或 Notification。

## 下一轮必须补齐

1. 完整 Xcode host + Widget Extension target。
2. App Group generic snapshot 真机 1,000 次原子读写。
3. Release signing、Hardened Runtime、Developer ID、notarization。
4. XCTest / CI，迁移 smoke harness。
5. Persistent App Server session、RPC pending、jitter / restart budget、current + previous version fixtures。
6. Light / Dark / 130% 字号 / Increase Contrast / external screen visual matrix。
