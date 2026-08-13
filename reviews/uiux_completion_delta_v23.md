# WorkPulse build 23 UI/UX 完成度 Delta

> 初次审查：2026-08-13（Europe/Oslo）  
> 最终 Delta 复核：2026-08-13，针对 Pinned recovery route、Expanded keyboard protection release 与 Large Text 分级后的当前源码  
> 审查对象：`native/WorkPulseNative` 当前 build 23 源码  
> 审查方式：只读 Combined UI/UX + Accessibility source audit  
> 证据边界：本轮没有操控最终安装包、Widget Gallery 或系统辅助功能，也没有把旧截图当作本轮 GUI 证据；因此本文只给出源码能证明的结论和仍需实机完成的矩阵。

## 结论

- **残余 P0：0。** 没有发现阻止应用启动、造成数据泄露或让全部核心入口不可用的 UI/UX 缺陷。
- **残余 P1：0。** 初审的 5 项均已有对应源码合同；Large Text 原始缺口已由 Widget reflow、Top panel 尺寸重算和控制中心可滚动/拓宽关闭。最大字号是否真的无裁切仍是强制实机 Gate，不能由源码宣称为 Pass，但当前没有足够证据继续把它定为“已发生或高概率阻断核心任务”的源码 P1。
- 四种 Widget 的 freshness 处理、Light/Dark 数据流和 Privacy 标题门控总体方向正确；控制中心已收敛为五组；Top Resident 保持 quota-first，Expanded 具备 Hover、Esc、VoiceOver/Switch Control 源码保护。但这些是源码结论，不等同于最终 GUI/辅助技术实机 Pass。
- 产品范围仍建议以 **Small Quota + Small Pinned** 为首发核心。Medium 可作为组合位，Large 在真实独立使用价值成立前继续视为实验能力，不作为首发价值承诺。

## 最终 Delta 复核总表

| 初审问题 | 当前源码证据 | 源码层判断 | 仍需手工证明 |
|---|---|---|---|
| P1-1 `hasValidPinnedTarget` | schema 6 新增布尔字段；Host 用 `validTargetURL != nil` 发布；URL 改变会重发 snapshot；Small/Medium/Large 均有 setup 文案；CoreVerify 覆盖 true/false（`Models.swift:318-433`；`WorkPulseMenuBarApp.swift:159-166, 1899-1910`；`WorkPulseWidget.swift:671-708, 785-804, 853-863`；`WorkPulseCoreVerify/main.swift:216-261`） | **Closed in source** | Widget Gallery 中 empty/invalid/valid 的真实渲染、刷新与点击 |
| P1-2 Large Text | Widget 已读取 `dynamicTypeSize` 并在 accessibility size reflow/减少次级密度；Top 用 `usesAccessibilityTextLayout` 重算 Resident/Alert/Expanded；控制中心可滚动并拓宽（`WorkPulseWidget.swift:600-947`；`NotchOverlayController.swift:169-173, 393-407, 568-755`；`WorkPulseMenuBarApp.swift:2511-2548`） | **Closed in source / Mandatory manual Gate** | 默认、Large、最大可用文字档位的真实渲染；固定字号与两档尺寸是 P2 韧性改进点，不冒充无裁切证明 |
| P1-3 contrast | Top 读取 `colorSchemeContrast`；Light normal source/row alpha 提高到 0.70/0.72，Increase Contrast 为 0.82/0.86，边界同步增强（`NotchOverlayController.swift:553-556, 688-735`） | **Closed in source** | no-notch Light/Dark 与 Increase Contrast 的真实渲染测量 |
| P1-4 quota selected AX | bucket Button 增加“已选择/未选择” value 与 `.isSelected` trait（`WorkPulseMenuBarApp.swift:2676-2706`） | **Closed in source** | VoiceOver 实际读序、选择后 announcement 与状态刷新 |
| P1-5 Alert keyboard focus | Alert 新增 focus state、键盘交互状态和剩余倒计时暂停/恢复（`NotchOverlayController.swift:106-110, 223-288, 589-622`） | **Closed in source** | Full Keyboard Access 是否能实际聚焦非激活 panel，并保持 >12 秒 |

本轮以其声明的 `zsh` 再次运行 `verify_system_surfaces.sh`，全部静态检查通过。注意：其中与这些项目相关的 Gate 主要是 token presence（`156-181`），不能替代布局、读序、焦点或渲染验收；特别是“存在 `dynamicTypeSize.isAccessibilitySize`”、`workpulse://routine/setup` 或 15 秒保护任务，分别不能证明最大字号无裁切、WidgetKit 点击已回流或 Full Keyboard Access 焦点行为正确。`WorkPulseCoreVerify` 的 route assertion 可在源码中看到，但本次 SwiftPM 执行被当前沙箱的嵌套 `sandbox-exec` 拒绝，因此本文不把它写成运行通过。

## 本轮新增 Delta：恢复路由与 Expanded 键盘保护

| 检查项 | 最新源码合同 | 判断 | 仍需实机 Gate |
|---|---|---|---|
| Pinned Widget 恢复路由 | `PulseUnavailableWidgetView` 支持独立 `recoveryURL`；Small Pinned 的 empty/corrupt/unsupported 均使用 `workpulse://routine/setup`；`DeepLinkRouter` 有 `.routineSetup` 且 Host 给出固定入口设置指引（`WorkPulseWidget.swift:575-599, 711-716`；`Models.swift:268-300`；`WorkPulseMenuBarApp.swift:1603-1609`） | **Closed in source**。`.available + hasValidPinnedTarget == false` 仍通过 routine UUID 路由，但 Host 会再次检查 `validTargetURL` 并进入相同设置指引，不再尝试打开无效 HTTPS 目标（`WorkPulseMenuBarApp.swift:1588-1602`） | empty/corrupt/unsupported/available-invalid 四态都从真实 Widget 点按；确认只出现一次明确指引且不会误开浏览器 |
| Expanded 键盘保护解除 | 每次 `keyDown` 都把保护置为 true、取消旧任务并续期 15 秒；到期后显式置 false，鼠标不在 panel 内时重新触发 300ms 退场；关闭/恢复时会取消任务并清零（`NotchOverlayController.swift:412-470`） | **Closed in source for “永久卡住”问题** | FKA 真实焦点链中连续按键会续期；停止键盘输入 15 秒后能退场；Esc、鼠标重入及 VoiceOver/Switch Control 不被计时器破坏。15 秒是 heuristic，不等于焦点态证明 |

## 已确认的源码优点

1. **Widget 家族边界清楚。** Bundle 只注册 Small Quota、Small Pinned、Medium Quick 与 Large Overview，各自仅声明对应 family（`WorkPulseWidget.swift:983-1045`）。
2. **stale 不伪装成实时。** Small Quota 在 stale 时隐藏旧百分比主视觉（`625-665`）；Medium 显示“额度需更新”（`752-774`）；Large 每个额度卡独立判断 freshness（`881-903`），任务摘要也独立判断 freshness（`938-945`）。
3. **Light/Dark/System 与强调色能随 Widget snapshot 传递。** Host 发布 `themePreference` 与 `accentPreference`（`WorkPulseMenuBarApp.swift:1899-1910`），Widget 使用明确的主题解析与前景色（`WorkPulseWidget.swift:509-542`）。
4. **Privacy 标题门控是结构性的。** 用户标题只在 Privacy Off 且单独 opt-in 时写入 Widget snapshot（`Models.swift:393-433`；`WorkPulseMenuBarApp.swift:531-552, 1899-1910`）；Top Expanded 在 Privacy 下改为 A/B + 时间（`WorkPulseMenuBarApp.swift:948-984`）。
5. **控制中心信息架构已收敛。** 控制页只有“顶部显示、隐私、外观与启动、固定入口、系统通知”五组（`WorkPulseMenuBarApp.swift:2835-3000`），没有独立 Dashboard，也没有商业化宣传卡。
6. **Top 三态的基础保护存在。** Resident/Alert 都是单一可按按钮并有明确 AX label；Expanded 有关闭按钮、Esc、悬停保护和点击外部关闭；VoiceOver/Switch Control 开启时 Alert 不启动自动关闭、Expanded 离开鼠标也不自动关闭（`NotchOverlayController.swift:223-334, 392-431, 553-736`）。

## 初审 P1 的最终状态

### P1-1 固定入口缺少“目标是否有效”的 Widget 状态合同：Closed in source

**初审源码证据（修复前）**

- `WidgetSnapshot` 只有 `routineID/routineTitle/routineCapability`，没有 `hasValidPinnedTarget` 或等价字段（`Models.swift:318-387`）。
- Host 无论 `targetURLString` 为空、无效还是有效，都会用 `manualRoutine` 发布 available snapshot；发布参数没有目标可用性（`WorkPulseMenuBarApp.swift:1847-1908`）。
- Small Pinned 对所有 `.available` snapshot 都显示“点按打开保存的对话”（`WorkPulseWidget.swift:657-692`）；Medium 与 Large 也同样显示可操作的固定入口（`765-782, 831-837`）。只有完全没有 snapshot 才出现“尚未固定入口”。

**用户影响**

首次使用、链接被清空或链接无效时，Widget 仍表现为已有可打开入口。点击后才看到“尚未设置”，属于核心任务的 false affordance，尤其直接影响首发核心 Small Pinned。

**直接修法**

1. 将 snapshot schema 升级，加入 `hasValidPinnedTarget`；Host 使用 `validTargetURL != nil` 写入。
2. `targetURLString` 改变时立即重新发布 Widget snapshot。
3. 三个含固定入口的 Widget（Small Pinned、Medium、Large）在 false 时显示“设置固定入口”，点击进入设置/控制中心，不再写“打开保存的对话”。
4. 加入 empty、invalid、valid、Privacy On/Off 的 CoreVerify 与 Widget rendering fixture。

**最终 Delta**：schema 已升级为 6 并加入 `hasValidPinnedTarget`；Host 使用 `validTargetURL != nil` 发布，`targetURLString` 改变会触发 snapshot 重发；Small/Medium/Large 已分别切换为“设置固定入口 / 添加 HTTPS 链接”；CoreVerify 同时断言默认 false 与显式 true。**源码层关闭。** 空、无效、有效链接的真实 Widget 刷新与点击仍保留在手工矩阵。

### P1-2 Large Text 原始源码缺口已关闭；最大字号保留为 Mandatory manual Gate

**最新源码证据**

- 已完成的缓解：Widget 读取 `dynamicTypeSize`；Small 关键字号改用 semantic style；Medium/Large 在 accessibility size 改为纵向布局，Large 限制只展示一个 quota bucket（`WorkPulseWidget.swift:600-947`）。
- Top 已新增 `usesAccessibilityTextLayout`。`onAppear/onChange(dynamicTypeSize)` 会立即触发当前 mode 重新定位；accessibility size 下 Resident 从 `320 × 58` 增至 `380 × 92`、Alert 从 `390 × 112` 增至 `460 × 150`、Expanded 从 `430 × (280 + rows × 42)` 增至 `520 × (360 + rows × 58)`（`NotchOverlayController.swift:169-173, 227-245, 380-407, 568-755`）。这关闭了“字号变化而 panel 完全不重算”的旧缺口。
- 控制中心也已读取 `dynamicTypeSize`，accessibility size 下 min/ideal/max width 提高到 `460/520/560`，并保留纵向 ScrollView（`WorkPulseMenuBarApp.swift:2504-2539`）。这显著降低了标题和五组设置的横向挤压风险。
- 仍存在两类**韧性风险**：全部 accessibility categories 共用一档 panel 常量；Top Expanded 标题/底部动作、控制中心 quota 数字与 gauge 仍有固定尺寸（`NotchOverlayController.swift:393-409, 657-699`；`WorkPulseMenuBarApp.swift:2631-2688`）。这值得作为 P2 继续用 semantic style、`@ScaledMetric` 或内容测量优化。
- Medium/Large 在系统固定 family 尺寸中仍依赖 `lineLimit` 与密度降级。源码可以证明“存在 reflow 合同”，不能证明最大档位下无裁切（`WorkPulseWidget.swift:721-947`）。
- 重新分级后，这些风险本身不足以证明核心 quota、固定入口或控制操作已经在 Large Text 下不可达。继续保留 P1 会把“缺少实机证据”误写成“已确认源码缺陷”。因此原始 P1 在源码层关闭，最大字号改为发布前必须完成的手工 Gate；若任一关键值或动作在实机矩阵中裁切/不可达，立即重新打开 P1。

**用户影响**

源码仍不能排除 truncation、reset 被截断、按钮挤压或 Expanded 超出 panel；固定小字号也可能弱化用户的阅读偏好。这里是待验证风险，不是本轮已经观察到的 GUI 失败。

**直接修法**

1. Top 保留现有两档尺寸作为基线，再按实际 `dynamicTypeSize` category 或 SwiftUI 内容测量计算高度；不要让全部 accessibility categories 共用一套常量。
2. Expanded 标题和动作改用 semantic style；Resident/Alert/Expanded 在空间不足时使用 `ViewThatFits` 精简次级信息，不能通过缩小关键字体“通过”。
3. 控制中心 quota 数字改用 semantic style 或 `@ScaledMetric`，在 accessibility size 将 gauge + reset/source HStack 改为纵向布局，而不只增加弹层宽度。
4. Medium/Large 在最大文字下用 `ViewThatFits`/layout priority 明确保留核心信息，不能只依赖 family 固定尺寸自行压缩。

**手工 Gate**：默认、Large、最大可用文字档位逐一验证 Small Quota、Small Pinned、Medium、Large、Resident、Alert、Expanded 和控制中心五组。关键 quota、reset、任务状态、固定入口、刷新/关闭动作必须无裁切且可到达；失败即重新打开 P1。固定字号、category-specific 尺寸和内容测量作为 P2 韧性改进，不以它们是否存在代替实机结果。

### P1-3 浅色无刘海 Top 浮层低对比：Closed in source

**初审源码证据（修复前）**

- 无物理刘海且主题为 Light 时，surface 为近白色，primary 为深色（`NotchOverlayController.swift:166-181`）。
- Expanded source 使用 `primaryTextColor.opacity(0.46)` 的 10pt 字体，行标签使用 `opacity(0.55)` 的 11pt 字体（`NotchOverlayController.swift:622-626, 678-689`）。
- 以源码 RGB 与 alpha 合成计算，对浅色 surface 的近似 contrast 分别只有 **2.94:1** 和 **3.84:1**；两者都不足以稳妥承载小号正文。
- 源码没有读取 `colorSchemeContrast`，Increase Contrast 不会主动提高这些自定义 alpha。

**用户影响**

外接无刘海显示器或没有刘海的 Mac 在 Light 模式下，Expanded 的来源和行标签可读性不足；Increase Contrast 用户也得不到预期增强。

**直接修法**

1. 优先改用系统 `.secondary`/`.tertiary` 语义色并实测；若必须自定义，Light 下行标签至少使用当前 primary 的约 `0.62` alpha、source 约 `0.68` alpha，再以实测对比度校准。
2. 读取 `@Environment(\.colorSchemeContrast)`，在 `.increased` 下同步增强文本、卡片边界、focus ring 与选中态。
3. 保留文字/图标/形状冗余，不能让 warning/critical/success 只靠颜色表达。

**最终 Delta**：正常 Light 的 source/row label alpha 已提高到 0.70/0.72，按同一源码颜色近似计算分别约 **6.26:1 / 6.71:1**；Increase Contrast 提高到 0.82/0.86，并同步增强外框。**源码层关闭。** no-notch 实际渲染、色彩管理与系统设置响应仍需手工测量。

### P1-4 VoiceOver 无法从 quota bucket 控件得知当前选中项：Closed in source

**初审源码证据（修复前）**

- quota bucket 行视觉上有 `selected` 和 checkmark（`WorkPulseMenuBarApp.swift:2673-2700`）。
- 该 Button 最后覆盖为自定义 `.accessibilityLabel(...)`，但没有 `.accessibilityValue("已选择/未选择")` 或 selected trait（`2701`）。
- 因为父级已覆盖 label，不能依赖内部 checkmark 图标稳定传达选择状态。

**用户影响**

多 quota window 是当前真实场景。VoiceOver 用户能听到每个 window 与剩余比例，却无法可靠确认 Resident/Widget 当前采用哪个 window。

**直接修法**

为 bucket Button 增加 `accessibilityValue(selected ? "已选择" : "未选择")`，在平台可用时增加 `.isSelected` trait，并在选择后提供简洁状态变化 announcement；不要把百分比、window、reset 从 label 中移除。

**最终 Delta**：bucket Button 已加入 `accessibilityValue(selected ? "已选择" : "未选择")` 与条件 `.isSelected` trait。**源码层关闭。** VoiceOver 的实际读序、announcement 和选择后跨表面刷新仍需手工验证。

### P1-5 Alert 缺少 Full Keyboard Access 倒计时保护：Closed in source

**初审源码证据（修复前）**

- Alert 在非 VoiceOver/Switch Control 环境中立即启动 6 秒倒计时（`NotchOverlayController.swift:221-244, 344-353`）。
- 鼠标 Hover 能暂停并恢复倒计时（`254-271`）。
- Expanded 有 `expandedKeyboardInteractionActive` 和 key monitor（`274-317, 372-419`），但 Alert 没有对应的 keyboard-focus 状态或 focus-enter 保护。

**用户影响**

只启用 Full Keyboard Access 的用户可能正在把焦点移向 Alert 或阅读其动作时，Alert 仍自动消失。这与“用户正在交互时不应自行缩回”的既定交互原则不一致。

**直接修法**

1. 为 Alert 增加独立 keyboard/focus interaction 状态；焦点进入或发生键盘导航时暂停倒计时，焦点离开后从剩余时间继续。
2. 不要让 Alert 抢走当前应用焦点；应允许用户从菜单栏入口/Resident 可靠进入 Expanded，并保留系统通知 fallback。
3. VoiceOver/Switch Control 仍保持无自动关闭；Esc/明确关闭恢复 Resident。

**最终 Delta**：Alert 已新增 `alertKeyboardInteractionActive`、FocusState 和统一 `updateAlertDismissalProtection()`；焦点进入会扣除已耗时并暂停，焦点离开从剩余时间继续。**源码层关闭。** 由于 Alert panel 仍以非激活方式展示，Full Keyboard Access 是否能在真实系统焦点链聚焦该按钮必须实测，不能由 `.focused` 的存在代替。

## 四个 Widget 的剩余手工矩阵

| Widget | 必测状态 | Light/Dark/System | stale/unavailable | Large Text | Increase Contrast | 交互与 AX |
|---|---|---|---|---|---|---|
| Small Quota | fresh 10/20/63/100%、有/无 reset、preview | 三主题各拍真实桌面图，确认主背景、数字、语义色 | 超过 `freshUntil` 后不能突出旧百分比；corrupt/unsupported 文案可恢复 | 默认、Large、最大档位，quota/freshness/reset 不裁切 | progress、warning/critical、source 均可辨；不能只靠颜色 | VoiceOver 合并顺序正确；点击只进入 usage/refresh 路径 |
| Small Pinned | empty/corrupt/unsupported/available-invalid/valid、长中英标题、Privacy On/Off | 三主题标题与动作清楚 | 无目标必须是 setup state；有目标不受 quota stale 误伤 | 两行标题、状态与动作均保留 | pin/箭头、选中/可用状态不靠色相 | VoiceOver 读“固定入口 + 标题/隐藏 + 动作”；前三类走 `routine/setup`，available-invalid 走受 Host 二次校验的 routine route，valid 才打开 HTTPS |
| Medium | fresh/stale quota × empty/valid pinned 的组合矩阵 | 两列在两主题和 System 切换后不混色 | 左区 stale、右区可用性必须各自独立 | accessibility size 改为可读布局，两个入口不重叠 | Divider、两个 action region、focus ring 可见 | 两个 Link 的 AX 名称与点击区域独立；误触率实测 |
| Large | 0/1/4 tasks、1/2 buckets、long title、Privacy | header、卡片、时间戳在两主题清晰 | quota 与 tasks 分别 stale；总体不能只用旧时间戳暗示实时 | cards 纵向增长，不裁切 task/status/source | 卡片边界、状态图标、selected/alert 均可辨 | 读序为 header→quota→tasks→pinned→source；非按钮卡片不应被读成可操作 |

额外要求：每次 Widget 主题或隐私设置改变后，先确认 Host 写入新 snapshot，再确认 WidgetKit timeline 实际刷新；不能用 Host 控制中心已经变化代替 Widget 变化证据。

## 控制中心五组手工矩阵

| 区域 | 键盘 | VoiceOver / Switch Control | Large Text / Contrast | 状态组合 |
|---|---|---|---|---|
| 概览 | Tab 顺序为刷新→quota bucket→固定入口→同步；focus ring 可见 | quota gauge、bucket selected、任务状态、固定入口与同步状态读序正确 | 最大文字可滚动到全部内容，quota/reset 不被 gauge 挤压 | live/refreshing/stale/unavailable；0/1/3 tasks；Widget sync success/error |
| 顶部显示 | 三个 Toggle 与阈值 Picker 都可用键盘操作 | 每个 Toggle 读 label、detail、on/off；阈值读“每周期最多一次” | segment 与长说明不裁切 | Resident/Alert/Notification 三开关 8 种组合；阈值 0/10/20/30 |
| 隐私 | Privacy On 后焦点仍按逻辑顺序移动，disabled 控件不造成陷阱 | `PulseToggleRow(children: .combine)` 必须实测仍保留 toggle action/value | disabled 不能只靠 0.48 opacity，说明文本仍可读 | Privacy On 强制禁用任务名/入口名；Off 后分别 opt-in |
| 外观与启动 | System/Light/Dark、五色、登录启动均可键盘选择 | 五个颜色按钮读名称与 selected；登录启动读真实状态 | Increase Contrast 下颜色圆、checkmark、focus ring 均可见 | System 跟随系统即时变化；物理刘海仍黑，无刘海浮层随主题 |
| 固定入口 | 两个 TextField 读序与错误恢复清楚 | placeholder、HTTPS hint、validation error 均可读 | 长 URL/标题不把错误或下一组挤出不可达区域 | empty、invalid scheme、无 host、valid HTTPS、清空后的 Widget 同步 |
| 系统通知 | Allow/Test 按钮与 receipt 可达 | authorized/denied/notDetermined、点击回流 receipt 读清楚 | success/denied 不只靠绿/灰 | 请求、系统拒绝、投递、点击回流分别验证，不互相冒充 |

## Top Resident / Alert / Expanded 手工矩阵

| Surface | 视觉状态 | Mouse | Full Keyboard Access | VoiceOver | Switch Control |
|---|---|---|---|---|---|
| Resident | fresh/stale/unavailable；1/2 buckets；0/1/4 tasks；notch/no-notch；Light/Dark | 点击展开，外接屏不抢内建刘海 | 可聚焦并 Enter/Space 展开；focus ring 清楚 | label 顺序为 window→remaining→reset→task count；Privacy 无名称 | 可扫描到 resident 并展开 |
| Alert | task complete/fail/cancel、quota threshold、notification return；generic privacy | Hover >12 秒不消失，移出后继续剩余倒计时 | 聚焦后 >12 秒不消失；Enter/Space 展开；Esc 恢复 | 开启前后触发均不自动消失；title/detail/action 可读 | 开启前后触发均不自动消失；动作可达 |
| Expanded | 1/2/4 buckets、0/1/4 tasks、Privacy On/Off、临时名称 10 秒、长 source | Hover 保持；移出 300ms 后收起；重入取消；点击外部关闭 | Tab 顺序：关闭→刷新→次要动作；连续按键会续期；停止键盘输入 15 秒后可退场；Esc 恢复 | 读序为标题→主 quota→reset→其他 bucket→task rows→source→actions；无抢焦点/截断；辅助技术开启时不受 15 秒退场影响 | 扫描顺序与动作相同；交互期间不收起；不受 15 秒退场影响 |

显示器矩阵至少覆盖：仅内建刘海、内建 + 外接（外接为主显示器）、仅无刘海设备/场景、外接断开与重连。三个 Surface 都必须遵守同一 placement 规则，不能只验证 Resident。

## 最终 UI/UX Gate

以下条件同时成立后，UI/UX 才可从 Conditional Go 升级为完整 Pass：

1. 初审 5 个 P1 的源码合同已全部关闭；其中 Large Text、Alert focus、Pinned recovery 和 Expanded keyboard release 都必须完成对应手工 Gate，不能把源码关闭写成产品 Pass。
2. Small Quota 与 Small Pinned 完成真实 Widget Gallery 搜索、添加、刷新和点击；empty/invalid/valid 固定入口均有当前 build 证据。
3. 四个 Widget 完成 Light/Dark/System、fresh/stale、Large Text、Increase Contrast 矩阵；Medium/Large 即使不首发，也不能以已注册但未验收的状态计入“全部完成”。
4. 控制中心五组完成真实窗口的 Tab、VoiceOver、Switch Control、Large Text 与 Increase Contrast 验收。
5. Resident/Alert/Expanded 完成 Full Keyboard Access、VoiceOver、Switch Control 以及 notch/no-notch Light/Dark 验收；Alert 必须证明键盘交互期间不会自行消失；Expanded 必须证明键盘保护可续期、会解除，且 VoiceOver/Switch Control 不被 15 秒任务误收回。
6. 所有 Privacy On 的可见文本与 AX label 中，任务名、入口名、路径和 prompt 暴露数均为 0。

在此之前，准确表述应为：**核心功能可 dogfood；5 个初审 P1 均已源码关闭，残余源码 P0/P1 为 0；Large Text、WidgetKit 点击回流、Full Keyboard Access、VoiceOver、Switch Control 与系统级 GUI 矩阵仍是未关闭的发布 Gate。**
