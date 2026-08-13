# WorkPulse 系统表面 UI/UX 重新审查 V1

> 角色：UI/UX 设计审查  
> 日期：2026-08-12  
> 范围：桌面 Widget、刘海/顶部岛、macOS 通知  
> 证据：当前 SwiftUI/AppKit 源码、PRD V5、当前原生运行态截图与辅助功能树  
> 约束：本轮只审查，不修改源码

## 1. 结论先行

当前把刘海常驻内容从“7 天窗口已更新”改为“剩余额度 + 下次重置时间”，方向正确，信息价值明显提高。但它还不是最优终稿。

当前真实运行态是：

- 常驻：`Codex 55% 剩余` ｜ `周二 09:58 重置`
- 展开：`Codex 7 天窗口` ｜ `55% 剩余 · 周二 09:58 重置`
- 辅助功能：`WorkPulse 常驻状态，Codex 55% 剩余，周二 09:58 重置`

真正的核心问题已经从“信息没价值”变成了“信息缺少所属窗口”。当 Codex 同时存在 5 小时、7 天或其他 bucket 时，只显示 `Codex 55%` 会让用户无法判断这是哪个额度。常驻最优信息顺序应是：

> `7 天 · 55% 剩余` ｜ `周二 09:58 重置`

这里“7 天”比重复显示“Codex”更有决策价值。`Codex` 可保留在 VoiceOver、菜单栏和展开态标题中。

此外，展开态仍混入“固定入口”“手动固定未同步状态”等与 quota 无关的信息，底部来源行字号过小且把两个能力状态拼在一起。它目前更像缩小版状态面板，而不是一次围绕用户点击意图展开的详情。

总体建议：

1. 顶部岛继续作为“一眼扫读 + 必要时展开”的额度表面。
2. 展开态必须按上下文组织，点击 quota 就只展示 quota，不混入固定入口。
3. 首版只交付真正有持续价值的 Small Quota 和 Small Pinned Widget；Medium/Large 在真实 Needs You 或 Scheduled 来源接通前保持 gated。
4. 通知必须在隐私和信息价值之间重新平衡，当前“一项任务正在等待操作”过于泛化。

## 2. 三种系统表面的职责边界

| 表面 | 用户问题 | 生命周期 | 信息上限 | 推荐交互 |
|---|---|---|---|---|
| Small Widget | 我现在还有多少额度/我的固定入口在哪里？ | 长期、低打扰 | 1 个主指标 + 1 个时间或动作 | 单击打开对应目标 |
| Medium/Large Widget | 今天有哪些事情值得注意？ | 长期、摘要型 | 2–3 个真实且独立的数据区域 | 分区 deep link |
| 顶部 Resident | 我现在还能不能继续工作，何时恢复？ | 用户主动常驻 | 额度窗口、剩余、reset | 单击展开 |
| 顶部 Alert | 刚刚发生了什么，需要立即看吗？ | 6–12 秒或直到用户处理 | 事件类别、必要动作、时间 | 单击展开、稍后 |
| 顶部 Expanded | 我点击的这件事具体是什么？ | 用户主动、短时 | 当前上下文的详情与 1–2 个动作 | 刷新、稍后、打开 |
| macOS 通知 | 顶部岛不可达时，我是否需要回来处理？ | 系统管理 | 可安全显示的事件类别与动作 | 查看、稍后 |

原则：三个表面不是把同一张卡片换尺寸。Widget 是环境信息，顶部岛是即时状态和短交互，通知是 fallback。任何同一事件只应有一个主动表面。

## 3. 顶部 Resident 复核

### 3.1 当前优点

- 真正回答了用户最关心的两个问题：剩多少、何时重置。
- 286 × 42 pt 的实际形态中没有文字截断，左右分区清楚。
- 黑色轮廓已经与物理刘海合并，当前截图未出现内容被刘海遮挡。
- 整个胶囊都是按钮，鼠标命中范围足够。
- fresh、stale、unavailable 使用不同 SF Symbol，不是只靠颜色表达。
- 多显示器逻辑优先带刘海的内建屏幕，符合用户已明确提出的放置偏好。

### 3.2 仍需调整

#### P0：必须显示 bucket/window 身份

`Codex 55%` 在多额度窗口下存在歧义。用户真正需要的是“哪个窗口还剩 55%”。推荐视觉文案：

- 5 小时窗口：`5 小时 · 55% 剩余`
- 7 天窗口：`7 天 · 55% 剩余`
- 未知窗口：`Codex · 55% 剩余`
- 右侧保持：`周二 09:58 重置`

如果来源提供明确且简短的 bucket 名称，也可显示 `7 天额度 · 55%`，但不得把内部 `limitID` 直接暴露给普通用户。

#### P0：stale 或 reset 已过期时，不能继续把精确百分比当主信息

当前 `.live` 但 stale 时，左侧仍显示 `Codex 55% 剩余`，右侧才显示“可能过期”。扫读时用户会先相信精确值。reset 时间已经过去时也会保留旧百分比。建议状态规则：

| 状态 | 常驻主文案 | 次文案 |
|---|---|---|
| fresh live | `7 天 · 55% 剩余` | `周二 09:58 重置` |
| refreshing | `Codex 正在更新` | `读取最新额度` |
| stale/cached | `额度可能已过期` | `点击刷新` |
| reset 已过去 | `等待额度更新` | `点击刷新` |
| unavailable | `Codex 额度不可用` | `点击刷新` |
| demo | `演示额度` | `非实时` |

精确 quota 和 reset 只在 freshness 可证实时作为主信息。

#### P1：数字应使用等宽数字

百分比和时间会周期变化，建议使用 `monospacedDigit()`，避免 `55%`、`8%`、`100%` 导致左右内容轻微跳动。主信息保持 semibold，reset 使用 regular/medium，避免两侧竞争。

#### P1：VoiceOver 缺少窗口、freshness 和操作提示

当前朗读有剩余和 reset，但没有说明这是 7 天窗口、是否 fresh，以及按下后会发生什么。建议完整标签：

> “Codex 7 天额度，剩余 55%，周二 09:58 重置，1 分钟前更新。按下查看额度详情。”

不要朗读“绿色”“打勾”等视觉词。

### 3.3 Resident 视觉验收标准

- 在 286 pt 当前宽度下，`100%`、中文周几、24 小时制和最长本地化短日期均不截断。
- 5 小时与 7 天 bucket 可在 1 秒内辨别，不能只靠颜色或隐藏设置判断。
- 主信息与 reset 基线对齐；数字变化不产生明显水平抖动。
- 物理刘海下缘与黑色形态连续，左右肩部无白缝、圆角反折或文字进入刘海安全区。
- 100%、130% 文本尺寸下不重叠；空间不足时优先缩短日期格式，不缩到 11 pt 以下。
- VoiceOver 一次朗读窗口、剩余、reset、freshness 和“按下查看详情”。

## 4. 顶部 Expanded 复核

### 4.1 当前问题

当前展开态显示：

1. `WorkPulse` 品牌标题；
2. `Codex 7 天窗口` + `55% 剩余 · 周二 09:58 重置`；
3. `固定入口 · 未设置`；
4. `Codex App Server 读取成功 · 1:10 · 手动固定 · 未同步状态`；
5. `刷新`。

这里有三类低价值或重复信息：

- 用户点击 quota 后，`固定入口` 与当前意图无关；未设置时尤其不应占一整行。
- “手动固定 · 未同步状态”属于固定入口能力，却和 quota 来源拼在同一 footer。
- `WorkPulse` 重复品牌，不如直接写“Codex 额度”建立上下文。

底部 source 使用 10 pt、50% 白色。对比度虽不一定失败，但实际截图中读取成本明显高，不适合作为 freshness 的唯一位置。

### 4.2 推荐结构

quota 展开态应改为上下文专用结构：

```text
Codex 额度                         ×

7 天窗口
55% 剩余              周二 09:58 重置

Codex App Server · 1 分钟前更新
[刷新]
```

存在多个 bucket 时，标题下增加紧凑的 `5 小时 / 7 天` 切换；不存在多个 bucket 时不显示选择器。固定入口不出现在 quota 展开态。

事件 Alert 展开态继续使用另一套结构：事件类别、freshness、稍后、从本机移除。不要强行用同一个通用 Expanded 内容模型承载所有情境。

### 4.3 可执行改动

- **P0**：从 quota Expanded 移除“固定入口”和 manual capability 拼接。
- **P0**：把 source、observed age、freshness 合并成一条 11–12 pt 的可信度信息。
- **P1**：标题从 `WorkPulse` 改为 `Codex 额度`；品牌图标可保留但降级。
- **P1**：剩余和 reset 使用两列指标，reset 不再塞进同一个长 value 字符串。
- **P1**：关闭按钮至少 28 × 28 pt，有 hover、pressed、focus-visible 状态；当前图标按钮视觉命中区过小。
- **P1**：刷新期间按钮禁用并显示“正在更新”；成功后更新 relative age，失败后保留明确错误而不是静默收起。
- **P2**：Expanded 的视觉宽度允许在 360–420 pt 之间根据最长本地化内容适配，不使用无限制的单行压缩。

### 4.4 Expanded 验收标准

- 用户展开后 2 秒内能回答：哪个窗口、剩多少、何时重置、数据有多新。
- quota Expanded 不出现固定入口、Needs You 或 Gmail 文案。
- 390 pt 宽度下，`100% 剩余` 与最长短日期均不截断；130% 字号允许转为上下两行。
- Tab 顺序为 bucket selector（如有）→ 刷新 → 关闭；Escape 始终收起并恢复 Resident。
- 键盘焦点进入按钮时不会触发 6 秒自动消失。
- VoiceOver 不重复朗读图标名和可见文案，状态变化后只播报一次更新结果。

## 5. 顶部 Alert 复核

### 5.1 常驻与瞬时形态应严格区分

- Resident 只显示用户主动选择的长期指标，不主动抢注意力。
- Alert 只用于可信、fresh、发生状态跃迁且需要行动的事件。
- 低额度阈值提醒属于 Alert，但文案必须包含 bucket、剩余和 reset；只写“打开查看额度窗口”仍然让用户多做一步。
- Alert 完成或超时后恢复 Resident，不留下两个顶部表面。

### 5.2 当前 6 秒 + hover 暂停对键盘和 VoiceOver 不够安全

当前 Alert 只在鼠标 hover 时暂停。键盘焦点、VoiceOver 正在朗读、用户打开控制中心等情形不会暂停。建议：

- **P0**：Alert 获得键盘焦点或辅助功能焦点时暂停倒计时。
- **P0**：VoiceOver 开启时不自动在 6 秒内消失，至少延长到 12 秒或要求明确关闭。
- **P1**：普通 Alert 显示 8–10 秒；work-loss risk 可以保留到用户查看、稍后或转为通知。
- **P1**：Respect Reduce Motion；出现/收起只做 150–200 ms 淡入与尺寸变化，关闭动画时立即切换。

### 5.3 quota Alert 推荐文案

```text
7 天额度剩余 20%
周二 09:58 重置
```

点击进入 quota Expanded。不要再显示“打开 WorkPulse 查看额度窗口”这类把信息隐藏到下一层的文案。

## 6. Widget 重新审查

### 6.1 首版组件范围应收缩

当前四个 Widget 在结构上完整，但真实产品价值并不对等：

| Widget | 当前价值 | 建议 |
|---|---|---|
| Small Quota | 高频、真实、可扫读 | 首版交付 |
| Small Pinned | 高频入口、无需 adapter | 首版交付 |
| Medium Now & Next | Needs You 尚未连接时一半是死区 | 真实 Needs You 前 gated |
| Large Daily Brief | 没有 Gmail/Scheduled/Needs You 时只是三项导航菜单 | 至少两个真实摘要源前 gated |

这不是删除长期方向，而是避免用“尚未连接”“未同步”填满桌面。桌面组件长期存在，低价值免责声明会迅速变成视觉噪音。

### 6.2 Small Quota 当前密度过高

当前 systemSmall 同时放入：标题、freshness、38 pt 百分比、换算说明、窗口、source、limitID、observed time、reset。真实小组件高度下很容易压缩或裁切，也违背“一眼扫读”。推荐仅保留：

```text
7 天额度        已更新
55%
周二 09:58 重置
```

来源和 observed age 进入 VoiceOver 标签、tooltip 或点击后的 Expanded，不必每次占据可视空间。“根据来源用量换算”可以放在首次说明，不应永久显示。

### 6.3 Gallery placeholder 真实性

当前 placeholder 使用精确的 `64%` 类演示数值，并仅以 `Widget Gallery` 作为 source。普通用户可能把它理解为实时额度。

- **P0**：Gallery/placeholder 必须可见标注“示例”，或使用 `--%` + “连接后显示”。
- **P0**：demo/fixture 快照继续禁止进入真实桌面 Widget。
- **P1**：所有 Widget 的 stale 状态不展示精确 quota 作为当前值。

### 6.4 Pinned 与 Daily Brief

- Small Pinned 的“固定例程 + 手动入口”层级合理；标题最多两行，底部只保留“打开对话”，不重复“未同步运行状态”两次。
- Large Daily Brief 顶部“本机脱敏摘要 · 不读取邮件内容”属于必要边界，但 footer“打开 WorkPulse 查看来源、freshness 与操作边界”过于产品内部化。应改为具体动作或删除。
- `Needs You 尚未连接` 不应长期占 Daily Brief 第一行；未接通时隐藏该 section，并用剩余真实 section 重新布局。

### 6.5 Widget 视觉验收标准

- systemSmall 在实际 Widget Gallery 与桌面尺寸中，Light/Dark、130% 字号无裁切。
- 用户 2 秒内辨别 quota window、remaining、reset；source 不与主指标争夺注意力。
- placeholder、demo、stale、live 四态不能仅靠颜色区分。
- Widget 跟随 macOS 系统 Light/Dark；应用内主题选择不应暗示可强制改变 Widget 外观。
- 每个可点击区域有独立且完整的 VoiceOver 标签；Large Widget 三行分别朗读目标与结果。
- Increase Contrast 下边界、文字和图标仍清楚；Reduce Transparency 下不依赖材料模糊维持层级。

## 7. macOS 通知重新审查

### 7.1 当前优势

- 通知是 Overlay 不可达时的 fallback，不与顶部 Alert 重复投递。
- deep link 只使用本机 event UUID，隐私边界清楚。
- 支持“查看”和“稍后提醒”，且稍后不伪造来源已解决。
- quota 通知按 bucket cycle 去重，避免每次刷新重复轰炸。

### 7.2 当前通知信息价值不足

`WorkPulse 需要你的处理 / 一个任务正在等待操作` 只表达“有事”，没有表达“需要什么”。它和此前“7 天窗口已更新”的问题相同：真实但没有决策价值。

在不泄露项目、线程、prompt 和标题的前提下，仍可显示安全的事件类别：

- `Codex 等待你的输入`
- `Codex 请求确认`
- `Codex 任务可能丢失进度`
- `7 天额度剩余 20% · 周二 09:58 重置`

如果团队坚持通知完全 generic，则必须把它定义为最高隐私模式，而不是唯一模式。推荐默认“隐藏内容名称，但显示事件类别”。

### 7.3 可执行改动

- **P0**：quota 通知包含 window、remaining、reset，且 stale 数据不得触发。
- **P1**：Needs You 通知显示安全事件类别，不显示用户标题、路径或内容。
- **P1**：提供“通知声音”开关；默认仅 work-loss risk / quota paused 使用声音，普通 needs input 默认静音。
- **P1**：应用处于前台且顶部 Alert 已呈现时，通知中心不得再次 banner + sound。
- **P1**：通知被系统 Focus、权限或预览设置抑制时，Menu Bar 仍保留可发现的未处理状态。
- **P2**：测试通知继续明确写“测试”，并使用与生产提醒不同的 identifier/视觉文案。

### 7.4 通知验收标准

- 锁屏截图不出现线程名、项目名、prompt、文件路径、Gmail 标题或自定义入口名。
- 用户仅看通知即可判断事件类别和是否需要立即返回。
- 同一 event/cycle 在 Notification、顶部 Alert 中只出现一次主动提醒。
- “稍后”执行后有可验证的本地状态，1 小时后才重新进入可投递状态。
- 通知关闭、Focus 开启、应用前台、顶部岛不可达四种状态均有明确 fallback。

## 8. Light/Dark、多显示器与全屏

### 8.1 主题

- 顶部岛固定黑色是合理的硬件融合策略，不需要跟随应用浅色/深色切换。
- 菜单栏弹层可跟随用户选择的 Light/Dark。
- Widget 由 macOS 环境控制主题，不能把应用内主题开关描述为“同时控制桌面 Widget”。
- 需要在设置文案中明确：主题影响菜单栏；顶部岛保持黑色；Widget 跟随系统。

### 8.2 多显示器

当前“优先带刘海的内建屏幕，即使它不是 main screen”与用户反馈一致。验收矩阵必须包括：

1. 内建带刘海 + 外接主屏：只在内建屏显示；
2. 内建带刘海 + 外接非主屏：只在内建屏显示；
3. 合盖模式：降级到当前 main display 顶部胶囊；
4. 内建屏重新打开：自动迁回内建刘海，不产生副本；
5. 分辨率、缩放、屏幕排列变化：panel 重新定位，内容不进入物理刘海。

### 8.3 全屏与演示场景

当前 panel 可进入所有 Spaces 与 full-screen auxiliary。对视频、演示和屏幕共享，这可能成为长期遮挡。

- **P1**：默认在全屏视频/演示中隐藏 Resident，Alert 改走通知或 Menu Bar。
- **P1**：提供“全屏时仍显示顶部状态”的显式开关，默认关闭。
- **P2**：屏幕共享时继续使用 generic 文案，并允许一键临时隐藏顶部岛。

## 9. 优先级总表

### P0：下一版必须关闭

1. Resident 加入 quota window/bucket 身份，避免多窗口歧义。
2. stale、reset 已过去、unavailable 不再把精确百分比作为主信息。
3. quota Expanded 移除无关固定入口和 capability 拼接，改为上下文专用内容。
4. Alert 在键盘/VoiceOver 焦点下暂停倒计时，避免读到一半消失。
5. Small Quota placeholder 明确“示例”；demo/fixture 不进入真实 Widget。
6. quota Alert/Notification 同时包含 window、remaining、reset，且只用 fresh live 数据。

### P1：首轮可用性优化

1. Resident 数字等宽、VoiceOver 补充窗口/freshness/操作提示。
2. Expanded 使用“剩余/重置”两列，source + observed age 独立成可信度行。
3. 关闭按钮扩大命中区，补齐 hover、pressed、focus、loading 状态。
4. Medium Now & Next、Large Daily Brief 在真实来源接通前不进入首版 Gallery。
5. Needs You 通知显示安全事件类别；增加通知声音策略。
6. 全屏默认隐藏 Resident；保留用户显式开启选项。
7. 完成 Light/Dark、130% 字号、Increase Contrast、VoiceOver 真机矩阵。

### P2：视觉完成度

1. 顶部岛日期格式按空间自适应，避免固定字符串压缩。
2. 统一 4 pt spacing scale、11/12/14 pt 字体层级和等宽数字规则。
3. Reduce Motion 下关闭尺寸动画；普通状态变化控制在 150–200 ms。
4. 提供屏幕共享临时隐藏与多屏迁移的轻量反馈。
5. 对中文、英文和 12/24 小时制做本地化长度回归。

## 10. 最终 UI/UX 放行条件

只有同时满足以下条件，三种系统表面才能判定为 UI/UX Go：

- 常驻顶部岛能无歧义回答“哪个窗口、剩多少、何时重置”。
- 展开态只呈现用户刚刚点击的上下文，不成为缩小版 Dashboard。
- stale、demo、unavailable 在所有表面都不冒充 fresh live 数据。
- Widget 在真实 Gallery/桌面而非 Web 模拟中通过 Light/Dark、130% 字号和 VoiceOver。
- Alert 不因固定 6 秒计时打断键盘或 VoiceOver 用户。
- 通知既不泄露私人内容，也能让用户判断“需要输入、确认、恢复还是等待额度”。
- 内建刘海、外接屏、合盖、全屏切换时只有一个顶部表面，且不遮挡或漂移。

当前判断：**Resident 信息方向为 Conditional Go；Expanded、Widget Gallery 与 Notification 信息架构仍为 No-Go，直到 P0 关闭。**
