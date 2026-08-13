# WorkPulse macOS Companion

WorkPulse 是一个无独立主窗口的 Codex 本地伴生应用。最终用户不需要 Xcode，也不需要通过 App Store 安装。开发者如果只构建菜单栏、顶部层和通知，可使用 Command Line Tools；要让 Widget 稳定进入 macOS 组件库，扩展还必须经过 Apple Development 或 Developer ID 团队签名。

## 产品表面

- `WorkPulseMenuBar`：后台 `LSUIElement` 宿主和紧凑的 `MenuBarExtra` 设置入口，不创建 Dashboard 或普通窗口。
- `WorkPulseWidget`：WidgetKit extension 提供 Small Quota、Small Pinned、Medium 快速查看和 Large 今日概览。中型与大型只组合已支持的额度、运行任务计数和手动固定入口，不伪造 Needs You、Gmail 或 Scheduled 状态。
- `NotchOverlayController`：顶部 Resident、一次性 Alert 和用户主动 Expanded 三态 `NSPanel`；无刘海屏幕使用同一顶部浮层降级。
- `NotificationCoordinator`：用户显式授权的 macOS 通知；真实事件保持 capability-gated，已验证的实时 quota 可按阈值、每周期去重提醒。
- `WorkPulseCore`：额度读取、freshness、隐私边界、事件 ledger、单一 active owner、快照存储和提醒策略。

固定对话目前是 Manual Pin：只保存用户输入的 HTTPS 入口，不读取对话、Gmail 正文或 Scheduled 状态。Codex quota 由本机 App Server 只读获取，并展示所有可见 bucket。

## 构建形态

`WorkPulse.xcodeproj` 由 `project.yml` 生成，包含：

- `WorkPulse.app`
- 嵌入式 `WorkPulseWidget.appex`
- 宿主与 Widget 共用团队作用域 App Group：`$(DEVELOPMENT_TEAM).com.workpulse.shared`

`scripts/package_app.sh` 已可使用 Command Line Tools 生成嵌入 `WorkPulseWidget.appex` 的本机 ad-hoc ZIP，并为宿主与 Widget 配置相同 App Group。为了避免 LaunchServices 同时登记桌面构建副本和 Applications 安装副本，脚本只保留 ZIP；最终用户不需要 Xcode。安装后必须让 LaunchServices 登记包含它的 `WorkPulse.app`，不要直接用 `pluginkit -a` 登记 `.appex`，否则 macOS 会把它判定为脱离宿主的插件并从 Widget 描述符缓存中清除。

完整 Xcode 是生成 Apple Development 身份、配置团队签名、调试 Widget Extension、Developer ID 分发与 notarization 的标准路径。构建脚本会从当前 Xcode 登录状态派生 Team ID 与 App Group，不在仓库中保存作者的 Personal Team。Host 与 Widget 的严格验签、同 TeamIdentifier、同 App Group、唯一 PlugInKit 注册和 WidgetKit 加载已在本机开发构建中通过。最终使用者安装未来经过 Developer ID 签名与 notarization 的成品时不需要安装 Xcode；当前仓库尚未提供这种公开发行包。

## 本地验证

在本目录运行：

```bash
swift build

swift run WorkPulseCoreVerify

./scripts/verify_system_surfaces.sh
./scripts/typecheck_widget.sh
./scripts/package_app.sh
./scripts/install_local_dev.sh
./scripts/verify_widget_runtime.sh
```

团队签名产物就绪后，可用下列脚本安装。脚本会先严格验签、拒绝无 TeamIdentifier 的 Widget，并把旧版本移动到 `/tmp` 的可恢复备份后再登记宿主：

```bash
# 已在 Xcode 登录 Personal Team 时，构建脚本会自动识别 Team ID。
./scripts/build_full_product.sh
./scripts/install_signed_product.sh
./scripts/verify_widget_runtime.sh
```

真实额度探针只读取并脱敏报告 bucket 数量：

```bash
swift run --disable-sandbox --scratch-path /tmp/workpulse-native-build WorkPulseAppServerProbe
```

确定性 QA 运行态：

```bash
WORKPULSE_QA_STATE=quota-two-bucket \
WORKPULSE_QA_OVERLAY=1 \
swift run WorkPulseMenuBar
```

直接运行 SwiftPM executable 时系统通知会被安全禁用，因为 `UserNotifications` 要求 `.app` bundle；菜单栏和顶部层仍可验证。`WORKPULSE_QA_EVENTS=1` 只加载明确标记的模拟 Needs You，不能外发 Widget 数据或生产通知。

## 当前可信边界

- 已验证：无独立页面、品牌菜单栏控制中心、顶部 Resident/Alert/Expanded 三态、额度优先常驻、悬停保持与移出收起、物理刘海始终使用深色融合外壳、内建刘海屏优先、多屏定位、Privacy Mode 强制隐藏任务标题、明确任务终态、真实两组 quota bucket、低额度严格跨阈值提醒、嵌入 `.appex`、共享 App Group 快照、Apple Development 团队签名、唯一 PlugInKit 注册，以及真实 macOS Widget Gallery 的搜索、添加和点击回流。
- 已验证通知 transport：WorkPulse 在系统设置中已授权，Alert、Notification Center、Sound 均启用；签名宿主已排程并获得真实 delivered request ID。任务系统通知永远使用 generic 文案，仅在点击返回 WorkPulse 后才按本机隐私偏好恢复具体结果；真实系统通知 click/open 回执仍需解锁后手工 GUI 验收。通知受 Focus 和系统呈现策略控制，产品不承诺必定横幅或精确送达时间。
- build 23 本机验收记录：`../../reviews/final_acceptance_v23_2026-08-13.md`。当前开发快照的 `WorkPulseCoreVerify` 为 260 checks；Small Quota 与 Small Pinned 为首发优先，Medium/Large 只组合已支持的真实数据。组件共享快照为 schema 6，并具备损坏缓存自愈、有效固定入口状态、启动 quota 保持、Large Text 自适应、Increase Contrast、VoiceOver 选中态和 Full Keyboard Access Alert 保护。控制中心已收敛为五组，仓库仅保留一个正式 Xcode 工程。隔离的 generic task-terminal QA 通知已被 macOS 实际 delivered，最新构建的真实点击回执仍是暂停开发前未完成的人工 Gate。
- 待视觉与无障碍终验：控制中心 Light/Dark/System、大字号、VoiceOver、锁屏与全屏矩阵。内建屏加外接屏的实际窗口坐标已通过。
- 待外部分发验证：Developer ID 签名与 notarization。当前 Personal Team 构建仅用于本机开发和 dogfood，不是可向客户分发的安装包。
- 尚不支持：跨 ChatGPT/Codex 客户端的真实 approval/needs-input 监听、Gmail/Scheduled 自动状态和 exact return。生产 event capability registry 默认关闭。
