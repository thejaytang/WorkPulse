# WorkPulse V4 用户需求审查

> 角色：用户研究与产品洞察  
> 审查日期：2026-08-11  
> 审查对象：[PRD_V3](../PRD_V3.md)、[当前桌面 Demo](../workpulse_mac_desktop_demo.html)、[V3 评审 Demo](../workpulse_v3_review_demo.html)、[此前设计研究](../DESIGN_RESEARCH.md)  
> 重点用户：多任务 Codex supervisor；每日 Gmail / Scheduled routine 用户  
> 本文只提出需求与验证建议，不修改主 HTML。

## 0. 结论先行

V3 对首发用户的收缩是正确的，但当前 Demo 又把两个边界不同的产品拼回了一张卡片：

1. **多任务 Codex supervisor** 的核心是“停止轮询、及时处理阻塞、准确返回上下文、理解 Codex quota”。这是有较强公开需求信号的 P0。
2. **每日 Gmail / Scheduled routine 用户** 的核心不是“把邮箱搬上桌面”，而是“确认例程是否按时、具备所需权限并产生可用结果，然后打开最新结果或管理例程”。这是可验证的 P1，前提是存在可信的 Scheduled 状态来源。
3. “固定对话”不是两类用户共有的稳定对象。Codex 用户需要固定的是可恢复的工作目标；Scheduled 用户需要固定的是例程身份。公开案例对“每天新线程”与“持续同一线程”的偏好相反，因此产品不能把“返回同一对话”写成默认承诺。
4. WorkPulse 不应申请 Gmail 权限、不应读取邮件正文，也不应重新生成 Gmail 摘要。它只展示来自 ChatGPT Scheduled 的泛化状态。否则伴侣应用会从“状态层”变成第二个高敏感数据处理者。
5. Quota 必须明确标为 **Codex quota**。它既不是 ChatGPT 全产品额度，也不决定 Gmail Scheduled 是否能运行。当前 Demo 在 Gmail 例程旁显示 5 小时额度，容易制造错误因果关系，应在后续视觉稿中拆开。
6. 如果无法可靠获得 Scheduled 的 task ID、last run、next run、pause / permission failure 和 latest result target，就不能发布“Scheduled Health”；最多发布一个没有 freshness 的手动入口。

## 1. 证据等级与限制

为避免把少量抱怨夸大为普遍频率，本文使用四种标记：

- **F 已确认事实**：OpenAI 官方文档、当前产品材料或可重复的 Demo 行为。
- **O 公开观察信号**：GitHub issue、Reddit / 社区个案。说明真实失败模式，不代表总体发生率。
- **I 基于证据的产品推断**：由 F 与多个 O 推导出的设计动作。
- **U 待验证假设**：公开材料不足，必须通过 Pilot、访谈或 diary 验证。

Reddit 和 GitHub issue 都是自选择样本；点赞数只代表话题可见度，不可用作发生率估计。2026 年 ChatGPT Scheduled 与 Codex 桌面端变化较快，所有接口和行为在开发前还需再次核查。

## 2. 两类目标用户与 Anti-persona

### 2.1 Persona A：多任务 Codex supervisor

典型特征：

- 同时运行 2 个以上 Codex thread / subagent，期间切换到编辑器、浏览器或会议。
- 任务持续 1 分钟到数十分钟；等待 approval、用户输入、失败或 quota block 会停止进度。
- 更在意“哪一个需要我”而不是全量活动流。
- 需要从系统级提示直接回到正确 thread、turn 或 approval，而不是先进入一个总仪表盘再查找。
- 对 quota 有实际工作安排需求，但不能接受缓存数字被包装成权威结论。

核心 JTBD：

| 触发时刻 | Job to be Done | 成功结果 | 证据与置信度 |
|---|---|---|---|
| 离开 Codex 去做别的工作 | 在不持续轮询的情况下知道是否真正需要我 | approval / input /重大失败及时出现；普通运行保持安静 | O：用户明确描述切窗后错过 approval、session stalled。[Codex #3052](https://github.com/openai/codex/issues/3052)。高 |
| 多个 agent 同时运行 | 一眼找出阻塞整个进度的那个目标 | Needs You 按风险排序，不被 completion 淹没 | O：长时间无输出可能是仍在运行，也可能是 stalled / waiting，现有状态难区分。[Codex #16900](https://github.com/openai/codex/issues/16900)。中高 |
| 收到提醒 | 一步回到可处理上下文 | 打开正确 thread / turn / approval，状态从 seen 到 resolved 可追踪 | O：旧 thread 可能从侧栏消失但数据仍在；说明稳定入口有价值。[Codex #21128](https://github.com/openai/codex/issues/21128)。但外部或 pinned thread 也有无法恢复的报告，[#30916](https://github.com/openai/codex/issues/30916)、[#28607](https://github.com/openai/codex/issues/28607)。高，但实现风险高 |
| 准备开新长任务 | 了解当前最紧张 Codex quota window | 看到 source、remaining、reset、freshness 后自行决定 | O：Web 与 macOS 同账户曾同时显示互相矛盾的百分比和 reset。[Codex #23192](https://github.com/openai/codex/issues/23192)。高 |
| 长任务安静运行 | 知道监控仍存活，而不是把安静误判成失败 | 有 last event / monitoring state；不制造虚假 failure | O：[Codex #16900](https://github.com/openai/codex/issues/16900)。中高 |

### 2.2 Persona B：每日 Gmail / Scheduled routine 用户

典型特征：

- 已在 ChatGPT Scheduled 中建立每日 Gmail 审查、晨报、日历摘要或监控任务。
- 关心“今天是否运行、是否有值得处理的变化、为什么没运行”，不想再次配置一个自动化平台。
- 对邮件标题、联系人、组织名称出现在桌面、通知和屏幕共享中高度敏感。
- 可能使用 Business / Enterprise，Gmail 可用性受 ChatGPT workspace 与 Google Workspace admin scopes 共同控制。
- 需要打开最新一次输出，偶尔需要编辑、恢复或暂停例程。

核心 JTBD：

| 触发时刻 | Job to be Done | 成功结果 | 证据与置信度 |
|---|---|---|---|
| 早晨第一次看 Mac | 确认例程已按时完成且具备所需数据访问 | 显示 last verified run、结果状态与 freshness；成功无事时不打断 | F：ChatGPT 支持 recurring / monitoring tasks 和 meaningful-change notification；Scheduled 页面存在于 ChatGPT 桌面端，但不在 Codex。[OpenAI Scheduled Tasks](https://help.openai.com/en/articles/10291617-scheduled-tasks-in-chatgpt)。高 |
| 例程没有可用结果 | 知道是 paused、权限不足、工具不可用还是尚未运行 | 一个清楚原因和“在 ChatGPT 中检查”动作，不是假装成功 | F：任务可能因需用户操作而暂停；managed workspace 可限制 app actions。[OpenAI Scheduled Tasks](https://help.openai.com/en/articles/10291617-scheduled-tasks-in-chatgpt)。O：手动聊天可访问 app，而 scheduled run 失去访问的案例。[Reddit](https://www.reddit.com/r/ChatGPT/comments/1v3rt63/plugins_in_scheduled_tasks/)。中高 |
| 今天有新结果 | 快速进入当天输出，而不是翻找历史 | “打开最新结果”直接到对应输出 | O：有用户希望每日运行创建新 chat，也有用户希望保持连续 thread，偏好分裂。[新 chat 请求](https://www.reddit.com/r/ChatGPT/comments/1r6wqbg/is_there_a_way_to_force_chatgpt_scheduled_tasks/)、[观察到新 thread 行为](https://www.reddit.com/r/ChatGPTPro/comments/1twmat3/major_changes_to_scheduling_capabilities/)。中 |
| 需要修改或恢复例程 | 进入官方管理表面，而不是在伴侣应用里重建逻辑 | “管理例程”打开 ChatGPT Scheduled 页面或具体 task | F：官方提供 Scheduled 页面管理创建、编辑、暂停、恢复和删除。[OpenAI Scheduled Tasks](https://help.openai.com/en/articles/10291617-scheduled-tasks-in-chatgpt)。高 |
| 屏幕共享或同事经过 | 保持邮件与例程内容私密 | 默认只显示“每日例程 / 已完成 / 需检查”，不展示邮箱内容 | F：ChatGPT 连接 Google app 后可同步和索引内容，Memory 可能使用这些内容进行个性化；这是高敏感数据边界。[OpenAI Google App Data Controls](https://help.openai.com/en/articles/10408842-google-connector-for-chatgpt-data-controls-faq)。O：用户对连接后在未明确要求时出现 Gmail 信息表达强烈不安。[Reddit](https://www.reddit.com/r/ChatGPT/comments/1rdpsww/chatgpt_read_my_emails_tried_to_convince_me_it/)。高 |

### 2.3 Anti-persona

P0/P1 不应主动服务：

- 只偶尔问一次 ChatGPT、没有长任务和 Scheduled routine 的轻度用户。
- 期望 WorkPulse 自动阅读、分类、回复 Gmail 的“AI inbox”用户。这是另一个产品与权限模型。
- 需要跨平台团队自动化、审计日志和多用户审批的企业 ops 团队，应使用正式 workflow / IT 管理产品。
- 只想看一个大致 quota 百分比且不关心来源的人。此人可被普通 quota tracker 满足，不足以支撑 WorkPulse 差异化。
- 希望伴侣应用自动批准 Codex shell / file 权限的人。安全风险与 Codex approval 的本意冲突。
- 需要医疗、法律、财务等敏感邮箱内容直接出现在桌面卡片中的用户，除非未来有专门合规、审计与数据处理设计。

## 3. 关键需求审查

### 3.1 多任务 supervisor：不是“任务看板”，而是注意力路由器

**F**：V3 将 `needs approval > failed work-loss risk > turn blocked by quota > needs input > ... > completed` 排序，并区分 acknowledged 与 resolved，这个方向正确。

**O**：Codex 用户的公开请求把 approval 与长任务完成区分为不同事件；前者会造成工作停滞，后者主要用于减少轮询。[Codex #3052](https://github.com/openai/codex/issues/3052)。多 agent 场景还存在“安静但健康”与“真正 stalled”无法区分的问题。[Codex #16900](https://github.com/openai/codex/issues/16900)。

**I**：P0 应把价值承诺写成“只在行动有边际价值时打断”。Resident 只保留最高优先级 unresolved 状态和数量，不播放每一步 activity；Extra Large workboard 不应提前进入 MVP。

**U**：60 秒是否是 completion 的正确阈值尚无群体证据。应让 Pilot 记录每次“我已经忘记这个任务 / 我仍在等待它”的临界时长，并按任务类型和用户行为校准，而不是只问偏好。

### 3.2 固定对象：稳定入口有价值，“同一对话”没有被验证

当前 Demo 的 `routine` scene 写着“固定对话 · Scheduled”“操作返回同一对话”，并展示 last run / next run。这在视觉上清楚，但混淆了三种不同对象：

| 对象 | 可承诺内容 | 不可承诺内容 | 推荐 CTA |
|---|---|---|---|
| Codex tracked thread | 在 source capability 允许时展示 live state、Needs You 与 freshness | thread 永远可恢复、外部创建 thread 一定能在桌面打开 | 打开当前操作 |
| Manual Link | 用户保存的稳定快捷方式 | 自动 last run、next run、paused、freshness | 打开链接 |
| ChatGPT Scheduled routine | 只有可信 adapter 才能展示 task health、last / next run、latest result | 所有运行永远追加到同一 chat；Codex 能直接枚举 Scheduled | 打开最新结果；管理例程 |

**F**：官方说明 Scheduled 在 ChatGPT 桌面端中可用，但不在 Codex；删除关联 chat 会自动暂停 task。[OpenAI Scheduled Tasks](https://help.openai.com/en/articles/10291617-scheduled-tasks-in-chatgpt)。

**O**：一位 Gmail + Calendar 用户明确希望每日新 chat，避免结果不断追加；另一位用户观察到新 scheduler 已为每次提醒创建新 thread。这些案例不证明多数偏好，但足以否定“同一对话是普遍正确”的前提。[案例 1](https://www.reddit.com/r/ChatGPT/comments/1r6wqbg/is_there_a_way_to_force_chatgpt_scheduled_tasks/)、[案例 2](https://www.reddit.com/r/ChatGPTPro/comments/1twmat3/major_changes_to_scheduling_capabilities/)。

**I**：用户真正固定的是“每日 Gmail 审查”这个 routine identity，而不是某条 chat。卡片默认应有两个明确动作：“打开最新结果”“管理例程”。Manual Link 场景必须移除 last run / next run 或标为用户手动设定，不能使用“已同步”语言。

**U**：不同 routine 对连续上下文的需求可能不同。晨报倾向每天独立结果，个人教练或长程写作可能更需要连续上下文。Pilot 应按 routine 类型分层，而不是给出一个全局开关后就认为问题已解决。

### 3.3 Gmail 信任与隐私边界

**F**：Google app 连接后，ChatGPT 可能建立 indexed copy 并同步 Gmail / Calendar / Drive 内容；开启 Memory 时可能利用这些内容进行个性化。断开后 indexed copy 会在 30 天内删除。官方同时说明，直接同步的 Google app 数据一般不用于 generalized model training，但反馈、手动粘贴或出现在响应中的内容有列明例外。[OpenAI Google App Data Controls](https://help.openai.com/en/articles/10408842-google-connector-for-chatgpt-data-controls-faq)。

**F**：Business / Enterprise 的 app 可用性、持久权限与动作可能受 workspace admin 控制，任务可能需要 approval 或不能执行某些动作。[OpenAI Scheduled Tasks](https://help.openai.com/en/articles/10291617-scheduled-tasks-in-chatgpt)。

**O**：社区出现高可见度帖子，用户在已连接 Gmail 后，对邮件内容在未明确要求的对话里出现感到意外和不安。这不能证明越权访问，但证明“已连接”不等于用户理解后续使用范围。[Reddit Gmail 隐私讨论](https://www.reddit.com/r/ChatGPT/comments/1rdpsww/chatgpt_read_my_emails_tried_to_convince_me_it/)。

**I，必须写入需求**：

- WorkPulse P0/P1 不请求 Google OAuth，不保存 Gmail subject、sender、snippet、body 或附件。
- WorkPulse 只接收泛化的 Scheduled 状态和可打开目标，例如 `completed_no_action`、`result_available`、`permission_required`、`paused`、`unknown`。
- Widget、刘海、通知默认显示“每日例程”，用户主动开启后才显示“每日 Gmail 审查”。即使开启标题，也不显示邮件正文或联系人。
- Onboarding 必须用一句可验证的边界说明：“WorkPulse 不访问你的 Gmail；Gmail 权限由 ChatGPT 与 Google 管理。WorkPulse 仅显示例程状态并打开 ChatGPT。”
- Settings 提供“清除本地 routine 链接和状态缓存”，并说明这不会删除 ChatGPT Scheduled task，也不会断开 Gmail。
- 权限故障 CTA 为“在 ChatGPT 检查连接”，不可在 WorkPulse 内诱导用户重新授权 Google。

### 3.4 提醒疲劳：成功状态不等于提醒事件

**F**：通知中断研究的 field experiment（N=247）发现，减少 notification-caused interruptions 可改善表现并降低 strain，但对高 FoMO / 不同响应规范的人影响不同。[Journal of Occupational Health / PMC](https://pmc.ncbi.nlm.nih.gov/articles/PMC10244611/)。Chrome 大规模研究也显示通知权限 prompt 的 desktop grant rate 仅 10%，更安静的 UI 可显著减少不必要操作而仅小幅影响授权率。[Google Research](https://research.google/pubs/shhhbe-quiet-reducing-the-unwanted-interruptions-of-notification-permission-prompts-on-chrome/)。

**O**：Scheduled 社区既有“任务运行但不通知”的报告，也有“无法停止旧提醒”的报告。这些是个案，却说明通知通道可靠性与可控性都影响信任。[通知缺失案例](https://www.reddit.com/r/ChatGPT/comments/1ozfk8h/is_anyone_else_having_issues_with_push/)、[无法停止案例](https://www.reddit.com/r/ChatGPT/comments/1jqjiyb)。

**I，默认路由**：

| 事件 | Resident / Widget | Alert | macOS Notification | 默认声音 |
|---|---|---|---|---|
| Codex approval / explicit input | unresolved 持久显示 | 用户离开 source 后显示 | Overlay 不可达时一次 | 关；用户可开 |
| 重大失败 / work-loss risk | unresolved 持久显示 | 显示 | 一次，可升级 | 关 |
| turn blocked by quota | 状态显示 | 显示 | 一次、无声 | 关 |
| 长任务完成 | unread badge | 仅用户离开且超过阈值 | 默认关闭，用户选择开启 | 关 |
| Routine 成功、无值得处理内容 | 更新 last run | 不显示 | 不发送 | 关 |
| Routine 有新结果但不紧急 | `result available` | 不显示 | 默认不发送；可合并入每日摘要 | 关 |
| Routine paused / permission lost / repeated failure | unresolved 持久显示 | 一次 | 一次、去重 | 关 |

跨表面必须共用 event ID 和 resolution：同一 failure 不得被刘海、Widget 和 Notification 分别计为三次提醒。成功例程不进入 Needs You；“今天没有重要邮件”是完成结果，不是通知理由。

### 3.5 Quota 数据可信度与决策边界

**O**：2026 年公开 issue 记录了同一 Codex 账号的 Web Analytics 与 macOS App 同时在 5 小时 remaining、5 小时 reset、weekly remaining 和 weekly reset 上互相矛盾；报告者的重启、重装和缓存清理未立即解决。[Codex #23192](https://github.com/openai/codex/issues/23192)。另有订阅状态变化后 macOS 显示 limit reached、但 Web 仍可运行的个案，用户因此误用 banked reset。[Reddit](https://www.reddit.com/r/codex/comments/1un41jw/psa_codex_macos_may_show_a_stale_usage_limit/)。

**I，quota truth contract**：

- 每个数值必须带 `source`、`fetchedAt`、window / limiter 名称和 reset timestamp；remaining 若由 used 推导，标为 **Derived**。
- 页面用语是“Codex 5 小时窗口”与“Codex weekly window”，不能写“ChatGPT 总额度”。
- Gmail / Scheduled routine 页面不默认展示 Codex quota；两者没有已确认的运行因果关系。
- `cached` 或 `stale` 仍可显示最后值，但不能产生 threshold alert，也不能建议购买或使用 reset。
- enforcement 与 meter 冲突时显示“来源冲突，请在 Codex 中确认”，同时保留两个时间戳，不选边站。
- WorkPulse 只提供 headroom，不预测“够不够完成这个任务”，也不将 quota 消耗速度包装成确定性 forecast。

**U**：quota 对用户的主要价值可能是安排工作，也可能只是降低焦虑。Pilot 必须记录 quota 是否真正改变了“现在启动 / 延后 / 换模型 / 缩小任务”决策；只有浏览没有决策变化，不足以支持把 quota 放在每个表面。

## 4. 当前 PRD 与 Demo 的具体差距

| 发现 | 风险 | 需求动作 | 优先级 |
|---|---|---|---|
| Demo routine scene 展示“固定对话 · Scheduled”、last run 和 next run | 用户误以为手动 pin 拥有 live sync；与 V3 ManualLink 无 freshness 的定义冲突 | 将对象改为“固定例程”；按 source capability 分成 Manual Link 与 Scheduled Health 两种状态 | P0 文案修正；P1 数据能力 |
| Caption 承诺“返回同一对话” | 与用户偏好分裂及 Scheduled thread 行为不一致 | 改成“打开最新结果”；另设“管理例程” | P1 |
| Gmail 例程卡旁显示 Codex 5 小时 quota | 暗示 Codex quota 决定 ChatGPT Scheduled；容易误导 | routine surface 默认不显示 Codex quota；只在全局 Usage 中展示 | P0 |
| 默认可见“每日 Gmail 审查” | 屏幕共享泄露工具和工作习惯 | 默认 generic title；用户单独选择展示标题 | P0 |
| “最后运行 / 下次运行”没有 source / freshness | 失败或缓存时仍显得权威 | 所有自动状态显示 source + freshness；未知时显示 Unknown，不沿用绿色成功 | P1 Gate |
| Large Daily Brief 汇总 Needs You、Scheduled、quota | 可能重新生成已有内容，增加噪音与额度消耗 | 先做确定性本地聚合；Routine 成功无事不进入 Brief 重点 | P1 实验 |
| Extra Large 工作看板信息丰富 | 容易把注意力路由器变成第二个 Codex UI | 保留 P2，除非 Pilot 证明 2 个状态不够完成 supervisor JTBD | P2 |

## 5. 明确“不做”的功能

1. 不读取、缓存、搜索、总结或分类 Gmail 内容；不申请 Google OAuth。
2. 不在 Widget / 刘海 / Notification 显示 sender、subject、snippet、附件名或收件箱数量。
3. 不把 Manual Link 伪装成 Scheduled sync，不推断任务已经运行或失败。
4. 不承诺 Scheduled 永远在同一 chat 运行；不以 chat ID 作为唯一 routine identity。
5. 不在 WorkPulse 内创建、编辑复杂 Scheduled prompt、处理 Google admin scopes 或代替 ChatGPT 的 Scheduled 管理页。
6. 不把 Codex quota、ChatGPT Scheduled 可用性和 Gmail 权限合成单一“AI 健康分”。
7. 不自动批准 Codex approval，不代用户执行高风险确认。
8. 不为每封新邮件或每个 agent step 发送提醒。
9. 不在 quota stale / conflict 时给出“可以继续跑”“应该购买 reset”等建议。
10. 不因连接丢失把 running 标成 failed；必须单独显示 `monitoring_lost / unknown`。
11. 不用 Daily Brief 重写用户已有结果作为默认行为；AI 生成必须 opt-in 并说明数据范围与额度影响。
12. 不把刘海常驻作为核心价值验证前提；P0 的价值必须可由 Menu Bar + Needs You + direct return 独立成立。

## 6. 可执行 Pilot 方案

### 6.1 招募与周期

- 16 人，连续 10 天：8 名多任务 Codex supervisor、8 名 Gmail / Scheduled routine 用户；允许 2–4 人同时属于两类，但分别计入任务。
- Codex cohort 入组门槛：每周至少 3 天同时运行 2 个以上任务，最近两周至少遇到一次 approval / input / failure / quota block。
- Routine cohort 入组门槛：已有至少一个运行 7 天以上的 recurring or monitoring task，其中至少 4 人使用 Gmail；至少 2 人来自 managed workspace。
- 第 1–3 天记录 baseline；第 4 天 75 分钟 controlled session；第 4–10 天 prototype diary。
- Gmail cohort 优先使用 participant-owned test account 或低敏感例程。研究记录只保存 task 状态、操作时间和主观评分，不收集邮件正文、截图中的邮件内容或 prompt 全文。

### 6.2 Codex supervisor controlled tasks

| 编号 | 任务 | 观察指标 | 失败判定 |
|---|---|---|---|
| C1 | 同时启动 3 个任务：短完成、长运行、需要 approval；随后切到浏览器 | 是否先识别 approval；首次发现时间；是否误点完成任务 | approval 被 completion 覆盖，或用户需打开总面板后搜索 |
| C2 | 在 subagent 中制造 approval / needs input | event 是否带正确 parent / child target；能否一步返回 | 无事件、重复事件或打开错误 thread |
| C3 | 让一个任务 5 分钟无可见输出但保持健康 | 是否显示 running + last event；用户是否认为 failed | 系统发 failure，或用户因不确定而返回轮询 2 次以上 |
| C4 | 运行中中断 App Server / 网络再恢复 | `monitoring_lost` 的检测、措辞和恢复；是否错误标 failed | monitoring lost 未被识别，或恢复后保留虚假 unresolved failure |
| C5 | 让 3 个任务在 20 秒内完成，其中一个失败 | 去重、排序、每日提醒负担 | 3 个完成分别弹 active notification，重大失败未优先 |
| C6 | 注入 fresh、cached、stale、source conflict 四种 quota snapshot | 用户能否指出哪个数值可用于决策；是否误认为 ChatGPT 总额度 | stale 触发阈值提醒；用户按冲突数字使用 reset |
| C7 | 打开一个近期 thread、一个旧 pinned thread、一个外部创建 thread | exact-context return 成功率与 fallback 质量 | 打开错误目标且无清楚 fallback |
| C8 | 双外屏、全屏和屏幕共享下重复 C1 / C5 | privacy、surface ownership、多屏稳定性 | 私密标题泄露；同事件跨屏重复提醒 |

Diary 每次只记录五项：触发事件、是否有用、当时是否已在 source、采取的动作、若没有 WorkPulse 是否会手动检查。每天结束记录手动打开 Codex 仅为“看状态”的次数。

### 6.3 Gmail / Scheduled routine controlled tasks

| 编号 | 任务 | 观察指标 | 失败判定 |
|---|---|---|---|
| R1 | 添加已有 Gmail Scheduled routine；展示 WorkPulse 数据边界说明 | 用户能否准确复述 WorkPulse 是否访问 Gmail；配置时间 | 误以为 WorkPulse 获得 Gmail 权限，或误以为断开 WorkPulse 会删除 Scheduled task |
| R2 | 成功运行但无重要变化 | 是否保持安静；早晨是否能确认运行 | 发送 active notification，或用户无法确认 freshness |
| R3 | 成功产生新结果 | “打开最新结果”准确率；用户是否还需要“同一对话” | 打开 task 创建 chat 而非最新结果且用户无法理解 |
| R4 | 比较 A：“固定同一对话”与 B：“固定例程 + 最新结果 / 管理例程” | 首选、完成时间、错误率、理由 | 不能仅用偏好投票；需要任务成功证据 |
| R5 | 撤销 Gmail permission、模拟 workspace admin 禁用 action | 是否显示 permission required；CTA 是否回到 ChatGPT | 仍显示绿色完成，或 WorkPulse 请求 Google OAuth |
| R6 | 删除关联 chat / 暂停 task / missed run | paused、unknown、failed 是否区分；去重 | 把 paused 解释为 inbox 无重要邮件，或连续重复提醒 |
| R7 | 在屏幕共享中展示 widget 和通知，再切换 Privacy Mode | 敏感内容暴露、模式理解、切换速度 | sender / subject / routine title 在默认模式暴露 |
| R8 | 同一天有 3 个 routine 结果，其中 2 个无动作、1 个 permission failure | 聚合与优先级；每日提醒数量 | 每个成功结果独立提醒；permission failure 被埋没 |

Diary 每天记录：是否按预期运行、WorkPulse 是否减少打开 Scheduled 页检查、是否打开最新结果、是否采取动作、是否出现隐私或提醒不适。不要记录邮件内容。

### 6.4 访谈问题，避免只问“喜不喜欢”

1. “上一次你因为没看到 approval 而延误工作是什么时候？当时损失了什么？”
2. “你今天第几次只是为了看任务是否结束而打开 Codex？”
3. “看到 quota 后，你改变了哪个具体决定？如果没有，为什么还看它？”
4. “你的每日例程最糟糕的失败不是‘没运行’，而是哪一种？”
5. “如果每天结果进入新 thread，什么会丢？如果全部留在同一 thread，什么会变难？”
6. “哪一个信息出现在屏幕共享里会让你立刻卸载？”
7. “成功但无事发生时，你希望收到什么？如果答案是‘什么都不要’，你仍如何确认它运行了？”
8. “如果 WorkPulse 与 ChatGPT / Codex 显示不同 quota，你会相信谁，为什么？”

## 7. 指标与 Go / No-Go 阈值

### 7.1 P0 Codex supervisor Gate

| 指标 | Go | 继续迭代 | No-Go / 降级 |
|---|---:|---:|---:|
| Supported approval / major failure event recall，controlled suite | 100% | 95–99% 且失败可定位 | <95%，或漏掉任一高风险 approval |
| False active alert | 0 个 controlled false approval / failure；diary ≤1% | >1% 且可通过规则修复 | 任何会诱导错误高风险动作的 false alert |
| Exact-context return | ≥95%，错误时 100% 有明确 fallback | 90–94% | <90%，不发布 Needs You direct action |
| Monitoring loss detection | 100% controlled disconnect 被识别，median ≤5 秒；0 次被标成 task failure | median 5–15 秒 | 无法区分 `monitoring_lost` 与 `failed` |
| 手动状态轮询变化 | participant-level median 下降 ≥30% | 下降 15–29% | <15% 或反而增加 |
| Action-needed resolution time | 相对 baseline median 下降 ≥30% | 下降 10–29% | 无改善 |
| 有用 active alert 比例 | ≥80% | 65–79% | <65%，或 ≥25% 用户在第 7 天关闭全部通知 |
| Quota snapshot fidelity | 对 source 原值与 timestamp 100% 无改写；stale alert 0 | 仅格式差异 | 任一缓存值被当 fresh，或产生“足够完成任务”结论 |
| “Codex quota ≠ ChatGPT 总额度”理解 | ≥90% 无提示答对 | 75–89% | <75% |
| 保留意愿 | ≥6/8 愿意继续保留 Menu Bar，且至少 5/8 每周有重复使用场景 | 4–5/8 | ≤3/8 |

硬性 **No-Go**：没有 machine-readable approval / lifecycle source；无法稳定恢复正确 thread / turn；monitoring loss 会被误报为 failure。若只剩 quota，按 PRD V3 原则不以 WorkPulse 名义发布。

### 7.2 P1 Gmail / Scheduled Gate

| 指标 | Go | 继续迭代 | No-Go / 降级 |
|---|---:|---:|---:|
| Scheduled state fidelity | last / next / paused / failure / freshness 对可信 source 100% 一致 | 仅展示延迟且明确 stale | 无可信 adapter；降级为 Manual Link，不称 Health |
| 成功无动作的 active notifications | 0 | 任何一次都修正规则后复测 | 无法区分 success-no-action 与 action-needed |
| Permission / pause failure detection | controlled suite 100%，diary 支持事件 ≥95% | 90–94% | <90% 或仍显示绿色成功 |
| 打开最新结果 | ≥90% 直达正确结果；其余有 Scheduled 管理页 fallback | 80–89% | <80% 或链接经常失效且无 fallback |
| 数据边界理解 | 8/8 知道 WorkPulse 不访问 Gmail、不删除 Scheduled、不管理 Google scopes | 6–7/8 | ≤5/8 |
| 敏感内容泄露 | 默认 Widget / Alert / Notification / screen share 测试为 0 | 仅 opt-in 标题暴露且文案清楚 | 任一 sender / subject / snippet 默认暴露 |
| 例程检查减少 | 打开 Scheduled 页仅为“确认运行”的次数 median 下降 ≥30% | 下降 15–29% | <15% |
| 例程入口复用 | ≥6/8 在 7 天中至少 4 天使用；≥5/8 更偏好 routine identity 模型 | 4–5/8 | ≤3/8 |
| 提醒控制 | unresolved failure 只主动提醒一次；100% 可 mute / resolve | 偶发重复但可修复 | 用户必须关闭全部通知才能停止单一 routine |

硬性 **No-Go**：如果状态只能从用户自填时间推断，或不能验证 latest run / pause / permission state，就不发布 Scheduled Health。可保留“固定例程入口”，但必须显示“未同步状态”。

### 7.3 产品组合 Gate

- 两个 cohort 必须能在无解释情况下区分 **Codex Needs You / Codex quota** 与 **ChatGPT Scheduled routine**，答对率 ≥90%。否则拆成独立导航与 Widget 配置，不在同一卡片呈现。
- 在 7 天 diary 中，任何一个 cohort 的 median 主动提醒数不应因 WorkPulse 比原系统增加超过 1 次/日；若增加但轮询没有下降，No-Go。
- 默认隐私模式下 0 条敏感标题暴露，0 次跨屏重复 active alert。
- 刘海不单独决定发布。若 Menu Bar 通过价值 Gate、刘海多屏稳定性未通过，可关闭刘海继续 Pilot。

## 8. 建议写入下一版需求的 P0 / P1 / P2

### P0

- Codex Needs You：approval、explicit input、重大失败、turn blocked by quota。
- machine-readable source、event ID 去重、acknowledged / resolved 分离。
- exact-context return + 明确 fallback。
- `monitoring_lost / unknown` 独立状态，禁止误标 failed。
- Codex quota source、window、remaining、reset、freshness；stale 不触发 alert。
- Manual Link 只做入口，不拥有 freshness。
- Privacy 默认 generic；通知权限在用户选择事件后再请求。
- 信息架构上分开 Codex quota 与 ChatGPT routine。

### P1，条件式

- Scheduled Health adapter：task identity、last verified run、next run、paused / permission / failure、latest result target。
- “固定例程”卡：打开最新结果 + 管理例程，不承诺同一 chat。
- Routine 成功无动作静默；paused / permission loss / repeated failure 一次性提醒。
- 确定性 Daily Brief，只聚合已有结果；不默认读取 Gmail 或调用 AI。
- 每个 routine 的 generic title、mute、quiet hours 与 result notification opt-in。

### P2

- Extra Large cross-thread workboard，仅在 P0 用户明确需要超过 Now & Next 时进入。
- AI-generated Brief，仅在用户证明愿意为重写付出 quota、时间和隐私成本后进入。
- ChatGPT Projects / Chats / Scheduled 的更深同步，只在官方稳定接口与权限边界明确后进入。
- Routine 类型自适应的“连续 thread / 每日结果”偏好，只在可控且有足够研究证据时设计。

## 9. 研究仍不能确认的事项

1. 60 秒完成提醒阈值是否适用于编程、研究、写作和数据分析；公开 issue 只能证明“长任务完成提醒有需求”，不能给出统一阈值。
2. 多数 Gmail routine 用户究竟更重视“知道运行了”还是“快速阅读结果”；需要行为日志而非意向问卷。
3. 固定 routine identity 相比 ChatGPT 官方 Scheduled 页是否能产生足够日常复用；官方页面已经提供管理能力，WorkPulse 必须证明减少检查成本，而不是复制它。
4. managed workspace 用户是否愿意安装 notarized DMG；这取决于企业 IT policy，不可从个人用户推断。
5. quota 是否真的改变工作安排，以及用户能否容忍 source conflict；必须在真实 reset boundary 和订阅状态变化中验证。
6. 多屏用户是否愿意保留 Resident；这影响刘海层是否值得继续，但不影响 Menu Bar P0 的核心价值。

## 10. 最终研究判断

**Go，进入受控 Pilot 的部分**：Codex Needs You、exact-context return、monitoring truth、source-aware Codex quota、Privacy 默认 generic。

**Conditional Go**：固定 Routine 入口。即使无 API，也可作为 Manual Link 测试“稳定入口”价值，但不能显示自动 last / next run。

**No-Go，直到可信 adapter 通过 Gate**：Scheduled Health、Gmail 例程实时状态、permission failure 自动识别、latest result 自动跳转。

**No-Go，作为当前默认产品承诺**：“返回同一对话”、Gmail 内容桌面化、统一 ChatGPT/Codex quota、成功例程主动提醒、AI 自动重写 Daily Brief。

这两类用户可以共享 WorkPulse 的系统级外壳、隐私模式、事件去重和打开上下文机制，但不应共享同一个数据语义。P0 是 Codex 注意力路由器；P1 才是 ChatGPT Scheduled 例程健康层。
