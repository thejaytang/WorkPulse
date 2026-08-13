# WorkPulse build 18 最终本机验收

日期：2026-08-13（Europe/Oslo）

## 放行结论

- 本机 WorkPulse 伴生应用：**Go**。
- 刘海 Resident / Alert / Expanded：**Go**。
- macOS 桌面 Widget：**Go**，已在真实组件库添加一个 Small Quota 和一个 Small Pinned。
- macOS 本地通知 transport：**Go with system constraints**，授权、Alert、通知中心、声音和 delivered 均已验证；Focus 与系统策略仍决定实际呈现。
- 对外收费分发：**No-Go**，仍需 Developer ID + notarization，或另行完成 Mac App Store 架构与审核。

## 本轮实际完成

1. 顶部常驻始终以额度为主：`窗口身份 + 剩余额度 + 重置时间`；运行任务只显示次级 `● N`。
2. 点击顶部层展开后同时显示所有额度窗口和具体运行任务；Privacy Mode 下默认使用任务 A/B，可临时显示真实名称 10 秒。
3. 物理刘海始终使用深色融合外壳，不会因 Light/System 主题变白；主题只作用于控制中心、Widget 与无刘海屏幕的浮动胶囊。
4. 外接屏不抢占顶部岛：定位策略固定优先内建刘海屏，不跟随鼠标或前台窗口。
5. Expanded 鼠标悬停时不收起，移出后恢复收起；Alert 悬停暂停倒计时。
6. Small Quota 实际桌面显示真实 production snapshot，并点击回流顶部额度表面；运行任务不会抢占 `workpulse://usage`。
7. Small Pinned 已保存并显示本机固定入口；实际点击准确打开 ChatGPT 的 `Gmail 每日审查任务`。
8. WorkPulse 通知已在系统设置开启，测试通知真实进入 delivered 列表，文案明确标注“本机预览”，不冒充生产事件。
9. 修复升级时旧 Widget 扩展立即被系统拉起的问题：安装器先注销旧 `.appex`，再停止进程、替换并登记新版本。
10. 修复 Widget 写放大：任务名称或 `lastActivityAt` 改变但 Widget 可见任务数量不变时，不再写快照或调用 timeline reload；15 秒实测 revision `3422 → 3422`。
11. 任务轮询由 2 秒调整为 5 秒，降低只读 SQLite / rollout 扫描和能耗，同时保持可接受的状态响应。
12. Medium `额度与入口` 已实际添加：左右两区分别有独立按钮，额度区点击回流顶部额度，入口区使用同一 Manual Pin。
13. Large `工作概览` 已实际添加：展示两组额度、2 个运行任务计数和固定入口；固定入口点击准确打开 Gmail 对话。验收后已移除 Medium/Large，桌面只保留用户最有价值的两个 Small。

## 验证证据

- 安装版本：`0.3.1 (18)`。
- 安装路径：`~/Applications/WorkPulse.app`。
- Apple Development Team：`<APPLE_TEAM_ID>`。
- Host + Widget Extension：`codesign --deep --strict` 通过。
- `WorkPulseCoreVerify`：242 checks 通过。
- `verify_system_surfaces.sh`：通过。
- `verify_widget_runtime.sh`：通过。
- 桌面实例：Small Quota = 1，Small Pinned = 1。
- 临时尺寸验收：Medium = 1、Large = 1，视觉和点击完成后均移除；当前各为 0。
- Gmail 固定入口：实际打开 `chatgpt.com/c/<REDACTED_CONVERSATION_ID>`，页面标题为 `Gmail 每日审查任务`。
- 签名 ZIP：`native/WorkPulseNative/build/full-product/WorkPulse-full-product.zip`。
- SHA-256：`f02fdc45a1f2834eddea51a8427f3e5a073e2a065b3141456b3fd9c1fa3929e5`。
- 可恢复上一版：`/tmp/WorkPulse-before-signed-20260813-060836.app`。

## 仍然明确不承诺

- macOS 没有第三方可调用的系统 Dynamic Island API；WorkPulse 的顶部岛是受控 `NSPanel`，不是 Apple 系统灵动岛。
- WidgetKit 不保证实时或精确刷新，界面展示的是带 freshness 的最近快照。
- 通知不保证必定出现横幅、声音或锁屏提醒，最终由系统设置与 Focus 决定。
- 当前 Gmail 只是人工固定的快捷入口，不读取 Gmail 状态；Needs You、Scheduled 和 Daily Brief 尚无可信 production adapter。
- 当前 Personal Team 构建只适合本机个人使用，不能作为对外出售的正式安装包。
