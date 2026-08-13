# WorkPulse UI/UX 第四轮审查

> 审查角色：macOS UI/UX 设计师  
> 日期：2026-08-11  
> 审查范围：`PRD_V3.md`、`workpulse_mac_desktop_demo.html`、浅色与深色实现截图、`design-qa.md`  
> 修改边界：本文件仅记录审查结论，不修改产品 PRD、主 HTML 或共享视觉资源

## 1. 结论

当前 Demo 的浅色与深色主画面已经形成一致、克制的 macOS 视觉语言，固定“每日 Gmail 审查”卡片的首屏层级也足够清楚。但它尚未达到“可作为原生实现视觉真值”的标准。

`design-qa.md` 的 `passed` 只证明当前默认场景与参考截图在指定视口下接近，不能证明产品体验已经通过。现有实现仍有以下阻断项：

1. Demo 默认显示真实任务和固定对话标题，而 PRD 要求 Widget、通知始终 generic，Overlay 标题默认关闭。
2. “每日 Gmail 审查”被呈现为可信 Scheduled 状态，但 PRD 把 Scheduled Health 放在 P1 且要求可信 adapter；当前还混入未定义来源的“6 / 8 小时深度工作”。
3. Medium Widget 的 Next 同时显示两项，且整个 Widget 只有一个点击行为，无法分别返回 Current 与 Needs You 的正确上下文。
4. Alert 先“查看”再“前往审批”，破坏“一次操作回到可处理上下文”的核心目标。
5. Resident 不是可聚焦、可点击控件；菜单栏 popover 也没有落实 PRD 要求的键盘导航和焦点返回。
6. 多处正文仍为 9 至 10px，多处产品控件小于 44×44pt；浅色 `text.tertiary` 与浅色 surface 的对比度不足。
7. Alert 的 4 / 8 / 10 秒、hover 暂停、通知接管以及多屏降级尚未在 Demo 中真实演示或验证。

因此，本轮结论为：**视觉方向通过，产品级 UI/UX 有条件通过；完成下列 P0 后方可进入原生高保真冻结。**

## 2. P0，原生实现前必须修正

### P0-01：统一隐私默认值和真实显示行为

证据：

- PRD 要求 Widget snapshot 与通知正文从数据层始终 generic，Overlay thread title 默认关闭。
- Demo 在 Privacy Mode 关闭时显示“每日 Gmail 审查”“研究代理需要审批”“第三轮 PRD 审查”等真实名称。
- 通知正文只有打开 Privacy Mode 后才切换为 generic。

实施要求：

- Widget 和 Notification 不受 Privacy Mode 开关影响，始终读取 `genericTitle`、`genericSummary`，不把真实标题写入其 snapshot 或 request content。
- Resident、Alert、Expanded、MenuBar preview 默认使用 generic；用户在 Onboarding 中单独开启“在顶部状态层显示任务标题”后才可显示真实名称。
- 固定例程如需显示“每日 Gmail 审查”，必须提供 item-level 明示授权：`允许在桌面显示此名称`。默认文案为“每日例程”。
- Privacy Mode 开启时，邮件图标、`3 封邮件`、场景说明和 toast 也要泛化。当前只替换标题仍会泄露 Gmail 来源和工作量。
- Privacy Mode 下打开固定对话后的 toast 应为“正在打开固定例程”，不得重新暴露标题。

验收：

- 搜索 Widget snapshot 与通知 request content，敏感标题数量为 0。
- Privacy Mode 开启前后逐帧录屏，所有即时表面在 1 秒内脱敏且无闪现。
- 未授权 item-level title 时，桌面截图中不得出现 Gmail、项目名、thread 名或文件名。

### P0-02：重新定义“每日 Gmail 审查”的产品身份和可信状态

当前卡片视觉上像一个已连接的 Scheduled 工作流，但 PRD 当前只保证手动 Pinned target，并把 Scheduled Health 放在 P1 条件式能力中。`上次审查 08:00 已完成`、`3 封邮件`、`下次审查 16:00` 会让用户理解为 WorkPulse 已获得 Gmail 和 Scheduled 实时状态。

实施要求：

将例程分为三个 capability state：

| 状态 | 标题下方标签 | 允许展示 | 禁止展示 |
|---|---|---|---|
| Manual，P0 | `固定对话 · 手动` | 用户保存的名称、打开入口、用户设置的提醒时间 | 自动完成、邮件数量、真实运行状态 |
| Scheduled verified，P1 | `固定例程 · 已连接` | last run、Needs You 数量、next run、freshness | 无来源的“已完成”或邮件摘要 |
| Stale / unavailable | `状态可能已过期` | 最后可信结果与更新时间 | 绿色健康状态和新的 Needs You 数值 |

当前 `今日配额 · 6 / 8 小时深度工作 · 75%` 不属于 Codex App Server quota，也未在 PRD 中定义。P0 必须删除，或明确改名为用户手动设置的“今日专注目标”。推荐直接替换为真实的 Small Quota 数据：`Codex 5 小时窗口 · 64% · 12:40 重置`。

三点菜单目前没有行为，原生实现前必须二选一：

- 实现 `编辑名称 / 隐藏标题 / 更改提醒 / 移除固定`；
- 若尚未进入范围，则移除三点按钮。

验收：

- 没有 Gmail / Scheduled 可信 adapter 时，不出现“已完成”“3 封邮件”“下次审查”等自动状态。
- 每个自动数值均可在详情中查看来源和 freshness。
- Manual 与 Connected 状态的视觉标签在 5 秒内可以被用户区分。

### P0-03：将固定例程映射到真实 WidgetKit family

当前 `routine-card + routine-status` 是 460px 宽的自定义自由布局，不等于 WidgetKit 的标准 Small / Medium / Large family。它不能作为“原生桌面小组件已经定稿”的证据。

推荐映射：

- **Medium Pinned Routine**：标题、状态、Needs You 数量、next run、整卡打开。
- **Small Quota**：独立 Widget，不与 Routine 绑定成不可拆的垂直 stack。
- 若确实需要三列 last / needs / next，则使用 **Large Pinned Routine**，并接受其为 P1。

P0 Medium Routine 最多展示：

1. 泛化或获准标题。
2. 一个主状态，如“3 项需要处理”。
3. 一个 next run。
4. 整卡打开目标。

不要在 Medium 内同时放三列指标、主按钮和第二张 quota 卡。

### P0-04：修正 Medium Now & Next 的优先级与点击模型

PRD 规定 Next 只展示最高优先级一项；当前 Demo 同时展示 Daily Brief 与 Needs You，且整个 Widget 的 click handler 都返回当前线程。

实施要求：

- Next 只显示一个最高优先级事件。本场景应显示 `需要批准 · 1`，Daily Brief 不应排在它上方。
- Current 和 Next 必须是两个独立的 `Link` / `AppIntent` 目标。
- 点击 Current 打开运行中的 thread；点击 Next 打开 approval 对应 target。
- 同一 `eventId` 不能同时出现在 Current 与 Next。
- 如果 Next 没有已验证 `openTarget`，文案写“打开 WorkPulse 详情”，不能写“打开任务”。

验收：

- Medium 最多两个点击区域。
- Current 和 Next 的点击目标分别通过 Gate B。
- 仅用键盘可聚焦并分别激活两个区域。

### P0-05：Alert 必须实现一步返回，而不是两步漏斗

当前 Alert 的主操作为“查看”，打开 Expanded 后才出现“前往审批”。这与核心 JTBD 和 `AC-F01` 冲突。

实施要求：

- Alert 主操作直接改为“打开审批”，一次进入验证过的目标上下文。
- 若需要查看 Expanded，用户点击 Resident 或菜单栏，而不是强迫所有 Alert 先进入 Expanded。
- Alert 保留一个主操作和一个 44pt 关闭按钮。Snooze 放在 Expanded 或系统通知中，避免顶部卡出现两个同权操作。
- Alert 宽度收敛到 PRD 的 360 至 420pt；当前 478px 超出上限。
- Demo 应真实模拟 8 秒 approval、10 秒 failure、4 秒 completion；hover 和 accessibility focus 时暂停，离开后至少保留 3 秒。

验收：

- Alert 主操作一次进入正确审批上下文。
- Alert 不改变当前 app 或输入框焦点。
- 自动收回后事件仍在 Resident / MenuBar / Inbox 保持未解决状态。

### P0-06：Resident 必须成为真正的可访问控件

当前 Resident 是一个 `<section>`，不能点击、Tab 聚焦或使用 `Enter` / `Space` 打开 Expanded。

实施要求：

- 原生实现使用可访问的 button-like surface，视觉高度 32 至 36pt，但 hit area 至少 44pt。
- 默认 generic 文案，如“1 项任务运行中”，真实 thread title 为 opt-in。
- hover 只改变强调度，不打开 Expanded。
- click、`Enter`、`Space` 打开 Expanded，关闭后焦点返回 Resident。
- 不把整个 Resident 与 Alert 共用一个永久 `aria-live`；Resident 静态更新不应重复播报。

### P0-07：补齐 MenuBar 主入口，而非只完成视觉壳

当前菜单栏状态项视觉清楚，但 popover 与 PRD 仍有差距：

- 缺少 System Health 区。
- Header 没有静音状态。
- Privacy 只在 popover 内可见，开启后菜单栏状态项没有持续标志。
- “打开 Inbox”复用了通用 `data-action="open"`，实际进入 Expanded，而不是主应用 Inbox。
- 没有实现上下箭头导航、打开后的初始焦点、`Esc` 焦点返回。

实施要求：

- MenuBar status item 默认采用 18pt symbol + badge；是否常驻显示 `WorkPulse` 文字作为可配置的 verbose mode。
- Privacy Mode 开启时，在 status item 上持续显示锁形标记。
- popover 顺序固定为 Header、System Health、Needs You、Active、Quota、Footer。
- `打开 Inbox`、`诊断`使用不同 scene action，禁止复用审批打开逻辑。
- 键盘打开后聚焦第一条可操作 Needs You；上下箭头移动，`Enter` 激活，`Esc` 关闭并返回状态项。

### P0-08：通知必须默认 generic，并明确接管关系

当前通知在 Privacy Mode 关闭时显示真实“研究代理需要审批”，违反 PRD 的 generic notification contract。

实施要求：

- 默认标题：`ChatGPT 有一项任务需要处理`。
- 正文：`打开 WorkPulse 查看并返回对应上下文。`
- 主操作具体化为“打开审批”，次操作为“1 小时后提醒”或系统 action menu，不使用含糊的“打开”“稍后”。
- 通知场景中不能再次播放 Alert；Resident 只保留未解决标记。
- Demo 必须能够验证 notification ownership 已接管，返回桌面后不重播 Alert。

### P0-09：修复对比度、文字尺寸和 hit area

当前浅色 `--dim: #747e89` 在约 `#fafcfe` surface 上对比度约 4.0:1，未达到普通文字 4.5:1。浅色 `--mint: #8edfb8` 在近白色 surface 上约 1.5:1，不能单独作为状态点或进度图形。

实施要求：

- 浅色 `text.tertiary` 至少调整至约 `#69747F`，并在壁纸最亮区域合成后复测。
- 拆分 `accent.action` 与 `status.healthy`。浅色状态图形使用更深的绿色，如 `#2F7658`；浅 mint 只用于大面积按钮背景，搭配深色文字。
- translucent surface 必须设最低不透明度或底部 scrim，不能让壁纸亮度决定文本是否合格。
- 所有产品 metadata 不低于 11pt。当前 Routine、Large、Workboard、Notification 和 Popover 内仍存在大量 9 至 10px 文本。
- 产品控件 hit area 至少 44×44pt。当前 34 至 38px 的 Routine more、Island button、Expanded close、Privacy chip、Notification action、MenuBar footer button 均不合格。

验收：

- 两主题、三张不同明度壁纸下，正文 ≥4.5:1、非文本状态图形与 focus ring ≥3:1。
- 130% 字号下主操作不裁切，辅助信息按优先级隐藏而非缩小到 9px。

### P0-10：增加无刘海与多屏可视化证据

PRD 已定义多屏规则，但当前截图只覆盖单一带刘海画布，不能验证真实退化。

至少补齐以下真机或高保真测试证据：

1. 内建刘海屏：Resident、Alert、Expanded。
2. 外接无刘海屏：MenuBar popover，不在中央模拟假刘海。
3. 内建屏 + 外屏：Alert 仅 key window 屏出现一次。
4. Clamshell：Resident 自动不可用，MenuBar 保持能力完整。
5. 全屏：completion / quota critical 只更新 badge，不转系统通知。
6. Alert 生命周期内拔掉目标屏：关闭 Overlay，保留 MenuBar 状态，不在另一屏重新播放动画。

## 3. P1，Pilot 后完善

### P1-01：把 Pinned Routine 建立为独立产品模块

固定“每日 Gmail 审查”有明确用户价值，但应作为 P1 **Pinned Routine**，而不是用未验证的 Scheduled 数据混入 P0。

建议支持：

- 固定一个已保存 URL 或 WorkPulse-owned target。
- 用户自定义名称、图标、提醒时间和是否允许桌面显示标题。
- 可信 adapter 可用后增加 last run、next run、Needs You count。
- Stale、Offline、Unsupported 状态与普通 Widget 使用同一 freshness 模型。
- 不在 Widget 内显示邮件主题、发件人或正文。

### P1-02：Large Daily Brief 收敛为“3 + 2”结构

当前 Hero 写“3 个变化”，下面却展示 Needs You、Completed、Scheduled、Quota 四张同权卡，数量和层级不一致。

建议：

- 最多 3 个 priorities。
- 最多 2 个 context chips，从 Scheduled、Quota、Coverage 中选择。
- 明确标注 `本地汇总`、生成时间和 source coverage。
- 没有可信 Scheduled 来源时隐藏 Scheduled，而不是展示模拟状态。
- 每个 priority 是独立 open target；Footer 打开完整 Brief。

### P1-03：主题 token 从颜色值升级为语义角色

当前同一个 mint 同时承担品牌、健康、主操作和进度，导致浅色主题中的可访问性和层级难以同时满足。

建议 token：

- `accent.action.background`
- `accent.action.foreground`
- `status.healthy.foreground`
- `status.healthy.background`
- `status.attention`
- `status.critical`
- `surface.widget`
- `surface.overlay`
- `surface.notification`
- `text.primary / secondary / tertiary`

Light 与 Dark 使用独立 Asset Catalog 动态值，不做机械反转。布局、字重、信息优先级和 semantic role 必须跨主题完全一致，颜色明度可以不同。

### P1-04：完善辅助功能模式

- Increase Contrast 下加强边界，取消依赖半透明层次。
- Reduce Transparency 下使用不透明 surface。
- Differentiate Without Color 下，为 approval、failure、running 配置不同 SF Symbol 和文字标签。
- VoiceOver 只播报新 action-blocking Alert；Resident 普通进度变化不主动播报。
- Radiogroup 使用原生 segmented control，或在 Web Demo 中实现 Arrow key 与 roving tabindex。
- Widget 整卡和内部链接必须是语义化控件，不能只给 `<article>` 注册 click handler。

### P1-05：MenuBar compact / verbose 两种密度

- Compact，默认：symbol + badge。
- Verbose，可选：symbol + WorkPulse + badge 或 quota。
- 菜单栏空间不足时自动退化为 Compact。
- Privacy、Monitoring lost 需要可辨认但不能依赖颜色的小型标记。

## 4. P2，扩展阶段

### P2-01：Extra Large Workboard

当前 Demo 使用三列工作区 + quota 侧栏，与 PRD 的 2×2 模块结构不一致。P2 实现时应回到：Active、Needs You、Scheduled、Usage 四模块；空模块隐藏并自动重排。

### P2-02：跨设备 Live Activity

只有 iPhone companion 成立后才设计真正的 ActivityKit Live Activity。Mac 自定义 Overlay 不应复用 Dynamic Island 命名或暗示系统级能力。

### P2-03：主题个性化

在 Light / Dark / System 三种原生外观稳定后，再考虑用户自定义强调色。自定义色必须通过状态对比度和隐私截图测试，不能改变语义状态颜色。

## 5. 按表面汇总

| 表面 | 当前优点 | 主要问题 | 优先动作 |
|---|---|---|---|
| 双主题 | 布局一致、层级清楚、浅深色均克制 | Light tertiary 和 mint 状态对比不足；材质受壁纸影响 | P0 拆分语义色并复测合成对比度 |
| Gmail Routine | 三列信息和主 CTA 扫视效率高 | 暗示未验证的 Gmail / Scheduled 状态；自由尺寸不对应 WidgetKit | P0 降级为 Manual，P1 建立 Pinned Routine |
| Small | 主数值与 reset 清楚 | 英文标题、浅色 ring 对比低 | P0 改为“Codex 额度”，加强状态图形 |
| Medium | Current / Next 大方向正确 | Next 两项且点击目标不独立 | P0 只保留最高优先级并分离 target |
| Large | 汇总密度可控 | “3 个变化”与四张卡矛盾；Scheduled 来源不明 | P1 改为 3 priorities + 2 chips |
| MenuBar | 可见且不抢注意力 | popover 功能和键盘未落地；Privacy 无常驻标记 | P0 完整实现主入口 |
| Resident | 视觉克制 | 不可点击、不可聚焦、默认暴露标题 | P0 button semantics + generic default |
| Alert | 视觉高优先级明确 | 过宽、两步到审批、计时未实现 | P0 直接“打开审批”，实现 4/8/10 秒 |
| Notification | 信息完整 | 默认泄露真实标题，操作文案模糊 | P0 始终 generic，明确 snooze |
| Privacy | 切换机制已存在 | 只替换标题，图标、计数、caption、toast 仍可泄露 | P0 扩大泛化范围 |
| Accessibility | 有 focus ring 与 Reduce Motion | 小字号、小 hit area、非语义 click、live region 过宽 | P0 修基本项，P1 完善辅助模式 |
| 多屏 | PRD 逻辑基本明确 | 没有视觉或真机证据 | P0 建立六场景测试矩阵 |

## 6. 建议新增验收标准

- **AC-UIV4-01**：Widget 和通知在 Privacy Mode 关闭时仍只包含 generic 文案；item-level 桌面标题必须经过单独授权。
- **AC-UIV4-02**：Manual Pinned Routine 不展示自动完成、邮件数量或 Scheduled freshness。
- **AC-UIV4-03**：Medium 的 Current 与 Next 分别打开两个验证过的 target，且 Next 只显示一个最高优先级事件。
- **AC-UIV4-04**：Approval Alert 主操作一次进入正确审批上下文，不经过 Expanded 中转。
- **AC-UIV4-05**：Resident 仅用键盘即可打开和关闭 Expanded，关闭后焦点返回 Resident。
- **AC-UIV4-06**：菜单栏 `打开 Inbox` 与 `诊断`进入不同且正确的主应用 scene。
- **AC-UIV4-07**：Alert 按 4 / 8 / 10 秒规则自动收回，hover 与 accessibility focus 暂停；收回后状态仍持久存在。
- **AC-UIV4-08**：浅色和深色在最亮、最暗壁纸区域均满足文字 4.5:1、图形 3:1。
- **AC-UIV4-09**：所有产品交互目标至少 44×44pt，metadata 不低于 11pt。
- **AC-UIV4-10**：双屏场景中同一 Alert 只出现一次且生命周期内不跳屏。
- **AC-UIV4-11**：无刘海和 Clamshell 模式下，所有 P0 状态与操作从 MenuBar 完整可达。
- **AC-UIV4-12**：Privacy Mode 下 Gmail 图标、邮件单位、caption 和 toast 均泛化，不仅是标题。

## 7. 本轮最终意见

- **可以保留**：整体 Quiet Graphite / Pearl 方向、固定例程的主视觉层级、Small 的单值模型、Medium 的左右结构、菜单栏为可靠入口、Overlay 为 opt-in。
- **必须重做**：隐私默认实现、固定例程的数据语义、Medium 点击模型、Alert 一步返回、Resident 可访问性、MenuBar action mapping、对比度和多屏验证。
- **暂不进入 P0**：可信 Gmail / Scheduled Health、Large Brief、Extra Large Workboard、主题自定义与跨设备 Live Activity。

在这些 P0 修复完成前，不建议把当前 `design-qa.md` 的 `passed` 解释为产品设计已冻结；它应保留为“默认 Routine 场景的视觉一致性通过”。
