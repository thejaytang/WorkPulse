# WorkPulse 完整产品用户任务审计 V2

> 日期：2026-08-13  
> 角色：用户需求研究智能体  
> 审计对象：顶部 Resident / Expanded、正在运行的 Codex 任务、固定入口、Widget、提醒、隐私、主题与菜单栏控制中心  
> 方法：当前运行态截图与辅助功能树、WidgetKit 实际渲染、最新版源码能力对照、3 秒 **glance test** 任务分解  
> 约束：本轮只审查，不修改产品源码

## 1. 结论先行

WorkPulse 已经从“只有 quota 的刘海原型”发展为一个较完整的本机 companion，但当前功能组合再次变得过多。最大的用户体验问题不是缺功能，而是顶部常驻区会在任务开始后自动用任务名替换 quota。

当前真实截图中：

- 无任务的初始态能显示 `75% 剩余`，但该状态是明确标注的演示值；
- 检测到两个运行任务后，Resident 变为 `我想为 chatg... / 共 2 个 · 运行 3 分...`；
- 任务名和运行时长都被截断，用户既不能确认“具体是哪一个任务”，也看不到此前明确要求的 remaining + reset。

因此，当前自动切换策略不通过 3 秒 **glance test**。它同时损害了两个任务：

1. 无法稳定回答“额度还剩多少、什么时候重置”；
2. 无法准确回答“正在运行哪个任务”。

### 本轮产品决策

1. **默认 Resident 必须稳定保留 quota window + remaining + reset，运行任务不得自动抢占。**
2. **运行任务状态首发只承诺“数量 + 展开查看列表”。** 原始线程标题不应默认放在 286pt 刘海常驻区。
3. **固定入口和 Small Pinned Widget 必须首发。** 这是用户明确提出的“每日 Gmail 审查对话常驻桌面”需求，但只承诺打开保存的 HTTPS 入口。
4. **首发 Widget 只开放 Small Quota 与 Small Pinned。** Medium Quota + Pinned 和 Large 工作概览只能在真实 7–14 天使用验证后开放。
5. **低额度 crossing Alert 可以首发，但必须 opt-in。** 任务完成 Alert、系统通知 fallback 和任务名通知需经过完整 E2E 后开放。
6. **隐私默认值必须反转。** 新用户默认隐藏任务名和固定入口名；Widgets 只发布任务数量；通知不得复用“刘海显示任务名称”开关。
7. **首发主题只保留浅色 / 深色。** 5 种强调色没有解决核心任务，增加大量 QA 组合，应删除。带物理刘海的顶部岛继续固定深色以融入硬件。
8. **菜单栏控制中心可以保留，但只作为配置和故障恢复入口。** 它不能成为一个隐藏的 Dashboard，也不应承担日常查看任务。

总体判定：**Small Quota Widget 的视觉方向为 Conditional Go；当前 Resident 任务自动接管为 No-Go；完整产品仍需收缩后才能进入首发。**

## 2. 审计证据与限制

### 2.1 本轮运行证据

#### Step 1：Resident 初始演示态，信息结构健康但不是 live 证据

![Resident 演示态](evidence/user_completion_audit_v2/01-resident-demo.jpeg)

辅助功能文本：`WorkPulse 常驻状态，演示 75% 剩余，演示 · 非实时`。

健康度：**Conditional**。

优点是 demo 没有伪装成真实数据，remaining 是第一视觉重点。缺点是它没有 reset，也不能证明 live/stale/unavailable 的实际切换。

#### Step 2：检测到运行任务后的 Resident，3 秒任务失败

![Resident 运行任务态](evidence/user_completion_audit_v2/02-resident-running-task.jpeg)

视觉上只能读到 `我想为 chatg...` 和 `共 2 个 · 运行 3 分...`。辅助功能文本包含完整第一任务标题和数量，但普通扫视用户看不到完整标题，也不知道第二个任务是什么。

健康度：**No-Go**。

结构问题：

- 运行任务自动替换 quota，破坏常驻信息稳定性；
- 长任务标题天然不适合 286pt 宽度；
- 两个任务只展示第一个任务的截断标题，信息代表性不足；
- “运行 3 分 24 秒”每秒变化，但对用户下一步决策价值低；
- 绿色状态和圆形图标表达“正在运行”，却无法说明任务是否等待输入、正在执行或只是生命周期尚未结束。

#### Step 3：Small Quota 的 WidgetKit 渲染，扫读成功但不是 Gallery E2E

![WidgetKit Small Quota](evidence/user_completion_audit_v2/03-widgetkit-quota-dark.jpeg)

Widget 可在约 2 秒内读出：`7 天窗口 / 83% / 周三 20:09 重置`。主要信息层级正确，数字与 reset 没有被来源、observed time 或能力说明挤占。

健康度：**Conditional Go**。

限制：这是 WidgetKit Simulator 的 timeline，不是用户桌面 Widget Gallery。它不能证明组件可搜索、可添加、App Group 可读、系统调度会刷新或点击会正确回流。

#### Step 4：控制中心、提醒与主题

本轮没有取得当前 build 的 MenuBarExtra 控制中心截图。当前运行实例可显示顶部 Resident，但 Computer Use 无法进入系统托管的菜单栏额外项；带 Team 签名的已安装 build 也未能在本轮作为可访问进程启动。因此本部分只做当前源码的结构和文案审查，不作视觉通过结论。

健康度：**Source-level Conditional / Runtime blocker**。

### 2.2 当前能力事实

- 最新源码提供 `概览 / 控制` 两页菜单栏控制中心，不是独立主窗口。
- Resident、一次性顶部 Alert、通知 fallback 已分为独立偏好。
- 运行任务读取来自 Codex 本机 `state_5.sqlite` 和 rollout 生命周期事件；Widget 只发布任务数量，不发布任务名。
- WidgetBundle 当前暴露 Small Quota、Small Pinned、Medium Quota + Pinned、Large 工作概览四种组件。
- Large 已删除虚构的 Gmail / Scheduled / Needs You Daily Brief，改为 quota、运行任务数量和手动入口的本机概览。
- 当前完整 ZIP 内含 `.appex`，但本轮严格签名验证返回信任失败；Widget Simulator 可渲染，不等于系统 Gallery 已交付。

## 3. 八个真实用户任务复核

| 用户任务 | 当前可否完成 | 主要问题 | 首发决策 |
|---|---|---|---|
| 3 秒知道哪个 quota、剩多少、何时 reset | 无任务时结构可以；有任务时失败 | 运行任务自动替换 quota | **必须首发并修复** |
| 3 秒知道是否有任务在运行 | 可知道数量 | 无法准确识别具体任务；状态语义过强 | **必须首发数量，标题 gated** |
| 查看具体运行任务 | 展开态源码可列最多 4 个 | 本轮点击 Resident 未成功展开；没有 exact return | **验证后开放** |
| 一次点击打开固定任务/对话 | 具备手动 HTTPS 入口和 Small Pinned | 只能证明系统接受打开请求，不能证明到达正确对话 | **必须首发** |
| 桌面查看额度 | Small Quota 渲染清楚 | Gallery/App Group/deep link 未完成 E2E | **必须首发，交付 gated** |
| 重要事件提醒 | quota crossing 与 task completion 路径存在 | task completion 无 exact return；系统通知不保证展示 | **quota 首发；task completion gated** |
| 屏幕共享/锁屏不泄露任务 | Widget 只发数量是正确的 | 新安装默认显示任务名；通知可能复用任务名 | **必须首发并修复默认值** |
| 设置主题和行为 | 控制中心提供大量设置 | 5 强调色与 System 主题扩大复杂度；配置页趋向 Dashboard | **只保留必要设置** |

## 4. 必须首发

### M1. 稳定的 Quota Resident

默认常驻信息固定为：

```text
7 天 · 54% 剩余      周二 09:58 重置
```

规则：

- multi-bucket 必须显示 `5 小时` / `7 天` 等短 window 身份；
- active task 出现时不得自动替换 quota；
- stale 时主信息改成 `7 天额度需更新 / 点击刷新`，旧数值不得继续以当前值语气突出；
- unavailable、demo 与 live 不能只靠颜色区分；
- Resident 只承担一个稳定任务，不轮播、不每秒跳变。

可测验收：

- 20 个 fresh 双 bucket 试次中，3 秒内 window + remaining + reset 全对率 ≥90%；
- fresh window 误认 = 0；
- stale 试次中把旧值当当前值的比例 = 0；
- `100%`、中文周几、12/24 小时制和 130% 字号均不裁切；
- 任务开始/完成期间 quota 文案位置不变化。

### M2. 运行任务数量与任务详情入口

用户确实需要知道 Codex 是否仍在工作，但“原始线程标题”不等于适合刘海的任务名。

首发策略：

- Resident quota 旁只允许一个非文字或极短的运行指示，例如 `● 2`，不占用 remaining/reset；
- 点击 Resident 后，Expanded 先保持 quota 上下文，并提供 `2 个任务运行中` 的次级入口；或者在控制中心概览列出任务；
- 完整任务名只在用户主动展开后显示；
- 任务状态文案只能说“生命周期显示仍在运行”，不能推断模型正在生成、等待工具或等待用户；
- 一个以上任务时，不能只用第一项代表全部任务。

可测验收：

- 3 秒内“是否运行 / 数量”正确率 ≥95%；
- 点击后 2 秒内能找到所有用户级运行任务，subagent 不混入；
- 真实 terminal event 后 2 次轮询内从运行列表移除；
- reader unavailable 时不显示 `0` 或“没有任务”，而显示“任务状态不可用”；
- 默认不在 Resident、通知或 Widget 展示任务标题。

### M3. Small Quota Widget

必须保留当前简洁结构：window、remaining、reset。source 与 observed time 放进点击后的 Expanded 或 VoiceOver，不长期占据桌面。

可测验收：

- 干净用户账户在 Widget Gallery 可搜索并添加；
- live、stale、empty、corrupt、future schema、demo 六态视觉不互相伪装；
- Widget 显示的 bucket、remaining、reset 与控制中心同一快照 100% 一致；
- stale 后不突出旧百分比；
- 点击 `workpulse://usage` 后正确出现 quota detail，成功率 100%；
- 不承诺实时刷新，界面必须能表达快照年龄/过期。

### M4. Small Pinned Widget 与固定入口

这是用户已经明确表达的高频需求：把“每日 Gmail 审查”等对话固定到桌面。

首发边界：

- 只保存用户手动提供的 HTTPS 链接；
- 不读取 Gmail，不推断 Scheduled health，不显示 last run / next run / 未读数；
- Widget 名称只在用户明确允许时展示；Privacy Mode 下用 `每日例程` 等 generic title；
- 点击后的反馈使用“已交给系统打开”，不能声称“已打开正确对话”。

可测验收：

- 无效、空白、非 HTTPS、已删除 routine ID 均有明确恢复路径；
- 7 天 diary 中至少 4 天使用固定入口，才保留为 Gallery 推荐项；
- open requested 成功率 100%，错误目标 = 0；
- 敏感标题未经 opt-in 出现在 Widget 的次数 = 0。

### M5. 最小控制中心

控制中心只能是 MenuBarExtra 的配置和恢复壳层。首发保留：

- 全部 quota bucket 与刷新；
- 当前运行任务数量与主动展开的列表；
- 固定入口设置/修复；
- Resident、顶部 Alert、通知 fallback 三个独立开关；
- Privacy、显示任务名、显示固定入口名；
- Light / Dark；
- Widget 同步状态与退出。

不在控制中心建立 Daily Brief、Needs You Inbox、消费仪表盘、订阅/授权宣传或历史分析。

可测验收：

- 用户从菜单栏进入后 5 秒内找到 quota 刷新、固定入口和隐私开关；
- 95% 用户能正确解释三个提醒开关的差别；
- 关闭 Resident 不影响 Alert，关闭 Alert 不影响 Resident；
- 所有设置变更重启后保持；
- 控制中心关闭后无独立普通窗口残留。

### M6. 隐私默认值

新安装推荐默认：

- Privacy Mode：开启；
- Resident 任务名：关闭；
- Widget 固定入口名：关闭，直到用户明确允许；
- Notification 任务名：始终 generic，或提供独立 opt-in，默认关闭；
- Widget 运行任务：只显示数量。

当前 copy `不读取对话正文` 过于绝对。任务 reader 会读取 rollout 文件片段并只解析生命周期事件。更准确的说法应为：

> 只解析本机任务生命周期事件；不展示或保存消息正文。

可测验收：

- 全新安装、屏幕共享、锁屏通知和 Widget 默认状态中敏感标题暴露 = 0；
- 开启 Privacy Mode 后所有外部表面在一个刷新周期内完成隐藏；
- “刘海显示任务名称”开关不再控制系统通知；
- 关闭名称展示后，VoiceOver 也不朗读被隐藏标题；
- 本地 snapshot、通知 payload 和 telemetry 不包含线程标题、prompt、cwd 或文件路径。

### M7. 浅色 / 深色主题

首发只保留用户明确要求的两个模式：Light、Dark。

- 控制中心和无刘海外屏胶囊响应用户选择；
- 带物理刘海的顶部岛固定深色，与硬件黑区连续；
- Widget 与 WorkPulse 主题的关系必须清楚。如果 Widget 接收应用主题，就需验证系统浅/深色变化；若跟随系统，则不要在设置中暗示可单独强制。

可测验收：Light / Dark × Widget / 控制中心 / 无刘海胶囊均有截图；对比度、Increase Contrast、Reduce Transparency、130% 字号通过；切换主题不改变信息层级或造成闪白。

## 5. 验证后开放

### V1. Resident 的“任务优先”模式

可以作为 opt-in，而不能自动发生。只有当用户 diary 证明他们更常查看任务而不是 quota，才开放 `额度优先 / 任务优先` 选择。

通过条件：任务模式 3 秒内任务识别正确率 ≥90%；标题相似时仍能区分；屏幕共享暴露 = 0。否则只保留数量提示和展开列表。

### V2. 任务完成 Alert / Notification

当前任务消失后可触发完成提醒，但用户点击后没有 exact return 到刚完成的任务，提醒会进入一个已经不再列出该任务的界面。

开放条件：

- terminal ground truth 下 completion precision ≥99%，高风险误报 = 0；
- 点击可回到具体 Codex task，或明确显示已完成任务的本机记录；
- 同一任务顶部 Alert 与 Notification 重复率 = 0；
- source 在前台时不打扰；用户离开时按通知偏好 fallback；
- task title 通知单独 opt-in，锁屏默认 generic。

### V3. 系统通知 fallback

只有真实验证 authorization、Focus、banner/sound/lock-screen 设置、handoff 与 opened 状态后开放。`UNUserNotificationCenter.add` 成功只能写“系统已接收请求”，不能写“已展示”。

### V4. Medium Quota + Pinned

它复用两项真实能力，但尚未证明比两只 Small 更好。只有当用户经常同时查看 quota 与打开 routine，且希望节省一个桌面位置时才开放。

通过条件：7 天内至少 50% 目标用户选择 Medium 替代两只 Small；左右分区点击正确率 100%；130% 字号不裁切。

### V5. Large 工作概览

当前 Large 已不再虚构 Daily Brief，是正确收缩。但它仍把 quota、运行数量与固定入口集中成一个桌面 Dashboard，与产品“轻量 companion”定位存在张力。

开放条件：

- 14 天内至少 5 天主动使用；
- 至少两个分区各产生 3 次以上真实动作；
- 相比 Small 组合显著减少打开控制中心的次数；
- 没有 task title、Gmail、Scheduled 或 Needs You 假状态。

### V6. 跟随系统主题

可以作为第三种便利选项，但不是用户要求的首发目标。只有 Light / Dark 两个明确模式稳定后再开放。

## 6. 应删除或从生产构建移除

### D1. Resident 自动被运行任务接管

直接删除自动切换。它让用户先前明确要求的 quota 消失，又无法完整显示任务身份。

### D2. 原始任务标题默认显示

默认 raw thread/prompt title 不适合刘海，也有隐私风险。只有用户 opt-in 后在 Expanded/控制中心显示；Resident 使用数量或用户设置的短标签。

### D3. 5 种强调色

Ocean、Violet、Mint、Sunset、Rose 不解决任何核心任务，却将 Light/Dark、Widget、外屏胶囊、对比度和状态色测试矩阵扩大五倍。首发删除整个强调色设置，使用一个中性品牌色；warning/critical 保留固定语义色。

### D4. 生产环境“预览顶部提醒”和“测试通知”常驻入口

这些是 QA 工具。正式用户界面中删除或放入隐藏 Diagnostics；不要让测试功能与真实提醒争夺注意力。

### D5. Daily Brief、Gmail/Scheduled 状态和 Needs You fixture

保持从生产 Widget 与控制中心移除。Large 只能称“工作概览”，不能重新包装成 Daily Brief。真实 adapter 与需求 diary 未通过前，不显示 `0`、`尚未连接` 或模拟事件占位。

### D6. 控制中心中的购买/授权宣传

`正式发布计划采用一次买断` 与当前任务无关，且产品尚处开发期。它不应占据配置表面。授权、签名和版本信息放入 About/Diagnostics。

### D7. 每秒精确运行时长

Resident 中删除秒级计时，使用 `4 分钟`、`1 小时 12 分` 等稳定粗粒度，或仅在 Expanded 中显示。秒级变化增加视觉噪音，不提升决策质量。

## 7. 首发组合

### 默认桌面体验

1. 顶部 Resident：固定显示 primary quota；右侧允许一个运行数量指示。
2. Small Quota Widget：可选桌面 glance。
3. Small Pinned Widget：可选高频对话入口。
4. MenuBarExtra 控制中心：设置、查看所有 bucket、任务列表和故障恢复。
5. 低额度 Alert：用户 opt-in，fresh crossing 才触发。

### 默认关闭

- 任务标题外显；
- 任务完成主动提醒；
- 通知中显示任务名；
- Medium 与 Large Widget；
- 任何 Needs You、Gmail、Scheduled 或 Daily Brief 状态。

## 8. 完成 Gate

| Gate | 可测标准 | 当前判断 |
|---|---|---|
| G1 Quota glance | 3 秒内 window/remaining/reset 全对 ≥90% | 无任务方向正确；任务开始后失败 |
| G2 Task glance | 数量正确 ≥95%；完整身份进入展开态；不可用不伪装 0 | 数量可见；Resident 标题截断 |
| G3 Pinned | 7 天至少 4 天使用；错误目标 0；只承诺 open requested | 能力存在，未完成自然使用 |
| G4 Widget | Gallery 可搜索添加；App Group、stale、点击、刷新 E2E | Simulator 通过；Gallery 未证明 |
| G5 Alert/Notification | fresh transition；无重复；不可达 fallback；点击可行动 | quota 可继续；task completion gated |
| G6 Privacy | 新安装所有外部表面敏感标题暴露 0 | 当前默认任务名开启，不通过 |
| G7 Theme/A11y | Light/Dark、130%、VoiceOver、Contrast、Reduce Motion | 本轮无完整运行证据 |
| G8 Control Center | 5 秒找到三项核心设置；无独立窗口；无 Dashboard 膨胀 | 源码结构可用，运行态未验 |

任何 Gate 未通过，WorkPulse 只能称为本机 **Technical Preview**，不能称完整产品已完成。

## 9. 最终用户价值排序

1. quota window + remaining + reset；
2. 固定对话/例程的一次点击入口；
3. 运行任务数量与主动查看列表；
4. Small Quota Widget；
5. fresh quota crossing Alert；
6. Small Pinned Widget 的日频复用；
7. task completion 提醒；
8. Medium / Large 汇总；
9. 主题自动化与装饰性强调色。

最终原则：**顶部常驻区不能靠自动切换猜测用户此刻最关心什么。稳定回答一个问题，比轮流显示两类不完整信息更有价值。**
