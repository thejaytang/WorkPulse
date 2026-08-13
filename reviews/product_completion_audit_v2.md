# WorkPulse 距离完整可交付产品的缺口清单 V2

> 审查日期：2026-08-13  
> 角色：产品经理 + 质疑者  
> 范围：当前源码、Xcode 工程、安装到 `~/Applications/WorkPulse.app` 的 build 9、当前运行界面、`reviews/` 下的审查与验收文档  
> 产品边界：macOS Codex 本地伴生应用；日常表面仅为 Widget、顶部刘海/岛和系统通知；菜单栏只承担设置与恢复；不需要独立 Dashboard

## 1. 结论先行

**WorkPulse 当前只能称为 Local Technical Preview / Internal Alpha，不能称为完整可交付产品。**

当前已经不是“没有做出界面”，而是存在三类更严重的产品问题：

1. **已实现的功能破坏了核心价值。** 只要存在运行中的 Codex 任务，顶部 Resident 就用任务名与运行时长完全替代“剩余额度 + 下次重置时间”。这与用户已明确的首要需求相反。
2. **隐私承诺与实际行为相反。** 当前 `Privacy Mode = 开` 时，顶部 Resident 仍显示实际任务标题。这不是文案问题，而是 P0 级隐私泄漏。
3. **工程完整不等于用户可交付。** 当前 App 内已嵌入 `.appex`，但严格签名校验仍失败，本机没有有效代码签名身份，Widget Gallery 的“可找到、可添加、可刷新、可点击”尚未证明。

当前最危险的团队误判，是把 `228 checks passed`、`.appex 已嵌入`和局部截图当成完成证据。这些只能证明代码路径存在，不能证明用户的任务闭环成立。

## 2. 当前已确认的证据

### 2.1 已成立的部分

- 生产 Scene 仅使用 `MenuBarExtra`，独立 Design QA Window 只存在于 `#if DEBUG`；“不做独立 Dashboard”的形态边界基本保住。
- 真实 Codex quota、多 bucket、freshness、reset 与低额度阈值逻辑已有本地数据路径和确定性测试。
- 顶部层已有 Resident / Alert / Expanded 三态，并使用原生 `NSPanel`。它是伴生应用的自绘顶部层，不是 Apple 向第三方 macOS App 开放的系统 **Dynamic Island**。
- Xcode host + Widget Extension target、App Group 和 WidgetBundle 代码存在；当前安装包 build 9 也已包含 `Contents/PlugIns/WorkPulseWidget.appex`。
- Widget 的 demo/placeholder 已显式标记“示例 / 非实时”；stale 状态不再把旧百分比伪装为当前值。
- Resident、一次性 Alert 和系统通知 fallback 已有独立设置。
- `SMAppService.mainApp` 的“登录 Mac 时启动”实现已存在。

### 2.2 仍然否决产品完成的当前证据

- 当前运行截图 `reviews/evidence/user_completion_audit_v2/02-resident-running-task.jpeg` 显示任务名被截断为“我想为 chatg...”，右侧是“共 2 个 · 运行 3 分...”，没有剩余额度与重置时间。
- 本轮通过辅助功能元素尝试点击当前 Resident，没有取得 Expanded 的当前运行证据。这可能是自动化能力限制，不直接判定为功能失败；但也意味着“Resident 可顺畅进入 Expanded”仍没有本轮真实交互证据。
- 同一时点本机偏好为 `workpulse.privacy = 1`，但顶部仍显示任务名。代码中 `showTaskNamesInNotch` 首次启动默认为 `true`，而 Resident、Expanded、任务完成 Alert 只检查该值，没有合并 `privacyMode`。
- `security find-identity -v -p codesigning` 返回 `0 valid identities found`。
- `codesign --verify --deep --strict ~/Applications/WorkPulse.app` 返回 `CSSMERR_TP_NOT_TRUSTED`。
- `scripts/verify_widget_runtime.sh` 返回 `FAIL: 宿主或扩展签名无效`。
- `WorkPulseCoreVerify` 通过 228 项检查，`verify_system_surfaces.sh` 也通过；但后者把“运行任务优先于剩余额度”当作 PASS，且声称 UI 只有浅/深两种主题，而实际源码已有“跟随系统/浅色/深色”三项。这说明自动校验本身已出现产品方向与证据漂移。
- 当前同时存在 `native/WorkPulseNative/WorkPulse.xcodeproj` 和 `native/WorkPulseNative/Xcode/WorkPulse.xcodeproj`，两份 `project.pbxproj` 不一致，尚无唯一构建真实源。
- `reviews/final_acceptance_v9_2026-08-12.md` 仍记载“没有 TeamIdentifier / 226 checks”，已与当前安装包和 228 checks 不一致。

## 3. 距离完整产品的优先级缺口

下表按“对用户价值或信任的伤害”优先于“开发工作量”排序。

### P0：不关闭就不得称为完整产品或外部 Pilot

| 排名 | 缺口与决策 | 用户价值/风险 | 必须提供的验收证据 |
|---|---|---|---|
| P0-1 | **Adopt：立即修复隐私模式的跨表面红线。** 定义单一的 `effectiveShowTaskNames = !privacyMode && showTaskNamesInNotch`，并应用到 Resident、Expanded、Alert、Notification、菜单栏与 VoiceOver。任务名首次启动必须默认关闭。 | 当前会在共享屏幕、会议、截图或旁人可见的顶部区域泄漏任务标题；这会直接破坏信任。 | 使用含敏感标题的 fixture，在 Privacy On/Off × Resident/Expanded/完成 Alert/系统通知/菜单栏/VoiceOver 矩阵中取得同一 build 的截图 + AX + 通知记录；Privacy On 时敏感标题暴露数 = 0，切换后立即更新，无需重启。 |
| P0-2 | **Reject 当前“运行任务自动抢占 Resident”。** Resident 默认且持续回答 `哪个窗口 + 剩余多少 + 何时重置`。任务运行状态降为菜单栏次级信息或 opt-in 实验；任务完成才可作为瞬时 Alert。 | 用户已明确说“剩余额度 + 下次更新时间”才有价值。当前每当 Codex 正在工作时反而隐藏这一信息，正好错过需要判断是否继续发起任务的时刻。 | 多 bucket 情境下，无任务/1 任务/2+ 任务均进行 3 秒扫读测试；用户识别 bucket、remaining、reset 的正确率 = 100%，任务开始/结束不得让 quota 无提示消失。 |
| P0-3 | **Adopt：把“消失 = 完成”的任务生命周期判断降为实验能力，未通过前默认关闭完成 Alert。** 必须区分 completed、failed、cancelled、waiting、source unavailable 和 stale；不得用绿色 success 表示仅仅“运行中”。 | 当前通过“上次存在、本次消失”生成“已完成”。暂时读取失败、归档、崩溃、解析边界或源不可用都可造成误报；展开后也没有“打开正确任务/结果”的交互闭环。 | 用真实任务与 fixture 覆盖正常完成、中止、失败、无终止事件、SQLite 短暂不可读、sleep/wake、App 重启与 24h stale；假完成提醒 = 0，重复提醒 = 0，点击后到达正确任务或明确告知无法定位。 |
| P0-4 | **Adopt：完成可信签名、Widget 注册和全新环境 Gallery 闭环。** “包含 `.appex`”不再作为可交付证据。 | 用户当前仍无法从产品证据确认在桌面组件库中找到 WorkPulse，这意味着核心表面之一尚未交付。 | 唯一 Release 工程构建；Host/Widget 同 Team + 同 App Group；`codesign --deep --strict`、`spctl`、notarization/stapling（外部分发时）全部通过；在全新 macOS 账户和另一台支持的 Mac 上能搜索、添加、移除和重新添加 Widget。 |
| P0-5 | **Adopt：只用 Small Quota 和 Small Pinned 完成 Widget 的真实 E2E。** Medium/Large 从首个可交付 WidgetBundle 移出，不得用源码存在代替使用验收。 | Small Quota 解决桌面 glance；Small Pinned 解决“每日 Gmail 审查对话”一键返回。当前用户的 `targetURL` 仍为空，因此 Small Pinned 在当前用户状态下还没有形成价值闭环。 | Small Quota：live/stale/offline/demo/schema mismatch、bucket 一致性、点击刷新全部通过。Small Pinned：设置合法 URL、空 URL、错误 URL、过期/不可达 URL、Privacy On/Off，并证明 100% 发起正确打开请求；需要明示“发起打开”不等于已验证到达正确对话。 |
| P0-6 | **Adopt：完成 Alert → Notification fallback 的真实送达、隐私、去重和回流闭环。** 系统“接收调度请求”不等于用户看到通知。 | 通知是顶部 Alert 被全屏、显示器状态或用户不活跃所抑制时的可靠底线。当前任务完成通知仍可泄漏标题，且“任务消失”可导致误报或重复。 | 同一 build 覆盖 notDetermined/authorized/denied/provisional、仅 Notification Center、声音关闭、Focus、App 前台、用户离开、全屏、多屏、锁屏、过期 deep link；每个 event/cycle 活跃 owner 唯一，重复送达 = 0，普通 refresh 的 Alert/Notification = 0，通知点击回到正确路由。 |
| P0-7 | **Adopt：建立唯一可复现的 Release 真实源和当前验收记录。** 合并/归档两份不一致的 Xcode project，每次验收必须绑定同一 build hash、签名、截图和日志。 | 当前文档、自动验证和安装包互相矛盾，团队无法回答“用户正在看的是哪个版本”，也无法可信地回归。 | 一条标准构建命令产生唯一产物；验收报告记录 Git/source revision（如适用）、bundle version、SHA-256、Team ID、entitlements、macOS/硬件、验收时间与证据路径；不得再使用过期“FINAL”报告代表当前状态。 |

### P1：P0 关闭后才值得做，但仍是高质量产品所必需

| 排名 | 缺口与决策 | 用户价值/风险 | 验收证据 |
|---|---|---|---|
| P1-1 | **Adopt：把菜单栏收缩为“状态 + 设置 + 恢复”控制中心，不再成为隐藏 Dashboard。** 现在 388×680 的 Overview 同时复制 quota、运行任务、固定入口和 Widget 状态，Controls 又堆叠大量偏好。 | 用户的日常价值应在三个系统表面中完成；菜单栏应该只在需要配置、修复或解释降级时出现。 | 5 个首次用户在无指导下完成：识别 quota 来源、设置固定入口、允许通知、查看 Widget 不可用原因、恢复刷新；任务成功率 ≥90%，不依赖独立页面。 |
| P1-2 | **Adopt：补齐首次设置与降级状态。** 需要能区分 Codex 未登录/本地数据不可用、quota 过期、Widget 未签名/未注册、通知被拒绝、固定 URL 未设置。 | 用户现在可以看到“同步”或“已写入”，但这不代表 Widget 已在系统注册，容易形成错误的可修复期待。 | 每个降级状态都显示“发生了什么 + 还能用什么 + 用户能做什么”；不可修复的构建能力不展示虚假“重试”。 |
| P1-3 | **Adopt：完成“登录 Mac 时启动”的真机 E2E。** 这是 launch at login，不是 WorkPulse 账号登录。 | 伴生应用如果在重启或重新登录后不恢复，Resident 和通知都不可靠。 | 开/关状态持久化；注销重登、重启、更新覆盖安装、移动 App 位置和卸载后状态正确；无重复进程，登录界面/锁屏不显示普通顶部层。 |
| P1-4 | **Adopt：重新定义主题的作用域，不得让一个偏好暗示控制所有表面。** 建议菜单栏跟随 System/Light/Dark；带物理刘海的顶部岛保持黑色融合；Widget 跟随 macOS 环境；强调色仅作为辅助定制。 | 当前源码把主题写入 Widget snapshot 并尝试设置顶部层外观；本机偏好是 Light + Violet，运行截图是黑色岛 + 绿色运行状态图标。这可以是“物理刘海保持黑色 + 语义状态色覆盖强调色”，也可以是设置未生效；UI 和当前证据无法区分两者，因此仍不能称为主题闭环。 | System/Light/Dark × 5 强调色 × normal/warning/critical × Increase Contrast/Differentiate Without Color 截图与对比度矩阵；明确文案告知哪些表面受影响；同一设置在重启后不漂移。 |
| P1-5 | **Adopt：完成多屏、全屏、Space、睡眠/唤醒和无刘海降级矩阵。** | 顶部层是自绘 `NSPanel`，不是系统保证的岛；已经出现过外接显示器选择与物理刘海遮挡问题。 | 内建刘海/内建无刘海/外接主屏/clamshell/mirroring × 全屏/Stage Manager/多 Space 截图 + 点击 + AX；无被刘海遮挡、无跨屏重复、屏幕切换后恢复正确。 |
| P1-6 | **Experiment：评估 2 秒任务轮询的能耗与可靠性，在证明价值前不作为核心默认功能。** | 当前持续查询本地 SQLite 并扫描 rollout JSONL；运行时长只是 wall-clock elapsed，不是任务进度，却有持续 I/O、电量和误解风险。 | 8 小时前/后台、空闲、多任务、大日志、sleep/wake 的 CPU、wakeups、磁盘读取、电量和状态正确性报告；若没有可观察的用户决策价值，停止默认轮询。 |
| P1-7 | **Adopt：完成可访问性与减少打扰验收。** | Alert 自动收起、顶部窄小点击区与颜色语义会影响 VoiceOver、键盘与低视力用户。 | Full Keyboard Access、VoiceOver、Reduce Motion、Increase Contrast、放大字号、Alert hover/focus 暂停与 Esc 回退矩阵；任何用户正在读取/操作的 Alert 不得自动消失。 |

### P2：明确延期，不得用它们阻塞当前核心交付

| 项目 | 决策 | 进入条件 |
|---|---|---|
| Medium Quick View / Large Work Overview | **Defer** | Small Quota 与 Small Pinned 先通过 Gallery E2E，再用 7–14 天 diary 证明更大尺寸有不重复的用户决策价值。 |
| 运行任务 Resident 模式 | **Experiment，默认关** | 先解决生命周期真实性、隐私和 deep link；再比较 Quota Resident 与 Task Resident 对实际决策的帮助。不允许自动抢占。 |
| 五种强调色 | **Defer** | 默认主题完成对比度和状态语义验收后才保留；如用户不使用，收缩为 1 个品牌色。 |
| WorkPulse 账号登录 | **Reject 当前版本** | 本地伴生应用应使用现有 Codex 本机会话，不重复处理用户凭据。只有真实跨设备同步或商业授权需求才重新评估。 |
| 购买/一次买断 | **Defer；移除当前虚假“授权”完成感** | 当前没有 StoreKit、receipt、license、restore purchase、activation 或 entitlement。本地/小范围 Pilot 不需要购买闭环；只有决定 Mac App Store 或 Developer ID 直销后才建立独立商业发布 Gate。 |
| Daily Brief、Gmail 内容、Scheduled 状态、Needs You 生产数据 | **Defer / No-Go until verified adapter** | 只有真实、经用户授权、可证明 freshness 的 adapter 存在时才可对外展示。当前固定 Gmail 审查对话只是一个手动入口，不是自动 Daily Brief。 |

## 4. 七个被点名功能的闭环判定

| 功能 | 当前状态 | 闭环判定 | 最小调整 |
|---|---|---|---|
| 顶部刘海运行任务 | 能读取任务标题、数量与 elapsed，但抢占 quota、标题截断、隐私泄漏、“运行”被涂绿，无打开任务动作 | **No-Go as default** | Resident 恢复 quota；运行任务放菜单栏或 opt-in；完成才弹 Alert；标题默认隐藏；必须能打开正确结果。 |
| Small Quota Widget | 信息层级已接近成立，但签名/Gallery/真实桌面未验证 | **Conditional Go** | 先过 Widget Gate，不增加新尺寸。 |
| Small Pinned Widget | 手动入口语义正确，但当前 URL 为空，没有现实闭环 | **Conditional Go** | 完成设置、错误恢复、隐私和正确打开请求验收。 |
| 菜单栏控制中心 | 没有独立生产页面，但面板已接近 mini Dashboard，设置密度高，仍有“测试”通知和未实现的购买承诺 | **Conditional Go** | 只保留状态、设置和恢复；移除生产构建中的 QA 操作和虚假授权完成感。 |
| 系统通知 | 有权限、category、schedule 与 deep-link 代码，无完整系统状态矩阵，任务标题会绕过隐私 | **No-Go for reliability claim** | 完成 fallback 送达、隐私、去重与回流 E2E。 |
| 登录/购买 | launch at login 已写代码；账号登录不存在也不需要；购买只有文案 | **Launch at login Conditional Go; account login Reject; purchase Defer** | 完成重登/重启 E2E；移除一次买断承诺，直到分发模式确定。 |
| 隐私模式 | UI 声称隐藏标题，运行时仍泄漏任务名 | **P0 No-Go** | 用一个 effective privacy policy 统一所有外部表面，默认隐藏。 |
| 主题/配色 | 有 System/Light/Dark + 5 强调色，但作用域与运行结果不一致 | **Not closed** | 先定义不同表面的平台一致性规则，再做对比度和实机矩阵；多强调色延期。 |

## 5. 收缩后的完整本地/Pilot 产品范围

### 必须包含

1. **Quota Resident**：默认常驻，显示 bucket/window、remaining、reset；stale/offline 不伪装精确当前值。
2. **Quota Expanded**：显示所有可用 bucket、观察时间、freshness 与刷新；不混入固定入口或运行任务 Dashboard。
3. **一次性 Alert**：只承担经验证的低额度跨阈值和可信任务完成；与 Resident 独立开关。
4. **系统通知 fallback**：只在顶部 Alert 不可达或策略选择通知时承担 active owner，可去重、可回流、可降级。
5. **Small Quota Widget**：用户可在 Gallery 找到并添加，显示真实额度与重置时间。
6. **Small Pinned Widget**：只作为用户明确保存的 ChatGPT/Codex 对话或每日例程入口，不伪装同步 Gmail、Scheduled 或任务状态。
7. **菜单栏设置/恢复入口**：负责数据状态、固定 URL、通知权限、隐私、登录时启动、Widget 可用性与错误恢复。
8. **可信安装与更新**：唯一构建、正确签名、必要时 notarization，并能在全新环境中安装、重启、更新和卸载。

### 明确不包含

- 独立 Dashboard 或主页。
- Medium/Large Widget。
- 默认运行任务 Resident。
- Daily Brief、Gmail 内容读取、Scheduled 真实状态、生产 Needs You。
- WorkPulse 账号系统、云同步或自行保管 Codex 凭据。
- 购买、一次买断或订阅。
- 多强调色作为发布阻断项。

## 6. 建议的下一轮实现顺序与 Gate

### Step 1：先止损，不做新功能

- 隐私模式统一红线，任务名默认关闭。
- 取消运行任务对 Resident 的自动抢占，恢复 quota-first。
- 默认关闭未证明的任务完成 Alert。
- 从生产 WidgetBundle 移出 Medium/Large。
- 移除“一次买断”和任何暗示已授权的文案。

**Gate 1：** Privacy On 跨表面泄漏 = 0；无任务和多任务时 Resident 都可在 3 秒内读出 bucket + remaining + reset。

### Step 2：关闭提醒语义

- 重做任务终止的可信状态机，或继续将它保持为关闭实验。
- 完成 Alert/Notification active owner、去重、权限、Focus 和点击回流 E2E。

**Gate 2：** 假完成 = 0，重复提醒 = 0，普通 refresh 提醒 = 0，隐私标题泄漏 = 0，不可达 Alert 按策略进入通知 fallback。

### Step 3：交付两只真实 Small Widget

- 归一 Xcode project，用可信 Team 签名 Host + Extension + App Group。
- 完成全新用户和另一台 Mac 的 Gallery 验收。
- 设置用户实际的每日 Gmail 审查对话 URL，验收 Small Pinned 的打开请求与错误恢复。

**Gate 3：** `codesign --deep --strict` 通过；外部分发时 `spctl` + notarization + stapling 通过；Gallery 可找到且只暴露两只 Small Widget；live/stale/offline/demo/deep link 全部有当前 build 证据。

### Step 4：收缩控制中心，补齐平台行为

- 完成 launch at login、多屏/全屏/Space/sleep-wake、VoiceOver 与主题作用域。
- 将菜单栏从内容 Dashboard 收缩为状态、设置和恢复。

**Gate 4：** 干净账户能无指导完成配置；重启后 Resident 恢复；无刘海/多屏/全屏正确降级；主题和可访问性矩阵通过。

### Step 5：再决定是否扩张

- 进行 7–14 天 dogfood/diary，分别记录 Small Quota 是否改变工作决策、Small Pinned 是否真正比任务历史列表更快。
- 只在真实数据证明增量价值后，再考虑 Medium/Large、运行任务 Resident、Daily Brief 或商业购买。

**Gate 5：** Small Pinned 在 7 天内至少 4 天被用于真实日常例程；Small Quota 至少 1 次改变任务开始/缩小/等待决策。未达标时不扩展尺寸。

## 7. 最终放行标准

WorkPulse 只有同时满足下列条件，才可从 Technical Preview 升级为“完整本地/Pilot 产品”：

1. 隐私模式对所有表面零泄漏，任务名默认隐藏。
2. Resident 在有无运行任务时都优先显示“剩余额度 + 下次重置时间 + 窗口身份”。
3. 任务完成语义可信，或该能力保持默认关闭。
4. Alert 和 Notification 实际送达、去重、权限与回流闭环全部通过。
5. 干净环境的 Widget Gallery 可找到 Small Quota 和 Small Pinned，并使用真实生产快照。
6. 唯一安装包通过签名、App Group、更新、登录时启动和多屏矩阵。
7. 菜单栏仍是控制中心，而不是产品日常主页。
8. 当前验收报告、安装包 hash、截图、AX 和系统日志全部指向同一 build。

**当前不放行。** 下一步不是再增加一种 Widget 尺寸、主题或购买界面，而是按 Step 1 先关闭隐私泄漏和 Resident 信息优先级回归，再用同一可信签名 build 完成两只 Small Widget 与通知的真实系统闭环。
