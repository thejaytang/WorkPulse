# WorkPulse build 18 技术完成度 Delta 18.1

> 审查时间：2026-08-13（Europe/Oslo）  
> 对象：已安装 `~/Applications/WorkPulse.app`，版本 `0.3.1 (18)`；build 18 ZIP；本轮开始时的 build 18 源码快照  
> 范围：`CodexTaskReader` 长期性能/能耗、通知 delivered/open/fallback 语义、Widget 时间线与签名安装一致性  
> 限制：只读源码和运行态；只创建本审查文档与 `/tmp` 基准产物，未修改产品源码

## 1. 结论

build 18 的真实 Widget 安装闭环仍成立，但本轮新增两个不能继续用“已完成”概括的 P1：

1. **Codex 任务读取正确性可用，但长期能耗仍未达标。** 轮询从 2 秒降到 5 秒并关闭 Widget 写放大，只减少了 App Group 写入，没有消除每次重新查询 SQLite、对每个候选 rollout 从尾部最多扫描 32 MiB 的 CPU 与内存成本。30 秒真实进程样本约消耗单核的 6.9%；独立 reader 暖缓存基准峰值内存约 349.6 MB。
2. **通知 transport 已验证，通知用户闭环未验证。** 当前证据能证明授权、系统设置开启、`UNUserNotificationCenter.add` 成功，以及请求出现在 Notification Center delivered 列表；不能证明 Banner 被看到、声音被听到、用户点击后路由成功，或 “稍后提醒” 一小时后真的再次通知。

Widget 的签名、嵌入、App Group、唯一 PlugInKit 注册、ZIP 与安装二进制一致性本轮复核均通过。Widget 时间线能预置 fresh → stale 转换，但 reset 边界仍可能短暂展示重置前百分比，且 transition date 未去重。

因此：

| 范围 | 判定 |
|---|---|
| 当前 Mac 的 Small Quota / Small Pinned | **Go with constraints** |
| build 18 签名、嵌入和安装一致性 | **Pass** |
| Widget 时间线 fresh → stale | **Supported, system-scheduled** |
| Widget reset 后数值真实性 | **Constrained / P1** |
| 系统通知 request + Notification Center delivered | **Pass** |
| 通知 Banner / sound / open / action 完整闭环 | **Not proven / P1** |
| `CodexTaskReader` 功能 | **Technical Preview** |
| `CodexTaskReader` 长期能耗 | **Not accepted / P1** |
| 外部分发 | **No-Go** |

## 2. 审查冻结点

本轮进行期间，主代理开始调整下一版通知接口。工作树出现过 `NotificationCoordinator` 新接口与 Host 调用尚未同步的短暂状态；一次只读 `swift build` 在该中间状态失败。该失败属于下一版在途改动，**不是已安装 build 18 的回归证据**，也不纳入 build 18 结论。

本报告对通知源码的判断以本轮开始时读到的 build 18 行为为准；对安装、签名、App Group、进程与 snapshot 的判断来自已安装 build 18 运行态。下一版必须在工作树冻结后重新执行完整 build、签名、安装和 E2E Gate，不能继承本报告的 Pass。

## 3. build 18 身份与安装一致性

本轮重新得到：

| Gate | 结果 |
|---|---|
| 安装版本 | `0.3.1 (18)` |
| ZIP SHA-256 | `f02fdc45a1f2834eddea51a8427f3e5a073e2a065b3141456b3fd9c1fa3929e5` |
| ZIP Host vs installed Host | byte-for-byte identical |
| ZIP Widget vs installed Widget | byte-for-byte identical |
| Host / Widget strict `codesign` | Pass，必须在真实用户安全域执行 |
| Host / Widget Team | 均为 `<APPLE_TEAM_ID>` |
| Host / Widget App Group | 均为 `<APPLE_TEAM_ID>.com.workpulse.shared` |
| Widget sandbox | enabled |
| PlugInKit | `com.workpulse.prototype.widgets (0.3.1)`，1 条 canonical 安装记录 |
| Host 进程 | 1 个 `~/Applications/WorkPulse.app/.../WorkPulse` |
| 项目 runtime verifier | Pass |

受限 sandbox 中仍会出现 `CSSMERR_TP_NOT_TRUSTED`、Authority unavailable、PlugInKit connection invalid 或看不到进程；同一产物在真实用户安全域严格验签通过，Authority 链为 Apple Development → WWDR → Apple Root CA。Release Gate 必须使用真实用户安全域，不能把 sandbox 结果当成签名失效。

当前 App Group `widget.json` 运行态为 schema 5、revision 3425、live Codex quota、running task count 2。快照仍只发布脱敏 task count，没有任务名称或消息正文。

### 安装器仍需加强

build 18 安装器在本轮冻结点仍有三个边界：

1. `pluginkit -r` 失败被容忍，可能在替换后留下重复注册。
2. 安装前只验证 nested Widget 有非空 TeamIdentifier，没有在 installer 内再次断言 Host Team = Widget Team、两者 App Group = Info.plist 声明、Host/Widget 版本一致。
3. 旧 App 被移动到 `/tmp` backup 后，如果复制、注册、启动或 post-install Gate 失败，脚本不会自动恢复并重新注册旧版本。

实际 build 18 产物本轮全部一致，所以这些是升级可靠性缺口，不是否定当前安装结果。

最小修复：注销失败立即停止；引入 rollback trap；安装前后复用一个 `verify_product_identity`，精确比较 Host/Widget Team、App Group、bundle ID、版本/build number、runtime flag；安装完成自动执行 `verify_widget_runtime.sh`，失败即恢复旧 App。

## 4. `CodexTaskReader` 长期性能与能耗

### 4.1 当前实现成本

每 5 秒一次 `refreshRunningTasks()`：

1. 新建只读 SQLite connection，查询最近 48 小时最多 50 个非 subagent thread；公开参数上限实际可到 200。
2. 对每个候选 rollout 打开 `FileHandle`，从文件尾向前按 256 KiB chunk 扫描，单文件最多 32 MiB。
3. 每个 chunk 会拆成多份 `Data`、复制、反转，再尝试 JSON lifecycle 解析。
4. 不缓存 candidate 的 inode、size、mtime、已解析 offset 或 latest lifecycle event；未变化文件下一轮仍重复扫描。
5. 任务消失时 `terminalOutcome` 会再次打开并扫描对应 rollout。

本机最近 48 小时元数据聚合：

```text
candidate_files=9
total_size=1177 MiB
largest_file=635 MiB
files_over_32_MiB=4
per_poll_theoretical_scan_cap=288 MiB
```

这不是说每轮一定产生 288 MiB 物理磁盘读取，warm OS cache 会显著减少 block I/O；它说明当前算法每轮仍可能重新遍历和分配这些尾部数据。若达到默认 50 candidates，理论上限为 1.6 GiB/轮。

### 4.2 独立 reader 基准

同一源码、`maximumCandidates=50`、连续 30 次、当前返回 task count 始终为 2：

```text
avg       79.408 ms / read
p95       87.299 ms
max      100.712 ms
wall       2.39 s / 30 reads
user CPU   2.13 s
sys CPU    0.20 s
max RSS  349,618,176 bytes
peak footprint 352,256,744 bytes
block input operations 0
```

暖缓存下 reader 单独按 5 秒周期运行，约等于单核 1.6% 的持续预算；`0 block input` 不代表零成本，CPU、page reclaim 和短期 `Data` 分配仍真实发生。

### 4.3 已安装 WorkPulse 进程样本

同一 PID 30 秒前后：

```text
CPU TIME  1:00.46 → 1:02.52  (+2.06 s / 30 s)
RSS       151,344 → 171,008 KiB
```

即该窗口平均约占单核 6.9%。RSS 单窗口增加约 19 MiB 可能包含系统 cache、Swift 分配器回收延迟以及 quota/UI 其他活动，不能全部归因于 task reader；但它足以否定“已完成长期低能耗验证”。之前另一 30 秒样本也得到约 2.10 秒 CPU 增量，结果方向一致。

### 4.4 最小可验证修复

推荐按最小范围实施，不需要重做数据模型：

1. 在 Host 生命周期内保留 reader cache，key 为 task ID，value 至少包含 rollout path、inode、size、mtime、last parsed offset、latest lifecycle event。
2. 文件 size/mtime 未变化时直接复用 lifecycle；只对变化文件扫描新增 tail。若 inode 变化或 size 变小，安全丢弃 cache 并重新扫描。
3. SQLite candidate 集也做短期 cache。active task 存在时可 10–15 秒轮询；没有 active task 时退避到 30–60 秒；wake、app activation、rollout 文件变化时立即刷新。
4. 同一轮多个 task 消失时收集全部明确 terminal outcome，再按 1 条摘要通知或有限队列处理；当前只取第一个 disappeared task 会漏报同轮其余终态。
5. lifecycle JSON parser 避免 `Array(pieces.dropFirst())`、`Array(inspectable.reversed())` 的整块复制；复用 formatter，并给超长单行设置安全上限。

验收 Gate：

- 30 分钟 Instruments Energy Log，任务数稳定时平均 CPU < 单核 0.5%，无周期性大峰值；
- 30 分钟 RSS 去掉启动 warm-up 后净增长 < 10 MiB；
- 25 个候选、总 rollout ≥ 2 GiB、至少 1 个 ≥ 500 MiB，warm p95 < 50 ms；
- 未变化轮次解析 bytes 接近 0；单个变化文件只读取新增 tail + 最多 1 MiB 边界回看；
- 文件 append、truncate、rotate、Codex schema 缺列、DB busy、sleep/wake 均不误报 completed；
- 同一轮 3 个任务 terminal，结果不漏、不重复，通知遵守批量策略。

## 5. 通知 delivered / open / fallback 语义

### 5.1 已经证实什么

2026-08-13 06:00 的隔离 QA 诊断为：

```text
authorizationStatus=2
alertSetting=2
notificationCenterSetting=2
soundSetting=2
deliveredRequestIDs=2 个 workpulse.qa-preview UUID
```

这里的两个 ID 来自两次独立 QA，每次预览按设计生成新 UUID，不是 production dedup 失败。

可以确认：用户已授权；Alert、Notification Center、Sound 设置均 enabled；系统接受了 request；两个 request 当前可由 `getDeliveredNotifications` 查询到。

不能据此确认：Banner 在屏幕上出现、声音实际播放、用户注意到、点击 OPEN、默认点击、LATER 或 deep link 路由成功。

### 5.2 当前语义混淆

1. quota 流程中的局部变量 `delivered` 同时表示“6 秒顶部 overlay 已创建”或“`center.add` 没有抛错”。后者应命名为 `acceptedForDelivery`，不能记录成用户已收到。
2. quota alert 只要 overlay `isReachable` 就优先展示，没有检查 `userIsActive`。用户离开但屏幕未锁时，6 秒 overlay 可能无人看到，却仍将 quota cycle 写入持久化去重，之后不再 notification fallback。
3. build 18 的 `didReceive` 先调用 `completionHandler()`，再异步执行 snooze/open 路由；没有 action receipt，无法证明 macOS 唤起 App 后回调已完成业务处理。
4. 所有非 `LATER` action 都走 open 分支，没有显式只允许 `UNNotificationDefaultActionIdentifier` 与 `OPEN`。
5. Event `LATER` 只把本地 ledger 设为 snoozed 1 小时，并没有创建一小时后的 `UNNotificationRequest`，也没有独立 timer 在到期时调用 `attemptActiveDelivery`。用户文案“已稍后 1 小时”目前不等于“一小时后一定再次提醒”。
6. Event notification 在 `center.add` 后保留 notification owner，但没有“系统已出现在 Notification Center”或“用户已打开”的独立 ledger state。不能用 `.presented` 混记，因为 App 后台时没有可靠 Banner presentation callback。
7. 同一轮多个 task 完成时当前只处理第一个 disappeared task，其余任务即使存在明确 terminal event，也不会通知。

### 5.3 最小状态模型

不需要推断用户是否真的“看见”，只需保存可验证事实：

```text
requestAcceptedAt
systemDeliveredObservedAt?   // getDeliveredNotifications 查询到
actionReceivedAt?
actionIdentifier?
routeAttemptedAt?
routeResult?                 // handled / invalid / failed
```

Overlay 单独记录 `overlayPresentedAt`。产品文案只允许：

- `requestAcceptedAt`：系统已接收通知请求；
- `systemDeliveredObservedAt`：已进入通知中心；
- `actionReceivedAt + routeResult=handled`：用户操作已回流到 WorkPulse；
- 永远不要把上述任一状态写成“用户已看到”。

### 5.4 最小修复与 Gate

1. quota fallback 复用 `DeliveryPolicy.preferredActiveSurface`：用户最近 60 秒活跃才选 overlay；不活跃时优先 notification。
2. 仅在 overlay `present()` 成功或 notification request accepted 后记录 cycle，但保存 channel 与 acceptance state。对 overlay 可选在未交互情况下仍补一条静默 Notification Center 记录，需产品确认打扰策略。
3. `didReceive` 先复制 Sendable 的字符串/枚举值；显式 switch `OPEN`、default、`LATER`、unknown；完成路由/调度尝试后立即调用 completion handler，并设置防超时兜底。
4. 为 QA 增加本地 action receipt JSON，写 request ID、action、route、result、timestamp，不写通知正文或任务标题。
5. `LATER` 要么立即调度同一事件一小时后的新 request；要么把 UI 改成“暂时隐藏 1 小时”，并实现到期 scheduler。两者不能继续混用。
6. 多 terminal task 做批量摘要，避免漏报和多 Banner 风暴。

通知 Gate 至少覆盖：

- App foreground/background/terminated 三种状态点击默认通知与 OPEN；
- 点击后 receipt 的 request ID、action、route、handled 均匹配；
- LATER 用 QA 短延时验证新 request 进入 pending → delivered；
- active + overlay reachable 只走 overlay，inactive + overlay reachable 走 notification；
- Focus on、锁屏、Alert off、Sound off、Notification Center off 各自验证降级文案；
- stable production request ID 重调度不产生重复 Notification Center 项；两次手动 QA UUID 仍允许并存。

## 6. Widget 时间线刷新

### 6.1 已支持

Provider 每次读取 App Group 当前 snapshot，并创建最多 30 分钟的 timeline。它把 `snapshot.freshUntil`、quota freshUntil/reset、running task freshUntil 等边界加 1 秒后预放入 future entries；这些 entry 复用同一 snapshot，但 View 用 `entry.date` 判断 freshness。

这能在 Host 没有再次写 snapshot 时，让旧 quota/task 在边界后从“已同步”切换为“需更新”。`.after(30 min)` 只是向 WidgetKit 请求刷新，macOS 可以延迟；因此支持的是系统预算下的周期快照，不是实时或准点刷新。

build 18 已关闭 task count 不变时每 5 秒写 snapshot 的放大。此前 15 秒 Gate 为 revision `3422 → 3422`；本轮 App Group revision 为 3425，更新时间对应正常 quota/background publish，而不是 5 秒持续递增。

### 6.2 仍有两个边界

1. transition dates 没有 `Set` 去重。primary quota 同时存在于 `snapshot.quota` 和 `quotaBuckets` 时，freshUntil/reset 可能重复，生成同 timestamp 多个 entry，浪费 timeline budget。
2. quota freshness 只看 `freshUntil`。如果 `resetsAt < freshUntil`，`resetsAt + 1s` 的 entry 仍会把重置前百分比判为 fresh，只把重置时间显示成过去时间；最坏持续到 freshUntil，当前 Host 通常为约 5 分钟。reset 后旧百分比不应继续标“已同步”。

最小修复：

- `transitionDates = Array(Set(...)).sorted()`；
- quota effective validity 使用 `min(freshUntil, resetsAt)`；在 View 中也防御 `resetsAt <= entry.date`，显示“等待来源更新”，不突出旧百分比；
- timeline builder 抽成纯函数，便于固定时钟测试；
- 只在 external DTO 变化时写 App Group；quota refresh、task count、routine/theme、source state 变化仍正常发布。

Widget Gate：

- timeline dates 严格递增且唯一；
- `freshUntil` 前 1 秒显示 fresh，后 1 秒显示 stale；
- `resetsAt` 前 1 秒显示旧百分比，后 1 秒不得标“已同步”；
- reset 与 freshUntil 相同、早于、晚于三种顺序均测试；
- Host 退出 45 分钟后 Widget 能进入 stale，不要求准点 network refresh；
- 真实桌面 Small Quota 与 Small Pinned 各验证 fresh/stale、Light/Dark、点击；CLI verifier 不能替代 Gallery/桌面 E2E。

## 7. 最小实现顺序

1. **P0 Freeze Gate**：冻结下一版工作树，`swift build`、Xcode Release build、CoreVerify、Widget type-check 全绿，再生成唯一 ZIP SHA。
2. **P1 Task reader**：先做 unchanged-file cache 与 adaptive cadence，再跑 30 分钟 Energy Gate；这是当前最大长期成本。
3. **P1 Notification truth model**：拆分 accepted/delivered/action/routed，修 inactive fallback、completion 顺序、LATER 和多任务终态。
4. **P1 Widget reset truth**：去重 transition dates，reset 即失效，补纯函数 timeline tests。
5. **P1 Installer rollback**：精确 identity/entitlement/version 比对，注销失败 fail-fast，任一 post-install Gate 失败自动恢复。
6. **最终 E2E**：新 build 重新安装；真实 Gallery 添加、桌面刷新、Small Quota/Pinned 点击；通知 background/terminated 点击、LATER、Focus/锁屏矩阵；签名检查必须在真实用户安全域执行。

## 8. 最终放行

build 18 可以继续作为当前 Mac 的个人 dogfood，但应把对外陈述收窄为：

> WorkPulse 已具备真实签名 Widget、顶部岛、Codex quota/task 技术预览和系统通知 transport。Widget 刷新由 macOS 调度；通知中心出现不等于用户已看到或已完成点击回流；Codex task reader 尚未通过长期能耗验收。

在 task reader Energy Gate、通知 action receipt、quota inactive fallback、Widget reset truth 四项关闭前，不应标记“核心产品技术完成”。
