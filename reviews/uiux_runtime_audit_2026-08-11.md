# WorkPulse 开发状态与 UI/UX 运行审查

审查时间：2026-08-11 20:20 CEST  
范围：当前 Swift 源码、原生 macOS 应用、Web 桌面演示、签名归档、键盘与辅助功能基础检查。  
原则：只审查，不修改产品源码；演示数据在测试后已关闭。

## 结论

- **本机开发 Technical Preview：可继续 dogfood。** Swift 全量构建、CoreVerify 189 项、Widget 源码 typecheck、Web 18 项检查、Codex App Server 两个额度周期读取均通过。
- **面向普通用户的 UI/UX 内测：暂不放行。** 当前最明确的阻断问题是两个额度周期出现后，760×520 默认窗口内容超高，浅色和深色模式顶部标题均被裁切。
- **桌面 Widget、系统通知和刘海状态层：仍不是可安装、可端到端测试的原生功能。** 当前 ZIP 内没有 `.appex`，刘海层仍是禁用占位；Web 页面只能作为设计审查样机。

## 逐步审查

1. **构建与核心逻辑：健康**
   - SwiftPM 全目标构建通过。
   - `WorkPulseCoreVerify`：189 checks 通过。
   - Widget 源码独立 typecheck 通过。
   - Web 验证：18 checks 通过，浏览器控制台无 error/warning。
   - App Server probe 成功读取两个额度 bucket，未在报告中记录具体额度值。

2. **归档与安装边界：有条件健康**
   - `WorkPulse-local-dev.zip` SHA-256：`15fdcfbdc73c82d18d8ad1cd1ab2f8eab34a7f4f17b42e0831736d6a6ce8324c`。
   - ZIP 独立解包后 `codesign --deep --strict` 通过，arm64、ad-hoc、无 TeamIdentifier。
   - 工作区内 convenience `.app` 会被桌面文件提供器重新附加 Finder metadata，当前原地 strict verify 失败；它不是可分发证据。
   - ZIP 内无 `.appex`，因此 Widget 仍不是可安装扩展。

3. **原生概览与真实性表达：健康**
   - Manual、Privacy、模拟数据、Technical Preview 的边界表达清楚。
   - “尚未连接 Gmail 或任意 ChatGPT 对话实时接口”避免了能力夸大。
   - 浅色、深色、跟随系统三种外观选择存在；本轮验证了浅色和深色。

4. **额度读取后的响应式布局：失败，P0**
   - 无额度详情时，深色概览在默认窗口内布局正常。
   - 两个真实 bucket 加入右侧“数据来源”后，内容高度超过默认 760×520 窗口；根容器没有滚动或自适应高度策略，顶部 `WorkPulse` 标题被推入标题栏并裁切。
   - 浅色、深色均可复现，因此不是主题特例。
   - 建议：概览主体改为 `ScrollView` 或按内容提高窗口最小高度，并覆盖 0、1、2、3 个 bucket 的回归矩阵。

5. **固定对话入口与 URL 输入：基本可用，P1**
   - HTTPS 链接为空或无效时主按钮会禁用，避免误打开。
   - 但输入 `not-a-url` 后只保留“请先设置 HTTPS 链接”，没有指出格式错误；建议给出就地文案“请输入以 https:// 开头的有效链接”。

6. **Needs You 未连接态：语义不完全一致，P1**
   - 左栏正确显示“Needs You 尚未连接”。
   - 同时右栏显示“选择一条提醒”，但此时根本没有提醒可选；建议在无来源、空列表时让双栏共享同一空态，或将右栏改为“连接可信来源后可查看提醒详情”。

7. **Needs You 模拟事件与详情：可用于开发演示，P1**
   - 5 条 fixture 能进入 Inbox/Detail，明确标注“模拟事件 · 非实时数据”和“未连接真实来源”。
   - 详情把“已看”和“来源已解决”分开，并说明 WorkPulse 不会代替来源执行批准、提交或重试，交互真实性较好。
   - 默认高度下列表和详情均需要滚动，最下方动作区不在首屏；对于高优先级提醒，建议让主要状态与安全边界保持可见，并测试最小窗口下的动作可发现性。

8. **键盘与辅助功能：未达到放行证据，P1**
   - `Tab` 后焦点仍停留在窗口，未证明完整键盘遍历；该结果也受 macOS“全键盘控制”系统设置影响。
   - 在列表第一项上发送向下键后，详情未切换到下一项，运行态未证明 `.onMoveCommand` 可达。
   - 事件行源码设置了 `.accessibilityLabel`，但当前系统辅助功能树中的 `AXButton` 仍返回空 `name/title/accessibility description`。需要用 VoiceOver 实机复测，并确保每条事件行公开完整名称、状态和操作提示。

9. **Web 桌面演示：视觉概念可审查，不能视为原生实现**
   - 优点：持续显示“Design simulation · 非实时数据”，Manual、Scheduled 概念与真实能力边界清楚；浅色和深色主题一致。
   - 问题：组件正文与元数据字号偏小、暗色次级文字对比偏弱；中大型组件下半部留白过多，信息密度和视觉重心仍需调整。

## 优先级

### P0

1. 修复多 bucket 下默认窗口顶部裁切，并为浅色、深色分别截图回归。

### P1

1. 统一 Needs You 无来源时左右栏空态。
2. 补充 URL 就地校验文案。
3. 让事件行的 VoiceOver 名称在系统 AX tree 中可见，并完成 VoiceOver 实机走查。
4. 证明 Tab、方向键、Return、Escape 的完整键盘路径；若依赖“全键盘控制”，需在测试说明中明确。
5. 调整 Web 中小字号、暗色对比和中大型组件的留白。

### P2

1. 建立每次 UI 回归前强制退出旧进程并重新启动当前归档的检查项。本轮最初发现已有旧进程驻留，界面与当前源码不一致；相关截图已隔离到 `rejected-stale-process/`，未作为审查证据。

## 截图证据

1. `01-native-overview-dark-current.jpg`：当前深色概览，无多 bucket 时正常。
2. `02-native-overview-dark-live-quota-clipped.jpg`：深色、多 bucket，顶部裁切。
3. `03-native-overview-light-live-quota-clipped.jpg`：浅色、多 bucket，顶部裁切。
4. `04-native-needs-you-unavailable-light.jpg`：Needs You 未连接态。
5. `05-native-needs-you-fixture-light.jpg`：5 条模拟事件与详情。
6. `06-web-alert-dark.jpg`：Web 深色提醒态。
7. `07-web-manual-light.jpg`：Web 浅色 Manual 固定入口。
8. `08-web-daily-brief-dark.jpg`：Web 深色 Daily Brief。

截图目录：`output/uiux-audit-2026-08-11/`

## 放行判断

| 范围 | 判断 | 条件 |
|---|---|---|
| 本机开发 dogfood | Go | 仅视为 Technical Preview |
| 原生 Menu Bar + Dashboard 内部 UI 测试 | Conditional Go | 先修复默认窗口裁切 |
| 面向普通用户的 UI/UX 内测 | No-Go | P0 修复并补齐键盘、VoiceOver 运行证据 |
| Widget | No-Go | 需要真实 Xcode extension、App Group、签名与端到端截图 |
| 系统通知 | No-Go | 尚无原生端到端实现证据 |
| 刘海状态层 | No-Go | 当前仍为禁用占位 |
