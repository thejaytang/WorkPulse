# WorkPulse build 19 最终独立技术 Delta

> 审查时间：2026-08-13（Europe/Oslo）  
> 审查对象：当前稳定工作树、已安装 `~/Applications/WorkPulse.app`、同源 build 19 ZIP  
> 范围：250 checks、Widget 深色背景、签名/App Group/ZIP 一致性、任务读取性能、通知 delivered/open 边界  
> 限制：只读源码与运行态；未修改产品源码

## 1. 最终结论

build 19 可以继续作为当前 Mac 的个人 dogfood，且相较 build 18 已真实关闭三个技术 P1：

1. **TaskReader 重复全量扫描已关闭。** 新增进程内 lifecycle cache 和增量 tail scan；同口径 30 次基准的平均耗时下降约 91%，峰值 RSS 下降约 90%。
2. **Widget 深色背景实现缺口已关闭。** 深色/浅色背景不再依赖可能被 WidgetKit 重写的环境顺序；每个正式 Widget 都保留自定义 container background，前景色与背景由同一个 resolved theme 驱动。
3. **Widget reset 与重复 timeline boundary 已关闭。** reset 后不再突出旧百分比，timeline date 已去重。

签名、App Group、ZIP、已安装 Host/Widget 和 PlugInKit 运行态本轮全部一致。250 项 CoreVerify、system-surface verification、Widget type-check、runtime verifier 均通过。

唯一不能升级为“完整闭环”的核心项仍是通知点击：build 19 已证明 preview 和 task-terminal request 进入 Notification Center 的 delivered 列表，但没有本次点击回调记录，不能声称用户点击后已回到正确顶部任务结果。

| 范围 | 判定 |
|---|---|
| build 19 当前 Mac 本机使用 | **Go with constraints** |
| 250 Core checks | **Pass** |
| Widget 深色背景实现与同源安装 | **Pass** |
| TaskReader 增量缓存性能修复 | **Pass** |
| Host/Widget/ZIP/Team/App Group | **Pass** |
| 通知 request accepted + Notification Center delivered | **Pass** |
| 通知 click/open/action E2E | **Not proven** |
| 长期整机 Energy Log | **Constrained / 未完成** |
| 外部普通用户分发 | **No-Go** |

## 2. 可重复验证 Gate

### 2.1 自动验证

本轮独立执行：

```text
WorkPulseCore verification passed: 250 checks
WorkPulse system-surface verification passed
WorkPulse Widget source type-check passed
verify_widget_runtime.sh: PASS
```

250 checks 中包含 build 19 新增的 task cache append-terminal 与 append-restart 回归：首次识别运行态后，追加 terminal event 会从活动列表移除，再追加新的 start event 会重新识别为运行。

必须正确解释这些 Gate：

- CoreVerify 是模型、策略、序列化、fixture 和 parser 的可执行验证；
- system-surface script 主要是源码/配置断言；
- Widget type-check 证明当前 Widget 源码可编译；
- runtime verifier 证明 `.appex` 已嵌入、严格验签且 PlugInKit 指向 canonical 安装路径；
- runtime verifier 自身明确提示，CLI 不能替代 Gallery、真实桌面、刷新和点击验收。

### 2.2 产物没有落后于源码

当前核心源码最后修改时间均早于 ZIP；没有发现比 build 19 ZIP 更新的 Host/Widget 产品源码。当前 ZIP 不是旧源码残留产物。

## 3. build 19 身份、签名与安装一致性

| Gate | 本轮结果 |
|---|---|
| Host 版本 | `0.3.1 (19)` |
| Widget 版本 | `0.3.1 (19)` |
| ZIP SHA-256 | `c39ceb015978dd9d57fa56632b8c85ccc850baf5b678bbf2ccb6f0db5bd39a71` |
| ZIP Host vs installed Host | byte-for-byte identical |
| ZIP Widget vs installed Widget | byte-for-byte identical |
| Host strict `codesign` | Pass，真实用户安全域 |
| nested Widget strict `codesign` | Pass，真实用户安全域 |
| Host / Widget Team | `<APPLE_TEAM_ID>` |
| Host / Widget App Group | `<APPLE_TEAM_ID>.com.workpulse.shared` |
| Widget sandbox | enabled |
| PlugInKit | 1 条，canonical installed path |
| 运行实例 | 1 Host + 1 build 19 Widget Extension |

最终重建时间为 06:49，源码晚于 ZIP 的文件数为 0。最终 ZIP 与 installed Host/Widget 再次 byte compare 均为 0（identical）；安装前版本保留于 `/tmp/WorkPulse-before-signed-20260813-065008.app`，用于失败恢复而非运行注册。最后一项 single-task terminal Alert 的专属 expanded content 已进入该最终 SHA，不再存在“源码晚于安装包”的中间状态。

Authority 链为 Apple Development → WWDR → Apple Root CA。Host 与 Widget 都含 `get-task-allow=true`；这适合 Personal Team 本机开发安装，不等于 Developer ID、notarization 或 Mac App Store 分发资格。

安装器相较 build 18 已将 `pluginkit -r` 改为 fail-fast，注销失败会保留现有安装并取消升级。但以下发布级边界仍未关闭：

1. installer 没有在替换前精确比较 Host Team = Widget Team、两者 App Group、Host/Widget build number；
2. 旧 App 移到 `/tmp` backup 后，后续复制/注册/启动失败没有自动 rollback；
3. post-install 没有自动执行完整 runtime verifier 并在失败时恢复旧版本。

这些不否定当前 build 19 安装的一致性，但仍阻止把脚本称为发布级 updater。

## 4. Widget 深色背景真实修复

### 4.1 完整证据链

当前生产 App Group snapshot 为：

```text
schemaVersion=5
themePreference=dark
accentPreference=violet
quota.provenance=liveCodexAppServer
runningTasks.count=2
```

build 19 的渲染链为：

1. `PulseWidgetAppearance` 从 snapshot 解析 `resolvedColorScheme`；
2. 通过独立 `pulseWidgetDarkSurface` environment value 传递布尔状态；
3. 根级显式设置深色前景 `RGB(0.94, 0.96, 1.00)`；
4. `PulseWidgetBackground(darkSurface:)` 显式选择深色 `RGB(0.055, 0.075, 0.12)` 或浅色背景；
5. Small Quota、Small Pinned、Medium Quick、Large Overview 和 unavailable states 全部调用该背景；
6. 四个 Widget configuration 均使用 `.containerBackgroundRemovable(false)`，防止系统移除主题背景后形成白字浅底；
7. 已安装 Widget binary 与 ZIP 内 Widget byte-identical，当前 extension 正从 canonical installed path 运行。

因此它不是 HTML/demo 或未打包源码修复，而是进入了已安装 build 19 的真实 Widget Extension。

团队同一 build 19 的主视觉验收已确认桌面深色背景正常。本独立复核尝试重新截取桌面时 Mac 已锁定，无法再生成第二份未锁屏截图；所以本报告独立验证了实现、snapshot、同源二进制和运行 extension，像素级第二次复现依赖主验收记录。若要形成完全可审计证据，应保存带 build number 的桌面 Small Quota/Pinned 深色截图。

### 4.2 timeline truth 同时修复

- transition dates 现在使用 `Set` 去重后排序；
- `PulseWidgetCopy.isCurrent` 同时要求 freshness 为 fresh 且 `entry.date < resetsAt`；
- reset 后旧百分比不再被标为“已同步”或突出显示；
- Widget 仍通过 future entries 表达 fresh → stale/reset，`.after(30 min)` 只是请求，实际刷新时机仍由 WidgetKit 决定。

结论：深色背景和 reset truth 均 **Pass**；“实时刷新”仍是不允许的产品承诺。

## 5. TaskReader 性能

### 5.1 build 19 改动

`CodexTaskLifecycleCache` 以 rollout path 缓存 file size、mtime 与 latest lifecycle event：

- size + mtime 未变化时直接返回缓存；
- 文件增长时只扫描上次尾部 256 KiB overlap 到当前尾部；
- 单次安全扫描上限仍为 32 MiB；
- cache 由 lock 保护，最多保留 256 个 path；
- Host 仍每 5 秒读取 SQLite candidate metadata，但不再对未变化的大 rollout 重复做 JSON/Data 全量尾部扫描；
- 同一轮多个 disappeared task 现在全部检查 terminal outcome，不再只处理第一个。

### 5.2 同口径独立基准

当前真实 Codex 数据，最近 48 小时 9 个候选、rollout 总量约 1.18 GiB、最大文件约 635 MiB、当前活动任务数始终为 2。

30 次连续 `read(maximumCandidates: 50)`：

| 指标 | build 18 | build 19 | Delta |
|---|---:|---:|---:|
| avg/read | 79.408 ms | 7.073 ms | 约 -91.1% |
| p95 | 87.299 ms | 6.254 ms | 约 -92.8% |
| max | 100.712 ms | 147.051 ms | 首次冷扫描 outlier |
| user + sys CPU | 2.33 s | 0.15 s | 约 -93.6% |
| maximum RSS | 349.6 MB | 35.6 MB | 约 -89.8% |
| block input operations | 0 | 0 | warm OS cache |

CoreVerify 内置 live probe 的另一轮结果为：

```text
tasks=2 avg=7.81ms p95=2.88ms
```

平均高于 p95 是因为首次冷扫描单点明显高，后续 cache hit 很低。build 19 的目标是降低长期重复成本，因此这个分布符合预期。

### 5.3 已安装进程样本

30 秒前后同一 build 19 Host：

```text
CPU TIME  0:20.51 → 0:21.47  (+0.96 s / 30 s)
RSS       236,176 → 179,264 KiB
```

该窗口约为单核 3.2%，相较 build 18 同口径约 6.9% 明显下降。这个进程样本还包含 quota、SwiftUI、overlay 和系统回调，不能全部归因于 TaskReader。纯 reader 的 warm p95 约 6 ms / 5 秒，约占单核 0.12%，说明 v18 的 TaskReader 性能 P1 可以关闭。

仍需保留两个边界：

1. 没有 30 分钟 Instruments Energy Log，不能据 30 秒样本宣布整机长期能耗完成；
2. cache key 没有 inode/file identity。文件 truncate 或 path replacement 后，如果新文件没有 lifecycle event，`resolved = newlyObserved ?? previous.event` 会保留旧 event；应在 size 变小或 inode 变化时禁止 fallback 到旧 event，并增加 truncate/replace fixture。

结论：增量缓存性能修复 **Pass**；长期整体能耗和 rare rotation correctness 为 **Constrained**。

## 6. 通知 delivered 与 click 边界

### 6.1 build 19 delivered 已证实

build 19 通知 QA 诊断文件更新时间为 06:41；随后 06:49 的最终重建只增加 single-task terminal Alert 的专属 expanded content，通知调度器与 delivered transport 没有再变化。系统返回：

```text
authorizationStatus=2
alertSetting=2
notificationCenterSetting=2
soundSetting=2
deliveredRequestIDs:
  - 3 个 workpulse.qa-preview.*
  - 1 个 workpulse.task-terminal.*
```

build 18 诊断此前只有两个 preview ID；build 19 QA 新增一个 preview 和一个真实 task-terminal request。最终 SHA 未再次制造额外通知打扰，因此 delivered 列表证据来自同版本、同通知 transport 的前一次 build 19 QA，而不是 06:49 重装后的新 request。可以确认：

- 授权、Alert、Notification Center、Sound 均 enabled；
- build 19 `center.add` 成功；
- preview transport 进入 delivered list；
- 明确 task terminal 也进入 delivered list；
- 多任务终态收集与 task outcome payload 已进入当前可编译、已安装同源代码。

`delivered` 的正确含义仍只是“系统当前可在 Notification Center delivered API 中查询到”，不等于 Banner 一定出现、声音一定被听到或用户一定注意到。

### 6.2 click/open 仍未证实

build 19 已实现 notification callback 到任务结果顶部层：`onOpenNotification` → `handleNotificationOpen` → `showTaskNotificationReturn`，并在 callback 时写 `workpulse.lastNotificationOpenAt`。

本轮读取当前 defaults 没有发现 `workpulse.lastNotificationOpenAt`。因此没有证据证明上述任一 delivered request 被点击，也不能宣布 task notification 已成功回到正确结果表面。

源码仍有这些语义边界：

1. `didReceive` 先调用 `completionHandler()`，再异步执行 open/snooze；
2. 所有非 `LATER` action 都进入 open 分支，没有显式限制为 default action 与 `OPEN`；
3. 只记录一个最后打开时间，没有 request ID、action ID、route 和 handled result，无法与某条 delivered request 一一核对；
4. Event `LATER` 仍只是 ledger snooze，未证明一小时后会产生新系统通知；
5. quota 流程的 `delivered` 变量仍同时表示 overlay presented 或 notification request accepted，命名不够严格。不过 build 19 已增加 `userIsActive` 条件，用户离开时不会再用 6 秒 overlay 阻断 notification fallback。

最小 click Gate：

1. 清空或记录基线 `lastNotificationOpenAt`；
2. 生成一个稳定 request ID 的 QA preview；
3. 在 App background 和 terminated 两种状态分别点击默认通知与 `OPEN`；
4. 验证顶部返回表面、timestamp 更新，并保存 request ID/action/route/result receipt；
5. task-terminal 点击后验证 outcome 与隐私文案；
6. LATER 使用短延时 QA 证明 pending → delivered，而非只验证 ledger hidden。

结论：通知 transport **Pass**；click/open **Not proven**。

## 7. 仍未关闭的真实项

### 当前 Mac 核心使用不阻塞，但需要后续 Gate

1. **P1：notification click/open E2E。** delivered 已证实，点击仍无 receipt。
2. **P2：TaskReader truncate/path replacement。** cache 需要 file identity 与禁止旧 event fallback。
3. **P2：30 分钟整体 Energy Log。** 纯 reader 已显著达标，Host 总体仍需长期证据。
4. **P2：installer rollback 与 exact identity recheck。** 当前安装一致，但升级失败恢复还不完整。
5. **P2：可审计视觉资产。** build 19 深色桌面已由主验收确认，应保存带版本证据的 Small Quota/Pinned 截图。

### 产品与分发边界不变

1. Codex quota 仍依赖本机 app-server method，TaskReader 仍依赖内部 SQLite/rollout schema，均为 **Technical Preview**。
2. production Needs You adapter 不存在；approval/input 仍不能称为真实监听。
3. Gmail/Scheduled/Daily Brief 仍只有固定入口，不读取执行状态。
4. Personal Team、`get-task-allow=true`、无 Developer ID/notarization/staple，外部分发仍 **No-Go**。

## 8. 最终放行

build 19 可准确描述为：

> 已安装、团队签名、具有真实 macOS Widget Extension 的本机 WorkPulse 伴生应用。深色 Widget、额度/reset、固定入口、顶部岛、Codex task 增量监测和系统通知 transport 已工作；Widget 由 macOS 调度，通知 delivered 不等于用户已看到或点击成功。

不应描述为：

- “通知点击闭环已完成”；
- “Widget 实时刷新”；
- “已读取 Gmail/Scheduled/Daily Brief 状态”；
- “可以直接发给外部用户安装”。

最终判定：**build 19 本机核心产品 Go with constraints；通知 click E2E 与外部分发继续 No-Go。**
