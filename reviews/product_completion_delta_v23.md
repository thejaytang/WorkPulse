# WorkPulse build 23 产品完成度 Delta

日期：2026-08-13（Europe/Oslo）  
审查方式：只读当前 build 23 源码、`reviews/final_acceptance_v23_2026-08-13.md`、最终安装/签名/Widget 证据，以及解锁后新增的 Resident / Expanded 画面。本轮未修改产品源码或用户设置。

## 结论

- **可以称为“本机个人版功能完成、可持续 dogfood”**：用户明确要求的 Widget、刘海、通知、控制中心、主题、隐私、固定对话、外接屏策略和无独立页面均已进入最终实现，当前没有发现新的源码 P0。
- **暂时不能称为“本机个人版完整验收全部完成”**：仍有 2 个手工 Gate，一是系统通知真实 click/open，二是同一 build 23 的最终控制中心/主题/AX/外接屏回归 smoke。
- **对外一次买断仍是 No-Go**：这与个人本机版是否完成是两件事，不要求现在上架 App Store。

## 用户明确要求逐项判断

| 用户要求 | 当前实现与真实证据 | 完成度判断 |
|---|---|---|
| 真正的 macOS Widget | build 23 含真实 WidgetKit extension、App Group、签名宿主嵌入、唯一 PlugInKit 注册和 runtime pass；当前 schema 6 snapshot 为 `liveCodexAppServer`，含 quota、运行任务摘要、有效固定入口状态和 Manual Pin。Bundle 提供 Small Quota、Small Pinned、Medium、Large | **Closed**。不是 HTML 模拟，也不是独立悬浮网页；首发重点继续是 Small Quota + Small Pinned |
| 刘海 quota-first + 任务状态 | 解锁后 Resident 实际显示 `7 天 · 62% 剩余｜周四 05:34 重置 · ● 2`；Expanded 展示主窗口、第二额度窗口和任务 A/B。12 秒后悬停状态仍保持展开 | **Closed**。额度和重置时间是常驻主信息，任务只用次级计数与展开行表达 |
| 系统通知 | authorization、Alert、Notification Center、Sound 均 enabled；build 23 隔离 QA 已真实 delivered `WORKPULSE_TASK_TERMINAL`。外部通知永远 generic，点击后才从本机结果缓存按当时隐私偏好恢复 | **Implemented + delivered；click/open Gate 未关闭** |
| 右上角控制中心 | Release 入口是原生 `MenuBarExtra(.window)`，显示额度百分比与任务状态点；一级设置已收敛为顶部显示、隐私、外观与启动、固定入口、系统通知 5 组，商业化宣传卡已删除 | **Implementation Closed；最终 GUI/AX smoke 待补** |
| 主题与强调色 | 支持 System / Light / Dark 与 5 个强调色；偏好会同步控制中心、Widget 与无刘海浮层，物理刘海外壳始终保持深色融合。当前本机偏好为 Dark + Violet，解锁后刘海画面可见紫色强调 | **Implementation Closed；Light/System、控制中心和 Widget 的 build 23 最终回归并入 Gate 2** |
| 隐私 | 当前 Privacy Mode 开启；解锁画面只显示任务 A/B，Widget snapshot 为 generic，固定入口显示“每日例程”。任务通知 title/body 不包含任务名；关闭名称授权或开启 Privacy 会 scrub 本机缓存名 | **Closed**。通知点击后的真实隐私呈现仍随 Gate 1 一并验收 |
| 固定某个对话 | 当前已配置 HTTPS `chatgpt.com` target；Widget snapshot 为 `manualPin`；Small Pinned 使用 `workpulse://routine/<UUID>`，只打开用户保存的入口，不读取 Gmail 或 Scheduled 状态 | **Closed within Manual Pin scope**。不是 Gmail 状态组件，也不是自动任务适配器 |
| 外接屏不抢刘海 | `preferredScreen()` 通过 `CGDisplayIsBuiltin` 与 `DisplayPlacementPolicy` 固定优先内建刘海屏，不跟随鼠标或前台窗口；无刘海时才降级为顶部浮层 | **Implementation Closed**。build 23 的外接屏断连/重连运行 smoke 并入 Gate 2 |
| 不需要独立页面 | Release Scene 只有 `MenuBarExtra`；普通 `Window("WorkPulse")` 不存在。源码中的 `WorkPulse Design QA` Window 受 `#if DEBUG` 限制，不进入最终 Release build | **Closed**。控制中心是右上角菜单栏弹层，不是独立应用页面 |

## 解锁后的新视觉证据

### 1. Resident：quota-first 已成立

![build 23 quota-first Resident](<local-project>/reviews/evidence/challenge_completion_delta_v23/01-resident-quota-first.png)

主信息顺序是窗口、剩余比例、重置时间；`● 2` 仅作为任务次级状态点，未再次退化为“7 天窗口已更新”之类低价值文案。

### 2. Expanded：额度与任务同时可读

![build 23 Expanded](<local-project>/reviews/evidence/challenge_completion_delta_v23/02-expanded.png)

隐私模式下没有任务真实名称；两组额度和任务运行时长均有明确文字，不只靠颜色表达。

### 3. 悬停 12 秒后仍保持

![build 23 Expanded hover 12s](<local-project>/reviews/evidence/challenge_completion_delta_v23/03-expanded-hover-12s.png)

该证据关闭了鼠标阅读期间自动收起的视觉回归，但不能替代 Full Keyboard Access、VoiceOver 和 Switch Control 的运行验收。

## 当前证据账本

- 安装版本：`0.3.1 (23)`。
- 当前签名 ZIP SHA-256：`41fafea9e4e6c069b90a18a5190d29a81e5709b3342a7830fd2ffe38629635aa`。
- Host / Widget：Universal Binary，同 TeamIdentifier / App Group，严格签名、同源和 Widget runtime pass。
- `WorkPulseCoreVerify`：本轮重新执行，260 checks passed。
- `verify_system_surfaces.sh`：本轮重新执行，通过。
- Widget source type-check：本轮重新执行，通过。
- 当前本机配置：Privacy On、Dark、Violet、ChatGPT HTTPS Manual Pin 已配置。
- 当前 Widget snapshot：schema 6、generic privacy、live quota bucket、运行任务摘要、有效 Manual Pin 状态。
- build 23 解锁后画面：Resident、Expanded、Expanded hover 12 秒已取得并检查。
- 通知：task-terminal QA 已 delivered，但 `lastNotificationOpenAt` 和 `lastNotificationOpenReceipt` 仍不存在，说明没有把 delivered 冒充 clicked。

## 仍缺的两个手工 Gate

### Gate 1：真实通知 click/open

从 Notification Center 点击 build 23 已 delivered 的“Codex 任务已完成”，确认：

1. 生成 `request / action / route / result / openedAt` receipt；
2. 回到 WorkPulse 的 `Codex 任务结果`，结果为“已完成”，时长为同一条 QA 任务的“运行 2 分钟”；
3. 不进入额度或 Needs You；
4. 外部通知始终 generic；Privacy On 时 Expanded 不出现任务名；
5. 若可行，再补一次 App 已退出后的冷启动点击。

### Gate 2：最终 GUI / AX / 显示器回归 smoke

只做验收，不再扩功能：

1. 打开右上角控制中心，确认 5 组设置的布局、Light/Dark/System 和强调色切换无回归；
2. Small Quota / Small Pinned 当前桌面渲染、同步与点击回流仍正确；
3. Full Keyboard Access 可进入 Expanded、遍历动作、Esc 返回，交互中不自动收起；
4. VoiceOver / Switch Control 能识别 quota、reset、任务状态、来源与动作；Privacy On 时可见文本和 AX label 均无敏感名称；
5. 连接外接屏后 Resident / Alert / Expanded 仍停在内建刘海屏；断连、重连后位置恢复正确。

Gate 2 通过前，不宣称完整 VoiceOver 合规或 build 23 的所有主题/显示器组合均已最终验收。

## 产品阶段与发布边界

当前准确阶段是：**本机个人版 Feature Complete / Dogfood Go / Final Acceptance Pending 2 Manual Gates**。

首发边界保持不变：

- Small Quota 与 Small Pinned 是核心 Widget；Medium/Large 是已实现的补充尺寸，不扩张首发叙事。
- Gmail 只是固定 ChatGPT 对话入口，不读取 Gmail；Scheduled、Daily Brief、Needs You production adapter 不属于 1.0。
- 顶部岛是受控 `NSPanel`，不是 Apple 官方 Dynamic Island API。
- WidgetKit 是 snapshot/timeline；通知受 Focus 和 macOS 呈现策略控制。
- “回到具体任务”指回到 WorkPulse 的该任务结果，不保证直接打开 Codex 原任务。

对外买断继续 **No-Go**，直到 Developer ID Application、notarization/stapling、稳定生产 bundle ID、无 Xcode 干净 Mac 安装升级、签名更新，以及购买/激活/恢复购买/退款撤销闭环完成。基于当前本机 Codex 数据读取方式，优先推荐 **Developer ID direct distribution**。

## 最终放行语句

两个手工 Gate 通过后，可以宣布：

> WorkPulse build 23 已完成本机个人版 1.0：它是真实 macOS Widget + 右上角菜单栏控制中心 + quota-first 顶部三态的 Codex 本地伴生应用，能够显示剩余额度、重置时间和运行任务，提供隐私安全的通知及固定对话入口，并正确处理内建/外接屏；不需要独立页面，也不承诺 Gmail/Scheduled/Daily Brief production 状态、打开原 Codex 任务或对外买断分发。
