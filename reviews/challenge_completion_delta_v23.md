# WorkPulse build 23 最终质疑 Delta

> 2026-08-13，只读源码复审；未修改产品源码或用户设置。

## 结论

- **源码残余 P0：0；P1：0。** 上轮两个 P1 均已关闭。
- 当前 `verify_system_surfaces.sh` 与 Widget source type-check 通过；253 项 CoreVerify 继续引用 build 23 已有最终证据。
- 这代表 source gate 关闭，不等于 macOS WidgetKit、辅助技术和系统通知的 runtime gate 已完成。

## Source closed

### 1. Small Pinned recovery 路由已正确分流

`PulseUnavailableWidgetView` 已允许传入 `recoveryURL`（`WorkPulseWidget.swift:575-598`）。Small Pinned 的 `.empty`、`.corrupt`、`.unsupported` 三个分支均显式使用 `workpulse://routine/setup`（`WorkPulseWidget.swift:712-716`），不再误入额度页。

`DeepLinkRouter` 已新增 `.routineSetup`，仅接受精确的 `/setup` path；宿主处理后显示“设置固定入口”提示，并明确指向右上角 WorkPulse → 控制 → 固定入口（`Models.swift:268-299`；`WorkPulseMenuBarApp.swift:1603-1610`）。当前实现是恢复引导，不冒充已经自动打开控制中心，因此未发现新的 **false affordance**。

### 2. Expanded 键盘保护会续期并解除

每次非 Esc `keyDown` 都调用 `protectExpandedKeyboardInteraction()`；该方法取消旧任务、重新计时 15 秒，并在到期后清除保护。若此时鼠标已在面板外，会重新进入 300ms 收回流程（`NotchOverlayController.swift:414-470`）。`dismissExpanded()` 与 monitor teardown 也会取消保护任务并清理状态（`NotchOverlayController.swift:317-345, 451-461`）。原“一次按键后永久粘住”已关闭。

### 3. False affordance、隐私与失败恢复复查

- 控制中心“刷新额度”继续调用真实 `refreshLiveQuota()`，刷新中禁用。
- Widget snapshot 继续固定 `approvedRoutineTitle: nil`，桌面 Widget 不发布自定义入口名称。
- 隐私模式仍覆盖任务标题显示并清除不应保留的名称；本轮未发现新的持久化泄露路径。
- 安装器继续保留 after-open 故障注入、失败 PID 归零、唯一 Host 与 Widget runtime 验收。

未发现新的 P0/P1。

## 非阻断源码观察

15 秒保护到期后会创建 300ms 的 `expandedExitTask`；极窄窗口内若再次按键，续期方法没有显式取消这个已经排队的 exit task。该场景需要精确撞在到期后的 300ms 内，当前不升级为 P1，但建议把“第 15 秒附近再次按键”加入实机混合输入测试；若可复现，应在续期时同步取消 `expandedExitTask`。

## Remaining runtime gates

1. 从真实 Small Pinned 的 empty/corrupt/unsupported 状态逐一点击，确认系统确实唤起 WorkPulse，并显示固定入口设置引导；随后用户能从右上角进入对应设置。
2. Expanded 实机覆盖：持续键盘输入超过 30 秒能多次续期；停止输入 15 秒且鼠标在外时自动收回；第 15 秒附近再次按键不误收回；Esc 与外部点击始终立即收回。
3. 完成 VoiceOver、Switch Control、Full Keyboard Access 与 Large Text：焦点顺序、动作触发、保护与解除、面板不裁切。
4. 点击已 delivered 的真实任务通知，取得 `request/action/route/result/openedAt`，证明回到同一任务结果 Expanded。
5. 在最终安装产物上完成 Widget Gallery 搜索、添加、刷新与点击，至少覆盖 Small Quota 与 Small Pinned。

当前结论：个人版 source gate 可判 **Go**；完整本机闭环仍需上述实机证据。对外买断继续受 Developer ID、notarization、购买恢复、更新和支持链约束。

