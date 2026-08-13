# WorkPulse V9 当前产品验收

日期：2026-08-12（Europe/Oslo）

## 结论

WorkPulse build 9 已达到可在本机测试菜单栏、顶部岛和通知的开发版状态，但完整产品仍未完成。真实 macOS Widget Gallery 交付仍被 Apple Team 签名阻塞；最新原生 UI 视觉与辅助功能验收仍被 Mac 锁屏阻塞。

产品形态保持为无独立 Dashboard 的本地伴生应用：菜单栏只承担设置和恢复入口；用户日常使用面是 Widget、顶部岛和系统通知。顶部岛是受系统约束的自绘 `NSPanel`，不是 Apple 提供给第三方 Mac 应用的原生 Dynamic Island。

## 已实现并由当前源码证明

- 四个 Widget Extension 类型：
  - Small：WorkPulse 额度
  - Small：WorkPulse 固定入口
  - Medium：WorkPulse 快速查看（额度 + 固定入口）
  - Large：WorkPulse 今日概览（运行任务数量 + 主要额度窗口 + 固定入口）
- Widget 不再发布虚构的 Daily Brief、Gmail、Scheduled 或未连接的 Needs You 状态。
- Gallery 预览使用明确的“示例 / 非实时”文案。
- Host 只向 Widget 发布 `liveCodexAppServer` 额度、脱敏任务数量和用户明确允许的固定入口标题。
- 顶部常驻优先显示具体运行任务名；无任务时显示额度窗口、剩余百分比和重置时间。
- 多任务展开最多显示四个任务；内部 subagent 不混入用户任务。
- 顶部岛优先选择内建有刘海显示屏；内建屏不可用时才退化到外接主屏顶部胶囊。
- 顶部内容从物理刘海 safe area 下缘开始，不把文字绘制到摄像头黑区。
- Resident、一次性 Alert、系统通知兜底和任务名显示分别由独立偏好控制。
- 低额度提醒是严格 threshold crossing，包含窗口身份、剩余额度和重置时间，并按额度周期去重。
- 过期额度不再以实时语气突出精确百分比。
- Expanded 支持 Esc、点击外部关闭，并使用可成为 key window 的 Panel 取得键盘焦点。
- build 9 的 ad-hoc Host 显式关闭 Widget App Group 写入，避免把无法访问的共享容器当成可用状态。

## 当前验证证据

- `WorkPulseCoreVerify`：226 checks passed。
- `WorkPulseWidgetCompile`：独立 compile + type-check passed。
- `verify_system_surfaces.sh`：passed。
- 本机真实 Codex App Server probe：`rateLimitBuckets=2; activeCodexTasks=1`，数值和名称未写入验收文档。
- 本机归档：`native/WorkPulseNative/build/WorkPulse-local-dev.zip`。
- 归档 SHA-256：`6cf3e06cc3a4d831b4d5c2fd7ed08e8efcea4ab8849e22f5d9c2eba78d2aaa4d`。
- 已安装宿主：`~/Applications/WorkPulse.app`，build 9。
- 宿主与 Widget `codesign --deep --strict`：passed。
- 当前签名：`Signature=adhoc`，`TeamIdentifier=not set`。
- 最近三分钟系统日志未出现新的 WorkPulse App Group 容器拒绝，说明无团队签名时的 Host 写入保护生效。

## 未通过的强门禁

### Widget Gallery

系统 `chronod` 在识别 build 9 Widget 后仍记录：

`Requested to add extension, but purging instead because we shouldn't cache it`

因此当前只能证明 `.appex` 结构和代码正确，不能声称 Widget 已进入系统组件库。完成条件：

1. 安装完整 Xcode。
2. 用户在 Xcode 登录 Apple Account，选择 Apple Development / Personal Team。
3. 使用同一 Team 为 Host 和 Widget 签名，并使用 Team-scoped App Group。
4. `scripts/build_full_product.sh`、`scripts/install_signed_product.sh` 和 `scripts/verify_widget_runtime.sh` 全部通过。
5. 在全新组件库会话中实际搜索、添加四种 Widget，验证真实数据、stale/empty、点击和刷新。

### 原生 UI / UX

Computer Use 返回：`The Mac is locked and automatic unlock could not unlock it.`

因此以下内容仍没有 build 9 运行态证据：

- 刘海上的具体任务名是否在三秒内可读。
- 内建屏 + 外接屏、clamshell、全屏、Space 切换的位置行为。
- 浅色 / 深色菜单、顶部岛和 Widget 的实际视觉效果。
- 键盘焦点、Esc、VoiceOver 朗读顺序和大字号。
- 通知授权、拒绝、Focus、无横幅和点击回流。

## 完成判定

当前状态：**Local development build / 未完成最终产品验收**。

只有 Apple Team 签名、Widget Gallery E2E 和解锁后的原生视觉/辅助功能矩阵全部通过后，才能把目标标记为完成。
