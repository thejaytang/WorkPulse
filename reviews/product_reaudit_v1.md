# WorkPulse 产品经理复审 V1

> 日期：2026-08-12  
> 范围：macOS Codex 伴生应用，仅围绕桌面 Widget、刘海/顶部状态层、系统通知，以及支撑这些表面的菜单栏配置弹层  
> 本轮性质：需求与信息架构复审，不修改源码  
> 核心约束：不提供独立 Dashboard、主窗口或 ChatGPT 替代客户端

## 1. 结论先行

当前产品的核心价值应收敛为两件事：

1. 不打开 Codex，也能一眼知道“还剩多少额度、什么时候重置”。
2. 不查找历史记录，也能从桌面直接进入一个高频固定对话或例程。

这两件事已经拥有相对可信的数据或可控的本机入口，可以形成闭环。其余能力必须依据真实来源分阶段开放。

本轮最重要的产品修正是：

- 刘海常驻的 P0 信息改为“剩余额度 + 下次重置时间”。“7 天窗口”“已更新”只能作为低优先级元数据，不能占据常驻主位置。
- 顶部展开态应跟随入口上下文，不再把额度、固定入口、来源状态混成一个通用面板。
- Small Quota 和 Small Pinned 是首发 Widget；Medium 应先改为“额度 + 固定入口”，当前依赖未连接 Needs You 的版本不应发布。
- Large Daily Brief、真实 Needs You、Scheduled/Gmail 状态延期到可信 adapter 接通后。没有数据源的 Daily Brief 不是摘要，只是能力占位。
- 通知只处理阈值跨越或可信事件，不通知“额度已刷新”“7 天窗口已更新”等无行动价值状态。
- 菜单栏弹层保留，但定位为配置与故障恢复壳层，不是第四个内容产品，也不是隐藏的 Dashboard。

## 2. 审查证据与限制

### 2.1 当前运行态

#### Step 1：刘海常驻，健康但仍可进一步克制

![当前刘海常驻](evidence/product_reaudit_v1/01-notch-resident.png)

当前已显示“Codex 55% 剩余”和“周二 09:58 重置”。这与用户的真实决策问题一致：是否还能继续工作，以及需要等多久。

主要问题：绿色对勾容易被理解为“任务成功”或“状态良好”，而不是“数据新鲜”。额度 55% 本身并无成功语义。建议常态使用中性图标/颜色，仅在低额度、过期或不可用时出现有意义的状态色。

#### Step 2：顶部展开，信息混杂

![当前顶部展开](evidence/product_reaudit_v1/02-notch-expanded.png)

展开态仍以“Codex 7 天窗口”为左侧标签，同时混入“固定入口未设置”和“手动固定 · 未同步状态”。这造成三个问题：

1. 进入额度详情后，固定入口不是当前任务所需信息。
2. “7 天窗口”重新获得了不应有的视觉权重。
3. 来源、观察时间和固定入口能力被拼成一行，例如“读取成功 · 1:10 · 手动固定 · 未同步状态”，用户难以判断每段文本分别说明什么。

展开态应改为上下文化详情：从额度常驻或额度 Widget 进入，只展示全部额度 bucket、重置、数据时间和刷新；从事件 Alert 进入，只展示事件与处置；从固定例程 Widget 点击则直接打开目标，不绕到额度面板。

### 2.2 源码与文档事实

- 宿主没有 SwiftUI 主窗口，当前使用 `MenuBarExtra`、顶部 `NSPanel`、Notification 和 Widget Extension 源码，产品边界正确。
- 当前宿主每 240 秒刷新一次 quota，成功快照的 `freshUntil` 为 5 分钟，能支持近实时顶部状态，但 Widget 仍受 WidgetKit timeline 限制，不能承诺秒级或严格实时。
- 当前 Widget 快照发布固定写入 `needsYou: nil`，因此 Medium Now & Next 在正式数据下必然显示“Needs You 尚未连接”。
- Small Quota 当前把“根据来源用量换算”“来源”“观察于”等元数据放在重置时间之前，信息层级与用户目标相反。
- 当前本机开发 ZIP 不包含已安装 `.appex`；Widget 源码存在不等于用户现在能在系统组件库中找到它。
- Codex App Server 当前可读取多个 rate-limit bucket，但仍是实验性能力；ChatGPT Scheduled/Gmail 没有已验证的公开 companion method。

### 2.3 本轮证据边界

- 本轮检查了刘海常驻与展开态的当前运行截图，以及当前 PRD、Widget、通知和菜单栏源码。
- 未完成 Widget Gallery 真机安装、系统通知锁屏展示、VoiceOver、Increase Contrast、全屏与 clamshell 运行测试。
- 因此本文件可用于重排需求和开发优先级，不能作为 Widget/通知已完成的发布验收。

## 3. 产品定位重写

### 3.1 一句话定位

WorkPulse 是 Codex 在 macOS 上的轻量状态与返回入口层：用 Widget 做长期环境感知，用刘海/顶部岛做即时状态和短暂提醒，用系统通知承接离开电脑或顶部表面不可达时的关键事件。

### 3.2 明确不做

- 不做独立 Dashboard、主窗口、任务中心或聊天客户端。
- 不复制 Codex/ChatGPT 对话内容，不在 WorkPulse 内回复对话。
- 不把手动固定链接描述为“已同步”“已运行”或“已完成”。
- 不根据无官方来源的数据制造 Scheduled、Gmail、每日摘要或 Needs You 状态。
- 不用通知和 Alert 重复播报普通状态更新。
- 不把“系统接受了打开 URL”表述为“已经到达正确对话”。

### 3.3 菜单栏的角色

菜单栏不是主要内容表面，只承担：

- 查看全部 quota bucket 与当前读取状态；
- 手动刷新；
- 设置/修复固定链接；
- 开关刘海常驻、低额度提醒、通知与隐私；
- 在顶部层不可用时提供稳定 fallback；
- 退出应用。

菜单栏应以额度为第一段、固定入口为第二段、事件为第三段、设置折叠为最后一段。当前先展示固定例程、后展示 quota 的顺序应调整。

## 4. 三种核心表面的 Jobs-to-be-Done

| 表面 | 主要 **Job-to-be-Done** | 不承担的任务 | 用户成功标准 |
|---|---|---|---|
| Widget | 不打断当前工作，长期查看关键状态或打开固定入口 | 实时倒计时、主动告警、复杂处置 | 1 秒内读懂状态，1 次点击到达正确下一步 |
| 刘海/顶部岛 | 持续展示一个最高频状态；在必要时短暂呈现需行动事件 | 充当 Dashboard、同时展示全部模块 | 常驻不干扰；提醒出现时知道发生了什么和下一步 |
| 系统通知 | 用户不在当前桌面上下文或顶部层不可达时，兜底传递关键事件 | 播报成功刷新、普通状态变化、重复提醒 | 每个事件/周期只通知一次，点击能回到对应上下文 |

三者不是同一内容的三份副本：

- Widget 负责“环境感知”和“固定入口”。
- 刘海常驻负责“现在还有多少、何时重置”。
- 刘海 Alert 和通知负责“刚刚发生且需要处理”。

## 5. 信息优先级

### 5.1 Quota 信息层级

| 优先级 | 信息 | 使用位置 |
|---|---|---|
| P0 | 剩余百分比 | 刘海常驻、Small/Medium Widget、阈值 Alert |
| P0 | 下次重置时间 | 刘海常驻、Small/Medium Widget、阈值 Alert |
| P1 | bucket 名称，例如 Codex、Weekly | 多 bucket 时的选择器、展开态、Widget 次级标签 |
| P1 | fresh / 上次 / 可能过期 / 不可用 | 所有额度表面的真实性状态 |
| P2 | 观察时间 | 展开态、菜单栏；Widget 仅在有空间时简写 |
| P2 | 来源 | 展开态、菜单栏；不占常驻主位置 |
| P3 | 5 小时/7 天等窗口长度 | 展开态和多 bucket 识别，不作为常驻主信息 |

禁止使用以下无行动价值的常驻主文案：

- “7 天窗口已更新”
- “额度已更新”
- “Codex 状态正常”
- 仅显示窗口名称而没有剩余与重置

### 5.2 固定入口信息层级

| 优先级 | 信息 |
|---|---|
| P0 | 用户定义名称或隐私模式下的 generic 名称 |
| P0 | 可点击打开 |
| P1 | “本机固定入口”或“手动入口”能力边界 |
| P2 | URL 无效或已移除时的修复入口 |

在没有 verified adapter 时，不显示 last run、next run、Gmail 数量、Scheduled 健康或“待处理”数量。

### 5.3 事件信息层级

| 优先级 | 信息 |
|---|---|
| P0 | 需要用户做什么，例如确认、补充输入、检查失败 |
| P0 | 是否仍然有效 |
| P1 | 发生时间/等待时长 |
| P1 | 打开、稍后、从本机列表移除 |
| P2 | 来源与能力边界 |

锁屏通知默认保持 generic；只有用户显式开启“通知中显示额度详情”时，quota 通知才可显示精确百分比与重置时间。事件通知继续隐藏线程、项目、prompt、路径和 Gmail 内容。

## 6. Widget 需求重构

### 6.1 首发：Small Quota

**核心任务**：一眼判断可用额度和等待时间。

推荐层级：

1. `55% 剩余`
2. `周二 09:58 重置`
3. `Codex · 刚刚` 或 `Weekly · 上次 01:10`

“根据来源用量换算”“完整 source label”“观察于”等说明移入顶部展开态或菜单栏。重置时间不得位于卡片最末行。

点击闭环：

1. 点击 Widget。
2. WorkPulse 在内建屏幕顶部打开 quota Expanded。
3. 展示全部 bucket 和刷新按钮。
4. 刷新成功后原位更新，并请求 Widget timeline reload。
5. 点击外部或 Esc 返回常驻。

降级状态：

| 状态 | 显示 |
|---|---|
| Fresh | 当前剩余 + 当前 reset |
| Aging/缓存 | `上次 55%` + reset，明确“上次” |
| Stale | `额度需更新` + `点按刷新`；不继续以当前语气展示 reset |
| Unavailable | `暂时无法读取` + `打开 WorkPulse 重试` |
| Demo/fixture | 不写入正式 Widget |
| Snapshot schema 不兼容 | `需要更新 WorkPulse` |

### 6.2 首发：Small Pinned Routine

**核心任务**：把一个高频 ChatGPT/Codex 对话变成桌面快捷入口。

显示：名称、固定图标、“本机固定入口”。“未同步运行状态”可作为辅助说明，但不要比入口本身更突出。

点击闭环：

1. 校验本机 routine UUID。
2. URL 有效时交给系统打开。
3. URL 无效、已移除或 UUID 过期时，在顶部显示修复提示，并指向菜单栏配置。
4. 不显示“打开成功”或“已到达对话”，只记录 open requested。

### 6.3 首发候选：Medium Quota + Pinned

当前 Medium Now & Next 应停止发布并改版。其 NOW 区域在生产快照中固定为 `needsYou: nil`，用户得到的是永久“尚未连接”，没有实际价值。

建议 Medium 改为：

- 左半：选定额度 bucket 的剩余 + reset；
- 右半：固定例程名称 + 打开动作；
- 两个区域使用独立 deep link。

这能复用已经可验证的两项能力，不依赖未来事件来源。

### 6.4 延期：Medium Needs You

只有同时满足以下条件才恢复：

- 已有非 fixture 的真实事件 adapter；
- freshness、terminal、source conflict 经过 Gate A/B；
- Widget snapshot 实际写入独立 `NeedsYouSummary`；
- fresh zero、stale、offline、conflict 的真机状态均完成验证。

### 6.5 延期：Large Daily Brief

当前 Large Daily Brief 不应进入首发。现状是三个结构化占位：Needs You 未连接、固定入口是手动链接、quota 是唯一真实动态数据。这不是用户理解中的“每日 Brief”。

恢复条件至少包括：

- 有一个 verified daily source，例如 Scheduled 官方 adapter 或用户明确配置的本机摘要来源；
- 能说明生成时间、覆盖范围、缺失来源和 freshness；
- 摘要中至少两类信息是真实可用，而不是 unavailable/manual 占位；
- 点击每一行都有明确下一步。

在此之前，用户仍可用 Small Pinned 直接打开“每日 Gmail 审查”对话，不需要虚构一张 Daily Brief 大卡片。

## 7. 刘海/顶部岛需求重构

### 7.1 Resident：用户选择常驻

**唯一主要任务**：持续显示选定 quota bucket 的剩余与 reset。

布局：

- 左：`Codex 55% 剩余`
- 右：`周二 09:58 重置`

规则：

- 不轮播多个 bucket，避免持续运动和认知跳变。
- 用户在菜单栏选择 primary bucket；Expanded 展示全部 bucket。
- fresh 正常态使用中性色，不使用“成功”绿作为默认语义。
- <=20% 可使用 amber；<=10% 可使用 red，但颜色不能是唯一编码。
- stale 显示 `Codex 额度需更新` / `点按刷新`；如保留上次数值，必须带“上次”。
- unavailable 显示 `Codex 暂时不可用` / `点按重试`。
- demo 必须持续标注“演示 · 非实时”。
- 多显示器固定内建刘海屏；内建屏不可用时降级到主屏顶部胶囊。

触发：

- 仅由用户开启/关闭。
- 应用启动、自动刷新成功、reset cycle 更新都不触发一次性弹出。

### 7.2 Expanded：上下文化详情

从 quota Resident/Widget 进入时：

- 标题：`Codex 额度`
- 每个 bucket 一行：名称、剩余、reset、freshness
- 次级元数据：`观察于 01:10 · Codex App Server`
- 操作：`刷新`
- 不显示固定入口、Needs You 或 Scheduled 能力声明

从事件 Alert/Notification 进入时：

- 标题和内容只对应该事件；
- 操作只包含 `打开`、`稍后 1 小时`、`从本机列表移除`；
- 明确“稍后/移除不会改变来源任务状态”；
- 事件已终止时展示“已不再需要处理”，不提供失效动作。

Expanded 不是一个固定模板，而是两类上下文的轻量详情容器。

### 7.3 Alert：一次性出现

允许触发：

- quota 首次跨越用户设置的 30%/20%/10% 阈值；
- verified `needsApproval`、`needsInput`、`workLossRiskFailure`、`quotaPaused` 的新鲜 transition；
- Widget/deep link 点击后由用户主动请求的顶部详情。

禁止触发：

- 普通 quota 刷新成功；
- reset 时间变化但无需用户行动；
- “7 天窗口已更新”；
- app 启动、唤醒、网络恢复；
- fixture、stale、offline、initial reconcile 或 source conflict。

Alert 生命周期：

1. 短暂出现 5–8 秒；hover 暂停倒计时。
2. 点击进入同一事件的 Expanded。
3. 未点击则消失并恢复 quota Resident。
4. 一个事件/一个 threshold cycle 只投递一次。

设置中的“预览一次性顶部提醒”应只在 Debug/QA 构建出现，不能成为正式用户功能。

## 8. 系统通知需求重构

### 8.1 通知的触发条件

Notification 不是 Overlay 的复制品，而是 fallback active owner。只有满足以下条件之一才使用：

- 顶部 Overlay 被用户关闭或当前不可达；
- 用户离开电脑/当前桌面上下文，且事件具有持续等待价值；
- 用户明确选择“低额度使用系统通知”。

如果 Alert 已成功呈现，同一事件不得再发通知。调度失败应释放 owner，使事件仍可在菜单栏中发现。

### 8.2 通知类别

#### Quota threshold

- 默认文案：`Codex 额度较低` / `打开 WorkPulse 查看剩余与重置时间。`
- 用户显式允许详情后：`Codex 剩余 18%` / `周二 09:58 重置。`
- 操作：`查看额度`。
- 不提供“稍后”，因为稍后不会改变 reset，也不形成有意义处置。

#### Needs You event

- 默认文案：`WorkPulse 需要你的处理` / `一个任务正在等待操作。`
- 操作：`查看`、`稍后 1 小时`。
- 点击必须使用规范化 event UUID 回到对应顶部 Expanded。

### 8.3 降级与去重

- 通知权限未决定：在菜单栏设置中解释用途后由用户主动允许。
- 权限拒绝：不重复请求，提示去系统设置；事件保留在菜单栏。
- deep link 过期：显示“这项提醒已结束或被移除”，不能静默失败。
- 每个 event ID + transition digest 只通知一次。
- 每个 quota bucket + reset cycle + threshold 只通知一次。
- 低额度后回升再下降但仍属于同一 cycle，不重复通知。

## 9. 跨表面交互闭环

### 9.1 查看额度

`Widget/Resident` → `Quota Expanded` → `刷新` → `原位更新` → `Widget timeline reload` → `关闭回 Resident`

成功标准：用户不需要打开独立窗口；从看到旧状态到确认最新额度不超过两次操作。

### 9.2 打开固定对话

`Pinned Widget` → `校验本机 UUID/HTTPS` → `交给系统打开`  
失败时：`顶部修复提示` → `菜单栏填写有效链接`

成功标准：正常路径一次点击；失败路径明确告诉用户修复位置，不制造到达确认。

### 9.3 处理事件

`Alert 或 Notification` → `Event Expanded` → `打开/稍后/移除` → `本地 ledger 更新` → `来源确认后 terminal`

成功标准：Presented、Open requested、Local seen、Source acknowledged、Resolved 不混淆。

## 10. 删除、降级与延期清单

### 10.1 应删除或仅保留 Debug

- 正式设置中的“预览一次性顶部提醒”。
- 普通刷新后弹出“已更新”或“7 天窗口已更新”。
- quota Expanded 中的固定入口摘要。
- 把“绿色对勾”作为所有 fresh quota 的默认成功语义。
- 任何 production fixture、演示控制和模拟通知入口。

### 10.2 应降级

- “5 小时/7 天窗口”从主标题降为 bucket 辅助信息。
- source、observed time、capability 从 Widget/Resident 主界面降到 Expanded/菜单栏。
- 菜单栏从内容中心降为配置、全量详情和恢复入口。
- “未同步运行状态”从固定 Widget 主信息降为辅助能力说明。

### 10.3 应延期

- 当前 Medium Now & Next，直至改为 Quota + Pinned 或接通真实 Needs You。
- Large Daily Brief，直至拥有 verified daily source。
- Needs You Alert/Notification 的生产启用，直至真实 adapter 与 Gate A/B 完成。
- Scheduled/Gmail last run、next run、邮件数、摘要和 exact return。
- 面向外部用户分发，直至 Widget `.appex`、App Group、Developer ID/notarization 与真机矩阵通过。

## 11. 调整后的 MVP 范围

### P0：当前应完成

- 刘海 Resident：剩余 + reset，fresh/stale/unavailable 降级。
- Quota Expanded：全部 bucket、reset、观察时间、来源、刷新。
- Small Quota Widget：剩余 + reset 优先。
- Small Pinned Widget：一次点击打开手动固定入口。
- Medium Quota + Pinned Widget，若本轮资源允许。
- quota threshold Alert；Notification 作为不可达 fallback。
- 菜单栏 quota-first 重排与必要设置。
- Light/Dark、Privacy、键盘、VoiceOver、多显示器和全屏降级。

### P1：能力接通后

- 真实 Needs You adapter、Event Expanded、事件 Alert/Notification。
- Medium Needs You 变体。
- 可配置的通知详情隐私级别。

### P2：verified daily source 后

- Large Daily Brief。
- Scheduled/Gmail 状态与摘要。
- 多固定入口、Widget 配置 Intent 和 exact return。

## 12. 新验收标准

### 12.1 信息价值

- 在 1 秒可视测试中，用户能回答“剩余多少”和“何时重置”。
- Resident 和 Small Quota 的最大/最高权重文本不是“7 天窗口”或“已更新”。
- reset 不得被来源说明挤到最后一行或被裁切。
- Expanded 只展示当前入口相关的信息。

### 12.2 真实性

- stale 数值必须写“上次”，或直接收敛为“需更新”。
- unavailable 不保留看似当前的 reset。
- Manual Pin 不出现 last run、next run、Gmail 数量或 Scheduled 正常状态。
- `needsYou: nil` 的 Widget 不作为首发默认产品展示。
- demo/fixture 不写入正式 Widget，不触发系统通知。

### 12.3 打扰控制

- 普通 quota refresh 产生 0 个 Alert、0 个 Notification。
- 同一 threshold cycle 最多 1 次主动提醒。
- Overlay 成功呈现后同一事件不再发 Notification。
- Alert 自动消失后正确恢复 Resident。

### 12.4 可达与恢复

- Pinned Widget 正常路径一次点击打开。
- 失效 UUID/URL 有可理解的修复路径。
- Widget 点击不打开独立 Dashboard。
- 内建刘海屏、外接主屏、clamshell、全屏各有明确降级且不重复呈现。

### 12.5 可访问性

- Resident 的 VoiceOver 顺序为“Codex，剩余 55%，周二 09:58 重置”。
- 颜色不是 fresh、stale、low quota 的唯一状态编码。
- 130% 字号、Increase Contrast、Reduce Motion 下无裁切。
- Alert 的计时变化不会使 VoiceOver 用户来不及操作；键盘聚焦时暂停消失。

## 13. 产品决策

### Go

- 继续本机 dogfood：Quota Resident、Quota Expanded、Small Quota、Small Pinned、手动固定入口。

### Conditional Go

- Medium Widget：仅在改为 Quota + Pinned 并完成真机 `.appex` 验证后进入 MVP。
- quota 系统通知：仅在授权、去重、锁屏隐私和 deep link E2E 通过后启用。

### No-Go

- 当前形态的 Medium Now & Next。
- 当前形态的 Large Daily Brief。
- 真实 Needs You、Scheduled/Gmail 状态或“已同步”宣称。
- 没有 `.appex` 的 ZIP 对外声称包含可安装 Widget。

最终原则：每个表面只回答一个最重要的问题。Widget 回答“桌面上我需要知道或打开什么”，刘海常驻回答“额度还剩多少、何时重置”，Alert/Notification 回答“刚刚有什么必须由我处理”。无法回答这三个问题的内容，应删除、降级或等待真实能力。
