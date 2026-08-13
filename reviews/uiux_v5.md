# WorkPulse UI/UX 第五轮审查

> 日期：2026-08-11  
> 审查范围：`native/WorkPulseNative` 与 `workpulse_mac_desktop_demo.html`  
> 角色：macOS UI/UX 设计师  
> 边界：只读审查；本文件不修改原生代码、Web Demo 或 PRD

## 1. 审查结论

原生 MVP 已完成三个重要进步：

1. Light / Dark / System 使用 SwiftUI 原生外观，并在主窗口、菜单栏和 Settings 之间保持同一设置。
2. 标题显示至少具备 `Privacy Mode` 与用户授权的双重判断，Widget snapshot 默认生成 generic title。
3. Core 已开始区分 `manualPin`、`verifiedAdapter` 和 `unavailable`，并加入 WorkPulse deep-link route。

但当前界面尚未真正消费这些能力状态。原生壳中的 routine 默认是 `manualPin`，却同时显示 `Scheduled`、上次完成时间、3 封邮件、下次审查和绿色健康状态；CTA 在没有目标 URL 时仍显示为主要“打开”按钮。结果是：底层数据模型比界面诚实，但用户看到的仍像一个已经验证连接的 Gmail 自动化。

本轮结论：**原生结构可继续，P0 体验尚未通过。先完成能力门控、隐私 presentation 和点击路径，再进入 Overlay / Notification 扩展。**

## 2. Web 与 Native 一致性概览

| 维度 | Web Demo | Native 当前实现 | 结论 |
|---|---|---|---|
| 双主题 | 自定义 graphite / pearl token | SwiftUI 系统色与 `preferredColorScheme` | 结构一致，色彩语言尚未统一 |
| 固定例程 | 默认显示 Gmail + Scheduled 自动状态 | 默认仍显示 Gmail + Scheduled，但 Dashboard 标注 Demo | 两端都需要能力门控 |
| Privacy | 主要替换标题 | `visibleRoutineTitle` 只替换标题 | 两端都未完整泛化图标、单位、指标和反馈 |
| 标题授权 | Web 为全局 Privacy 切换 | Native 增加 `allowRoutineTitle` | Native 方向正确，但授权作用域不清 |
| 手动固定 | Web 看起来像已连接 | Core 已有 `manualPin` | Native UI 尚未使用 capability |
| 点击路径 | Web toast 模拟 | Native 调用 `NSWorkspace.open`，但目标为 nil | Native 更接近真实，仍需 setup / failure 状态 |
| Widget | Web 展示 Quota、Now & Next、Brief | Native 只有 Pinned Routine Small / Medium scaffold | 不能称为 P0 Widget 已实现 |
| 无障碍 | 有 focus ring，但大量自定义语义缺口 | 系统控件较好，仍缺组合标签和状态语义 | Native 基础更好，需补 QA |

## 3. P0 修订清单

### P0-01：让 `RoutineCapability` 真正控制界面

Core 已有：

- `manualPin`
- `verifiedAdapter`
- `unavailable`

但默认 routine 未显式传 capability，因此落入 `manualPin`；与此同时它的 `state` 是 `needsReview`，菜单栏副标题写“固定对话 · Scheduled”，并展示自动 last / next / attention 数据。这是当前最大矛盾。

界面门控规则应为：

| Capability | 标题标签 | 可显示内容 | 主操作 |
|---|---|---|---|
| `manualPin` | `固定对话 · 手动` | 用户输入名称、用户输入提醒、目标地址是否已设置 | 打开已保存目标；无目标时“设置对话链接” |
| `verifiedAdapter` | `已连接 · {来源}` | 来源证明的 last run、next run、attention、run state、freshness | 打开来源上下文 |
| `unavailable` | `连接不可用` | 最后可信值、断开时间、诊断说明 | 检查连接 |

限制：

- `manualPin` 不得组合 `needsReview`、`completed`、`failed` 等自动状态，除非这些值明确是用户手动录入并标记 Manual。
- `Scheduled` 只在 capability 明确包含 scheduled health 时出现。
- 橙色 Needs You 和绿色健康点只能来自 verified data；Demo 或 Manual 使用中性灰和“演示 / 手动”标签。
- Dashboard、MenuBar、Widget 必须使用同一个 `RoutinePresentation`，不能各自重新推断能力。

### P0-02：Privacy Mode 必须改变整个 presentation，而不是只换标题

当前 `visibleRoutineTitle` 的双重判断是正确基础，但其余内容仍暴露 Gmail 语义：

- envelope 图标。
- “上次审查 / 下次审查”。
- “3 封邮件”。
- Settings 中包含真实标题的 Toggle 文案。
- Demo source 与 feedback 可能继续暴露来源。

建议定义每个 surface 的 presentation：

```text
title
icon
statusLabel
attentionUnit
sourceLabel
primaryActionLabel
accessibilitySummary
```

Privacy Mode 下至少变为：

- 标题：`每日例程`。
- 图标：`clock.arrow.circlepath` 或通用 task icon，不使用 envelope。
- 指标：`3 项待处理`，不写“封邮件”。
- 时间标签：`上次运行 / 下次运行`，不写“审查”。
- source：`来源已隐藏`。
- CTA：`打开例程`。

设置中的 `允许显示“每日 Gmail 审查”` 本身会泄露标题，应改为 `允许在应用内显示例程名称`。真实名称仅放在进入 Pinned 编辑页后的受控字段中。

### P0-03：锁定外部表面的标题授权范围

`SnapshotFactory.makeWidgetSnapshot` 默认 generic 是正确的，但仍允许 `allowSensitiveTitle: true`，验证程序也把敏感 Widget title 视为合法路径。与此同时 Dashboard 文案称“Widget 与系统通知正式版仍默认使用通用标题”。

必须明确一个产品决策：

- **推荐 P0**：Widget 与 Notification 永远 generic；`allowRoutineTitle` 只影响主应用、MenuBar popover 和 Overlay。
- 如未来允许桌面显示标题，必须增加独立的 surface-specific 授权，不能复用应用内开关。

建议的授权模型：

```text
showTitleInApp
showTitleInMenuBarPreview
showTitleInOverlay
showTitleInWidget = false  // P0 locked
showTitleInNotification = false  // P0 locked
```

验收时检查序列化后的 Widget snapshot 与 pending notification content，而不是只截图。

### P0-04：修复没有目标地址时的主操作

默认 `targetURLString` 为 nil，但 MenuBar 和 Dashboard 都显示高强调“打开对话 / 打开目标”。用户点击后才看到错误反馈。

正确状态：

- 无目标：主按钮改为 `设置对话链接`，进入 Pinned 编辑页。
- URL 语法无效：按钮禁用，旁边显示原因。
- URL 有效但未验证：按钮写 `测试并打开`。
- URL 已验证：按钮写 `打开对话`。
- `NSWorkspace.shared.open` 返回失败：不改变 acknowledgement，显示可恢复错误并提供复制链接。

反馈不能永久占据 MenuBar popover。错误应内联在按钮下方，并在用户修正或关闭 popover 后清除。

### P0-05：将 DeepLinkRouter 接入真实点击路径

Core 已支持：

- `workpulse://inbox`
- `workpulse://usage`
- `workpulse://routine/{id}`

但 Widget 尚无 `.widgetURL` / `Link`，MenuBar 的 routine 也不经过 route。P0 应建立一套一致规则：

- Pinned Routine Widget：`workpulse://routine/{id}`。
- Small Quota：`workpulse://usage`。
- Needs You：已验证 target 直接打开来源；否则 `workpulse://inbox`。
- 打开失败不自动 marked seen。
- URL 打开后必须定位到对应 scene，而不是只激活应用窗口。

### P0-06：原生 Widget 不能替代 PRD 定义的 Small / Medium

当前 Widget extension 只有 `WorkPulsePinnedRoutineWidget`：

- Small 显示“几项需要处理”。
- Medium 显示 Needs You + 下次审查。

它是 Pinned Routine 组件，不是 PRD 的：

- Small Quota Pulse。
- Medium Now & Next。

应明确命名和范围：

1. 保留 `Pinned Routine Medium`，作为额外 Widget 或 P1。
2. 新增 `Quota Small`，读取 quota snapshot。
3. 新增 `Now & Next Medium`，Current 与 Next 分别有 open target。
4. Widget Gallery 中不要把 Pinned Routine Small 宣传为 Quota Small。

另外，当前 provider 的 placeholder 同时被 `getSnapshot` 和 `getTimeline` 当真实数据使用，安装后会长期显示“3 项、Cached”。正式 build 必须读取 App Group snapshot，并具有：Loading、Empty、Manual、Verified、Stale、Offline、Unsupported。

### P0-07：本地化 freshness、source 和 quota 文案

当前 MenuBar 会显示：

- `Fresh` / `Stale` 英文枚举。
- `Demo snapshot`。
- `今日配额`。

实施要求：

- `fresh → 已更新`
- `cached → 缓存 · {时间}`
- `stale → 状态可能已过期`
- `offline → 离线`
- `unsupported → 当前来源不支持`
- `Demo snapshot → 演示数据`
- `今日配额 → Codex 5 小时窗口`，窗口长度来自 `windowDurationMinutes`

没有 quota 时不能回退为 0%。显示 `额度不可用` 与来源原因。

### P0-08：修正演示时间逻辑

默认 last run 固定为“今天 08:00”，next run 固定为“今天 16:00”。当系统时间早于 08:00 时，“上次审查 08:00”位于未来；当系统时间晚于 16:00 时，“下次审查 16:00”位于过去。

演示种子必须相对当前时间构造：

- last run 永远早于 `now`。
- next run 永远晚于 `now`。
- day detail 根据日期动态显示“今天 / 明天 / 昨天”。
- Manual capability 没有可信运行记录时显示 `未同步`，不制造时间。

### P0-09：标题与图标必须同时服从 capability 和 privacy

当前 envelope 图标无论 Manual、Verified、Privacy 都保持相同，会暗示已连接 Gmail。

推荐图标映射：

| 状态 | SF Symbol | 文本标签 |
|---|---|---|
| Manual pin | `link` | 手动固定 |
| Verified scheduled routine | `clock.arrow.circlepath` | 已连接 |
| Verified Gmail routine + title approved | `envelope` | Gmail 已连接 |
| Needs review | `exclamationmark.circle` | 需要处理 |
| Stale | `clock.badge.exclamationmark` | 状态可能已过期 |
| Disconnected | `bolt.slash` | 连接已中断 |
| Privacy | `lock.fill` 或通用例程图标 | 标题已隐藏 |

菜单栏应用图标 `waveform.path.ecg` 容易被理解为健康监测。P0 至少保证其有稳定的 `WorkPulse` accessibility label；P1 再建立独立品牌 symbol。

### P0-10：补齐 Native 的辅助功能语义

SwiftUI 原生控件提供了良好基础，但以下仍需显式处理：

- Header envelope 是装饰图标时使用 `.accessibilityHidden(true)`，避免重复朗读。
- 橙色状态点与绿色状态点不能只有颜色，添加 `accessibilityLabel` 或同时显示文字。
- 每个三层 metric 组合为一个 VoiceOver 元素，例如“需要处理，3 项”。
- icon-only SettingsLink 明确标注“设置”。
- Dashboard 的太阳 / 月亮 / 系统图标 Picker 为每项提供文本或 accessibility label。
- Privacy 导致 title permission Toggle disabled 时，增加说明“关闭 Privacy Mode 后可更改”。
- MenuBar CTA、Settings icon 和 Widget link 的 hit area 不小于 44pt。
- 不以 `.green` / `.orange` 作为唯一状态表达；支持 Differentiate Without Color。

### P0-11：Dashboard 与 MenuBar 对 capability 的描述必须一致

Dashboard 已写“Pinned Routine · 演示状态源”和“尚未连接 Gmail”，而 MenuBar 同时写“Scheduled”“已完成”“3 封邮件”。用户会更信任系统级菜单栏，因此这不是轻微 copy 问题。

同一 presentation 必须在所有表面一致：

- Manual：所有表面都写 Manual。
- Demo：所有表面都显式写演示数据，不使用健康色。
- Verified：所有表面显示来源和 freshness。
- Offline：所有表面保留最后值并标记离线。

## 4. P1 修订清单

### P1-01：建立与 Web 视觉真值一致的 Native semantic tokens

Native 当前大量使用系统 `.green`、`.orange`，在 Light / Dark 下可用性较好，但与 Web 的 mint / graphite 视觉语言不完全一致。

建议建立 Asset Catalog 动态颜色：

- `AccentActionBackground`
- `AccentActionForeground`
- `StatusHealthy`
- `StatusAttention`
- `StatusCritical`
- `SurfaceRaised`
- `TextTertiary`

仍优先使用系统 material、secondary label 和控件样式，不用硬编码 Web hex 复制半透明效果。

### P1-02：建立 verified connection detail

Pinned 编辑页增加：

- capability。
- source 名称。
- last verified。
- supported fields。
- target quality。
- test connection。
- remove connection。

不要只给一个绿色“已连接”。用户应能理解为什么某些 routine 有 last run，而另一些只有手动链接。

### P1-03：增加可访问的 MenuBar 状态信息

MenuBar status item 后续应表达：

- Needs You 数量。
- Privacy 已开启。
- Monitoring lost。
- Idle。

默认视觉保持 compact；VoiceOver label 读出完整摘要，例如：

`WorkPulse，1 项需要处理，Privacy Mode 已开启。`

### P1-04：视觉回归矩阵

原生版本至少生成以下证据：

- Light / Dark / System。
- Privacy on / off。
- Manual / Verified / Stale / Offline。
- URL missing / valid / open failed。
- Small Quota / Medium Now & Next / Pinned Routine。
- 100%、130% 字号与 Increase Contrast。

Web 截图只能作为方向参考，不能替代 Native 真机渲染验收。

### P1-05：Overlay 和 Notification 实现后复用同一 Presentation

不要在 Overlay 与 Notification 中重新拼文案。它们必须使用 Core 输出的 surface-specific presentation，才能保证：

- Notification 永远 generic。
- Overlay title 默认 generic。
- Privacy 切换时一秒内同步。
- Manual 数据不伪装成 Live。
- CTA 与 target quality 一致。

## 5. 可验证验收标准

- **AC-UIV5-01**：`manualPin` routine 在 MenuBar、Dashboard、Widget 中均不显示 Scheduled、自动完成、邮件数量或来源健康状态。
- **AC-UIV5-02**：只有 `verifiedAdapter` 且 capability 支持对应字段时，才显示 last run、next run、attention 和 freshness。
- **AC-UIV5-03**：Privacy Mode 开启后，标题、图标、邮件单位、source、CTA 和 accessibility label 均泛化。
- **AC-UIV5-04**：Widget snapshot 与 Notification content 中敏感标题数量始终为 0；应用内标题授权不能改变该结果。
- **AC-UIV5-05**：targetURL 缺失时，所有“打开”按钮改为“设置链接”；不存在先点击再报错的主路径。
- **AC-UIV5-06**：有效 target 成功打开后才记录 acknowledgement；`NSWorkspace.open` 失败时事件状态不变。
- **AC-UIV5-07**：Pinned Routine Widget、Quota Widget 和 Now & Next Widget 使用不同 kind、不同信息结构和正确 deep link。
- **AC-UIV5-08**：Widget timeline 不以 placeholder 作为正式数据；无 snapshot 时显示 Empty，而不是固定的 3 项 Cached。
- **AC-UIV5-09**：所有 freshness 与 source label 完整本地化，不在用户界面出现 `Fresh`、`Cached`、`Demo snapshot` 等内部字符串。
- **AC-UIV5-10**：任意系统时间运行 Demo 时，lastRunAt < now < nextRunAt；相对日期文案正确。
- **AC-UIV5-11**：Manual、Verified、Stale、Disconnected 和 Privacy 状态各自具有图标与文字，非颜色单独表达。
- **AC-UIV5-12**：VoiceOver 将每个 metric 读为一个完整短句，装饰图标不重复播报，icon-only 设置入口读作“设置”。
- **AC-UIV5-13**：Light、Dark 和 System 切换后，主窗口、MenuBar、Settings 与 Widget 使用相同主题；重启后偏好保持。
- **AC-UIV5-14**：130% 字号下 MenuBar 三列指标不重叠；空间不足时改为纵向或隐藏低优先级 detail，不缩小字体。
- **AC-UIV5-15**：Dashboard 与 MenuBar 对同一 routine 的 capability、source、freshness 和 privacy 文案完全一致。

## 6. 最终建议

### 可以保留

- `ThemePreference` 与 SwiftUI `preferredColorScheme`。
- `PrivacyClass` + 用户标题授权的双重判断。
- `RoutineCapability` 的方向。
- generic snapshot 默认值。
- `WorkPulseRoute` / `DeepLinkRouter`。
- 系统字体、系统控件、SF Symbols 与相对克制的原生布局。

### P0 必须返修

- capability 与 run state 的门控。
- 完整 Privacy presentation。
- 无 URL 时的 CTA。
- Widget kind 与真实数据路径。
- deep link 接入。
- freshness / source 本地化。
- 演示时间逻辑。
- 图标状态语义。
- VoiceOver 组合和 action label。
- Dashboard 与 MenuBar 的一致性。

### P1 再完善

- Native semantic color tokens。
- verified connection 详情。
- MenuBar compact 状态编码。
- 原生视觉回归矩阵。
- Overlay / Notification 的统一 presentation。

在 `AC-UIV5-01` 至 `AC-UIV5-15` 通过前，不建议把 Native MVP 描述为“固定 Gmail 例程已连接”或“P0 Widget 已实现”；准确表述应是“原生菜单栏壳、主题、隐私模型和 Widget scaffold 已建立”。
