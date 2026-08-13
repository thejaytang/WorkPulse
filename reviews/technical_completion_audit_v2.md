# WorkPulse 技术完成度审计 V2

> 审计时间：2026-08-13（Europe/Oslo）  
> 范围：最新 Xcode 工程、Targets、Entitlements、App Group、签名、Widget `.appex`、Codex 数据连接、通知、顶部岛 `NSPanel`、多显示器、持久化和打包  
> 原则：只做静态检查、只读运行态检查和临时目录构建；未修改应用源码

## 1. 结论

**工程架构已经从 scaffold 进入“本机可运行的 Apple Development 技术预览”，但当前安装状态仍不满足完成验收。**

- **当前源码编译：Go。** 最新源码可用 Xcode Release 配置同时构建 universal Host 与 Widget Extension；Core 234 项验证、系统表面静态 Gate、Widget type-check 均通过。
- **本机 Widget 技术链路：Conditional Go。** 已安装 App 内存在真实 `.appex`，Host/Widget 同 Xcode Personal Team `<APPLE_TEAM_ID>`、同 App Group，`pluginkit` 能识别安装路径，共享 `widget.json` 正在更新。清理后系统只剩 1 条 canonical Widget 注册和 1 个 Host 进程；还缺 Gallery 搜索、添加、刷新、点击和 fresh→stale 视觉 Gate。
- **当前安装包验收：No-Go。** `WorkPulse-full-product.zip` 和 `~/Applications/WorkPulse.app` 生成于 2026-08-12 23:24，但多个关键源码文件在此后更新，最晚到 2026-08-13 00:28。当前运行的不是最新源码产物。
- **当前运行环境：清理 Gate 已关闭。** 本轮早段曾发现 3 个 Host、2 个 Widget Extension 和 4 条相同 Widget bundle ID 注册，其中 3 条来自 `/private/tmp`。团队清理后于 00:36 复测只剩 `~/Applications/WorkPulse.app` 的 1 个 Host、1 个 Widget Extension 和 1 条 PlugInKit 记录。此前目测结果应废弃，后续可在干净状态重做。
- **外部分发：No-Go。** 当前包是 `Apple Development` 签名，含 `get-task-allow=true`，`spctl` 判定 `rejected`；不是 Developer ID/notarized 交付物。用户本人本机试用不需要上架 App Store，但对外分发仍需 Developer ID 与 notarization。
- **签名稳定性：当前 Pass，但曾瞬时失败。** 本轮早段 `security find-identity` 一度为 `0 valid identities`，安装包虽有 `TeamIdentifier=<APPLE_TEAM_ID>`，但 `Authority` 不可用且 strict verify 报 `CSSMERR_TP_NOT_TRUSTED`。00:36 复测已恢复为 1 个有效 Apple Development identity，Authority 链完整，strict verify 通过。说明证书/钥匙串状态必须纳入每次 release Gate，不能只检查 TeamIdentifier。
- **Codex 数据：Technical Preview。** 本轮真实探针读取到 2 个 quota bucket 和 2 个活动任务，但额度 method、本地 SQLite schema 与 rollout lifecycle 文件均没有找到 OpenAI 官方公开兼容性承诺，必须保留版本漂移降级。

因此，正确的产品状态是：

> **可继续本机 dogfood；先清理重复运行态并从最新源码重建 build 10，再做 Widget/顶部岛/通知终验。不得把当前 build 9 ZIP 当作完成版或外部 Pilot。**

## 2. 状态定义

| 标记 | 含义 |
|---|---|
| **Supported** | 当前源码或本机产物已通过与承诺相匹配的验证 |
| **Constrained** | Apple 公开 API 支持，但受系统调度、用户设置、显示器形态或尚未完成的运行矩阵约束 |
| **Prototype-only** | 当前能工作，但依赖开发签名、未公开实现细节、fixture 或缺少稳定兼容性契约 |
| **Unsupported** | 当前没有真实实现，或 Apple/OpenAI 没有对应产品承诺路径 |

## 3. 边界矩阵

| 能力 | 状态 | 当前证据 | 真实边界 / 缺口 |
|---|---|---|---|
| Xcode Host + Widget targets | **Supported** | `WorkPulse.xcodeproj` 有 `WorkPulse`、`WorkPulseWidget` 两个 target；Host embed extension；Release universal build 通过 | `Xcode/WorkPulse.xcodeproj` 仍有一份较旧且内容不同的重复工程，必须只保留一个 source of truth |
| 无独立主页面 | **Supported** | Release 仅 `MenuBarExtra`；`LSUIElement=true`；QA Window 只在 `#if DEBUG` | 菜单栏控制中心仍是应用内配置入口，但不是独立 Dashboard |
| Widget `.appex` 嵌入 | **Supported** | 安装包存在 `Contents/PlugIns/WorkPulseWidget.appex`；extension point 为 `com.apple.widgetkit-extension` | 当前安装包不是最新源码构建 |
| App Group | **Supported（本机）** | Host/Widget 实际签名 entitlement 均为 `<APPLE_TEAM_ID>.com.workpulse.shared`；共享容器存在且 `widget.json` 正在更新 | 只应写 generic snapshot，不应作为密钥仓库；换 Team 后 group ID 会变化 |
| Apple Development 签名 | **Constrained（本机开发）** | 当前 Host/Widget strict `codesign` 通过；Personal Team/TeamIdentifier 均为 `<APPLE_TEAM_ID>`；00:36 钥匙串有 1 个有效 identity | 本轮曾出现 `0 valid identities`、Authority unavailable、`CSSMERR_TP_NOT_TRUSTED`，后来恢复；`get-task-allow=true`，只适合本机开发 |
| Developer ID / notarization | **Unsupported（当前产物）** | `spctl --assess` 返回 `rejected`；无 notarization/staple 证据 | 对外 ZIP/DMG 分发必须另走 Developer ID + Hardened Runtime + timestamp + notarization；不等于上架 App Store |
| Small/Medium/Large Widget | **Constrained** | 4 个 Widget 已编译、注册，安装 extension 进程实际启动 | Gallery 视觉 E2E 未完成；WidgetKit 时间线由系统调度，不能承诺实时刷新 |
| Widget quota + reset | **Constrained** | App Group snapshot 包含 quota buckets；Host 写后调用 `WidgetCenter.reloadAllTimelines()` | UI 仍写“实时”；provider 只生成一个 timeline entry，系统延迟刷新时可能继续突出已过期精确值 |
| 固定对话入口 Widget | **Supported（手动入口）** | 保存 HTTPS URL，Widget deep link 回到 Host，再由系统打开目标 | 只是快捷入口；不读取该对话内容、Scheduled 状态或 Gmail 结果 |
| Codex quota | **Prototype-only** | 非沙箱真实探针通过：`rateLimitBuckets=2` | 调用 `codex app-server` 的 `account/rateLimits/read`；本轮未找到 OpenAI 官方 published compatibility contract，失败时必须明确 unavailable |
| Codex 活动任务 | **Prototype-only** | 真实探针通过：`activeCodexTasks=2`；数据库只读打开，234 项含生命周期解析测试 | 直接依赖 `~/.codex/state_5.sqlite` 的 `threads` schema，并扫描 rollout JSONL；属于实现依赖，不是稳定公共 API |
| 任务名称隐私 | **Constrained** | 最新源码用 `privacyMode && showTaskNamesInNotch` 联合 Gate；Widget 只发任务数量 | `showTaskNamesInNotch` 首次默认仍为 true，不能称“明确 opt-in”；任务 title 可能源自用户 prompt |
| 常驻顶部岛 | **Constrained** | 原生 AppKit `NSPanel`，Resident / Alert / Expanded 三态；锁屏不可达时不冒充投递 | 这是自绘顶部层，不是 macOS 的系统 Dynamic Island 宿主；系统可保留的真实 Live Activity 表面是 menu bar，而不是物理刘海内嵌内容 |
| 物理刘海避让 | **Supported（代码路径）** | 使用 `NSScreen.safeAreaInsets`、`auxiliaryTopLeftArea/rightArea` 计算 camera housing，并将内容从遮挡区下缘开始 | 仍需实际刘海屏、全屏和不同菜单栏设置的截图矩阵 |
| 多显示器定位 | **Constrained** | 策略固定为 built-in+notch → built-in → main → first；监听屏幕变化；不跟随鼠标 | clamshell 时会按设计回退外接主屏；当前多进程污染，尚不能把目测位置算作最新 build 验收 |
| 系统通知 | **Constrained** | `UNUserNotificationCenter`、授权、category、actions、deep link、snooze 已实现 | 用户可拒绝；Focus/通知设置可抑制；`center.add` 成功只代表系统接收请求，不保证 banner 展示 |
| 任务完成通知 | **Constrained** | 活动任务消失可触发顶部 Alert；用户不活跃时策略可走系统通知 | 依赖活动任务 reader 的稳定性，且必须先建立 baseline |
| Needs You 审批/输入提醒 | **Prototype-only** | EventLedger、投递所有权、去重、顶部/通知链路存在 | 生产 adapter 尚不存在；当前 approval/input 事件只来自 controlled fixture，不能声称能监听 ChatGPT 审批或输入请求 |
| Scheduled / Gmail / Daily Brief | **Unsupported（实时状态）** | 仅有手动固定 URL 与演示 routine | 没有官方连接、认证、last run/next run/attention adapter；不得展示为已连接状态 |
| 本地持久化 | **Supported（基础）** | EventLedger 原子 JSON 写入 Application Support；Widget snapshot 原子写入 App Group；schema/revision 测试通过；两个文件均真实存在 | 尚无 Host+Widget 长时间并发、损坏恢复、磁盘满、权限变化的运行压力 Gate |
| 登录启动 | **Constrained** | 使用 `SMAppService.mainApp.register/unregister` | 仍需真实系统设置授权、注销/登录与升级后的运行测试 |
| 安装/打包脚本 | **Prototype-only** | full-product build、signed install、runtime verify 脚本存在；重复实例/注册已人工清理 | signed install 使用 `open -n` 且替换前不停止旧 Host，仍可能复发；现有 ZIP 已落后于源码 |

## 4. Apple API 边界复核

### 4.1 Widget 与 App Group

Apple 的公开路径与当前架构一致：使用 Widget Extension target 交付 Widget，并通过同一开发团队的 App Group 在 Host 与 Extension 之间共享数据。Apple 也明确说明 macOS App Group 可连接 sandboxed 与 nonsandboxed app，因此“nonsandboxed Host + sandboxed Widget”在平台边界上成立。

- [Creating a widget extension](https://developer.apple.com/documentation/widgetkit/creating-a-widget-extension)
- [Configuring app groups](https://developer.apple.com/documentation/xcode/configuring-app-groups)

但 WidgetKit 只承诺 glanceable、up-to-date，不承诺 Host 写入后立即刷新。`reloadAllTimelines()` 是请求系统重载，不是实时推送 SLA。因此 UI 不应标“实时”。

### 4.2 顶部岛 / 物理刘海

Apple 公布了 `NSScreen.safeAreaInsets` 和左右 auxiliary area，用于识别 camera housing 遮挡区。当前代码使用这些 API 是正确的：[NSScreen.safeAreaInsets](https://developer.apple.com/documentation/appkit/nsscreen/safeareainsets)。

但 Apple 没有给第三方 macOS app 一个“把自定义 resident UI 安装进物理刘海”的系统接口。当前 WorkPulse 是位于屏幕顶部的自绘 `NSPanel`，应称“顶部岛”或“刘海融合式浮层”，不能宣称是系统 Dynamic Island。

Apple 当前对 Live Activities 的 macOS 描述是显示在 **menu bar**；Dynamic Island 是 iPhone/iPad 上的呈现位置。因此若以后接入 ActivityKit，它可成为另一个系统管理的 menu bar 表面，但不能替代当前自绘物理刘海 UI：[ActivityKit](https://developer.apple.com/documentation/activitykit)。

### 4.3 通知

本地通知、foreground delegate 与 notification actions 都是 Apple 支持能力。系统可在 app 不运行时交付已经成功调度的本地通知，但 WorkPulse 当前的新事件发现依赖 Host 正在运行，因此“完全退出后仍发现新的 Codex 事件”不成立。[Scheduling a notification locally from your app](https://developer.apple.com/documentation/usernotifications/scheduling-a-notification-locally-from-your-app)

授权、声音、Alert、Focus、用户关闭通知等仍由系统和用户决定。当前代码只保留总授权状态，没有把 `alertSetting`、`soundSetting` 或 Focus 可见性纳入 diagnostics，因此 `authorized` 不能等同“banner 一定可见”。

### 4.4 分发

Apple 明确要求直接对客户分发的现代 macOS 软件使用 Developer ID、Hardened Runtime、secure timestamp，并在 notarization 产物中移除 `get-task-allow=true`。当前 build 9 不满足这一 Gate：[Notarizing macOS software before distribution](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)。

这与 Mac App Store 是两条不同路径。用户不需要为了本机伴生应用上架；只有向其他用户稳定分发时，才需要完成 Developer ID/notarization。

## 5. Codex 数据连接复核

### 5.1 本轮真实探针

在受限 sandbox 中，探针编译成功但 `codex app-server` 立即退出；在正常非 sandbox 环境中，同一探针通过：

```text
WorkPulse live probe passed: rateLimitBuckets=2; activeCodexTasks=2; values and names redacted
```

这证明当前 Mac、当前 Codex 版本和当前用户状态下连接可用，也证明 Host 不应直接迁移为 Mac App Store sandbox 架构而不做专项评估。

### 5.2 额度读取

`CodexRateLimitReader` 每 4 分钟启动本机 `codex app-server --listen stdio://`，完成 `initialize` 后调用 `account/rateLimits/read`。它当前可用，但本轮在 OpenAI 官方开发者文档域内没有找到该 method 的 published compatibility contract。

产品承诺只能是：

- 当前版本可读时显示 quota + reset；
- timeout、server exit、schema mismatch 时立即显示 unavailable；
- 不把 consumer ChatGPT subscription quota 与 API billing usage 混为一谈；
- 不承诺版本升级后零维护。

### 5.3 活动任务读取

`CodexRunningTaskReader`：

1. 只读打开 `~/.codex/state_5.sqlite`；
2. 查询未归档、非 subagent 的 `threads`；
3. 从 rollout 文件末尾向前扫描 lifecycle `event_msg`；
4. 从 `name/title/cwd` 生成展示名称。

它不会把 rollout 内容写入 Widget，Widget 只收到活动任务数量；但“只读元数据”也不能描述为“不读取文件内容”，因为实现确实扫描 rollout JSONL 内容，并可能使用 prompt 派生 title。首次默认展示任务名应改成显式 opt-in。

此外，2 秒一次、最多 50 个候选、每个文件最坏 32 MB 的扫描需要能耗与大文件压力测试。推荐缓存数据库 revision、rollout mtime/offset，只增量解析发生变化的任务。

## 6. 运行与产物证据

### 6.1 通过项

| Gate | 结果 |
|---|---|
| Xcode 26.6 / Swift 6.3.3 工具链 | Pass |
| 最新源码 Xcode Release，Host + Widget，`arm64 + x86_64`，不签名临时构建 | Pass |
| `.appex` 嵌入与 extension point | Pass |
| `verify_system_surfaces.sh` | Pass |
| `WorkPulseCoreVerify` | Pass，234 checks |
| `typecheck_widget.sh` | Pass |
| 非沙箱 Codex live probe | Pass，2 quota buckets，2 active tasks；值和名称未记录 |
| 已安装 Host/Widget strict `codesign` | 当前 Pass；本轮曾因钥匙串/证书信任状态报 `CSSMERR_TP_NOT_TRUSTED` |
| `verify_widget_runtime.sh` | Pass，Team `<APPLE_TEAM_ID>` |
| App Group snapshot | Pass，`widget.json` 于 2026-08-13 00:29 更新 |

### 6.2 未通过或不能计为完成

| Gate | 结果 | 原因 |
|---|---|---|
| 最新源码 signed artifact | Fail | 安装包和 ZIP 早于关键源码更新 |
| 单一 canonical Host / Widget registration | Pass after cleanup | 00:36 复测为 1 Host、1 Widget Extension、1 条 installed path 记录；早段重复状态已清理 |
| Widget Gallery 视觉搜索/添加/刷新/点击 | Not run cleanly | 当前运行环境被重复注册污染 |
| quota fresh→stale | Fail by design risk | 单 entry timeline + “实时”文案可能保留过期精确值 |
| 实际刘海 + 外接屏 + clamshell 全矩阵 | Not completed | 代码策略和 unit checks 通过，不等于真机视觉 Gate |
| 通知 Banner / Notification Center / Focus / 锁屏 | Not completed | 用户和系统设置相关，且当前多进程污染 |
| Developer ID / notarization / Gatekeeper | Fail | `spctl` rejected；Development entitlement |
| 生产 Needs You / Scheduled / Gmail | Fail | 无生产 adapter |

现有 full-product ZIP SHA-256：

```text
4f210375677a6df605a6ee09af1c1babab1633427d4caedd624861e6cfe9528c
```

该 hash 只能标识旧 build 9，不应作为最新源码的 release hash。

## 7. 可立即修复的问题

### P0：重新建立唯一、可追溯的验收产物

1. 已完成：停止临时与旧进程，清除 `/private/tmp` 重复 Widget 注册，只保留 `~/Applications/WorkPulse.app`。
2. 删除或明确废弃旧 `Xcode/WorkPulse.xcodeproj`，只保留根 `WorkPulse.xcodeproj` + `project.yml`。
3. 将版本由 build 9 提升为 build 10，避免同版本号对应两套不同二进制。
4. 从最新源码重新运行 full-product build、signed install、runtime verify；记录 ZIP hash、源码 commit/dirty state、Xcode 版本与签名 identity。
5. release Gate 同时断言 `security find-identity`、Authority chain、strict `codesign`、TeamIdentifier；不能因 TeamIdentifier 存在就忽略 trust failure。

**Gate P0-A**：清理部分已通过；最终仍需 build 10 的 Host/Widget Team、App Group、version 完全一致，钥匙串 identity 有效，Authority chain 可解析，ZIP 解压后 strict `codesign` 通过；`pgrep` 只有 1 个 canonical Host，`pluginkit` 只选择 installed path。

### P0：修正 Widget freshness 语义

1. 将“实时”改为“已同步”或“最近更新”。
2. timeline 同时生成当前 entry 与 `freshUntil + epsilon` 的 stale entry；不能只依赖 `.after(refresh)`。
3. stale entry 不突出精确剩余百分比；保留“打开 WorkPulse 更新”。
4. 做 Host killed、睡眠、系统延迟 reload、跨 reset 时间的验证。

**Gate P0-B**：即使 Host 退出且系统不立即 reload，过 `freshUntil` 后桌面不再把旧百分比显示为当前额度。

### P0：修复安装脚本的多实例风险

`install_signed_product.sh` 当前替换 bundle 前不终止旧 Host，并用 `open -n` 强制新实例。应：

- 只终止目标 bundle 的旧实例；
- 原子替换并保留可恢复备份；
- 使用普通 `open`；
- 应用自身增加 single-instance 保护；
- 安装后断言唯一 PID 与唯一 canonical extension path。

### P1：通知路由与诊断

- `needsApproval/needsInput/workLossRisk/quotaPaused` 当前只要 overlay 可达就优先 6 秒顶部 Alert，即使用户已离开；改为用户不活跃时优先系统通知。
- diagnostics 增加 `authorizationStatus`、`alertSetting`、`soundSetting` 与最近一次 request accepted/failed；不记录通知正文。
- 不把 `center.add` 成功写成“通知已展示”。

### P1：Codex adapter 的版本与隐私防护

- 任务名称默认关闭，首次由用户明确开启。
- 明确披露“只读扫描本地 Codex lifecycle 日志与任务 title”，不要写成完全不读文件内容。
- 给 `account/rateLimits/read`、SQLite schema、rollout event schema 增加 capability probe 与版本错误分类。
- 将 2 秒全量候选扫描改为基于 DB revision、mtime/offset 的增量读取，并做 CPU/energy Gate。

### P1：清理工程与文档漂移

- `README.md` 仍写“没有有效 codesigning identity”“已安装包 ad-hoc、没有 TeamIdentifier”，已与当前事实冲突。
- Widget 文件保留 `QuotaPulseView`、`QuickView`、`PinnedRoutineView`、`DailyOverviewView` 等旧视图，与新 `Pulse*` 视图并存，应删除死代码，避免后续误改旧 UI。
- 发布 Gate 应自动拒绝“源码比 ZIP 新”的产物。

## 8. 仍依赖用户、Apple 账号或外部平台的 blocker

| Blocker | 谁能解除 | 说明 |
|---|---|---|
| 通知授权、Focus、声音、锁屏展示 | 当前 Mac 用户 | 应用不能绕过系统和用户选择 |
| Widget Gallery 手工添加与最终视觉确认 | 当前 Mac 用户 / UI 自动化 | 代码和注册记录不能替代桌面真实截图与点击 |
| 外部分发 Developer ID | Apple Developer Program 账号持有人 | Personal Team 的 Apple Development 证书只够本机开发 |
| notarization credentials 与提交 | Apple Developer Program 账号持有人 | 不需要 App Store Review，但需要 Apple notary service |
| Codex app-server/SQLite 稳定契约 | OpenAI | 当前实现可用不等于未来版本兼容；WorkPulse 只能做好降级和版本检测 |
| Gmail/Scheduled/Daily Brief 实时数据 | OpenAI 或独立的授权数据源 | 当前没有官方 adapter；不能用 UI 模拟替代真实能力 |

## 9. 最小完成顺序与验证 Gate

1. **环境清洁 Gate（已通过）**：结束旧实例，移除临时注册；唯一 Host、唯一 canonical Widget path。安装脚本仍需修复以防复发。
2. **Artifact Gate**：build 10，从最新源码构建，Personal Team/App Group/versions/architectures/codesign 全一致；同时验证 identity 与 Authority trust，记录 hash。
3. **Widget Data Gate**：Host 写、Extension 读；fresh/stale/unavailable/corrupt/future-schema；Host killed 后不冒充实时。
4. **Widget Gallery Gate**：Small quota、Small pinned、Medium、Large 均能搜索、添加、刷新、点击；Light/Dark 和大字号无裁切。
5. **Top Surface Gate**：内建刘海屏 + 外接屏、断开/重连、clamshell、全屏、锁屏；所有 Resident/Alert/Expanded 都落在预期屏且不被 camera housing 遮挡。
6. **Notification Gate**：authorized/denied、Alert off、Sound off、Focus、foreground/background、snooze/deep link；一次事件最多一个主动 surface。
7. **Codex Drift Gate**：app-server 缺 method、SQLite 缺 table/column、rollout unknown event、Codex 不存在、timeout；全部安全降级，不显示假值。
8. **Local Completion Gate**：连续 dogfood 24 小时，无重复 Host、重复通知、Widget 旧值冒充实时或顶部岛跳到错误显示器。
9. **External Pilot Gate（若需要）**：Developer ID、Hardened Runtime、timestamp、notarization、staple、`spctl` pass，另一台干净 Mac 安装通过。

## 10. 最终产品承诺建议

完成 P0 与本机 Gate 后可以承诺：

- 本机显示 Codex 剩余额度和下次重置时间；
- 将一个 ChatGPT/Codex HTTPS 对话保存为桌面快捷入口；
- 通过菜单栏、顶部自绘浮层和系统通知呈现 WorkPulse 已验证的本地事件；
- 顶部浮层优先留在内建 Mac 屏幕，clamshell 时回退外接主屏；
- 无独立主页面，不要求上架 App Store。

仍不能承诺：

- Widget 或顶部岛“实时”刷新；
- macOS 原生 Dynamic Island；
- WorkPulse 能读取所有 ChatGPT consumer quota；
- 自动理解任意 Scheduled task、Gmail Daily Brief 或对话内容；
- Codex 内部 app-server/SQLite 在未来版本永远兼容；
- 未经 Developer ID/notarization 即可稳定分发给其他用户。
