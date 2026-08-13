# WorkPulse 双主题桌面 Demo · Design QA

- implementation: `<local-project>/workpulse_mac_desktop_demo.html`
- light source visual truth: `<local-project>/output/design-qa/reference-theme-light.png`
- dark source visual truth: `<local-project>/output/design-qa/reference-theme-dark.png`
- light implementation screenshot: `<local-project>/output/design-qa/implementation-theme-light.png`
- dark implementation screenshot: `<local-project>/output/design-qa/implementation-theme-dark.png`
- light full-view comparison: `<local-project>/output/design-qa/comparison-theme-light.png`
- dark full-view comparison: `<local-project>/output/design-qa/comparison-theme-dark.png`
- light focused comparison: `<local-project>/output/design-qa/comparison-theme-light-widget-focus.png`
- dark focused comparison: `<local-project>/output/design-qa/comparison-theme-dark-widget-focus.png`
- responsive evidence: `<local-project>/output/design-qa/implementation-responsive-1280x720.png`
- viewport: 1440 × 900 CSS px
- source pixels: 1586 × 992, normalized to 1440 × 900 for comparison
- implementation pixels: 1440 × 900 at DPR 1
- responsive viewport: 1280 × 720, 1440 × 900 desktop stage uniformly scaled to 0.8
- state: 固定对话，Privacy Mode 关闭，场景说明关闭，控制面板收起

## Comparison history

### Pass 1

Earlier findings:

- [P2] 浅色主题继承了页面根级白色文字，导致固定对话标题和时间在白色卡片上对比度不足。
- [P2] `private-generic` 与标题样式发生优先级冲突，正常模式同时显示“每日 Gmail 审查”和“每日例程”。
- [P2] 深色桌面的文件图标位于组件后方，破坏主组件的干净边界。
- [P2] 演示控制面板默认展开，首屏视觉重心与选定参考稿不一致。

Fixes made:

- 在浅色主题容器上明确设置 `color: var(--ink)`，让标题、时间和按钮继承正确的深色前景。
- 为固定对话标题增加专用隐私态选择器，正常模式只显示真实标题，Privacy Mode 只显示通用标题。
- 两种主题均隐藏与核心场景无关的桌面文件图标。
- 控制面板与场景说明改为默认收起，保留左下角“演示控制”入口。
- 将固定对话组件上移到与参考稿一致的顶部安全区。

Post-fix visual evidence:

- 两个主题都在相同 1440 × 900 视口重新截图，并分别与选定参考稿生成同图比较。
- 固定对话区域另生成近景比较，标题、三列指标、主操作和次级状态卡均清晰可读。
- 1280 × 720 缩放截图未出现裁切、重叠或不可操作控件。

### Pass 2

No actionable P0, P1 or P2 differences remained.

## Required fidelity surfaces

- Fonts and typography: 使用 macOS 系统字体栈。中文标题、数字指标与次级标签形成明确层级；浅色和深色下均无错误换行或截断。
- Spacing and layout rhythm: 两种主题保持同一 460 px 组件宽度、三列指标网格、统一圆角与 16 px 组件间距。浅色参考稿原本略窄，统一宽度属于跨主题一致性的产品约束。
- Colors and visual tokens: 浅色采用 pearl、mist blue、mint；深色采用 graphite、midnight navy、mint 和 amber。注意状态只用 amber，主操作只用 mint。
- Image quality and asset fidelity: 两张主题壁纸均为项目本地 1586 × 992 raster asset，以 `cover` 方式呈现，无 UI 残留、文字、水印或拉伸。界面图标统一使用 Phosphor Icons。
- Copy and content: 固定对话展示“上次审查”“需要处理”“下次审查”和“打开对话”，语义完整；Privacy Mode 有通用文案替代。
- Icons: 邮件、对话、主题、Dock 和状态图标采用同一图标库，线宽与基线一致。
- States and interactions: 浅色、深色、跟随系统、固定对话、场景选择、控制面板收起/展开、Privacy Mode 与主操作均可交互。
- Accessibility: 主题选择使用 `radiogroup`/`radio`，Privacy Mode 使用 `switch`，所有按钮具备可访问名称；键盘焦点环和 `prefers-reduced-motion` 已保留。

## Interaction and browser checks

- 浅色、深色、跟随系统切换：passed。
- 主题写入 `localStorage` 并在刷新后保持：passed。
- 固定对话场景保持可见：passed。
- “打开对话”触发正确反馈：passed。
- 控制面板收起和重新打开：passed。
- 1280 × 720 等比缩放：passed。
- 浏览器 console warnings/errors：none。

## Findings

No actionable P0, P1 or P2 findings.

## Follow-up polish

- [P3] 浅色参考稿的次级配额卡使用圆环，当前实现改为状态点和百分比，以保证浅色、深色信息结构一致。
- [P3] 参考稿使用彩色 macOS 应用图标，当前 Web Demo 使用统一线性图标；原生实现应替换为 SF Symbols 与真实应用图标资源。
- [P3] 左下角“演示控制”入口是审查工具专用，不会进入正式伴侣应用。

## Final result

final result: passed
