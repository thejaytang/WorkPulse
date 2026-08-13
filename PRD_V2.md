# WorkPulse 产品需求文档 V2.0

> 工作名：WorkPulse  
> 产品副标题：macOS AI Work Companion  
> 文档状态：团队评审版，可进入 Phase 0 技术与用户验证  
> 日期：2026-08-10  
> 平台：macOS 14+，优先 Apple Silicon  
> 首发范围：Codex-first，ChatGPT cloud 能力受官方接口约束  
> 分发策略：Phase 0 / Pilot 使用 Developer ID 签名与 notarized DMG；Mac App Store 另行评估
> 联合复审角色：产品经理、UI/UX 设计师、Apple 技术可行性、用户研究

## 0. 执行摘要

WorkPulse 是 Mac 上的 **AI work continuity layer**。它不复制 ChatGPT 或 Codex 的完整界面，而是在菜单栏、小组件、自定义刘海状态层和系统通知之间，持续回答三个问题：

1. 哪个 AI 工作正在进行？
2. 哪件事正在等待我处理？
3. 当前 Codex 额度窗口还剩多少 headroom，何时 reset？

V2 的首要产品是 **Needs You 注意力收件箱**，其次才是额度展示。用户最需要的不是更多仪表盘，而是无需轮询就能知道任务完成、失败或等待审批，并能回到正确上下文。公开反馈中，Codex 用户明确描述了长任务超过一分钟、切换窗口后只能反复查看完成状态的问题。[Codex completion notification issue](https://github.com/openai/codex/issues/3962)

V2 不再承诺“自动镜像 ChatGPT 桌面端全部项目、线程和 Scheduled”。OpenAI 官方文档确认 ChatGPT Projects 和 Scheduled 的产品能力，但未提供第三方伴侣应用枚举这些云端对象的公开接口。[OpenAI Projects and chats](https://learn.chatgpt.com/docs/projects) [OpenAI Scheduled tasks](https://learn.chatgpt.com/docs/automations)

V2 采用条件式路线：

- 稳定产品壳：`MenuBarExtra`、WidgetKit、macOS 通知、本地事件库、手动收藏与隐私控制。
- **Technical Preview**：通过受管 `codex app-server` `stdio` 子进程读取额度、usage 和 WorkPulse 可见的 Codex thread 事件。
- 不可承诺能力：自动镜像 ChatGPT cloud、精准打开任意 ChatGPT desktop thread、自动识别所有屏幕共享。
- P2 能力：iPhone companion 与 ActivityKit **Live Activities**，且只用于有明确开始和结束的单个长任务。

最关键的 Go / No-Go 条件是：必须验证 WorkPulse 能否获得可靠的任务事件，并提供可靠的上下文返回路径。若不能，产品不能以“ChatGPT 实时工作伴侣”发布。

## 1. V1 团队复审结论

### 1.1 保留的正确方向

- “小组件长期扫视、刘海表达变化、通知处理高价值打断”的表面分工正确。
- Resident、Alert 两种自动形态，加 Expanded 主动详情层的模型正确。
- 额度与任务状态分离、跨表面去重、显示数据来源和新鲜度的原则正确。
- Mac-only 首版不依赖 iPhone Live Activity 的决策正确。
- 视觉应保持 macOS 原生、低打扰和隐私优先。

### 1.2 V1 必须修正的问题

| 问题 | V1 风险 | V2 决策 |
|---|---|---|
| 首发用户过宽 | 同时服务一般 ChatGPT、Work、Codex、Scheduled 用户 | P0 锁定多任务 Codex 用户，其他用户是后续扩展 |
| MVP 过载 | 同时承诺三种 Widget、刘海、通知、Projects、Scheduled、Brief | P0 只做 Needs You、Quota、Small、Medium、菜单栏和可选刘海 |
| 数据承诺过强 | 把独立 App Server 当成 ChatGPT desktop 实时观察器 | App Server 降为 Technical Preview，并设置跨客户端可见性 Gate |
| 一键返回承诺无依据 | 官方没有公开稳定的 ChatGPT desktop thread deep-link contract | 只对已验证 URL 或 WorkPulse-owned thread 承诺准确返回 |
| Medium 定义不一致 | PRD 写 Now & Next，原型却是额度和项目列表 | Medium 只保留 Current + Next，额度降为辅助 chip |
| 重复打扰 | failed / exhausted 同时触发 Alert 和系统通知 | 引入 **surface ownership**，同一时刻只有一个主动提醒表面 |
| Hover 行为冲突 | 一处 hover 展开，另一处 hover 只预览 | hover 永不打开 Expanded，只高亮或显示 tooltip |
| `stale` 混入任务状态 | 数据可信度和工作流状态混淆 | freshness 独立为第二维度 |
| 隐私能力过度承诺 | 假设可自动检测任何屏幕共享 | P0 使用显式 Privacy Mode；自动检测不作承诺 |
| Daily Brief 证据不足 | 尚未证明用户需要伴侣应用重新生成 Brief | 降为 P1 实验，默认不额外消耗 AI 额度 |

## 2. 产品定位与边界

### 2.1 产品定位

> WorkPulse 是为高频 Codex Mac 用户设计的注意力与额度状态层。它把任务完成、失败、等待处理和 quota headroom 组织为安静、可信、可追溯的系统级体验。

### 2.2 不是这些产品

- 不是完整 Codex client，也不在 V2 内复制对话、终端、diff 和文件审查界面。
- 不是音乐、天气、剪贴板、相机、文件架等万能刘海工具箱。
- 不是 ChatGPT cloud Projects / Scheduled 的非官方同步器。
- 不是精确预测“剩余额度能否完成某项任务”的模型。
- 不是绕过 Focus、通知设置或审批上下文的高优先级提醒器。
- 不是 Apple 官方 Dynamic Island。Mac-only 的刘海层是普通 AppKit 浮层。

### 2.3 产品承诺分级

| 等级 | 定义 | 允许的产品文案 |
|---|---|---|
| Stable | Apple 或本地稳定能力，WorkPulse 可独立保证 | “可用”“支持” |
| Constrained | 能实现，但受系统刷新、权限或来源限制 | “在……条件下可用” |
| Technical Preview | 官方能力存在，但接口或部署仍具有实验性质 | “实验功能”“可能随 Codex 更新变化” |
| Unsupported | 当前无公开接口或无法可靠实现 | 不进入功能承诺 |

### 2.4 与 ChatGPT 官方体验的差异

ChatGPT 已经提供 Activity view、系统通知和任务状态表达，能够展示 unread、running、waiting 等活动信息。WorkPulse 不应把“首次提供后台任务状态”作为差异化。[OpenAI Notifications](https://learn.chatgpt.com/docs/notifications)

WorkPulse 的可验证差异必须集中在：

- 菜单栏、Widget、可选刘海与通知之间的一致状态模型。
- 用户可配置的打扰路由、升级和跨表面去重。
- quota 多窗口、reset、来源与 freshness 的透明表达。
- Needs You 历史、acknowledgement 和本地聚合。
- 在无刘海、外接屏、全屏和 Privacy Mode 中仍保持可达。

若这些差异不能显著减少轮询或缩短上下文返回时间，WorkPulse 就不应仅凭新的视觉外壳发布。

## 3. 用户研究结论

### 3.1 首发用户

多任务 Codex 开发者和 AI Builder：

- 每天有 3 个以上中长时 Codex turns 或 threads。
- 经常在 Codex 运行时切去编辑器、浏览器、终端或另一个项目。
- 遇到 approval、失败、完成和额度窗口切换。
- 使用带刘海 MacBook，也可能接无刘海外接显示器。
- 愿意安装签名 DMG，但要求本地优先、权限透明和低资源占用。

### 3.2 次级用户

- 使用 ChatGPT Projects 的研究、写作和分析用户。
- 使用 Scheduled 生成晨报、周期报告或研究跟踪的用户。
- 高度在意屏幕共享、通知正文和任务名泄露的企业用户。

这些用户不进入 P0 自动同步范围，只用于验证未来需求。

### 3.3 公开证据排名

| 排名 | 用户痛点 | 严重度 | 跨来源频率信号 | 信心 | 产品动作 |
|---|---|---:|---:|---:|---|
| 1 | 后台任务完成、失败或等待审批时只能轮询 | 高 | 高 | 高 | Needs You 成为首要产品 |
| 2 | 收到提醒后仍难回到正确项目或 thread | 高 | 中高 | 中高 | 上下文返回成为 Go / No-Go Gate |
| 3 | quota、reset 与不同表面状态不一致 | 高 | 中高 | 高 | 显示来源、新鲜度和窗口名，不二次解释服务端规则 |
| 4 | Scheduled 是否运行、失败或使用何种连接器不透明 | 高，仅自动化用户 | 中 | 中高 | P1 只做 Scheduled Health，不做完整管理器 |
| 5 | 刘海工具误触、跨屏错位、性能和隐私问题 | 中高 | 中高 | 高 | 菜单栏为主入口，刘海可关闭，默认全屏抑制 |

额度问题的公开案例包括 reset 锚点不确定和 Web / Mac 状态不一致。[Codex quota-window issue](https://github.com/openai/codex/issues/28246) [Codex usage desync issue](https://github.com/openai/codex/issues/23192)

### 3.4 竞品格局与机会边界

| 类型 | 代表产品 | 已覆盖能力 | 用户反馈暴露的问题 | WorkPulse 机会 |
|---|---|---|---|---|
| 额度型 | [CodexIsland](https://github.com/ericjypark/codex-island)、[CodexUsageBar](https://codexusagebar.com/)、[Limit Bar](https://limitbar.artsvit.com/) | 多窗口额度、reset、used / remaining、阈值提醒 | 额度本身容易同质化，无法解决任务等待和上下文返回 | 把 quota 放入工作决策，但明确只做 headroom，不伪装为完成概率 |
| Agent 通知型 | [Notchly](https://github.com/Notchly/Notchly)、[AgentNotch](https://github.com/appgram/agentnotch) | approval、完成提醒、声音、刘海动效 | 新动画不能解决多任务排序、去重和提醒收回后的状态持久化 | Needs You 收件箱、事件优先级、surface ownership、可靠 open target |
| 万能刘海型 | [Boring Notch](https://github.com/TheBoredTeam/boring.notch)、[Perch](https://apps.apple.com/us/app/dynamic-notch-island-perch/id6742724228) | 音乐、天气、日历、文件架、系统状态 | 外接屏、全屏、hover 误触、性能和功能膨胀持续造成体验负担 | 只做 AI work continuity，不进入通用工具箱竞争 |

由此得到三条产品边界：

1. quota 是获客入口，不是充分差异化。
2. 刘海是状态投放表面，不是产品本身。
3. 真正的产品资产是统一事件模型、可信 freshness、打扰路由和上下文返回。

### 3.5 研究边界

- Reddit、GitHub issues 和 App Store reviews 有明显 **self-selection bias**。
- 竞品功能页面证明存在供给，不证明付费意愿或留存。
- Daily Brief 有需求信号，但没有充分证据证明它必须通过 Mac Widget 或刘海消费。
- 尚无公开证据证明大多数用户希望 quota、Projects、Scheduled 和 Brief 全部集成在一个产品中。

## 4. 核心 **Jobs to be Done**

### JTBD-1：停止轮询

当 Codex 在后台运行时，我希望 WorkPulse 在完成、失败或需要我时可靠提醒，让我可以继续当前工作。

### JTBD-2：准确回到上下文

当我收到提醒时，我希望一次操作回到可验证的对应 thread 或 WorkPulse 详情，而不是先打开首页再搜索。

### JTBD-3：理解额度窗口

当我准备开启新的长任务时，我希望看到最紧张额度窗口的 remaining、reset 和数据新鲜度，由我自己决定是否开始。

### JTBD-4：在多屏环境中保持安静

当我全屏、演示、外接显示器或关闭刘海时，我仍能通过菜单栏和必要通知获得同一核心状态。

## 5. 成功定义

### 5.1 北极星指标

**Action-needed resolution time**：从 WorkPulse 获得可确认的 needs-action 事件，到用户打开对应可处理上下文的中位时间。

### 5.2 核心指标

- Context return success rate：主操作进入正确、可处理上下文的比例。
- Missed attention rate：高价值事件 30 分钟内未被看到的比例。
- Duplicate interruption rate：同一事件被两个主动表面重复打扰的比例，目标小于 1%。
- False freshness rate：过期数据被呈现为实时的比例，目标为 0。
- Notification disable rate：安装七天内关闭全部通知的比例。
- Overlay disable rate：安装七天内关闭刘海层的比例，用于判断其真实价值而非作为失败惩罚。
- Widget retention：不同尺寸七日后仍留在桌面的比例。
- Background cost：空闲 CPU、内存与 energy impact。

### 5.3 不使用的成功指标

- 通知发送数量。
- 刘海展开次数。
- Widget 点击次数的单独增长。
- Daily Brief 生成数量。

这些指标会激励产品制造打扰或无意义内容。

## 6. 发布前关键决策门

### Gate A：跨客户端任务可见性，最高优先级

验证独立 `codex app-server` 是否能观察 ChatGPT / Codex desktop 正在运行的目标 threads、状态变化和请求。若只能读取历史或 `notLoaded`，不得宣称实时镜像桌面端。

### Gate B：上下文返回

必须满足以下至少一种：

1. 有官方、稳定的 thread deep link。
2. WorkPulse 管理该 App Server thread，可打开自己的 task detail scene。
3. 用户保存的 URL 可稳定打开对应内容。

若三者均不成立，Needs You 的价值链不闭合，完整 MVP No-Go。

### Gate C：App Server 稳定性

覆盖登录、token refresh、Codex 升级、schema 变化、睡眠唤醒、进程崩溃和多账号。`stdio` 失败时必须进入 `unknown`，不能循环重启或展示旧状态为 Live。

### Gate D：刘海兼容性

通过带刘海、无刘海、双外屏、菜单栏自动隐藏、Spaces、Stage Manager、全屏视频和演示兼容矩阵。若主要场景不稳定，Pilot 默认关闭刘海，仅保留菜单栏。

### Gate E：用户价值

至少 8 名首发用户完成两周 diary study。核心问题：提醒是否减少轮询、上下文返回是否成功、刘海是否被保留。

## 7. 产品阶段与范围

### Phase 0：技术与用户验证，不对外承诺生产稳定

- `AppServerStdioAdapter` spike。
- Quota、thread status、turn completed / failed、approval 事件验证。
- 上下文返回 spike。
- Small / Medium Widget 真机刷新验证。
- 菜单栏、通知和可选刘海兼容矩阵。
- 8 至 12 名用户原型与 diary study。

### P0：Pilot MVP，Gate A / B / C 通过后

- Needs You 注意力收件箱。
- Quota Headroom。
- `MenuBarExtra` 可靠主入口。
- Small Quota Widget。
- Medium Now & Next Widget。
- 可关闭的 Resident / Alert / Expanded 刘海增强。
- 高价值 macOS 通知与跨表面去重。
- 手动 Privacy Mode、隐藏标题、全局静音和本地数据清除。
- App Server 功能明确标注 Technical Preview。

### P1：Beta

- Large Daily Brief Widget，先做本地聚合版。
- Scheduled Health，仅在获得可信来源后启用。
- Widget 内安全的本地“标记已看”“稍后提醒”。
- quota pace 仅作为明确标注的本地估算。
- 项目范围筛选和全局快捷键自定义。

### P2：条件式扩展

- Extra Large AI Workboard。
- OpenAI 提供正式接口后接入 ChatGPT cloud Projects / Chats / Scheduled。
- iPhone companion 与 ActivityKit Live Activity。
- 跨设备接力和团队状态。

## 8. 信息与状态模型

### 8.1 工作状态

WorkPulse 的 UI 状态必须由来源能力映射，不能假设所有来源都有同一状态：

- `running`：有正在进行的 turn 或工作。
- `needs_approval`：有明确 approval 请求。
- `needs_input`：有明确用户输入请求；实验来源不可用时显示 `unsupported`。
- `completed_unread`：来源报告完成，且 WorkPulse 本地尚未确认已看。
- `failed`：来源报告失败。
- `interrupted`：turn 被中断。
- `idle`：来源在线且无活动任务。
- `not_loaded`：thread 存在，但不在当前 App Server runtime。
- `unknown`：连接中断或证据不足。
- `unsupported`：该来源不提供该状态。

`queued` 和 `paused` 不进入跨来源核心模型，除非具体 adapter 明确支持。

### 8.2 Freshness 独立维度

- `live`：已连接事件流或在来源定义的新鲜度内。
- `cached`：使用最近可信快照，仍在允许窗口内。
- `stale`：超过来源阈值。
- `unavailable`：没有成功快照或来源不可用。

默认阈值，需在 Phase 0 校准：

| 来源 | Cached 起点 | Stale 起点 |
|---|---:|---:|
| 活动 thread 事件 | 10 秒无心跳 | 30 秒 |
| Usage / quota | 5 分钟 | 15 分钟 |
| 手动 Scheduled 元数据 | 不适用 | 到期后 15 分钟仍无可信结果 |
| Daily Brief | 不适用 | 计划生成时间后 1 小时 |

### 8.3 额度健康度

- `healthy`：remaining > 20%。
- `watch`：10% < remaining ≤ 20%。
- `critical`：0% < remaining ≤ 10%。
- `exhausted`：remaining = 0%。
- `unknown`：数据不可用或 stale。

阈值是提醒策略，不是任务完成概率。Small Widget 不得写“足以完成长任务”。

### 8.4 事件对象

每个事件至少包含：

```text
eventId
dedupeKey
sourceId
sourceType
threadId?
projectLabel?
eventType
severity
occurredAt
freshness
surfaceOwner
alertDisplayedAt?
notificationDeliveredAt?
acknowledgedAt?
resolvedAt?
openTarget?
privacyClass
```

`acknowledged` 只表示用户已看到提醒，`resolved` 才表示来源问题已解除。

## 9. 产品表面架构

```mermaid
flowchart LR
    A["Source adapters"] --> B["Event normalizer"]
    B --> C["Event store + freshness"]
    C --> D["Routing policy + surface ownership"]
    D --> E["MenuBarExtra\n可靠主入口"]
    D --> F["WidgetKit\n长期扫视"]
    D --> G["Notch overlay\n可选增强"]
    D --> H["macOS notification\n条件式打断"]
    E --> I["Main app\nInbox / Usage / Settings / Diagnostics"]
    F --> I
    G --> I
    H --> I
```

### 9.1 表面职责

| 表面 | 核心问题 | 主动打断 | 可靠性定位 |
|---|---|---:|---|
| 菜单栏 | 全部核心状态与总控 | 否 | P0 主入口 |
| Small Widget | 最紧张 quota window 还有多少 | 否 | P0 |
| Medium Widget | 现在发生什么，下一步是什么 | 否 | P0 |
| Large Widget | 今天最值得关注什么 | 否 | P1 |
| Extra Large Widget | 多任务全局工作台 | 否 | P2 |
| Resident | 一个持续状态 | 否 | 可关闭增强 |
| Alert | 一个新发生的高价值事件 | 轻度 | 可关闭增强 |
| Expanded | 用户主动查看的简要详情 | 用户发起 | 可关闭增强 |
| 系统通知 | 刘海不可达或事件升级 | 是 | P0 |

## 10. Widget 需求

Apple 的 WidgetKit 支持 small、medium、large 和 extra large；Widget 通过 timeline 更新，系统可能晚于请求时间刷新，不能作为秒级实时表面。[WidgetKit timeline](https://developer.apple.com/documentation/widgetkit/timeline) [Apple Widget strategy](https://developer.apple.com/documentation/widgetkit/developing-a-widgetkit-strategy)

### 10.1 Small：Quota Pulse，P0

唯一问题：当前最紧张的 Codex 额度窗口还剩多少？

结构：

1. 窗口名，一行。
2. 28 至 32pt remaining 百分比。
3. reset 倒计时。
4. 仅在异常时显示 `Cached`、`Stale` 或更新时间。

规则：

- 默认选择 remaining 最低的窗口。
- 点击整体打开 Usage scene。
- 不放刷新按钮、图表或第二个操作。
- 无数据时显示“连接后显示 Codex 额度”，不能用 0% 或 100% 占位。
- reset 倒计时可使用 dynamic date；百分比只随新快照变化。

### 10.2 Medium：Now & Next，P0

唯一问题：现在发生什么，下一步需要什么？

布局：56% Current + 44% Next。

Current：

- 一个最高优先级状态。
- 一行 thread 名或隐私化标题。
- 运行、等待或失败时间。
- 最多一个 `另有 N 项`。

Next 只显示以下最高优先级一项：

1. needs approval / input。
2. 最近失败。
3. 最近完成未读。
4. quota critical / exhausted。
5. 无事件时显示本地下一计划。

底部只允许一个辅助 quota chip。P0 最多两个点击区域，不在 Widget 内审批或输入。

### 10.3 Large：Daily Brief，P1 实验

唯一问题：今天最值得关注什么？

结构：

- Header：生成时间和覆盖状态。
- 两行以内 summary。
- 最多 3 个 priorities。
- 最多 2 个 context chips：Needs You、下一计划、Quota 中选择。
- Footer：打开 Brief。

模式：

1. 展示用户已有 Daily Brief 结果。
2. 根据 WorkPulse 已知事件做确定性本地聚合。
3. 用户明确选择后调用 AI 生成，显示会消耗额度。
4. 完全关闭。

默认采用模式 2，不默认额外调用 AI。生成失败时保留上次 Brief，并显示生成时间。

### 10.4 Extra Large：AI Workboard，P2

使用 2×2 网格：

- Active：最多 2 条。
- Needs You：最多 3 条。
- Scheduled：最多 3 条，仅可信来源可用。
- Usage：最多 2 个窗口。

收藏项目只作为数据范围筛选，不成为第五个区块。空模块隐藏，不留下四个空框。

### 10.5 Widget 通用状态

| 状态 | 表现 |
|---|---|
| Initial loading | 静态 skeleton + “正在同步”，不无限旋转 |
| Empty | 说明缺少什么，并提供进入主应用的单一动作 |
| Healthy | 正常内容，不持续显示“实时”徽章 |
| Cached / Stale | 保留最后快照，降低强调度，显示时间 |
| Error | 显示最后快照与“打开诊断” |
| Privacy | 标题替换为数量和泛化状态 |
| Unsupported | “当前来源未提供此数据”，区别于连接错误 |

Widget 可通过 `AppIntent` 执行安全的本地动作，但 P0 不在 Widget 内执行审批、删除、命令或长文本输入。[Apple interactive widgets](https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities)

## 11. 刘海交互规范

### 11.1 总体原则

- 菜单栏是可靠入口，刘海是可关闭增强。
- hover 永不打开 Expanded。
- 刘海不在无刘海屏幕中央模拟假刘海。
- 默认全屏 suppress Alert。
- 不在刘海中显示完整 prompt、回复、命令或日志。
- 不允许从紧凑表面确认高风险写操作。

### 11.2 Resident

职责：表达一个持续状态。

- 视觉高度 32 至 36pt，透明 hit area 至少 44pt。
- 宽度 220 至 320pt，根据内建刘海 safe area 适配。
- 只显示状态图形、单行标题和一个数字或时间。
- 无活动、无未读且未开启常驻额度时完全隐藏。
- hover 150ms 高亮；标题截断时 500ms 后显示单行 tooltip。
- click、`Enter`、`Space` 或快捷键打开 Expanded。
- Resident 固定在用户选择的显示器，不随鼠标跳屏。

### 11.3 Alert

职责：表达一个新发生的高价值事件，不抢焦点。

- 宽度 360 至 420pt，最多两行文案。
- 普通完成显示 4 秒。
- needs action 显示 8 秒。
- failed / exhausted 显示 10 秒。
- hover 或 VoiceOver 读取时暂停；鼠标离开后至少保留 3 秒。
- 一个主操作，关闭按钮 hit area 至少 44pt。
- 新事件不叠卡；高优先级替换低优先级，其余进入队列。
- 60 秒内同类完成事件合并。
- 单次未展开可见上限 30 秒。

### 11.4 Expanded

职责：用户主动查看的简要详情，不是自动通知。

- 宽度 `clamp(420pt, 34vw, 520pt)`。
- 高度 180 至 360pt，不超过可用屏高 50%。
- 第一层：最高优先级状态和唯一主操作。
- 第二层：quota 和 reset。
- 第三层：下一计划或事件队列。
- 点击 Resident、键盘激活或菜单栏入口打开。
- `Esc`、再次点击 Resident 或点击外部关闭。
- 关闭后焦点返回原触发点。
- 用户交互期间永不自动收回。
- 已展开时的新关键事件只插入顶部状态条，不重启动画。

### 11.5 多显示器与全屏

- Resident 默认固定内建屏，用户可选择其他显示器。
- Alert 只出现一次；无法可靠判断关注屏时使用用户固定屏或鼠标所在屏。
- 无刘海屏只使用右侧 `MenuBarExtra` 和锚定 popover。
- 普通全屏默认不叠加 Alert，只更新状态并由路由器决定是否通知。
- 用户可选择“全屏时显示关键失败”，但不能承诺覆盖所有 Spaces 和演示场景。

## 12. 通知与 **surface ownership**

### 12.1 所有权规则

同一事件在任一时刻只有一个主动提醒表面：

1. 用户最近 60 秒活跃、刘海可见、未全屏抑制：Alert 获得所有权。
2. 用户离开、锁屏、刘海关闭或不可达：系统通知获得所有权。
3. Alert 展示后仍未处理，达到升级阈值时，所有权转移给通知。
4. 通知已送达后，返回桌面不得重放 Alert，只在 Resident 保留未解决标记。
5. 点击 Alert、通知或 Expanded 的对应事件后，取消全部待发送升级。

### 12.2 Pilot 默认升级阈值

| 事件 | Alert | 通知升级 | 默认通知级别 |
|---|---:|---:|---|
| needs approval / input | 8 秒 | Alert 后 30 秒仍未确认 | `.active` |
| failed | 10 秒 | Alert 后 15 秒且用户不活跃 | `.active` |
| quota exhausted | 10 秒 | Alert 后 15 秒且用户不活跃 | `.active` |
| 长任务完成 | 4 秒 | 仅用户不活跃且任务 > 60 秒 | `.passive` 或 `.active`，由设置决定 |
| quota watch / critical | 4 秒，可关闭 | 默认不升级 | `.passive` |

这些阈值是 Pilot 假设，必须通过用户研究校准。WorkPulse 不把普通失败滥用为 `.timeSensitive`，系统 Focus 和用户设置拥有最终决定权。[Apple notification interruption level](https://developer.apple.com/documentation/usernotifications/unnotificationcontent/interruptionlevel)

### 12.3 通知操作

- 主操作：打开已验证的上下文。
- 次操作：稍后提醒。
- “标记已看”只更新 WorkPulse 本地 acknowledgement，不宣称解决来源问题。
- 不在通知中直接批准命令、权限或文件写入。

## 13. Needs You 注意力收件箱

### 13.1 P0 事件类型

- needs approval。
- needs input，仅当来源明确支持。
- failed。
- 长任务 completed。
- quota exhausted 导致的不可继续状态。

### 13.2 每条事件展示

- 来源与 capability label。
- thread / 项目泛化标题。
- 发生时间。
- 严重度。
- 新鲜度。
- 一个主操作。
- 稍后提醒或标记已看。
- 未解决状态。

### 13.3 排序

`needs approval` > `failed` > `quota exhausted` > `needs input` > `completed unread`

同级按发生时间倒序。不同来源无法比较时，不合并成虚假的统一执行进度。

## 14. Quota Headroom

OpenAI 官方 App Server 文档公开 `account/rateLimits/read`、`account/rateLimits/updated` 和 `account/usage/read`，包括 `usedPercent`、`windowDurationMins`、`resetsAt` 和多 bucket。[OpenAI App Server](https://learn.chatgpt.com/docs/app-server)

### 14.1 P0 展示

- 具体窗口名或 `limitId`。
- `remaining = max(0, 100 - usedPercent)`，标记为 Derived。
- used / remaining 切换。
- reset 倒计时与本地绝对时间。
- 来源、最后成功更新时间、freshness。
- watch / critical / exhausted 阈值。

### 14.2 不做

- 不把多个窗口压成一个“ChatGPT 总额度”。
- 不承诺覆盖 Deep Research、图片、视频或所有模型。
- 不根据百分比确定性预测任务一定完成。
- 不默认展示 lifetime token、streak 或复杂图表。
- 不静默消耗 rate-limit reset credit。

### 14.3 数据冲突

若 WorkPulse 数值与 ChatGPT / Codex 官方 UI 不一致：

- 标记 `Source conflict`。
- 显示各自更新时间。
- 不自行选择一个值称为权威。
- 提供诊断信息，不自动刷新轰炸服务。

## 15. Projects、Threads、Scheduled 与 Daily Brief

### 15.1 Codex threads

`thread/list`、`thread/status/changed` 和 `turn/completed` 等方法存在，但只对相应 App Server 可见或管理的 thread 可靠。未加载 thread 可能只有 `notLoaded` 状态。[OpenAI App Server](https://learn.chatgpt.com/docs/app-server)

P0 只展示：

- WorkPulse 确认可见的 thread。
- 由 `sourceKind`、title、cwd 和 runtime status 支持的字段。
- 本地 pin 和 acknowledgement。

### 15.2 ChatGPT Projects / Chats

- P0 仅手动收藏 URL 或名称。
- 手动数据标记 `Manual`。
- 不显示伪造的 running、completed 或 last sync。
- 打开动作只承诺打开已保存 URL 或 ChatGPT 应用回退。

### 15.3 Scheduled Health，P1 条件式

只有获得可信来源时才显示：

- 下次运行时间与时区。
- running / success / partial / failed / offline。
- 最近结果时间。
- 连接器或来源健康度。
- 结果入口。

未获得接口时只允许用户保存一个计划入口和自定义时间，不能称为“同步状态”。

### 15.4 Daily Brief，P1 实验

Brief 最多包含：

- 3 个 priorities。
- 2 个 Needs You。
- 最近失败或完成事件。
- 最紧张 quota window。
- 所有条目可追溯到来源。

默认使用确定性本地聚合，不默认调用 AI。若用户选择 AI 生成，必须先说明数据范围、额外额度消耗和失败回退。

## 16. 主应用与 Onboarding

### 16.1 主应用导航

最多五个一级入口：

1. Inbox。
2. Usage。
3. Brief，P1。
4. Pinned。
5. Settings & Diagnostics。

### 16.2 Onboarding

Step 1，产品边界：

- 说明 WorkPulse 不是 OpenAI 官方应用。
- 说明首发只覆盖 Codex 可见数据和本地收藏。

Step 2，连接：

- 检测本机 Codex。
- 解释 App Server Technical Preview。
- 不复制 `auth.json` 或导出 token。

Step 3，选择表面：

- 菜单栏默认开启。
- Small / Medium Widget 由用户随后添加。
- 刘海层先展示交互预览，由用户主动开启；Phase 0 再测试是否值得提高默认推荐强度。

Step 4，通知：

- 在用户选择需要提醒的事件后再请求通知权限。
- 默认只启用 approval、failed、quota exhausted。

Step 5，隐私：

- 是否显示 thread 标题。
- Privacy Mode 快捷键。
- 全屏时是否显示关键失败。

### 16.3 Settings & Diagnostics

- 数据来源与 capability 状态。
- 最近成功同步时间。
- App Server 版本与连接状态。
- CPU / energy 诊断。
- 通知队列和最近去重结果。
- 暂停采集、全局静音、清除本地数据。
- 导出脱敏诊断，不含 prompt 和正文。

## 17. 隐私、安全与权限

- 默认不写入 prompt、完整 assistant message、命令正文或文件内容。
- App Group 只存 Widget 所需的脱敏快照。
- WorkPulse 不复制 Codex token；认证由 Codex 进程处理。
- Privacy Mode 同步脱敏 Widget、Resident、Alert、Expanded 和通知。
- 自动屏幕共享检测不进入承诺。用户使用快捷键、菜单栏或设置切换 Privacy Mode。
- 可选会议应用 heuristic 必须标记“可能不完整”。
- 锁屏或通知预览受限时使用泛化文案，如“1 项任务需要处理”。
- 高风险 approval 必须打开完整上下文，不能在 Widget、Alert 或通知内直接确认。
- 不静默修改用户现有 Codex `notify` 配置。

## 18. 视觉设计系统

### 18.1 视觉方向

**Quiet graphite**：低饱和、无装饰性 AI 渐变、依赖 macOS 自适应材质和语义颜色。

语义 token：

- `surface.base`：窗口基础背景。
- `surface.raised`：Expanded / popover。
- `text.primary`、`text.secondary`、`text.tertiary`。
- `status.healthy`、`status.attention`、`status.critical`、`status.info`。
- `focus.ring`。

深色探索值可从现有原型的 graphite 系统继续，但最终颜色必须通过对比度测试；浅色模式使用 Asset Catalog 动态颜色，不直接反转深色值。

### 18.2 排版

- `SF Pro Text` 为主，数字使用 monospaced digits。
- `SF Mono` 只用于 source、状态码或技术字段。
- Widget hero：28 至 32pt。
- Expanded 标题：15pt semibold。
- 行标题：12 至 13pt semibold。
- 正文：12pt。
- metadata：不低于 11pt。
- 正式产品删除现有原型中 9 至 10px 正文。

### 18.3 间距与形状

- 4pt 网格：4 / 8 / 12 / 16 / 24 / 32。
- Widget 遵循系统 content margins。
- 小卡圆角 10 至 12pt。
- 浮层区块 16pt。
- Expanded 外层 22 至 24pt。
- 不使用持续光晕、呼吸点或与状态无关的阴影。

### 18.4 动效

- hover / pressed：120 至 180ms。
- Alert 进入：220 至 280ms。
- Alert 收回：180 至 220ms。
- Expanded：260 至 320ms。
- 低回弹，无明显 overshoot。
- Reduce Motion 下取消位移、缩放和弹性，仅保留约 100ms crossfade。
- Reduce Transparency 下使用不透明 surface 和清晰边界。

## 19. Accessibility

- 普通文字对比度至少 4.5:1；控件、图标和 focus ring 至少 3:1。
- hit area 至少 44×44pt。
- 状态通过图标、文字、颜色中的至少两种表达。
- 无 hover-only 功能。
- Alert 不抢焦点；普通完成不强制 VoiceOver announcement。
- Expanded 支持完整键盘操作，`Esc` 关闭并回到触发点。
- 系统文字放大至 130% 时，主操作不得裁切，辅助信息可优先隐藏。
- 支持 Increase Contrast、Reduce Motion、Reduce Transparency 和 Differentiate Without Color。
- 以真实中英文长标题测试，不按固定字符宽度设计。

## 20. 技术可行性矩阵

| 能力 | 结论 | V2 处理 |
|---|---|---|
| 四种 macOS Widget | Supported | Small / Medium P0，Large P1，Extra Large P2 |
| Widget AppIntent / Link | Supported with constraint | 只做安全本地动作和 scene 打开 |
| Widget 秒级状态 | Unsupported | 使用快照、timeline 和 freshness |
| MenuBarExtra | Supported | P0 可靠主入口 |
| 自定义刘海 NSPanel | Supported with constraint | 可关闭，不能称为系统 Dynamic Island |
| 所有全屏 / Spaces 可靠覆盖 | Prototype-only | 默认全屏抑制，真机矩阵验证 |
| macOS 通知 actions / 去重 | Supported | P0 |
| 自动检测所有屏幕共享 | Unsupported | 显式 Privacy Mode |
| Mac-only ActivityKit Live Activity | Unsupported | P2 需要 iPhone companion |
| iPhone Live Activity 显示到 Mac | Supported with constraint | macOS Tahoe 26+、配对和地区限制 |
| App Server quota / usage | Technical Preview | `stdio` spike，capability gate |
| App Server thread / turn events | Technical Preview | 仅对可验证可见 threads |
| App Server WebSocket | 不进入 MVP | 不开放端口 |
| ChatGPT cloud Projects 枚举 | Unsupported | 手动收藏 |
| ChatGPT Scheduled 自动同步 | Unsupported | P1 仅可信 adapter |
| 任意 ChatGPT desktop thread deep link | Unsupported as promise | Gate B |

Apple 说明 Live Activities 从 iPhone / iPad 开始，并在配对 Mac 菜单栏显示 compact、minimal 和 expanded 形态；它不是 Mac-only 自定义刘海的实现路径。[Apple Live Activities HIG](https://developer.apple.com/design/human-interface-guidelines/live-activities)

## 21. 推荐技术架构

```text
SwiftUI App
├── MenuBarExtra
├── MainWindow
├── AppKit OverlayCoordinator
├── Widget Extension
├── NotificationCoordinator
├── SnapshotStore            App Group，脱敏
├── EventStore               SQLite / SwiftData
├── EventNormalizer
├── RoutingPolicy
└── SourceAdapter
    ├── ManualLinkAdapter            Stable
    ├── CodexNotifyAdapter           Constrained
    ├── AppServerStdioAdapter        Technical Preview
    └── ChatGPTCloudAdapter          Not available
```

### 21.1 AppServerStdioAdapter 约束

- 仅启动受管 `stdio` 子进程，不开放 WebSocket 端口。
- 每次连接执行 `initialize`，记录 Codex 版本和 capability。
- 不假设 schema 永久不变。
- 指数退避重启，超过阈值进入 `unknown`。
- 最小订阅，不保存 prompt 和完整回复。
- 不读取或复制认证文件。
- 设置中永久显示 Experimental 标签。

### 21.2 Widget 数据路径

- 主应用 / adapter 写入 EventStore。
- Normalizer 生成脱敏 Snapshot。
- App Group 保存 Snapshot，不保存凭证和正文。
- Widget 读取 Snapshot 并请求 timeline。
- reset 时间可本地动态显示，额度值只由新 Snapshot 更新。

## 22. 功能需求

| ID | 优先级 | 需求 | 能力门 |
|---|---|---|---|
| FR-01 | Phase 0 | 验证 App Server 跨客户端可见性 | Gate A |
| FR-02 | Phase 0 | 验证稳定上下文返回 | Gate B |
| FR-03 | P0 | Needs You 事件库与本地阅读状态 | 可靠事件源 |
| FR-04 | P0 | quota 多窗口、remaining、reset、freshness | App Server Preview |
| FR-05 | P0 | surface ownership、去重与升级 | Stable local |
| FR-06 | P0 | MenuBarExtra 总控与回退 | Stable |
| FR-07 | P0 | Small Quota Widget | quota source |
| FR-08 | P0 | Medium Now & Next Widget | task source |
| FR-09 | P0 | Resident / Alert / Expanded | Gate D |
| FR-10 | P0 | macOS actionable notifications | notification permission |
| FR-11 | P0 | Privacy Mode 与统一脱敏 | Stable local |
| FR-12 | P0 | Settings & Diagnostics | Stable local |
| FR-13 | P1 | Large Daily Brief | local event coverage |
| FR-14 | P1 | Scheduled Health | trustworthy adapter |
| FR-15 | P2 | Extra Large AI Workboard | stable multi-source data |
| FR-16 | P2 | ChatGPT cloud sync | official supported API |
| FR-17 | P2 | iPhone Live Activity | iPhone companion |

## 23. 非功能需求

- 对当前受管 App Server thread，事件到菜单栏 / Alert 的目标延迟小于 2 秒；不适用于 Widget 或 ChatGPT cloud。
- 冷启动 2 秒内展示最近可信 Snapshot，并明确 Cached。
- Widget 不承诺秒级刷新。
- 断网和 adapter 崩溃后继续显示最后快照，但必须按阈值转为 Stale。
- 重启后不得重复发送 acknowledged 事件。
- 空闲状态不运行动画或高频轮询。
- 不记录 prompt、完整 assistant response 和文件内容。
- Phase 0 必须记录 CPU、内存、energy impact 和 adapter 重启次数。
- Schema 不兼容时关闭相应 capability，不让整个应用崩溃。

## 24. 验收标准

### 产品与数据

- **AC-P01**：没有可靠事件源时，不显示 running / completed 等伪状态。
- **AC-P02**：任一数值可查看 source、更新时间和 freshness。
- **AC-P03**：ChatGPT 手动收藏项不显示自动状态。
- **AC-P04**：上下文返回只对通过 Gate B 的目标标记“打开任务”。
- **AC-P05**：App Server 断开后 30 秒内相关任务转为 unknown / stale。

### Widget

- **AC-W01**：Small、Medium、Large、Extra Large 分别回答不同问题。
- **AC-W02**：每种尺寸具备 loading、empty、healthy、stale、error、privacy、unsupported。
- **AC-W03**：Small 在 3 秒内可识别 remaining 与 reset。
- **AC-W04**：Medium 最多两个点击区域，不重复同一事件。
- **AC-W05**：Widget 中不存在审批、删除或高风险写操作。

### 刘海与通知

- **AC-N01**：hover 不打开 Expanded；点击和键盘激活等价。
- **AC-N02**：Alert 遵循 4 / 8 / 10 秒规则，hover 和 VoiceOver 读取时暂停。
- **AC-N03**：Alert 不抢焦点；Expanded 交互时不自动关闭。
- **AC-N04**：同一事件同一时刻只有一个主动提醒表面。
- **AC-N05**：通知送达后返回桌面不重放 Alert。
- **AC-N06**：双显示器同一 Alert 只出现一次，Resident 不随鼠标跳屏。
- **AC-N07**：无刘海、刘海关闭和全屏抑制时，菜单栏仍可到达核心状态。

### 隐私与 Accessibility

- **AC-PR01**：Privacy Mode 切换时先脱敏，再更新所有表面，不闪现标题。
- **AC-PR02**：本地清除后 Snapshot、EventStore 和 Brief 历史均删除，认证仍由 Codex 管理。
- **AC-A01**：正文对比度至少 4.5:1，控件至少 3:1。
- **AC-A02**：仅用键盘和 VoiceOver 可完成展开、浏览、打开和关闭。
- **AC-A03**：Reduce Motion 下没有位移、缩放、弹性和持续脉冲。
- **AC-A04**：130% 文字缩放下主操作不裁切。

## 25. Phase 0 测试计划

### 25.1 技术 spikes

1. App Server 跨客户端可见性。
2. `stdio` 版本、schema、重连和认证。
3. Codex `notify` 共存，不覆盖用户配置。
4. Widget 真机 reload 与 dynamic date。
5. Overlay 多显示器、全屏和辅助功能矩阵。
6. Deep-link / open target。
7. Developer ID + notarization 与 Mac App Store sandbox 差异。

### 25.2 用户研究

对象：8 至 12 名首发用户，至少覆盖：

- 内建刘海屏为主。
- 长期外接显示器。
- 经常全屏 / 演示。
- 高隐私要求。

任务：

- 让两个 Codex 任务后台运行并处理一次 approval。
- 识别一个失败和一个完成事件。
- 根据 quota window 决定是否启动下一任务。
- 在双屏、全屏和 Privacy Mode 中完成相同流程。

关键问题：

- 用户最不能错过的是 approval、失败还是完成？
- “长任务”阈值应是 30 秒、60 秒还是自定义？
- 用户是否保留 Resident？
- quota 的价值是安排工作还是缓解焦虑？
- Daily Brief 是否值得额外消耗额度？
- 用户接受签名 DMG 还是要求 Mac App Store？

## 26. 风险与应对

| 风险 | 影响 | 应对 |
|---|---|---|
| App Server 改版或不可生产依赖 | 核心数据失效 | Technical Preview、capability gate、schema 协商 |
| 无法观察 desktop 实时任务 | 产品承诺不成立 | Gate A；失败则不发布完整 companion |
| 无稳定 deep link | 提醒后仍需寻找 thread | Gate B；改用 WorkPulse-owned scene 或降级文案 |
| quota 来源冲突 | 信任受损 | 并列来源与更新时间，不自称权威 |
| 刘海跨屏 / 全屏问题 | 遮挡或误触 | 菜单栏为主、刘海可关闭、默认全屏抑制 |
| 通知过多 | 用户关闭全部通知 | surface ownership、合并和可调升级 |
| 隐私泄露 | 高严重度 | 最小数据、手动 Privacy Mode、泛化通知正文 |
| MVP 被 Daily Brief 拖大 | 延迟验证核心价值 | Large / Brief 降为 P1 |
| App Store sandbox 限制 | 分发受阻 | 先 Developer ID + notarized DMG，商店版单独架构 |

## 27. V2 最终产品决策

1. WorkPulse 首发是 Codex-first 的 macOS 状态伴侣，不再称为 ChatGPT 全量实时伴侣。
2. 核心价值从“展示更多信息”调整为“Needs You + 可靠上下文返回 + quota truth”。
3. `MenuBarExtra` 是 P0 主入口；自定义刘海是可关闭的体验增强。
4. Resident 和 Alert 是两种自动投放形态；Expanded 仅由用户主动打开。
5. hover 永不展开 Expanded。
6. 同一事件只有一个主动提醒表面，系统通知只在不可达或升级时接管。
7. Small / Medium 进入 P0；Large Daily Brief 进入 P1；Extra Large 进入 P2。
8. ChatGPT Projects、Chats、Scheduled 自动同步必须等待正式支持接口。
9. Mac-only 不使用原生 ActivityKit；iPhone Live Activity 只用于有起止的长任务。
10. App Server 全部能力标记 Technical Preview，并受 Gate A / B / C 控制。
11. 自动检测所有屏幕共享不进入承诺，改用显式 Privacy Mode。
12. Phase 0 通过后才进入 Pilot MVP；若任务可见性和上下文返回失败，不发布被削弱成普通 quota tracker 的版本。
