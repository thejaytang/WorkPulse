# WorkPulse V8 用户需求终审：高频价值与表面排序

> 日期：2026-08-11  
> 角色：用户研究与产品需求终审  
> 最终复核快照：2026-08-11 15:05:15 CEST  
> 权威本机工件：`native/WorkPulseNative/build/WorkPulse-local-dev.zip`，SHA-256 `15fdcfbdc73c82d18d8ad1cd1ab2f8eab34a7f4f17b42e0831736d6a6ce8324c`，ad-hoc local developer archive，非 Pilot 分发包  
> 审查范围：`PRD_V5_FINAL.md`（当前 PRD）、`PRD_V4.md`、`CAPABILITY_AUDIT.md`、`native-qa.md`、当前 Native / Widget / Web copy、V4–V7 用户研究与事件真实性规范  
> 约束：只审查需求与实现证据，不修改产品源码  
> 判断口径：把“每天会不会用”“一次出错损失多大”“数据是否可信”“当前能否交付”分开，避免把技术形态当作用户价值。

## 0. 最终结论

WorkPulse 当前不应按“Widget、刘海、通知”排功能，而应按三个用户问题排：

1. **现在还能用多少，何时重置，数据是否刚更新？**
2. **我每天要回到的工作入口在哪里？**
3. **哪个 AI 任务此刻真的需要我？**

据此，V8 给出两套不应混淆的排序。

### 0.1 当前本机 developer MVP 的交付排序

1. **Codex quota + 用户主动刷新**：当前已有真实只读来源、multi-bucket 与失败清空证据，是最接近可用产品价值的状态能力。
2. **手动固定入口**：尤其是“每日 Gmail 审查”这类日常例程。它有较高日频价值，且不需要冒充 Gmail / Scheduled 同步。
3. **Menu Bar + Privacy + truth-safe copy**：作为所有 Mac 都可达的常驻入口，承载前两项，不依赖刘海或 Widget 安装。
4. **Needs You 交互演示**：只能用于研究者在场的理解测试，不得作为实时能力对外承诺。

### 0.2 完整 WorkPulse 产品通过 Truth Gate 后的战略排序

1. **Needs You**：事件频率不一定最高，但错过 approval、input、work-loss-risk failure 或具体 turn 的 quota pause，损失最大，也是产品区别于普通 quota tracker / shortcut launcher 的核心。
2. **Codex quota + freshness**：在启动长任务、接近 reset 或来源冲突时支持工作安排；保持被动，不以低百分比制造主动焦虑。
3. **固定例程入口**：每日高频，但本质是可靠快捷入口；只有可信 adapter 存在时才升级为 Scheduled Health。
4. **Scheduled Health**：对 routine cohort 有日频价值，但当前无可信 companion method，不能以虚假 last / next / completed 状态换取表面完整。
5. **Daily Brief / Large / Extra Large / Notch Resident**：属于汇总与体验增强，不是 MVP 核心。

因此，**当前 developer MVP 可以 Go；研究者在场的 formative lab 是 Conditional Go；完整 10 天 field Pilot 仍 No-Go**。formative lab 还要先补最新 Native quota success / failure、多 bucket、Manual、Privacy 与 VoiceOver smoke 的运行态证据；field Pilot 则必须等真实 Needs You、exact return、Widget / Notification 真机载体及研究测量基础设施关闭既有 blocker。

## 1. 审查证据与边界

### 1.1 当前已确认的实现事实

| 能力 | 当前事实 | 用户需求判断 |
|---|---|---|
| Codex quota | App Server `initialize + account/rateLimits/read` 已通过；实际返回 2 个 bucket；数值未落入验证文档 | 可进入 developer MVP，仍标 **Technical Preview** |
| Quota truth | 展示 source、window、reset、observed time；remaining 标“根据来源用量换算”；读取失败清空旧值；typed provenance gate 只允许 `.liveCodexAppServer` 写入 external snapshot | 符合首轮用户测试前置条件；QA / demo quota 不会外发 |
| Manual Pin | Native 已支持名称、HTTPS link、打开请求、编辑、移除确认与本地持久化 | 可测试真实日常入口价值 |
| Needs You | domain ledger 与 189 项确定性检查已存在；local seen 已与 source acknowledgement 分离；snooze 拒绝非未来 deadline；expired snooze 只有在 Presented 成功后才消费，失败可 transfer / release / retry；当前 UI 事件仍为 fixture，production capability registry 默认为空 | truth primitive 更完整，但仍只可做受控理解测试，不可做 field claim |
| Widget | Small Quota、Small Pinned Routine、Medium Now & Next、Large Daily Brief 四个 source scaffold 已 compile / type-check；WidgetSnapshot v3 已拆出独立 `NeedsYouSummary`；尚无 Xcode Extension、App Group E2E 或 Widget Gallery 安装 | 只能评审 contract，不能称已交付小组件 |
| Widget navigation | `workpulse://` 已在 source level 实现 app foreground、Inbox、Usage、routine UUID 校验与保存 URL 打开；main scene 已由 `WindowGroup` 收敛为单一 `Window`，关闭 deep-link 重复主窗口风险；尚无安装后 Widget / LaunchServices E2E | source blocker 与重复窗口问题已关闭，真机任务完成仍由 Gate W 阻断 |
| Notification | 有 delivery policy 与 generic copy 设计，尚无真实 permission、Focus、action callback 测试 | 不能计为当前提醒通道 |
| Notch Overlay | PRD 已正名为自定义 `NSPanel`；当前只有 Web concept / Native 占位开关 | Later，不阻塞核心价值 |
| Scheduled / Gmail | 没有 Gmail OAuth，也没有可信 Scheduled 状态 adapter | 只能 Manual Pin，不能称同步或健康监控 |
| 最新 Native 视觉证据 | 当前截图早于 live quota button 与后续 copy；130% 字号、VoiceOver 和 success-after-failure 仍未完成运行态复核 | 不阻止本机 developer dogfood，但阻止无条件的参与者 UI 签字 |

### 1.2 用户研究信号

- 公开 Codex issue 明确描述切走窗口后错过 approval、session 停住的问题，支持 Needs You 的高损失价值，但不提供总体发生频率：[openai/codex #3052](https://github.com/openai/codex/issues/3052)。
- 长时间无输出可能是正常运行，也可能是 stalled / waiting，支持“未知不等于失败”的 truth contract：[openai/codex #16900](https://github.com/openai/codex/issues/16900)。
- 同一账号不同 Codex 表面出现 quota 百分比与 reset 冲突的报告，支持 source、bucket 与 freshness 必须可见，而不是把数值包装成权威事实：[openai/codex #23192](https://github.com/openai/codex/issues/23192)。
- 近期公开 issue 直接请求“在运行前显示 remaining quota 与 reset time”，支持 quota 的决策时刻价值；但其中关于 Agent 与 Codex 是否共享池的描述只是单一用户观察，WorkPulse 不应替来源解释池结构：[openai/codex #33690](https://github.com/openai/codex/issues/33690)。
- OpenAI 官方说明 Scheduled 可 recurring / monitoring，也可能因需用户操作而暂停；这支持 future Health 场景，但不证明 WorkPulse 当前能读取状态：[Scheduled Tasks in ChatGPT](https://help.openai.com/en/articles/10291617-scheduled-tasks-in-chatgpt)。
- 通知中断研究支持减少非必要打断；个体差异明显，因此成功、普通完成和低 quota 不应默认主动提醒：[Journal of Occupational Health / PMC](https://pmc.ncbi.nlm.nih.gov/articles/PMC10244611/)。
- Gmail 是高敏感边界。WorkPulse 不应成为第二个邮件内容处理者：[Google app data controls](https://help.openai.com/en/articles/10408842-google-connector-for-chatgpt-data-controls-faq)。

这些来源证明真实问题和失败模式存在，不能用于声称“多数用户每天都会遇到”。最终频率仍必须由 10 天 diary 和受控任务验证。

## 2. 高频价值排序

| 需求 | 预计使用频率 | 单次价值 / 损失 | 当前证据可信度 | 当前可交付性 | V8 决策 |
|---|---|---:|---:|---:|---|
| Quota + reset + freshness + refresh | 中高，集中在开任务、接近 reset、出现冲突时 | 中高 | 高 | 高，Native Technical Preview | **Must Now** |
| 手动固定例程 / Gmail Brief 入口 | 高，目标 cohort 可日用 | 中 | 中高 | 高，Native 已具备单例程流程 | **Must Now** |
| Needs You | 事件型，未必每日发生 | 最高 | 问题证据高，运行能力证据不足 | 低，当前只有 fixture | **Must, Gated** |
| Small Quota Widget | 被动高可见 | 中 | 中高 | 中低，尚未安装验证 | **Must for first Xcode Pilot** |
| Small Pinned Routine Widget | 日频入口 | 中 | 中 | 中低，已有 source scaffold | **Should, ahead of ungated Now & Next** |
| Medium Now & Next | 多任务时高，其他时间低 | 高 | 用户问题证据高 | 低，真实事件未接入 | **Must only after Needs You Gate** |
| Scheduled Health | routine cohort 日频 | 高 | 用户问题中高，数据能力无 | 不可交付 | **Later / Adapter-gated** |
| Daily Brief Large Widget | 一天一次 | 中低，易与原输出重复 | 不确定 | Web concept + source scaffold，未安装 | **Later** |
| Notch Alert | 事件型 | 中高，但非通用 Mac 表面 | 不确定 | 仅概念 | **Should after Notification reliability** |
| Notch Resident | 长期可见 | 未证明，可能增压 | 低 | 仅概念 | **Later, opt-in** |
| Extra Large workboard | 低到中 | 未证明比 Codex 本身更好 | 低 | 仅概念 | **Later / likely avoid** |

### 2.1 对当前 PRD_V5 的关键调整建议

PRD_V5 已加入四个 Widget scaffold 与独立 Needs You summary，但其 Should 层仍把 Medium Now & Next 和 Large Daily Brief 与两只高确定性 Small Widget 并列。V8 建议按 capability 和日频证据进一步拆开：

- 第一只真机 Widget：**Small Quota**。
- 第二只可测试 Widget：**Small Pinned Routine**，用于验证固定入口的真实日频价值。
- **Medium Now & Next** 保留 P0 产品地位，但只有真实 Needs You 通过 Gate A / B / C 和事件 AC 后才启用。没有 live event 时，不以 fixture、历史事件或推断状态填充。
- PRD_V5 第 1 节的“固定对话”和第 7 节标题应统一改为“固定入口 / 固定例程”，把 conversation 仅作为用户提供的 target 类型。
- Medium Now & Next 应写成 **Should, capability-gated**；Large Daily Brief 应移到 Later，直到 Pilot 证明日次聚合比 Menu Bar + 两只 Small Widget增加净价值。
- PRD_V5 第 6 节现已与最新 event model 对齐，明确拆分 `Local seen` 和 `Source acknowledged`；打开详情或稍后提醒不能推进来源生命周期。该项在本轮终审中已关闭。

V8 中途发现 Medium / Large 曾复用 routine `attentionCount / routineFreshness` 表示 Needs You；该问题已在当前 WidgetSnapshot v3 关闭：`NeedsYouSummary` 已独立保存 generic count、observed time 和 freshness，Host 在真实 gated event summary 存在前明确传 `nil`。Widget copy 也已区分 `nil` 的“Needs You 尚未连接”、fresh count = 0 的“暂无需要处理”和 stale 的“状态可能已过期”。这没有改变功能排序，因为现在仍没有 live Needs You 数据；下一步是接入通过 Gate 的 event adapter 与 Widget 真机 E2E，而不是继续扩展概念状态。

这不是降低 Needs You 的战略重要性，而是避免一个长期被动表面先于可信数据源发布。

## 3. Must / Should / Later 需求

### 3.1 Must Now：developer MVP 与 formative lab

#### M1. Codex quota 读取与明确刷新

必须：

- 用户主动点击“读取本机 Codex 额度”。
- 同时保留所有 source bucket；默认选择规则透明，不丢失非默认 bucket。
- 展示 bucket / window、remaining、reset、source、observed time 和 freshness。
- remaining 是由 used 推导时明确写“根据来源用量换算”。
- 刷新失败立即显示 unavailable，不继续把旧值当 fresh。
- reset 到达只触发重新读取，不自动声称 quota 已恢复，也不声称具体任务恢复。
- 低 quota 只在 Widget / Menu Bar 被动展示；只有来源明确报告具体 turn 因额度暂停时才进入 Needs You。

不做：预测“这些额度够不够完成任务”、购买建议、把 Codex quota 写成 ChatGPT 总额度、把 reset 写成“刷新后恢复”。

#### M2. 手动固定例程入口

必须：

- 用“固定入口”或“固定例程”，不默认使用“固定对话”。
- 支持单例程的 add / edit / remove / privacy / open request。
- 默认 generic title 为“每日例程”；“每日 Gmail 审查”仅在应用内用户 opt-in 后展示。
- Manual 模式不展示自动 last run、next run、邮件数、completed 或 failed。
- 对“每日 Gmail Brief”，Manual 只承诺打开用户保存的 ChatGPT / Scheduled 管理入口，不承诺打开今天最新一次结果；若每天生成新 conversation，必须等 verified latest-result target。
- 移除前说明只删除 WorkPulse 本地入口，不删除 ChatGPT 内容或 Scheduled task。
- 打开后只记录 open-requested；系统接受 URL 不等于返回正确 conversation。

#### M3. Menu Bar 作为可靠常驻层

必须：

- 所有 Mac、无刘海、外接显示器和 clamshell 场景都能依赖 Menu Bar 进入 Usage、Routine 和 Needs You Inbox。
- 常驻层保持被动：显示 quota freshness、未解决数量或 source unavailable，不播放任务活动流。
- 无 live Needs You capability 时明确显示“当前未连接真实 Needs You 来源”，不能用 `0` 暗示监控健康。

#### M4. 隐私与真实性

必须：

- Widget、Notification、Alert 永远 generic。
- 不收集或外发 prompt、response、thread / project title、路径、命令、URL、Gmail sender / subject / snippet / body 或 Scheduled prompt。
- 所有 fixture 必须带“模拟 / 非实时来源”，且 production build 默认关闭，不能写入 Widget 或系统通知。
- Manual、live_verified、stale、offline、unsupported、notLoaded、sourceConflict 的 copy 和行为不同。

### 3.2 Must, Gated：完整产品与 10 天 Pilot

#### G1. Needs You 真实闭环

只有以下条件同时成立才启用：

- fresh、machine-readable、source-explicit observed event。
- approval、needs input、work-loss-risk failure、quota-paused 四类可准确区分。
- observed、presented、open-requested、local-seen、source-acknowledged、resolved 不互相冒充。
- 同一 unresolved cycle 只有一个 active owner；reconnect 不重放。
- target quality 与 CTA 一致；exact 打开失败在 1 秒内转 WorkPulse detail fallback。
- 任一 false approval、false work-loss-risk、wrong exact target 或 privacy exposure 立即 Safety Stop。

#### G2. 一次性主动提醒与系统 fallback

- 行动事件默认只投递一次；snooze 只改变再次投递时间，不写 resolved。
- snooze 到期后，只有同一 event ID 仍 fresh、source active、capability grant 仍有效时才可再次成为 active owner；source 已 resolved / invalidated 时不得重投。expired snooze 只有在 `Presented` 成功后才消费，调度失败必须允许 transfer / release / retry，不能因 claim 先行而丢失提醒。
- 首选表面由 availability 与用户设置决定，不允许 Notch Alert 和 macOS Notification 重复主动投递。
- 无刘海、Overlay 不稳定、全屏或外接屏时，Notification 是可靠 fallback；通知未授权时仍保留 Menu Bar / Inbox。
- 普通完成、recoverable failure、source disconnected、quota critical 和 Scheduled success-no-action 默认不主动提醒。

#### G3. 真机 Widget 基础

- 完整 Xcode App + Widget Extension + App Group。
- 安装进 Widget Gallery 并完成 snapshot E2E、坏数据、future schema、fresh / stale / unavailable 测试。
- **Small Quota** 作为首只 Widget；点击进入 WorkPulse Usage，不声称打开来源精确上下文。
- `workpulse://usage` 与 `workpulse://routine/{id}` 必须完成真实 scene navigation；parser Pass 或收到 open request 不能替代详情已呈现。
- external snapshot 继续 generic，模拟数据禁止发布。

### 3.3 Should

1. **Small Pinned Routine Widget**：在 Needs You adapter 尚未成熟时，它比空心的 Now & Next 更能验证日频价值。只显示用户手动设置的入口，不显示自动运行状态。
2. **Medium Now & Next**：只在 live event Gate 通过后启用；Now 与 Next 必须分别可点击并有不同 target。没有可信事件时显示“暂无可信主动提醒”，而不是伪造 running。
3. **通知权限渐进请求**：在用户选择 Needs You 事件并看到说明后再请求，不在 onboarding 第一屏索取。
4. **长任务完成 opt-in**：先由 Pilot 估计用户忘记任务的阈值，不预设统一 60 秒；默认被动或汇总。
5. **quiet hours、per-event mute、单次提醒历史**：不改变 source truth。
6. **Notch Alert**：作为 gated experimental surface，先证明无刘海 fallback 和多屏稳定，再评估是否比系统通知更快、更少打扰。

### 3.4 Later

1. **Scheduled Health**：只有可信 adapter 能给 task identity、last verified run、next run、paused / permission / failure、freshness 和 latest result target 时才进入。
2. **Daily Brief Large Widget**：只做已有可信状态的确定性聚合；不读取或重写 Gmail 内容，不默认调用 AI。
3. **Notch Resident / Expanded**：Resident 必须 opt-in，source offline 时不得继续像健康运行；Expanded 只是详情态，不形成第三套提醒系统。
4. **Extra Large workboard**：除非 Pilot 证明 Now & Next 无法满足 supervisor JTBD，否则不做第二个 Codex dashboard。
5. **AI-generated Brief、Gmail counts、自动枚举任意 ChatGPT chats/projects、跨平台团队协作、自动 approval**：当前不做。

## 4. 各形态的职责与常驻 / 一次性规则

| 表面 | 是否常驻 | 只回答什么问题 | 何时允许打断 | 失败 / 不可用降级 |
|---|---|---|---|---|
| Menu Bar | 是 | 是否有可信状态；有几项 Needs You；如何进入 | 从不自动展开 | 显示 source unavailable，保留手动入口 |
| Small Widget | 被动常驻 | Codex 额度、reset、freshness | 从不 | 显示 unavailable / stale，不保留伪 fresh |
| Small Pinned Routine | 被动常驻 | 今天常用入口在哪里 | 从不 | URL 无效时引导设置，不显示 run state |
| Medium Now & Next | 被动常驻 | 现在最需要处理什么；下一项是什么 | 从不主动弹出 | capability 未通过时不启用；无事件时为空态 |
| macOS Notification | 一次性 | 某项行动现在值得打断 | 仅四类 gated Needs You | 无授权时保留 Menu Bar / Inbox |
| Notch Alert | 一次性 | 同上，提供更近的短时行动入口 | 仅四类 gated Needs You，且它是唯一 active owner | 1 秒内或不可达时降级 detail / notification |
| Notch Resident | 可选常驻 | 一项可信运行或 unresolved 状态 | 不主动打断 | source 不新鲜即变 unknown / hidden |
| Daily Brief | 日次被动 | 今天有哪些已有可信变化 | 不主动；由用户打开 | 缺来源时省略该分区，不用 0 伪装正常 |

原则：

- 常驻表面负责**可感知与可返回**，不负责制造紧迫感。
- 一次性表面负责**需要行动的状态变化**，不是活动直播。
- “无事件”只有在监控能力 live 且 freshness 合格时才可表达为“暂无需要处理”；否则应写“尚未连接 / 状态不可用”。
- 用户已在 source 前台时 suppress active alert，但仍可保留被动 ledger。

## 5. 用户可理解的推荐 copy

### 5.1 Quota / refresh

| 场景 | 推荐 copy | 禁止 copy |
|---|---|---|
| fresh 单 bucket | `Codex 5 小时窗口 · 64% 剩余`；`根据来源用量换算 · 更新于 14:10`；`来源显示 15:40 重置` | `ChatGPT 剩余额度 64%`、`够用 3 小时` |
| multi-bucket | `检测到 2 个额度窗口 · 当前显示 Codex` | 只显示一个值且不说明选择 |
| stale | `额度可能已过期 · 上次读取于 13:42`；`重新读取` | `当前剩余 64%`、触发低额度提醒 |
| unavailable | `额度不可用 · 未显示旧值`；`稍后重试` | 继续显示旧进度环 |
| reset | `来源显示 15:40 重置` | `15:40 刷新额度`、`15:40 任务自动恢复` |
| CTA | `读取本机 Codex 额度` | `同步 ChatGPT 账户` |

### 5.2 固定入口 / 每日 Gmail Brief

| 场景 | 推荐 copy | 禁止 copy |
|---|---|---|
| 默认标题 | `每日例程` | 默认外露 `每日 Gmail 审查` |
| Manual 状态 | `手动固定 · 未同步状态`；`WorkPulse 不读取 Gmail 内容或 Scheduled 运行状态` | `Scheduled 已连接`、`今日 12 封邮件` |
| CTA | `打开固定入口`；有 URL 时 `交给系统打开` | `返回同一对话`、`打开最新结果` |
| open result | `已发送打开请求；WorkPulse 尚未确认是否到达对应对话。` | `已打开正确对话` |
| local reminder | `你设置的提醒：每天 09:00` | `下次运行：09:00` |
| remove | `只移除 WorkPulse 本地入口，不会删除 ChatGPT 内容或 Scheduled task。` | `删除例程` |

当未来 Scheduled adapter 通过 Gate 后，才允许使用：`来源确认上次运行于 08:03`、`来源显示下次运行于明天 09:00`、`在 ChatGPT 中查看最新结果`。即使如此，也不承诺每次运行都进入同一 conversation。

### 5.3 Needs You

| 事件 | Generic 标题 | Primary CTA | 不能说 |
|---|---|---|---|
| approval | `有一项 Codex 任务需要确认` | `处理审批` | `已批准`、暴露命令 / 路径 |
| needs input | `有一项 Codex 任务需要补充信息` | `补充输入` | 把模型自然语言问句推断成 input request |
| work-loss-risk | `Codex 报告一项高风险失败，需要检查` | `查看失败` | 无 artifact-loss 证据时写“工作已丢失” |
| quota paused | `有一项 Codex 任务因额度暂停` | `查看受阻任务与额度` | 仅凭低 quota 写“任务暂停” |
| open unconfirmed | `已发送打开请求；尚未确认是否到达对应任务。` | `查看 WorkPulse 详情` | `已返回任务` |
| local seen | `你已查看 · 来源仍待处理` | `继续处理` | `来源已确认`、`已完成` |
| source acknowledged | `来源已确认收到 · 尚未解决` | `查看状态` | 仅凭打开详情或 snooze 写此状态 |
| user disposition | `已从 Needs You 移除；原任务状态未被 WorkPulse 改变。` | 无 | `任务已恢复` |

### 5.4 常驻与一次性表面

- Menu Bar 无 live source：`当前未连接真实 Needs You 来源`，不显示绿色 `0`。
- active alert 自动收起：不显示 `已读`；事件仍在 Needs You。
- Notification request 被系统接受：内部只记 `已交给系统`，不记 `已呈现` 或 `用户已看到`。
- Notch Overlay 设置：`实验性刘海状态层`，不使用 `Dynamic Island / 灵动岛 / Live Activity` 作为系统能力名称。

## 6. 主要误导风险与停止线

| 风险 | 用户会怎样误解 | 当前控制 | V8 要求 |
|---|---|---|---|
| “固定对话” | WorkPulse 保证同一 thread / conversation 可恢复 | Native 已使用固定例程与 open-requested copy | 产品统一改称“固定入口 / 固定例程” |
| “剩余额度 / 刷新时间” | 数值是 ChatGPT 总额度；reset 时任务必恢复 | 已有 Codex、Derived、source copy | 统一用“重置”，保留 bucket 与 freshness |
| Manual 卡出现 last / next | WorkPulse 已同步 Scheduled | domain invariant 已清空自动字段 | external UI 不得从用户本地提醒推断运行 |
| Web Daily Brief mock number | 用户把概念数据当 live | V8 Web 顶部持续写 `Design simulation · 非实时数据`，Scheduled 卡另标 concept | Pilot build 移除整组 mock；演示模式不得出现在参与者 diary build |
| Needs You fixture | 用户以为实时监控开启 | Native 明示模拟且不外发 | production 默认关闭；无 capability 显示 unavailable |
| Native Inbox 空态真实性（Closed） | 用户可能把 capability unavailable 理解为 live zero | 15:03 后已按 capability 分支：未连接写“Needs You 尚未连接”，demo empty 写“暂无模拟事件” | 保留回归标准；未来只有 live fresh zero 才可写“暂无需要处理” |
| `NSWorkspace.open == success` | 已到正确任务 / 对话 | current copy 只写发送请求 | 未有 exact confirmation 不得写到达成功 |
| notification add accepted | 系统已展示、用户已看到 | delivery handoff 与用户状态已拆分 | presented / local_seen 只写可验证证据 |
| local seen 被写成 source acknowledged | 用户以为来源已收到操作或问题已推进 | 最新 ledger 已拆开 user disposition 与 source state | PRD / copy / telemetry 同步改为 local_seen 与 source_acknowledged |
| source disconnect | 任务失败或无需处理 | freshness model 已拆分 | 断连只写 monitoring unavailable |
| 常驻刘海 | Apple 原生保证、多屏都稳定 | PRD 已正名 Overlay | Gate D 前不进 Pilot，不作为发布依赖 |
| quota 与 Gmail 并排 | Codex quota 决定 Gmail Scheduled | PRD 已要求分开 | 不在 routine card 显示 Codex quota |

以下任一项出现，相关 capability 立即 No-Go / Safety Stop：

- 1 个 false approval 或 false work-loss-risk active alert。
- 1 个 wrong `verifiedExact` target。
- 1 个 Widget / Notification / Alert 敏感信息暴露。
- stale / historical event 被当作新 high-risk alert。
- source disconnected 被标成 task failure。
- fixture / demo 数据进入外部 Widget 或 Notification。

## 7. 用户任务成功标准

### 7.1 Quota 决策任务

测试：用户准备启动一个长 Codex task，看到两个 bucket、一个 stale 或 conflict 状态，并主动刷新。

成功标准：

- ≥90% 无帮助指出这是 Codex 而非 ChatGPT 总额度，并能说出当前 bucket、来源、观察时间和 reset。
- source 数值、timestamp 与 bucket fidelity = 100%；读取失败保留伪 fresh 旧值 = 0。
- stale / cached / conflict 触发主动提醒 = 0。
- ≥80% 能选择 truth-safe 下一步：现在开始、缩小任务、等待或回 Codex 确认；系统不替用户预测“够不够”。
- 在 diary 中，至少 50% 使用 quota 的参与者记录过一次具体决策变化；若只有浏览、无任何行动变化，则 quota 保留为工具但不扩大到所有表面。

### 7.2 固定例程任务

测试：添加“每日 Gmail 审查”入口、修改名称、开启 / 关闭应用内标题、打开、再移除。

成功标准：

- 无帮助完成率 ≥90%，setup median ≤3 分钟。
- 100% 受控参与者知道 WorkPulse 不读取 Gmail、不知道 Scheduled 是否运行、移除不会删除 ChatGPT task。
- open-request 与 exact-return 混淆率 = 0；打不开时能找到设置或安全 fallback。
- routine cohort 中 ≥6/8 在 7 天内至少 4 天使用固定入口；否则不值得占据独立 Small Pinned Routine Widget。
- 默认 external surface 敏感标题暴露 = 0。

### 7.3 Needs You 行动任务

测试：四类 critical event、source foreground / background、Overlay 可用 / 不可用、通知拒绝、reconnect、stale、错误 target。

成功标准：

- approval 与 work-loss-risk controlled recall = 100%；四类 critical 总 recall ≥95%。
- event-to-present p95 ≤2 秒；同一 unresolved cycle duplicate active owner = 0。
- false approval / work-loss-risk / quota-paused active alert = 0。
- `verifiedExact` controlled return = 100%，overall ≥95%；wrong target = 0。
- open failure 1 秒内出现 WorkPulse detail fallback，safe fallback rate = 100%。
- premature source acknowledgement / resolution = 0；打开详情只记 local seen；snooze 后仍显示 unresolved。
- snooze 到期重投必须复用同一 event ID；resolved / invalidated / stale / grant expired 的重投 = 0。
- 非未来 snooze deadline 接受率 = 0；claim 但未 Presented 不得消费 snooze，release 后同一事件可安全 retry。
- useful active alert rate ≥80%；participant median resolution time 相对 baseline 改善 ≥30%。

### 7.4 Widget 尺寸任务

测试：用户在 Widget Gallery 中添加 Small Quota、Small Pinned Routine；live Needs You Gate 通过后再测试 Medium Now & Next 与 Large Daily Brief。

成功标准：

- ≥90% 在 10 秒内说出每个尺寸只回答的一个核心问题。
- Small 能在 5 秒内读出 remaining、window、reset / freshness；不可用时不会误认为 0%。
- Small Pinned Routine 的标题、状态与 CTA 不被理解为 Scheduled sync，理解率 ≥90%。
- Medium Now 与 Next 的 click target 分离，wrong target = 0；没有 live capability 时不发布。
- Small Quota / Small Pinned 从 Widget 点击后，正确 WorkPulse detail 实际呈现率 = 100%；只更新 feedback 或只激活 app 不算完成。
- cold / warm deep link 各 100 次只能复用同一个主窗口；重复主窗口 = 0。当前单一 `Window` 为 source-level closure，仍须在 Gate W / LaunchServices E2E 复核。
- Widget / App Group 1,000 次原子读写、corrupt、future schema、stale E2E 全通过；敏感标题 = 0。
- 130% 字号、Increase Contrast、Differentiate Without Color、VoiceOver 下核心任务可完成；不能仅凭截图声称完整无障碍合规。

### 7.5 常驻 / 一次性提醒任务

测试：同一事件在 Menu Bar、Widget、Alert 和 Notification 可用性变化下路由。

成功标准：

- 同事件主动提醒最多一次；重复 active delivery = 0。
- 普通完成、Scheduled success-no-action、quota critical 的默认 active notification = 0。
- Overlay 不可达时 100% 安全降级到 Notification 或持久 Inbox；通知 denied 不制造“已提醒”。
- participant median 手动轮询下降 ≥30%，但每日主动提醒增量不超过 1 次。
- useful active alert ≥80%；第 7 天关闭全部通知的参与者 <25%。
- 无刘海、内外屏、clamshell、全屏和屏幕共享环境中，privacy exposure 与跨屏重复 = 0；Overlay 失败不得影响 Menu Bar / Widget / Notification。

### 7.6 Future Scheduled Health

只有 adapter 可测时执行：

- last / next / paused / failure / permission / freshness 对 source fidelity = 100%。
- success-no-action active notification = 0。
- permission / pause controlled detection = 100%，支持事件 diary recall ≥95%。
- 打开 latest result ≥90%，其余 100% 有 Scheduled 管理页 fallback。
- 所有人都知道 WorkPulse 不访问 Gmail、不删除 Scheduled、不管理 Google scopes。

若无可信 adapter，该组报告必须写 `Not tested / Unsupported`，不能用 Manual card 结果替代 Scheduled Health Pass。

## 8. 建议的验证顺序

1. **现在**：先补最新 Native quota success / failure、多 bucket、Manual、Privacy 与 VoiceOver smoke；通过后再做 3–5 人研究者在场的 formative lab，只测 live quota、multi-bucket / unavailable copy、Manual Pin add / edit / remove、Privacy 与 open-request 理解。
2. **完整 Xcode 后**：先装 Small Quota Widget；再 A/B Small Pinned Routine 是否比 Menu Bar 快捷入口增加了真实日频复用。
3. **Gate A / B / C 后**：在 controlled suite 中验证 Needs You 四类事件、exact / fallback、notification ownership 与 Safety Stop。
4. **上述全部通过后**：启动 10 天 field Pilot。当前 UI 中所有 deterministic fixture 必须从参与者 build 移除。
5. **Scheduled adapter 独立成立后**：另开 routine health cohort；不要让其阻塞 Codex P0，也不要用 Codex quota 作为 Scheduled health proxy。

## 9. 最终产品建议

### 9.1 现在应做

- 把首页与 Menu Bar 的第一主任务收敛为“读取本机 Codex 额度”和“打开固定例程”。
- 将第一只 Widget 锁定为 Small Quota。
- 将 Small Pinned Routine 从 P1 体验件提升为第二个优先验证的 Widget；它是否正式进入 P0 由 7 天复用数据决定。
- 保留 Needs You 的战略 P0，但把所有 live 表面藏在 capability flag 后；当前只做受控 fixture 与 truth acceptance。
- 所有主动提醒都按事件类型写 CTA，不提供一个泛化“打开审批”。

### 9.2 现在不应做

- 不为填满 Medium Widget 而展示未验证 Now / Next。
- 不把 Daily Gmail Brief 变成邮件摘要器，不申请 Gmail 权限。
- 不显示 Scheduled last / next / completed，直到有可信 adapter。
- 不优先做 Large / Extra Large、常驻刘海或活动动画。
- 不把 Web concept 的模拟数字带入 Pilot build。

### 9.3 最终 Go / No-Go

- **本机 developer MVP：Go。** 价值范围是 quota Technical Preview、Manual Pin、Menu Bar、Privacy 和受控研究 fixture。
- **3–5 人 formative lab：Conditional Go。** 先关闭最新 Native 运行态视觉与 VoiceOver smoke blocker；随后只测 quota、Manual、文案理解与表面偏好，不声称通知、Widget 或 Needs You 有自然使用效果。
- **首个 Xcode Widget milestone：Conditional Go。** 先完成 Small Quota、App Group E2E 和安装验证，再决定 Small Pinned Routine。
- **Needs You field Pilot：No-Go。** 直到 Gate A / B / C、真实 event loop、exact / fallback、Notification / Widget 真机表面、telemetry / ground truth 全部通过。
- **Scheduled Health / Gmail Brief live state：No-Go。** 当前保持 Manual；Large Daily Brief、Notch Resident 与 Extra Large 全部 Later。

15:03 Inbox 空态 copy 与 15:05 单窗口 deep-link delta 已关闭本轮最后两项 source-level 用户误导风险；它们不改变上述优先级与发布判断。

一句话产品定义应保持：

> WorkPulse 让你在 Mac 上看到可信的 Codex 额度、保留每天要回去的入口，并在 AI 真正需要你时安全提醒；它不读取 Gmail，也不假装知道尚未接通的 ChatGPT / Scheduled 状态。
