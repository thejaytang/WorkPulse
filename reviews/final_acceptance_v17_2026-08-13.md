# WorkPulse build 17 验收记录

日期：2026-08-13（Europe/Oslo）

## 结论

build 17 已完成本机核心产品闭环：顶部刘海层始终以额度为主，系统 Widget 可从真实 macOS 组件库添加到桌面并点击回流额度表面，WorkPulse 系统通知已授权且真实送达。当前安装版位于 `~/Applications/WorkPulse.app`。

本机个人使用和 dogfood：**Go**。对外付费分发仍不是 Go，因为 Personal Team 构建不具备 Developer ID/notarization 或 Mac App Store 上架能力。

## 本轮关闭的问题

- 物理刘海不再跟随浅色主题变白。Light、Dark、Follow System 只改变控制中心、Widget 与无刘海屏幕浮动胶囊；物理刘海 Resident、Alert、Expanded 始终使用深色融合外壳。
- Resident 不再被运行任务抢占。常驻信息稳定为 `窗口身份 + 剩余额度 + 重置时间`，运行任务只作为次级 `● N` 指示。
- Expanded 同时显示额度、其他额度窗口和运行任务；Privacy Mode 下任务使用 A/B 匿名标识，并提供“显示名称 10 秒”临时揭示。
- Widget 的 `workpulse://usage` 回流现在固定展示额度，不会在任务运行时显示无关任务提醒。
- 安装脚本会先终止旧 Widget 扩展，再显式重新登记新版 `.appex`，关闭组件库预览因版本不匹配而失效的问题。
- 新增仅限本机验收的 `WORKPULSE_QA_REQUEST_NOTIFICATIONS` 启动开关；普通用户仍通过控制中心主动授权，不会被首次启动强制弹窗。

## 运行与系统证据

- Swift/Xcode Release build：通过。
- `WorkPulseCoreVerify`：242 checks 通过。
- `verify_system_surfaces.sh`：通过。
- `verify_widget_runtime.sh`：通过。
- 安装版本：`0.3.1 (17)`。
- Host 与 Widget Extension：Apple Development Team `<APPLE_TEAM_ID>` 签名，`codesign --deep --strict` 通过。
- Widget Gallery：真实 macOS 组件库识别四个 kind：Small Quota、Small Pinned、Medium Quota + Pinned、Large Work Overview。
- 桌面实例：保留一个 `WorkPulseQuota` 实例；无障碍值为 `WorkPulse, 7 天窗口, 已同步, 63%, 周三 20:09 重置`（验收时实时值，之后会变化）。
- Widget 点击：实际回流到顶部额度提醒，显示 `7 天 · 62% 剩余 / 周三 20:09 重置`，再展开可同时查看两个额度窗口与两项运行任务。
- 固定入口：本机唯一匹配的 `Gmail 每日审查任务` 已保存为 Manual Pin；通过 `workpulse://routine/<UUID>` 实测准确打开 `chatgpt.com/c/<REDACTED_CONVERSATION_ID>`，页面标题与目标任务一致。
- 通知设置：`authorizationStatus=authorized`，Alert、Notification Center、Sound 均 enabled。
- 通知送达：系统返回一个 delivered request ID，测试内容明确标注为手动本机预览，不冒充真实任务。
- 多显示器：顶部层按内建显示器策略定位，不随鼠标或前台窗口移动到外接屏；系统表面验证通过。
- Hover：Expanded 鼠标悬停保持展开，Alert 悬停暂停倒计时；鼠标离开后才恢复收起逻辑。

## 当前安装产物

- App：`~/Applications/WorkPulse.app`
- 签名归档：`native/WorkPulseNative/build/full-product/WorkPulse-full-product.zip`
- SHA-256：`26152c1cd556f7b181941aaee434fc82cbd24cc89a955b5e5390cd0c8637b63a`
- 可恢复上一版：`/tmp/WorkPulse-before-signed-20260813-014509.app`

## 尚未关闭的商品化 Gate

1. 当前是 Apple Development Personal Team 签名，只适合这台 Mac 的本地测试。对外买断分发需要二选一：Developer ID + notarization，或 Mac App Store 上架。
2. 通知已证明授权、排程与 delivered；通知横幅的逐像素截图、声音录制和通知点击回流仍可作为发布前补充证据，不影响本机 dogfood。
3. Medium/Large Widget 已由系统识别并有真实数据语义，但首发价值仍低于 Small Quota 与 Small Pinned；是否保留四种尺寸属于产品范围决策，不是技术 blocker。

## 放行判定

- 本机 WorkPulse 伴生应用：**Go**。
- Widget + 刘海 +系统通知个人内测：**Go**。
- 面向外部用户收费分发：**No-Go**，等待分发渠道与签名方案决策。
