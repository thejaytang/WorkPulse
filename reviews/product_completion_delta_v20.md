# WorkPulse build 20 产品完成度 Delta

日期：2026-08-13（Europe/Oslo）  
审查范围：当前稳定源码、最终签名 ZIP、已安装 `0.3.1 (20)`、本轮可执行 verifier 与用户提供的 Widget runtime/signing/rollback 验收结果。Mac 当前锁屏，因此本报告不是一轮新的视觉或 VoiceOver 实机审计；未用旧 build 截图替代 build 20 证据。

## 冻结结论

- **本机个人 dogfood**：**Go**。
- **本机个人版 1.0 完整验收**：**Go with two unlock-time manual Gates**。当前没有未关闭的源码 P0；剩余项都是必须在解锁后取得的运行证据。
- **对外一次买断分发**：继续 **No-Go**。Developer ID、notarization、正式更新与购买恢复仍是独立商业化里程碑，不阻止本机个人使用，也不要求现在上架 App Store。
- 首发范围继续冻结为：`额度 + 运行任务状态 + 一个固定对话入口 + 顶部 Resident/Alert/Expanded + Small Quota/Small Pinned + 系统通知兜底 + 菜单栏控制中心`。不再扩展 Scheduled、Daily Brief、真实 Gmail 状态或 exact Codex return。

## build 20 已关闭的完成度差额

| 差额 | build 20 当前实现与证据 | 判断 |
|---|---|---|
| 外部通知可能泄漏任务名 | 任务终态通知 title 固定为 generic outcome，body 只含时长与通用回流提示；不会复用应用内“显示任务名称”授权。升级时清理旧版可能含名称的历史任务通知 | **Closed** |
| 点击后如何恢复具体任务 | 通知仅携带 opaque task ID 与 outcome；具体结果和可选名称只存本机。点击后根据当时 Privacy Mode 与应用内名称偏好决定是否恢复名称 | **Closed at implementation level** |
| 隐私授权撤销后的缓存 | 开启 Privacy Mode 或关闭任务名称授权都会执行 `scrubPersistedTaskNames()`，清除本机终态缓存中的 `displayName` | **Closed** |
| 单任务 Alert 点击目标 | 单任务 Alert 使用专属 `Codex 任务结果` Expanded，包含隐私门控名称、outcome、时长与本机生命周期来源 | **Closed** |
| 键盘与辅助技术交互被自动打断 | Expanded 检测键盘交互；VoiceOver 或 Switch Control 开启时 Alert 不启动自动收回，Expanded 也不会因鼠标离开自动收起；Esc 和明确关闭仍保留 | **Closed at implementation level**，最新 GUI/AX 运行证据待解锁 |
| 固定 5 秒轮询 | 用户活跃且有任务为 5 秒、无任务为 10 秒；用户空闲时退避到 30/60 秒；锁屏退避到 120 秒；解锁和 wake 后立即刷新 | **Closed**。不再把固定 5 秒空转作为当前产品缺口 |
| 安装与回滚 | 安装前校验 Host/Widget Team、App Group、build；安装后比对同源 binary、验证单实例与 Widget runtime；失败路径恢复旧版。用户提供的 rollback 验收为 pass | **Closed for local installer** |
| Widget 交付 | 已安装 build 20；Host/Widget signing、App Group、唯一 PlugInKit 注册、Widget runtime 与 rollback 均 pass | **Closed** |

## 当前证据账本

- 安装版本：`0.3.1 (20)`。
- 最终签名 ZIP SHA-256：`ef94a3d2078545506f0a53f522fdd9812683a0213e5f40b60c83d8a51142444e`。
- `WorkPulseCoreVerify`：本轮重新执行，**253 checks passed**。
- `verify_system_surfaces.sh`：本轮重新执行，通过。
- Widget source type-check：本轮重新执行，通过。
- Widget runtime / signing / rollback：用户提供的最终验收结果均为 pass。
- 通知 diagnostic：authorization、Alert、Notification Center、Sound 均 enabled，delivered 列表中存在 task-terminal request。
- 当前 `workpulse.lastNotificationOpenReceipt` 与 `workpulse.lastNotificationOpenAt` 均不存在。因此 delivered 已证实，但 click/open 未证实。
- 当前屏幕为锁屏状态，没有取得 build 20 的最新 Resident、Expanded、控制中心、Widget、通知中心画面或 AX/VoiceOver 运行记录。

## 解锁后仅保留两个手工 Gate

### Gate 1：真实任务通知 click/open

在同一最终 build 20 上，从 macOS 通知中心点击一条 task-terminal 通知，至少覆盖一次默认点击或“查看”动作，并确认：

1. 外部通知 title/body 始终 generic，不出现任务名、项目名、路径或固定入口标题；
2. 回到 WorkPulse 的 `Codex 任务结果`，不进入额度或 Needs You；
3. outcome 与 delivered notification 一致；
4. 生成包含 request、action、route、result、openedAt 的 open receipt；
5. Privacy Mode 开启时结果表面隐藏名称；Privacy Off 且明确允许名称时，只从本机缓存恢复；撤销授权后同一缓存名称不可再次恢复。

如果条件允许，再补一次 App 已退出后的冷启动点击。它能提高证据完整度，但不改变当前源码完成度判断。

### Gate 2：最终 build 20 GUI / AX smoke

解锁后只做回归验收，不再扩功能：

1. Resident 仍是 `窗口身份 + 剩余额度 + 重置时间`，任务仅为次级 `● N`；
2. Expanded、单任务 Alert、Small Quota、Small Pinned 和控制中心无布局/主题回归；
3. Full Keyboard Access 可进入 Expanded、遍历可见动作并用 Esc 返回；键盘交互期间不自动收起；
4. VoiceOver / Switch Control 开启时 Alert 不自动消失，quota、reset、任务状态、来源和关闭/动作按钮可被识别；
5. Privacy Mode 下可见文本与 AX label 均不包含任务名或固定入口名。

本 Gate 通过前，不宣称完整 VoiceOver 合规或最终像素级视觉验收；只能宣称相关实现已完成并通过静态/编译 Gate。

## 首发与商业化边界

- Small Quota 和 Small Pinned 继续作为首发 Widget；Medium/Large 可保留实现，但不扩张首发叙事。
- Gmail 只是 Manual Pin，不读取邮箱；Scheduled、Daily Brief、Needs You production adapter 不属于 1.0。
- 顶部岛是受控 `NSPanel`，不是 Apple 官方 Dynamic Island API。
- WidgetKit 是 snapshot/timeline；通知受 Focus 和 macOS 呈现策略控制。
- “回到具体任务”定义为回到 WorkPulse 的该任务结果，不承诺直接打开 Codex 原任务。

对外买断继续 **No-Go**，直到完成 Developer ID Application 签名、notarization/stapling、稳定生产 bundle ID、无 Xcode 干净 Mac 安装升级、签名更新/回滚，以及购买、激活、恢复购买、离线和退款撤销闭环。基于当前本机 Codex 数据读取架构，优先推荐 **Developer ID direct distribution**。

## 最终放行语句

两个解锁后 Gate 通过后，可以宣布：

> WorkPulse build 20 已完成本机个人版 1.0 验收：以剩余额度和重置时间为常驻主信息，用次级状态点表达运行任务，提供隐私安全的任务终态提醒、Small Quota、Small Pinned、顶部三态、系统通知兜底和菜单栏控制中心；不承诺 Gmail/Scheduled/Daily Brief production 状态、打开原 Codex 任务或对外买断分发。
