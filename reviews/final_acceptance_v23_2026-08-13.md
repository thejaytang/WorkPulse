# WorkPulse build 23 最终本机验收

> 冻结时间：2026-08-13 07:43 CEST  
> 版本：0.3.1 (23)  
> 结论：本机 dogfood **Go**；解锁后的常规 GUI/AX 验收已完成，个人版完整验收仍保留系统通知点击、Widget Gallery 与辅助功能三项手工 Gate；对外买断 **No-Go**

## 冻结产物

- 归档：`native/WorkPulseNative/build/full-product/WorkPulse-full-product.zip`
- SHA-256：`41fafea9e4e6c069b90a18a5190d29a81e5709b3342a7830fd2ffe38629635aa`
- 安装：`~/Applications/WorkPulse.app`
- Apple Development Team：`<APPLE_TEAM_ID>`
- Host/Widget：build 23，Universal Binary，同 TeamIdentifier/App Group，严格签名、同源和 Widget runtime Pass。

## 已验证

- SwiftPM 无警告编译、260 CoreVerify、Widget typecheck、system surface verifier、Xcode Release build：Pass。
- 控制中心一级设置已从七组收敛为五组；低额度提醒并入顶部显示，删除无操作价值的商业化宣传卡。
- 仓库只保留一个正式 `WorkPulse.xcodeproj`；旧 build 19 重复工程已移至可恢复的 `/tmp/WorkPulse-obsolete-build19.xcodeproj`。
- 通知与任务名隐私、启动缓存清洗、旧通知迁移 callback 顺序、安装自动回滚、自适应轮询、键盘/VoiceOver/Switch Control 交互保护：source closed。

## 真实任务通知待点击证据

build 23 增加仅能由明确环境变量启动的隔离 QA 通道。它不保存任务名，并使用与生产任务终态相同的 Notification category 与 deep link。

macOS 已实际 delivered：

- request ID：`workpulse.task-terminal.qa.45269BAE-9E2C-48BD-B731-EFE8A02F4B38`
- authorizationStatus = 2
- alertSetting = 2
- notificationCenterSetting = 2
- soundSetting = 2

当前尚无 `lastNotificationOpenAt`/receipt，证明没有把“已投递”冒充为“已点击回流”。

## 2026-08-13 解锁后新增实机证据

- 当前源码、ZIP 和已安装包同源；ZIP SHA-256 为 `41fafea9e4e6c069b90a18a5190d29a81e5709b3342a7830fd2ffe38629635aa`。
- 已安装 Host 为 0.3.1 (23)，Apple Development 签名链、TeamIdentifier `<APPLE_TEAM_ID>`、App Group `<APPLE_TEAM_ID>.com.workpulse.shared` 与严格验签通过。
- `verify_system_surfaces.sh`、Widget typecheck 与 260 项 CoreVerify 再次通过。
- 安装器使用当前 `codesign --entitlements -` 接口验证 Host/Widget App Group，并用干净登录环境启动宿主，避免继承 Codex/CI/QA 变量；最终快照实测包含 2 个 live quota bucket 与 2 个运行任务。
- 重装期间每 250ms 连续采样 15 秒，`quotaBuckets` 始终为 2；旧 live snapshot 会保持到新 App Server 读取完成，再从 revision 22 原位更新到 revision 23，启动空额度 race 已关闭。
- App Group 已实测生成 schema 6 快照；损坏快照会保留诊断副本后自愈。Widget 明确区分有效/未设置固定入口，并为 Large Text、Increase Contrast、VoiceOver 选中态和 Full Keyboard Access Alert 交互增加源码保护。
- Resident 在物理刘海下缘稳定显示 `7 天 · 63% 剩余 / 周四 05:34 重置 / ● 2`；运行任务未抢占额度主信息。
- Expanded 同时显示全部额度窗口与 2 个运行任务；Privacy Mode 开启时任务按 A/B 匿名，不读取对话正文。
- 鼠标停留 6.5 秒仍保持展开；键盘交互期间未自动收回；`Esc` 可立即关闭。
- 用同一源码的 Debug 设计验收窗口检查控制中心：AX 树完整暴露五组一级设置、所有开关、单选项、文本框、按钮和状态。
- 控制中心实测通过：浅色/深色切换、海洋蓝/紫罗兰强调色切换、Privacy Mode 对任务名开关的硬性禁用、Resident/一次性 Alert/系统通知三偏好独立、Tab 导航与可见焦点环。测试后已恢复深色与紫罗兰。
- 临时 Debug Host 已退出并注销；系统重新只保留 `~/Applications/WorkPulse.app` 的一条正式 Widget 扩展和单一 Host/Widget 进程。
- 多屏定位诊断检测到 2 块显示器，Resident 与 Expanded 均满足 `selectedBuiltIn=true`、`selectedHasNotch=true`、`panelOnSelected=true`、`contentTopInset=32`；锁屏时 Alert 按交付合同拒绝展示，因此 Alert 的解锁态多屏证据仍归入手工 Gate。
- 修复安装卫生：Xcode Debug/Release 构建产生的临时 Widget 现在会同时从 PlugInKit 与 LaunchServices 注销；失败副本和备份路径也会被注销。最终重装后 PlugInKit 仅登记正式安装路径。
- 最新隔离 QA 任务终态通知已由 macOS 实际 delivered；诊断包含 `authorizationStatus/alertSetting/notificationCenterSetting/soundSetting = 2`，仍未生成点击回执。

## 剩余手工 Gate

1. 在 Notification Center 点击最新“Codex 任务已完成”通知，确认 `request/action/route/result/openedAt` 回执与“运行 2 分钟”的同一任务结果 Expanded。
2. 在 macOS 组件库搜索 WorkPulse，分别完成添加、真实刷新和点击回流；当前只证明系统注册、签名、App Group 与扩展运行正常。
3. 在同一 build 23 上实际开启 VoiceOver 与 Switch Control，确认 Expanded/Alert 不自动中断焦点；当前已完成 AX 树、键盘和源码保护验证，但尚未开启两项系统辅助功能。

以上三项均涉及 macOS 系统表面的真实用户操作，完成前不得写成个人版完整验收通过。

## 发布边界

对外一次买断仍缺 Developer ID、notarization、购买/恢复、更新和支持链，因此为 **No-Go**。
