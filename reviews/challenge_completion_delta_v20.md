# WorkPulse build 20 质疑审查：最终 Delta 复审

> 角色：质疑智能体  
> 复审时间：2026-08-13（Europe/Oslo）  
> 对象：最终 build 20 源码、签名 ZIP、已安装 `~/Applications/WorkPulse.app`  
> 方法：只读复核，不修改产品源码或用户设置

## 更新后的结论

上一版报告指出的任务通知名称泄漏、持久化任务名清理、辅助技术自动收回、安装回滚与固定 5 秒轮询，当前均已出现对应源码修复。最终签名产物也已进入已安装 build 20。

因此，更新后的判断是：

- **已确认的 P0 源码缺陷：0 个。**
- 本机个人 dogfood：**Go**。
- “本机个人版 1.0 完整验收”：仍是 **Conditional Go**，只差系统通知真实点击和当前 build 的键盘/VoiceOver 运行证据。
- 对外买断分发：继续 **No-Go**。Developer ID、notarization、更新与购买恢复不属于这轮本机修复。

这里必须区分三件事：源码修复已经成立，运行 Gate 尚未完成，不等于源码缺陷仍存在；但没有运行证据，也不能把产品描述为已经完整验收。

## 最终产物与验证证据

| 项目 | 当前证据 | 判定 |
|---|---|---|
| App 版本 | 已安装 `0.3.1 (20)` | Pass |
| 最终 ZIP SHA-256 | `ef94a3d2078545506f0a53f522fdd9812683a0213e5f40b60c83d8a51142444e` | Pass |
| ZIP 与已安装 Host | binary byte-for-byte identical | Pass |
| ZIP 与已安装 Widget | binary byte-for-byte identical | Pass |
| Host + Widget 签名 | `codesign --deep --strict` 通过 | Pass |
| Widget runtime | canonical PlugInKit、团队签名 `<APPLE_TEAM_ID>`、Host 关联通过 | Pass |
| system-surface verifier | 全部通过 | Pass |
| Widget source type-check | 通过 | Pass |
| CoreVerify | 253 checks 通过 | Pass |
| 当前 GUI 复审 | Mac 锁屏，无法重新截图或操作 | Pending |
| 通知点击 receipt | 当前不存在 `lastNotificationOpenReceipt/At` | Pending |

本轮不复用旧 build 截图冒充最终 build 20 的视觉或辅助功能证据。

## Source closed：上一版问题已在源码关闭

### 1. 任务系统通知已经与任务名称授权解耦

**上一版问题**：`showTaskNamesInNotch` 的授权会间接进入系统通知，违反 PRD 的 Notification 永远 generic。

**当前修复**：

- `scheduleTaskTerminalAlert` 已删除外部传入 title，只按 outcome 生成固定的 generic title：完成、取消、失败、中止（`NotificationCoordinator.swift:176-199`）。
- 调用处只传 task ID、generic detail 和 outcome，不再传任务名称（`WorkPulseMenuBarApp.swift:1352-1362`）。
- detail 仅包含运行时长和“打开 WorkPulse 查看结果”，没有项目、线程、prompt、path 或任务 title。
- build 20 首次运行会移除旧 `workpulse.task-terminal.*` delivered/pending 通知，避免旧版本已经生成的含名通知继续留在通知中心（`NotificationCoordinator.swift:71-90`）。

**更新判定**：上一版 P0 隐私泄漏在源码层 **Closed**。

仍需一次最终通知中心/锁屏观察，证明系统实际展示的 build 20 内容与源码一致；这是 runtime Gate，不再是已知源码缺陷。

### 2. 任务结果本机缓存现在服从隐私授权

**当前修复**：

- 任务终态只在 `exposesTaskNames` 为真时把压缩后的 displayName 写入 `recentTaskTerminalResults`，否则持久化 `nil`（`WorkPulseMenuBarApp.swift:1440-1461`）。
- 开启 Privacy Mode 或关闭任务名称显示时，会立即遍历历史结果并把 displayName 清为 `nil`（`:79-90`、`:121-129`、`:1464-1481`）。
- 通知点击恢复任务结果时，再次以当前 `exposesTaskNames` 做显示门控；即使本机曾有名称，Privacy Mode 下也只显示 generic task（`:1588-1602`、`:1658-1685`）。

**更新判定**：常规用户路径下的持久化名称清理 **Closed**。

防御性 P2 仍可加强：初始化会先读入 `recentTaskTerminalResults`，但没有在 init 末尾再次强制执行 `privacyMode || !showTaskNamesInNotch` 的 scrub。正常 UI 切换会同步 scrub，且显示层仍 fail closed，因此这不是当前泄漏 blocker；但升级、异常终止或外部修改 defaults 后，启动时再做一次 invariant scrub 会更稳健。

### 3. Notification `LATER` 已正确撤下，回流 receipt 已可审计

- 三个通知类别都只注册 `OPEN`；响应只接受默认点击或 `OPEN`。
- 未实现可靠系统重投前，不再向用户提供会被理解为“一小时后再次通知”的 `LATER`。
- callback receipt 已包含 request ID、action ID、route、result 与 openedAt，并在控制中心显示最近回流状态。
- 任务通知通过 opaque task ID 回到本机最近终态记录，再按当前隐私偏好恢复名称和 outcome。

**更新判定**：通知 contract 与可观测 receipt 结构 **Closed**；真实 click/open 仍 Pending。

### 4. VoiceOver / Switch Control / 键盘自动收回已增加保护

**当前修复**：

- VoiceOver 或 Switch Control 开启时，Alert 不再启动 6 秒自动 dismiss（`NotchOverlayController.swift:240-244`）。
- 这两类辅助技术运行时，hover 状态不会重新启动计时（`:254-270`）。
- Expanded 在 VoiceOver / Switch Control 下不会因鼠标离开自动收回（`:302-317`）。
- 本地 keyDown 会标记 keyboard interaction active，鼠标离开不会在键盘交互期间自动关闭（`:372-397`）。
- Esc、点击外部、关闭按钮仍保留明确退出路径。

**更新判定**：上一版“只识别 hover”的源码缺陷 **Closed**。

静态代码仍不能证明 Full Keyboard Access 的真实焦点顺序，也不能证明 Expanded 初次出现、用户尚未按下第一个键之前不会被 SwiftUI 初始 hover=false 事件收回。应通过运行测试判断；除非复现失败，不应继续把它表述为确定的源码 P0。

### 5. 安装回滚已从骨架升级为真实恢复路径

**当前修复**：

- `restore_installed_app` 会依次验证签名、LaunchServices、PlugInKit、进程启动与 Widget runtime；任何一步失败都返回失败，不再吞掉错误后宣称成功（`install_signed_product.sh:15-27`）。
- rollback 只有在 `restore_installed_app` 通过时才打印“已验证恢复”；否则打印严重错误（`:29-53`）。
- 安装成功前仍检查 Host/Widget Team、App Group、build、binary 同源、单 Host 与 Widget runtime。

**真实故障注入证据**：

- `/tmp/WorkPulse-failed-install-20260813-071823.app` 是复制后注入失败留下的新 build 20，Host hash 为 `f30ff3f…69d2`。
- 随后成功安装前保存的 `/tmp/WorkPulse-before-signed-20260813-071836.app` Host hash 为 `017d4dda…55a2`，与失败的新版本不同。这说明 07:18:23 的失败路径确实先恢复了旧版本，07:18:36 的正常安装才再次把它移入备份。
- 当前已安装 Host hash 与失败注入的新 build 一致，说明最终成功安装的是新版本，而不是残留旧版本。

**更新判定**：复制后失败的真实 rollback **Pass**；本机安装器 blocker 关闭。

注册后、启动后与 runtime verifier 中的多点故障矩阵仍适合作为未来对外 updater QA，但不是当前本机安装完成的必要 blocker。

### 6. Task monitoring 已采用 adaptive polling

**当前策略**（`WorkPulseMenuBarApp.swift:1122-1142`、`:1223-1233`）：

- 用户活跃且有任务：5 秒；
- 用户活跃且无任务：10 秒；
- 5 分钟无输入且有任务：30 秒；
- 5 分钟无输入且无任务：60 秒；
- 锁屏：120 秒；
- Mac wake 与 session active：立即刷新。

这关闭了“始终固定 5 秒”这一源码问题。TaskReader 本身也已具备增量尾扫、inode/device file identity 和 path replacement fail-closed。

**短运行证据**：锁屏后的第一个 30 秒窗口 CPU time `2.02s → 2.65s`，可能包含安装后 warm-up；紧接着的稳定 30 秒窗口为 `2.65s → 2.65s`，RSS 从约 156 MiB 回落到约 60 MiB。它支持锁屏退避已经生效，但不能代替长时 Energy Log。

**更新判定**：adaptive polling source **Closed**；长期能耗 **Runtime pending**。

## Runtime pending：不是源码回归，但仍不能声称已验收

### R1. 通知点击回到具体任务

这是当前本机核心闭环唯一明确的运行 blocker。

当前系统尚无 `workpulse.lastNotificationOpenReceipt` 和 `workpulse.lastNotificationOpenAt`，所以没有证据证明最终 build 20 的 delivered task notification 被点击。最小 Gate：

1. App 在后台时点击默认通知 body，确认进入对应 task result。
2. App 退出后从通知中心点击，确认冷启动仍正确回流。
3. 点击明确“查看”，receipt 的 request/action/route/result 与展示一致。
4. Privacy On 时通知与 Expanded 均无任务名；Privacy Off + 应用内名称授权时，仅 Expanded 可显示名称。

### R2. 当前 build 的键盘与辅助技术流程

源码保护已经补齐，但同一最终 build 仍需：

- Full Keyboard Access：Resident → Expanded → Tab 遍历 → 触发刷新/稍后/移除/关闭；
- VoiceOver：朗读 quota、reset、任务、来源与按钮，朗读中不自动消失；
- Switch Control：能进入并触发主动作；
- Esc 返回 Resident；鼠标 hover/移出行为不回归；
- 130%/更大文字、Increase Contrast、Differentiate Without Color 下不裁切且不只依赖颜色。

Mac 当前锁屏，无法在本轮完成这组 GUI 取证。它阻止“已通过可访问性验收”的声明，但不否定已经存在的源码修复。

### R3. 长期 Energy Log

锁屏稳定短样本已经比 build 19 明显更好；仍建议在对外发布前跑 30 分钟 Instruments Energy Log 和 8 小时 dogfood，覆盖无任务、1–3 个任务、大 rollout、前后台、sleep/wake。

建议阈值保持：无任务稳定期平均 CPU `< 0.5%` 单核、wakeups `< 2/min`、warm-up 后 30 分钟 RSS 净增长 `< 10 MiB`。这属于发布质量 Gate，不再是 adaptive polling 源码 blocker。

### R4. Widget 大字号与 Medium/Large 价值

当前 WidgetBundle 仍发布两个 Small、一个 Medium 和一个 Large。用户最初明确要求不同尺寸，所以保留 Medium/Large 并非自动错误；当前命名也已诚实收缩为“额度与入口”和“工作概览”，没有冒充 Daily Brief/Gmail/Scheduled adapter。

质疑结论调整为：

- Small Quota 与 Small Pinned 是核心首发能力；
- Medium/Large 可以作为可选尺寸保留，但不要作为已验证的核心价值宣传；
- 若要宣布所有尺寸完成，仍需 Light/Dark、130%/更大文字、Increase Contrast、VoiceOver、刷新与独立 deep link 的 Gate W；
- 7 天 diary 仍用于判断 Medium/Large 是否值得长期维护，而不是决定当前代码能否安装。

## 剩余 P2：不阻塞本机使用，但应清理

### P2-1 隐私 migration completion 时机

`removeLegacyTaskNotificationsIfNeeded` 在两个异步查询 callback 完成前就把 migration key 写为 20。如果进程在 callback 执行前异常退出，下一次启动不会重试。最终系统大概率已经执行完当前迁移，但更稳健的实现应在 delivered 和 pending 两组移除请求都已发出后再持久化完成标记。

### P2-2 启动时隐私 invariant scrub

如上所述，init 加载历史 task results 后应再做一次 fail-closed scrub。这是本机数据最小化的 defense-in-depth，不是当前外部展示泄漏。

### P2-3 PRD 与 Xcode source of truth

- `PRD_V5_FINAL.md` 文件名、V6 标题、旧的 Medium/Large 定义与“尚未完成 Xcode/Widget embed”等状态已经漂移。
- 正式构建脚本使用根 `WorkPulse.xcodeproj` build 20；`Xcode/WorkPulse.xcodeproj` 仍是 build 19 遗留副本，可能误导人工打开错误项目。

应冻结一份 build 20 PRD，并只保留一个正式 project source of truth。

## 最终分层放行

| 范围 | 当前判定 | 真正剩余条件 |
|---|---|---|
| build 20 源码核心 | **Go** | 未发现新的 P0 源码缺陷 |
| 当前 Mac 本机 dogfood | **Go** | 可直接继续使用 |
| 本机个人版 1.0 完整闭环 | **Conditional Go** | 真实通知 click receipt + 当前 build 键盘/VoiceOver Gate |
| 全尺寸 Widget 完整验收 | **Conditional Go** | Gate W 的大字号、对比度、VoiceOver 与 deep link |
| 长期低能耗声明 | **Pending** | 30 分钟 Energy Log / 8 小时 dogfood |
| 外部一次买断分发 | **No-Go** | Developer ID、notarization、updater、购买恢复与支持流程 |

## 最终质疑

团队已经关闭了上一版报告中可由源码直接修复的核心缺口。现在不应继续把同一问题重复列为代码缺陷，也不应因为 verifier 通过就跳过真实系统行为。

最短完成路径不是再加功能，而是解锁 Mac 后完成两组证据：通知真实点击，以及键盘/VoiceOver/Switch Control。通过后，本机个人版的核心闭环才可以从 Conditional Go 升级为 Go；Medium/Large 使用价值、长时能耗和商业分发继续作为独立 Gate 管理。
