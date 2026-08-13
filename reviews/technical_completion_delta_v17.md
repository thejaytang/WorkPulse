# WorkPulse build 17 技术完成度 Delta 终审

> 审查时间：2026-08-13（Europe/Oslo）  
> 审查对象：已安装 `~/Applications/WorkPulse.app`，版本 `0.3.1 (17)`，及同源 ZIP / 源码  
> 角色：独立技术实现审查  
> 限制：仅运行只读检查、临时构建/探针和隔离通知 QA；未修改应用源码

## 1. 最终判定

### 本机个人使用：Go with constraints

build 17 已经关闭了此前最关键的“伪完成”问题：它不是只有 Widget 源码或模拟器，而是一个真实安装、团队签名、包含 `.appex`、能进入 macOS Widget Gallery、能添加桌面实例并点击回流 quota 表面的本机伴生应用。

本机核心闭环成立：

1. Resident 固定以 quota + reset 为主信息，运行任务退为次级计数。
2. 物理刘海使用深色融合表面，不跟随浅色主题变成白卡。
3. Widget Gallery 可发现 WorkPulse；Small Quota 已添加到桌面并实际点击回流 quota。
4. App Group 正在发布 production quota snapshot，Widget Extension 从同一容器读取。
5. 系统通知已授权，Alert、Notification Center、Sound 均 enabled；系统返回真实 delivered request ID。
6. 当前 ZIP、已安装 Host 和 Widget 二进制完全一致，版本、Team、App Group 与源码构建号一致。

### 对外分发：No-Go

当前仍是 `Apple Development` Personal Team 构建，包含 `get-task-allow=true`：

- `spctl --assess`：`rejected`；
- `stapler validate`：无 notarization ticket；
- 没有 Developer ID Application 签名；
- 没有 notarization / staple；
- 没有另一台干净 Mac 的安装、升级与卸载验证。

因此它适合当前 Mac 的个人 dogfood，不是可以交给外部客户的正式 ZIP/DMG。用户无需为个人伴生应用上架 App Store；若要外部分发，可选 Developer ID + notarization，或另行评估 Mac App Store。

### 产品数据边界：仍是 Technical Preview

Codex quota 和活动任务在当前环境真实可用，但分别依赖本机 `codex app-server` method、内部 SQLite schema 与 rollout lifecycle 文件。这些不是 WorkPulse 可控制的稳定公共契约，必须保留显式 unavailable、版本探针和升级回归 Gate。

## 2. build 17 身份与可追溯性

| 项目 | 本轮结果 |
|---|---|
| 安装版本 | `0.3.1 (17)` |
| Project build number | Host / Widget 均为 `17` |
| 安装路径 | `~/Applications/WorkPulse.app` |
| ZIP | `native/WorkPulseNative/build/full-product/WorkPulse-full-product.zip` |
| ZIP SHA-256 | `26152c1cd556f7b181941aaee434fc82cbd24cc89a955b5e5390cd0c8637b63a` |
| Host 架构 | universal `arm64 + x86_64` |
| Widget 架构 | universal `arm64 + x86_64` |
| ZIP 与安装 Host | byte-for-byte identical |
| ZIP 与安装 Widget | byte-for-byte identical |
| TeamIdentifier | `<APPLE_TEAM_ID>` |
| App Group | `<APPLE_TEAM_ID>.com.workpulse.shared` |
| Host / Widget strict codesign | Pass（真实用户安全会话） |
| PlugInKit | 1 条，唯一 canonical installed path |
| 运行实例 | 1 Host + 1 Widget Extension |

关键源码时间均不晚于 build 17 产物；不存在 build 9/15 时“安装包早于源码”的问题。

## 3. 签名矛盾的最终解释

此前出现的：

```text
0 valid identities found
CSSMERR_TP_NOT_TRUSTED
```

不是另一个用户、另一个 keychain domain，也不能据此判断证书瞬时失效。相同 `uid=501 tang`、相同 default/list keychain：

```text
<user-login-keychain>
```

在普通受限 sandbox 命令中，`security find-identity` 看不到完整 trust material，返回 0；同一分钟在真实用户安全会话、非 sandbox 环境中连续三次均返回：

```text
Apple Development: <REDACTED_APPLE_ID> (MSXF4K32LD)
1 valid identities found
```

且 build 17：

- Authority 链为 Apple Development → WWDR → Apple Root CA；
- `TeamIdentifier=<APPLE_TEAM_ID>`；
- Host + nested Widget strict `codesign` 通过。

因此正确结论是：

> **Personal Team 本机签名当前有效；sandbox 内的 Keychain/Trust 结果不具备 release 判定力。签名 Gate 必须在真实用户安全会话执行。**

这取代任何“证书曾瞬时失效”的旧解释。

## 4. 核心表面终审

### 4.1 Widget Gallery / 桌面实例 / 点击回流

| Gate | 状态 | 证据与边界 |
|---|---|---|
| `.appex` 构建和嵌入 | **Pass** | Host 内为真实 WidgetKit Extension，extension point 正确 |
| 同 Team / 同 App Group | **Pass** | 实际 signed entitlements 一致；Widget sandbox 开启 |
| PlugInKit 唯一注册 | **Pass** | 只有 installed app 的 1 条记录；无 `/tmp` / DerivedData 重复记录 |
| Gallery 可发现四个 kind | **Pass** | 本轮同源验收记录确认 Gallery 识别 Small Quota、Small Pinned、Medium、Large |
| 桌面添加 | **Pass** | 已添加一个真实 `WorkPulseQuota` 实例，而非 WidgetKit Simulator |
| production snapshot | **Pass** | 桌面值来自 team-scoped App Group；快照为 `privacyClass=generic`、2 个 quota bucket |
| quota 点击回流 | **Pass** | 实际点击 Small Quota 后回到顶部 quota alert；运行任务不会抢占 `workpulse://usage` |
| Widget 自动 freshness 切换 | **Supported by code / runtime scheduling constrained** | timeline 已加入 `freshUntil + 1s` future entry，stale 不突出精确百分比；仍由 WidgetKit 决定实际调度时机 |
| 四个 kind 全部逐一添加/点击 | **未完全证明** | 当前有真实 Small Quota 闭环；没有四个 kind 各自的桌面添加、Light/Dark、大字号和点击证据 |

Widget 已不再标“实时”，fresh 时写“已同步”，stale 时写“需更新”，避免把 WidgetKit 周期快照冒充实时数据流。

### 4.2 App Group 快照

本轮只读观测：

```text
schemaVersion = 5
privacyClass = generic
quotaBuckets = 2
routineCapability = manualPin
```

快照真实存在且持续更新，revision 超过 3,000；没有向 Widget 发布任务标题或消息正文。Host 写入与 Extension 读取的基本链路成立。

但发现一个新的稳定性问题：任务数量保持 3 不变时，10 秒内 snapshot revision 从 `3310` 增至 `3314`，即写入 4 次。原因是：

1. task reader 每 2 秒轮询；
2. rollout 文件 `mtime` 被映射为 `lastActivityAt`；
3. `previousTasks != tasks` 因时间变化成立；
4. 每次调用 `publishWidgetSnapshotIfAvailable()`；
5. `writeNext` 后调用 `WidgetCenter.shared.reloadAllTimelines()`。

这不是正确性 blocker，但会造成不必要的磁盘写入、WidgetKit reload throttling 和能耗。应只在 Widget 可见 DTO 发生变化时写入，例如任务 count、quota、routine、theme 或 freshness boundary，而不是每次 lifecycle 日志 mtime 改变都写。

### 4.3 顶部岛 / 物理刘海 / 多显示器

已关闭：

- Resident 主标题始终为 quota；任务只显示 `● N`。
- Expanded 同时显示 quota、其他 bucket 和活动任务。
- fresh install 默认 Privacy Mode；任务名可由用户临时显示 10 秒，然后自动隐藏。
- `usesDarkSurface = isNotchScreen || isDarkSurface`，物理刘海 Resident / Alert / Expanded 始终深色。
- 使用 `safeAreaInsets`、左右 auxiliary areas 计算物理 camera housing。
- 显示器策略为 built-in+notch → built-in → main → first，不跟随鼠标或前台窗口。

仍有约束：

- 这是自绘 `NSPanel` 顶部岛，不是 Apple 的 macOS Dynamic Island 系统 API。
- “深色融合”已由源码和本机验收确认，但工作区未保存同一 build 的 Light/Dark × 内建/外接四格截图，无法做逐像素接缝审计。
- clamshell、全屏 App、Stage Manager、菜单栏自动隐藏、显示器热插拔后的连续运行矩阵仍未完整保留证据。
- 当前 navy-black 是否在不同亮度下与硬件刘海无接缝，仍是视觉 QA，不是 API 可行性问题。

### 4.4 系统通知

本轮运行真实已安装 App 的隔离 QA 模式，系统返回：

```json
{
  "authorizationStatus": 2,
  "alertSetting": 2,
  "notificationCenterSetting": 2,
  "soundSetting": 2,
  "deliveredRequestIDs": [
    "workpulse.qa-preview.…",
    "workpulse.qa-preview.…"
  ]
}
```

`2` 对应 authorized/enabled。原始 build 17 验收时已有 1 个 delivered QA ID；本次独立复测又调度一条使用新 UUID 的手动预览，因此当前列表为 2。这不是生产去重失败，QA 设计本来就为每次预览生成唯一 ID。

已验证：

- 用户授权真实存在；
- Alert、Notification Center、Sound 均 enabled；
- `UNUserNotificationCenter.add` 调度成功；
- 系统 delivered 列表真实出现请求；
- QA 文案明确是本机预览，不冒充真实任务；
- category、OPEN、LATER、deep link handler 已实现；
- quota crossing 以 limit/cycle 持久化去重；
- event 使用 EventLedger ownership；
- task terminal 只有明确 terminal event 才触发，request ID 稳定。

仍未完全关闭：

- 没有通知点击后回流目标表面的本轮 UI 证据；这里只验证了 Widget 点击回流。
- 没有 Banner 像素截图或声音录制；delivered 不等于用户一定看到了 Banner。
- Focus、锁屏、Alert off、Sound off、Notification Center off 的降级矩阵没有完整跑完。
- production `needsApproval` / `needsInput` adapter 尚不存在，因此其通知只能测试投递框架，不能称已监听真实 ChatGPT 事件。

另外，`DeliveryPolicy` 对 approval/input 类事件在用户不活跃时仍优先可达 overlay，而不是通知；如果未来接入生产 adapter，应与 long-task completion 一样在用户离开时优先系统通知，否则 6 秒顶部 Alert 可能被错过。

## 5. Codex 数据连接稳定性

### 5.1 本轮真实结果

非 sandbox live probe：

```text
WorkPulse live probe passed: rateLimitBuckets=2; activeCodexTasks=2; values and names redacted
```

测试与类型检查：

| Gate | 结果 |
|---|---|
| `verify_system_surfaces.sh` | Pass |
| `WorkPulseCoreVerify` | Pass，242 checks |
| Widget source type-check | Pass |
| Codex live probe | Pass |

### 5.2 quota reader

实现通过 `codex app-server --listen stdio://` 初始化，再调用 `account/rateLimits/read`，8 秒 timeout；解析多个 quota bucket，失败时回落 unavailable。

当前能工作，但没有发现 OpenAI 官方 published compatibility contract 保证该 method 长期稳定。正确产品承诺是“当前本机 Codex 版本可读”，不是“ChatGPT consumer quota 的长期公共 API”。

### 5.3 task reader

实现只读打开 `~/.codex/state_5.sqlite`，查询 `threads`，再扫描 rollout JSONL 最后最多 32 MB，识别 started/completed/cancelled/failed/aborted。

改进点：

- 明确终态才提醒，已关闭“任务消失就误报完成”。
- subagent 被过滤；Widget 只收任务数量；默认 Privacy Mode 避免标题暴露。
- 但 2 秒 × 最多 50 candidates × 每个最坏 32 MB 的轮询仍需 Energy Log 与大文件压力测试。
- 应缓存 DB revision、rollout inode/mtime/offset，只对变化文件增量解析。
- SQLite table/column 或 event type 变化时只能安全降级，不能推断任务完成。

## 6. Personal Team 与正式分发边界

| 用途 | build 17 状态 | 判定 |
|---|---|---|
| 当前 Mac 本机安装 / dogfood | Apple Development Personal Team、strict codesign Pass | **Go** |
| 同账号开发测试 | 取决于 Apple Development provisioning 与目标机器 | **Constrained** |
| 把 ZIP 发给普通外部用户 | `spctl rejected`，无 notary ticket | **No-Go** |
| Developer ID 直销 | 无 Developer ID、notarization、staple、更新与许可体系 | **Not implemented** |
| Mac App Store | Host 依赖非 sandbox Codex 子进程与本地状态访问，未做 sandbox 可行性验证 | **Not evaluated / likely architecture change** |

Apple Development TeamIdentifier 和 App Group 证明“本机 Widget 能运行”，不能替代 Developer ID/notarization 的客户分发 Gate。

## 7. 仍未关闭的真实 blocker

### 对本机核心使用不构成 blocker，但应修复

1. **P1：Widget snapshot/reload 写放大。** 10 秒 4 次写入，需按 external DTO 变化去重并对 reload 做 debounce。
2. **P1：task reader 能耗与版本漂移。** 2 秒全量扫描需要增量缓存、Energy Log 和 Codex 升级回归测试。
3. **P1：通知完整矩阵。** 通知点击回流、Focus、锁屏、Alert/Sound off 仍缺 E2E。
4. **P1：多显示器长期矩阵。** clamshell、全屏、自动隐藏菜单栏和热插拔证据未完整保存。
5. **P2：四种 Widget 的逐一 QA。** Small Quota 已完整闭环；Small Pinned、Medium、Large 仍缺每种尺寸的桌面添加、点击、Light/Dark、大字号与 stale 证据。

### 对宣称“真实 ChatGPT 工作提醒”构成 blocker

1. **Needs You 生产 adapter 不存在。** 当前 approval/input event 只有 controlled fixture。
2. **Scheduled/Gmail/Daily Brief 状态源不存在。** Small Pinned 只是 HTTPS 快捷入口，不读取 Gmail 或对话运行状态。
3. **Codex reader 无稳定公共契约。** 只能标 Technical Preview 并做好 failure-safe 降级。

### 对外部分发的硬 blocker

1. Developer ID Application 证书与签名。
2. Hardened Runtime distribution export，移除 `get-task-allow=true`。
3. secure timestamp、notarization、staple，`spctl` Pass。
4. 干净 Mac 的安装、升级、登录启动、Widget Gallery、卸载验证。
5. 若收费：明确 Mac App Store 或 Developer ID 直销，并实现对应 purchase/license/update/restore 闭环。

## 8. 最小下一步顺序

1. 先修 snapshot/reload 写放大：10 分钟稳定任务状态下，App Group 写入与 `reloadAllTimelines()` 不超过 1 次；quota/routine/theme 变化仍能及时刷新。
2. 完成通知点击回流与 Focus/锁屏矩阵；每个 production event 最多一个主动 surface，QA preview 单独统计。
3. 跑 30 分钟 Energy Log：3 个活动任务、50 个候选、大 rollout 文件；task reader 不造成持续高 CPU/磁盘读。
4. 补齐 Small Pinned、Medium、Large 的真实桌面矩阵，或基于产品价值把首发范围收缩为两个 Small。
5. 只有决定外部分发后，再投入 Developer ID/notarization/付费与更新通道。

## 9. 可对用户承诺与不可承诺

### 现在可以承诺

- 当前 Mac 能在菜单栏、顶部岛和桌面 Widget 查看 Codex quota + reset。
- Small Quota 可从真实 macOS Widget Gallery 添加并点击回到 quota 表面。
- 可以把一个 HTTPS ChatGPT/Codex 对话保存为桌面快捷入口。
- 活动 Codex 任务可作为本机 Technical Preview 计数；明确终态可触发顶部/通知框架。
- 默认 Privacy Mode 不把任务标题写入 Widget。
- 应用没有独立 Dashboard，也不要求为了本机使用上架 App Store。

### 仍不可承诺

- Widget 是实时数据流，或 WidgetKit 每次都即时刷新。
- 顶部岛是 Apple 原生 macOS Dynamic Island。
- WorkPulse 能监听所有 ChatGPT 审批、输入、Scheduled、Gmail 或 Daily Brief。
- `account/rateLimits/read`、`state_5.sqlite` 和 rollout schema 永久兼容。
- 当前 Personal Team ZIP 可稳定分发给外部用户。

## 10. 放行结论

| 范围 | 判定 |
|---|---|
| 当前 Mac 的 quota-first Resident | **Go** |
| Small Quota Widget 本机闭环 | **Go** |
| Small Pinned / Medium / Large | **Conditional Go**，技术可用，逐尺寸 E2E 与产品价值仍待补齐 |
| 本机系统通知框架 | **Go with constraints**，authorized + delivered 已证实，点击/Focus/锁屏矩阵待补 |
| Codex quota / task reader | **Technical Preview** |
| 真实 Needs You / Scheduled / Gmail 状态 | **No-Go** |
| 本机个人 dogfood | **Go** |
| 外部免费或收费分发 | **No-Go**，等待 Developer ID/notarization 与干净机 Gate |
