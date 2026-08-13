# WorkPulse：Mac AI 工作状态层调研与设计建议

更新日期：2026-08-10

## 核心结论

这个产品最有价值的方向，不是继续堆叠音乐、天气、剪贴板和文件架，而是把分散在 ChatGPT、Work、Codex 和 Scheduled 中的工作状态整理为一个统一的 **AI work continuity layer**：

- 桌面组件回答“今天整体怎么样”；
- 刘海或菜单栏回答“此刻发生什么”；
- 完整应用负责配置、历史、来源和故障处理。

## 平台边界

1. Apple 的原生 **Live Activities** 现在可以显示在 Mac 菜单栏，但官方说明是活动从 iPhone 或 iPad 发起，并自动出现在配对 Mac 上。点击会进入 iPhone Mirroring。Mac-only 第一版不应把它当作必要依赖。
2. Mac-only 第一版可以用自定义顶部面板模拟刘海交互，同时提供 `MenuBarExtra` 作为无刘海和外接显示器的稳定入口。
3. macOS 原生 WidgetKit 支持 small、medium、large 和 extra large。各尺寸必须改变信息层级，而不是简单放大。
4. WidgetKit 不适合秒级刷新。额度倒计时可以显示基于已知 reset 时间的本地倒计时，但远端数据刷新仍应遵守系统节奏；真正需要持续更新的状态放在菜单栏或应用进程中。

## 竞品观察

| 产品 | 已验证价值 | 对本产品的启示 |
|---|---|---|
| [Limit Bar](https://limitbar.artsvit.com/) | Codex、Claude Code 额度、reset、本地优先 | 额度必须一眼可读，并标出数据来源 |
| [CodexUsageBar](https://codexusagebar.com/) | 菜单栏百分比、阈值提醒、服务状态 | 异常和低额度提醒比完整报表更重要 |
| [CodexBar](https://gordonbeeming.com/projects/codex-bar) | 通过本地 Codex App Server 读取 rate limits | OpenAI 当前官方 App Server 文档已公开 `account/rateLimits/read` 和 usage 能力，可作为 Codex 额度的正式适配路径 |
| [Boring Notch](https://github.com/TheBoredTeam/boring.notch) | 音乐、日历、文件架、HUD，开源 | 刘海的 hover/expand 心智已被用户理解 |
| [DynamicLake](https://www.dynamiclake.com/) | Dynamic Island 式动效、计时器、外接屏 | 必须同时处理有刘海与无刘海显示器 |
| [NotchThings](https://apps.apple.com/us/app/notchthings-notch-tools/id6762610441?mt=12) | 可配置组件、系统指标、AI usage tracking | 是最近的直接竞品，说明“万能工具箱”赛道已拥挤 |

## 建议的信息架构

### 桌面组件

- Small：一个核心值，例如当前窗口余量和 reset。
- Medium：余量 + 三个活动/收藏项目。
- Large：Daily Brief，三个优先事项和下一次计划。
- Extra Large：Daily Brief + 项目状态 + Scheduled + 额度的完整工作台。

### 刘海的两种自动形态与一层手动交互

- Resident / 常驻紧凑态：固定在刘海位置，只显示一个核心状态，例如任务运行时间、待处理数量或额度余量。
- Alert / 提醒弹出态：新消息、完成、失败、等待输入或额度预警发生时，从常驻态向下短暂展开；用户不处理时收回，并在常驻态保留未读标记。
- Expanded / 手动展开态：用户点击或悬停后主动打开的完整控制面板。它不是第三种通知，而是查看详情与操作的交互层。

### 内容状态

- Quiet：没有需要处理的状态时保持最小，或完全隐藏。
- Running：任务名、运行时长、预计完成时间。
- Action required：只显示一个明确的问题和一个主操作。
- Low headroom：剩余余量、reset 倒计时、是否适合开启新任务。
- Completed：结果入口短暂保留，随后自动收起。
- Failed：错误摘要和“打开详情”，不在刘海中堆叠日志。

### 菜单栏

- 无刘海或外接显示器的主入口；
- 展示简化额度和等待处理数量；
- 打开后提供暂停、继续、打开任务、隐私显示和刷新；
- 不依赖桌面组件是否被用户添加。

## 推荐开发路线

### MVP：Mac-only

- SwiftUI 主应用；
- WidgetKit 四种尺寸；
- `MenuBarExtra`；
- 自定义刘海面板；
- App Group 共享快照；
- 本地收藏项目、Daily Brief 和 Scheduled 适配；
- Codex App Server usage 适配器；
- 其他不稳定来源统一标记为 Experimental 或 Estimated。

### 第二阶段：iPhone companion

只有当用户确实需要 Apple 原生跨设备 **Live Activities** 时再增加 iPhone target，并通过 ActivityKit 将短期运行任务同步到 Mac 菜单栏。这样不会让第一版被 iPhone 开发、签名、APNs 和跨设备状态同步拖慢。

## 关键产品约束

- 不在顶部表面显示提示词、文件名或敏感研究标题，除非用户主动开启；
- 同时只突出一个需要行动的状态；
- 不把静态收藏项目伪装成实时运行；
- 区分 official、local adapter、estimated 三种数据来源；
- 完成态有明确自动消失时间；
- 外接显示器必须有可用退化方案。
- 当前额度数据只代表 Codex App Server 暴露的具体窗口，不代表 ChatGPT 所有模型和工具的统一额度。

## 官方参考

- [Apple Live Activities HIG](https://developer.apple.com/design/human-interface-guidelines/live-activities)
- [Apple ActivityKit](https://developer.apple.com/documentation/activitykit)
- [Apple Widget families](https://developer.apple.com/documentation/widgetkit/widgetfamily/)
- [Apple Widgets HIG](https://developer.apple.com/design/human-interface-guidelines/widgets)
- [OpenAI ChatGPT and Codex use cases](https://learn.chatgpt.com/use-cases?category=automation&category=front-end&category=macos)
