# WorkPulse 技术实现复核 V1

> 日期：2026-08-12  
> 角色：技术实现智能体  
> 范围：Widget、刘海/顶部岛、系统通知，以及它们依赖的签名、App Group、数据刷新与 deep link  
> 输入：当前 WorkPulse 源码、`reviews/product_reaudit_v1.md`、Apple 官方文档  
> 本轮性质：只做技术复核，不修改产品源码

## 1. 结论先行

WorkPulse 的三类表面都可以做，但必须修正一个核心表述：macOS 没有向第三方 Mac App 开放“硬件刘海中的系统 Dynamic Island”接口。当前所谓刘海/灵动岛是 WorkPulse 自己创建的顶部 `NSPanel`，借助 `NSScreen.safeAreaInsets` 和顶部可见区域贴合摄像头外壳。它可以做到视觉上连续、常驻和可交互，但不是 Apple 管理的 **Dynamic Island**，不具有系统级生命周期、排他布局或送达保证。

Apple 当前把 **Dynamic Island** 的系统呈现定位在 iPhone；同一套 **Live Activities** 在 Mac 上的系统位置是 menu bar，而不是 Mac 刘海。因而“Mac 系统灵动岛”应标记为 **Unsupported**，“WorkPulse 自绘顶部岛”标记为 **Constrained**。这是根据 Apple 平台映射作出的技术判断。[Apple Live Activities HIG](https://developer.apple.com/design/human-interface-guidelines/live-activities)

Widget 的工程骨架已存在，且 target、extension point、App Group 代码路径基本齐备；但当前交付的 `build/WorkPulse.app` 是 host-only 包，没有 `Contents/PlugIns/WorkPulseWidget.appex`，也没有签入 App Group entitlement。因此“现在可在系统组件库找到 WorkPulse Widget”仍是 **Prototype-only**，不能对用户承诺已经支持。

系统通知的本地调度、类别、操作和 deep link 使用的是公开 API，属于 **Supported**；但通知必须授权，送达不保证，锁屏/声音/横幅还受用户设置与 Focus 影响。真实 Needs You 事件源尚未接通，所以事件通知只能算 **Prototype-only**。额度通知的数据源可用，但当前“跨越阈值”和“离开电脑时使用通知”的产品语义尚未被代码完整实现。

## 2. 状态定义

| 标记 | 含义 |
|---|---|
| **Supported** | Apple 公开 API 支持，当前代码已有可工作的主要路径；仍需正常发布验证 |
| **Constrained** | 可实现，但受系统调度、窗口层级、进程存活、显示器状态或用户设置限制，不能承诺绝对行为 |
| **Prototype-only** | 源码、工程骨架或 fixture 已存在，但当前安装包/真实数据/E2E 验证不成立 |
| **Unsupported** | 没有对应公开系统能力，或当前方案不能实现该产品承诺 |

## 3. 产品承诺复核矩阵

| 产品承诺 | 状态 | 技术结论 |
|---|---|---|
| 在 Mac 硬件刘海中使用 Apple 原生 Dynamic Island | **Unsupported** | Apple 文档把 Dynamic Island 呈现定义在 iPhone；Mac 对应系统表面是 menu bar。WorkPulse 无权控制摄像头外壳或系统刘海区域 |
| 在刘海下方绘制视觉连续的常驻顶部岛 | **Constrained** | 可用无边框 `NSPanel`、公开的 safe area 和辅助顶部区域实现；只在 WorkPulse 进程运行、用户开启且窗口未被系统场景压制时存在 |
| 顶部岛 Resident / Alert / Expanded 三态 | **Supported** | 当前状态机、自动收起、hover 暂停、Esc/点外部关闭均已有代码；但 Expanded 的信息架构仍未按产品复审拆分上下文 |
| 常驻顶部岛永远可见 | **Unsupported** | 锁屏、登录窗口、App 未运行、崩溃、退出、系统安全界面等情形不能保证；全屏、Stage Manager 和显示器切换只能做兼容与降级 |
| 自动固定在内建有刘海屏 | **Constrained** | 当前策略优先 built-in + notch，并监听屏幕参数变化；clamshell 时会降级到主屏顶部胶囊。镜像、切换主屏、全屏组合仍需真机矩阵 |
| 在物理摄像头黑区内显示文字或接收点击 | **Unsupported** | 物理区域会遮挡像素且不可交互；只能把内容安排在 safe area 下方，并让黑色形状视觉连接到硬件刘海 |
| Small / Medium / Large 桌面 Widget | **Prototype-only** | Widget 源码声明了三种 family 和四个 widget，但当前 host-only 包没有 `.appex`；Gallery 不会发现它 |
| Widget 安装后读取宿主快照 | **Supported** | Apple 支持 App Group 共享容器，当前宿主写 `widget.json`、extension 读取同名文件；前提是两 target 用同一 Team 和 App Group 正确签名 |
| Widget 实时或每 4 分钟严格更新 | **Unsupported** | WidgetKit extension 不持续运行，timeline/reload 有系统预算和合并策略；不能把宿主的 240 秒轮询等同于 Widget 刷新频率 |
| 点击 Widget 打开对应顶部详情或固定链接 | **Constrained** | `widgetURL` / `Link` 和 `workpulse://` 路由可用；系统会启动/唤醒 host，但“已请求打开”不能等同“已到达正确 ChatGPT 对话” |
| 本地额度通知和自定义操作 | **Supported** | `UNUserNotificationCenter`、category/action、deep link 均为公开能力；必须先获得授权并按当前通知设置降级 |
| 通知在精确时间、锁屏、横幅和声音中必然出现 | **Unsupported** | Apple 明确说明通知及时送达不保证；用户可关闭 alert/sound/lock screen，Focus 也可改变呈现 |
| 真实 Needs You / Scheduled / Gmail 通知 | **Prototype-only** | 当前只有 ledger、delivery policy 和 fixture；没有 verified production adapter，不得宣称真实监听 |
| 低额度“首次跨越”阈值时提醒一次 | **Prototype-only** | 当前算法只判断“本周期首次观察到 `remaining <= threshold`”，没有保存上一观测值，因此首次启动时已低于阈值也会提醒，不是真正 crossing |
| Overlay 成功后同一事件不再发通知 | **Constrained** | ledger 有 owner 去重，但当前“成功呈现”依据是调用 `showAlert` 后立即标记，不是可见性确认；全屏或系统遮挡下可能误判 |

## 4. 刘海/顶部岛复核

### 4.1 Apple API 边界

公开且适合使用的能力包括：

- `NSScreen.safeAreaInsets`：标明屏幕边缘中不会被摄像头外壳遮挡的范围。Apple 说明部分 Mac 的 top inset 会反映 camera housing。[Apple `safeAreaInsets`](https://developer.apple.com/documentation/appkit/nsscreen/safeareainsets)
- `NSScreen.auxiliaryTopLeftArea` / `auxiliaryTopRightArea`：在 top inset 非零时给出顶部左右可见区域，可用于估算中间物理刘海宽度。[Apple `auxiliaryTopLeftArea`](https://developer.apple.com/documentation/appkit/nsscreen/auxiliarytopleftarea-uglc)
- `NSPanel` / `NSWindow.CollectionBehavior`：可创建非激活、跨 Space 的浮层。`canJoinAllSpaces` 只表示窗口可以出现在所有 Space，不等于系统保证它覆盖所有界面。[Apple `canJoinAllSpaces`](https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior-swift.struct/canjoinallspaces)

当前实现与 API 对应关系：

- `present` 读取 safe area、计算左右辅助区域间距，并把内容整体下移到 top inset 后方：`NotchOverlayController.swift:274-303`。
- `preferredScreen` 枚举当前屏幕，优先内建有刘海屏：`NotchOverlayController.swift:306-324`。
- `NSPanel` 为 borderless、nonactivating、statusBar level，并加入 all spaces/full-screen auxiliary：`NotchOverlayController.swift:359-375`。
- 系统屏幕参数变化会触发重新定位，而不是缓存 `NSScreen.screens`。这符合 Apple 关于屏幕可动态重配置的说明。[Apple `NSScreen.screens`](https://developer.apple.com/documentation/appkit/nsscreen/screens)

### 4.2 “常驻”允许到什么程度

结论：应用可保留一个自己的浮层窗口，但“常驻”只能定义为“当 WorkPulse 正在运行、用户启用、会话活跃且系统允许窗口呈现时持续显示”。不能定义为系统级常驻。

限制如下：

1. App 退出或崩溃后，`NSPanel` 立即消失；当前工程也没有 `SMAppService` Login Item，因此重启登录后不会自动恢复，除非另行实现“登录时启动”。
2. 锁屏和登录界面不属于第三方普通窗口可承诺覆盖的空间。
3. `.statusBar` 是 status window 层级，不是保留屏幕空间的 API；其他系统 UI、全屏安全场景和更高层级窗口可覆盖它。
4. 当前 `hidesOnDeactivate = false` 与 Apple 对一般 floating panel “通常在 app deactive 时隐藏”的建议不同。它可以工作，但必须经过遮挡、干扰、焦点和 App Review 风险测试，不能把“显示在别的 App 上方”视作无条件系统认可。[Apple `isFloatingPanel`](https://developer.apple.com/documentation/appkit/nspanel/isfloatingpanel)
5. Expanded 调用 `makeKeyAndOrderFront`，而 panel 同时是 `.nonactivatingPanel` 和 `becomesKeyOnlyIfNeeded`。鼠标动作可工作，但完整键盘焦点、Tab 顺序、VoiceOver 和文本大小仍需真机验证。[Apple `becomesKeyOnlyIfNeeded`](https://developer.apple.com/documentation/appkit/nspanel/becomeskeyonlyifneeded)

### 4.3 多显示器与物理刘海定位

当前选择顺序正确：内建有刘海 > 内建屏 > 主屏 > 第一块屏。它解决了“鼠标在外接屏时岛跟过去”的错误，也符合产品“物理刘海属于内建显示器”的语义。

仍需补齐以下边界：

- clamshell：内建屏不在 `NSScreen.screens` 时，只能在外接主屏顶端用普通胶囊，不能称刘海模式。
- mirroring：系统可能只暴露一个代表性屏幕对象；应验证 built-in/primary 识别和缩放后的 panel 坐标。
- 菜单栏自动隐藏、全屏、Stage Manager、多 Space：`.fullScreenAuxiliary` 和 `.canJoinAllSpaces` 是参与资格，不是可见保证。
- 显示缩放、不同 refresh rate 和旋转外接屏：需验证 `frame`、safe area、辅助区域与视觉形状一致。
- 物理刘海宽度取不到时，当前 shape 使用估算值；这是合理 fallback，但必须在不同 MacBook 型号截图比对。
- 当前 `isReachable` 仅判断 `NSScreen.screens` 非空，无法证明 panel 实际可见。事件 owner 不应据此认定“已送达”。

## 5. Widget 复核

### 5.1 真正安装所需条件

Apple 要求 Widget 作为 Widget Extension target 随宿主 App 分发。Widget 可以有多个 widget type；系统通过 extension point 发现它。[Apple Creating a widget extension](https://developer.apple.com/documentation/widgetkit/creating-a-widget-extension)

WorkPulse 的完整产物至少必须同时满足：

1. Xcode 工程含 macOS application target 和 Widget app-extension target。
2. host 依赖并嵌入 `WorkPulseWidget.appex`。当前 `project.yml:10-19` 已声明。
3. extension 的 `Info.plist` 含 `NSExtensionPointIdentifier = com.apple.widgetkit-extension`。
4. host 与 extension 使用唯一且有效的 bundle identifier，并由同一 Apple Development/Developer ID Team 签名。
5. App Group `group.com.workpulse.prototype` 已在开发者账号能力中注册，并同时出现在 host 与 extension 的签名 entitlement。
6. 安装后的结构存在 `WorkPulse.app/Contents/PlugIns/WorkPulseWidget.appex`，host 和 `.appex` 都通过严格签名校验。
7. host 能把 `widget.json` 写入 group container，extension 能从同一 container 解码，并能在 Gallery 中添加后显示 production snapshot。

Apple 明确支持通过 App Group 在 app 与 extension 间共享 container；`containerURL(forSecurityApplicationGroupIdentifier:)` 是公开路径。[Apple Configuring app groups](https://developer.apple.com/documentation/xcode/configuring-app-groups)

### 5.2 当前工程的真实状态

已经存在：

- Xcode target 和 embed 声明：`project.yml:9-49`。
- 两份 App Group entitlement 文件，标识符一致。
- Widget extension point `Info.plist`。
- 宿主写共享 `widget.json` 并调用 `WidgetCenter.shared.reloadAllTimelines()`：`WorkPulseMenuBarApp.swift:979-1011`。
- extension 从 group container 读取、校验 schema 并生成 timeline：`WorkPulseWidget.swift:48-95`。
- Small Quota、Small Pinned、Medium Now & Next、Large Daily Brief 的 SwiftUI 声明。

尚未成立：

- 当前机器只有 Command Line Tools，`xcodebuild` 无法执行完整工程构建。
- 当前 `scripts/package_app.sh` 只编译 `WorkPulseMenuBar`，复制宿主二进制并 ad-hoc 签名：`package_app.sh:18-37`。
- 当前 `build/WorkPulse.app` 实际没有 `Contents/PlugIns`，也没有签名 App Group entitlement。
- `typecheck_widget.sh` 只能证明 Widget 源码可通过类型检查，不能证明 extension 被构建、嵌入、注册或出现在 Gallery。
- `build_full_product.sh` 已写好 `.appex`、签名和 entitlement Gate，但尚未在本机执行通过：`build_full_product.sh:9-47`。

因此当前四个 Widget 的统一状态是 **Prototype-only**。其中产品层还应区分：Small Quota 与 Small Pinned 可进入首发；Medium 仍是旧版 Needs You + Pinned；Large Daily Brief 仍依赖未连接数据，后两者不应随首发 bundle 暴露。

### 5.3 刷新与“实时”边界

WidgetKit 由系统在独立进程渲染，extension 不持续运行。系统对 reload 有动态预算，常见约为 15–60 分钟，timeline 时间也可能被合并；Apple 建议 timeline entry 至少约相隔 5 分钟。[Apple Keeping a widget up to date](https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date)

当前 host 每 240 秒读取一次 quota，但这只在 host 进程活着时发生：`WorkPulseMenuBarApp.swift:830-848`。写入共享快照后调用 reload 是正确的“请求更新”，不是刷新 SLA。产品文案必须使用“最近快照/可能过期”，不能使用“实时额度”或“4 分钟更新”。

当前 provider 的 fallback 为 30 分钟，并选择 `freshUntil`、reset 和 fallback 的最早未来时间。这是合理的 timeline 策略，但如果 `freshUntil` 为 5 分钟且 host 没有新数据，Widget 只会重新读取同一个已过期文件，不会自行连接 Codex App Server。

## 6. 系统通知复核

### 6.1 Apple API 支持范围

`UserNotifications` 支持本地通知、category、action、响应回调与 deep link。当前 `NotificationCoordinator` 已实现这些基本构件：`NotificationCoordinator.swift:24-49, 71-118, 128-149`。

通知必须由用户授权；Apple 建议在有上下文时请求，而不是首启自动弹窗。首次决定后，重复调用不会再次弹窗，用户可随时在系统设置改变权限。[Apple Asking permission to use notifications](https://developer.apple.com/documentation/usernotifications/asking-permission-to-use-notifications)

Apple 同时明确说明本地和远程通知会尽力及时送达，但不保证。因此以下情况都不能作为产品承诺：精确到秒、必定横幅、必定有声音、必定锁屏显示。[Apple User Notifications](https://developer.apple.com/documentation/usernotifications)

### 6.2 当前实现差距

1. 代码只缓存 `authorizationStatus`，没有保存和判断 `alertSetting`、`soundSetting`、`lockScreenSetting`、`scheduledDeliverySetting`。授权不等于横幅和声音都已开启。
2. `willPresent` 固定请求 `.banner + .sound`，即使用户正在使用 WorkPulse/Codex，也没有按 active owner 和重复打扰规则抑制。
3. 产品要求“用户离开电脑时事件改用通知”，但 `DeliveryPolicy` 对 needsApproval/needsInput 等事件只要 overlay enabled/reachable 就先选 overlay，没有使用 `userIsActive` 决定通知。当前离开状态仍可能只在顶部弹 6 秒。
4. 事件 overlay 在调用 `showAlert` 后立即 `markPresented`；`isReachable` 仅等于有屏幕，不能证明用户实际看见。需要 presentation acknowledgement 或超时 fallback。
5. quota 去重按 `limitID + reset cycle` 有效，但算法不存上一观测值，只是“该 cycle 尚未提醒且当前低于阈值”。这不满足“首次跨越阈值”的严格定义。
6. 当前只有一个用户选择阈值，不是 30%/20%/10% 多级逐一 crossing。产品必须二选一：维持单阈值，或新增每级状态机。
7. notification preview 仍存在正式菜单路径，按产品复审应限 Debug/QA。
8. Needs You 通知的 transport 可用，但 source adapter 未接通，生产 capability 必须保持关闭。

## 7. 当前哪些表面只是 scaffold

| 表面/能力 | 当前事实 | 状态 |
|---|---|---|
| Small Quota Widget | 视图和 provider 有源码；未安装 `.appex`；信息层级仍把来源和窗口放在 reset 前 | **Prototype-only** |
| Small Pinned Widget | 视图和 deep link 有源码；未安装 `.appex`；只确认 open request | **Prototype-only** |
| Medium Now & Next | 代码存在，但 production snapshot 固定写 `needsYou: nil` | **Prototype-only / 不应首发** |
| Large Daily Brief | 代码存在，至少两类核心信息没有 verified source | **Prototype-only / 不应首发** |
| App Group 共享 | entitlements 和读写代码存在；当前签名包没有 group entitlement | **Prototype-only，完整签名后可 Supported** |
| 顶部 Resident/Alert/Expanded | host-only App 中可运行；属于自绘 overlay，不是系统 Dynamic Island | **Constrained** |
| quota 数据 | 本机 Codex App Server reader 与刷新循环存在 | **Constrained**，依赖实验性本机来源与 host 存活 |
| quota threshold Alert | 可触发、按 cycle 去重；不是严格 crossing | **Prototype-only** |
| quota 系统通知 | transport 存在；权限和阈值语义未完成 E2E | **Constrained / Conditional** |
| Needs You ledger / routing | 状态机、owner 和 fixture 存在 | **Prototype-only** |
| Scheduled/Gmail | 无 production adapter | **Unsupported（当前版本）** |
| 登录时自动启动 | 未见 `SMAppService` 或 Login Item | **Unsupported（当前版本）** |
| Developer ID / notarization | 当前包为 ad-hoc；完整脚本未执行 | **Prototype-only** |

## 8. 最小实现顺序

### Step 0：冻结产品术语

- 对外统一称“顶部岛”或“刘海顶部浮层”，不称“macOS 原生灵动岛”。
- 明确“常驻”条件：App 运行 + 用户开启 + 当前会话可呈现。
- Widget 只承诺“最近快照”，不承诺实时。

**Gate 0**：PRD、设置文案、安装说明和验收表中不再出现“系统 Dynamic Island”“永远常驻”“Widget 每 4 分钟实时更新”。

### Step 1：先完成 Quota Resident + Quota Expanded

- 保留当前屏幕选择与 safe-area 逻辑。
- Expanded 从固定入口/事件模板中拆出，只展示全部 quota bucket、reset、freshness、source、刷新。
- 正常 fresh 使用中性色，低额度才使用 warning/critical。
- 补齐 stale/unavailable/重置已过期边界。

**Gate 1**：内建刘海、内建非主屏、外接主屏、clamshell、mirroring、全屏、Stage Manager、多 Space 各通过一次视觉与点击验证；无内容被硬件刘海遮挡；Esc、点外部、VoiceOver 均可退出 Expanded。

### Step 2：修正提醒状态机，再启用 quota Alert

- 保存每个 bucket 的上一 fresh observation。
- 只有 `previous > threshold && current <= threshold` 才算 crossing；initial reconcile 不提醒。
- reset cycle 改变后重置 crossing state。
- 明确单阈值或多级阈值，不混用产品文案。

**Gate 2**：initial-low、30→19、19→18、19→25→19、cycle reset、stale、offline、source conflict 均有确定性测试；每个目标阈值/周期最多一次。

### Step 3：构建真实 Widget 产物

- 在装有完整 Xcode 的开发 Mac 上注册 App Group 和 Team。
- 构建 Release App，确认 `.appex` 嵌入、两端 entitlement 一致、严格签名通过。
- 首发 WidgetBundle 暂只暴露 Small Quota 与 Small Pinned；Medium/Large 暂移出 production bundle。

**Gate 3**：全新用户环境安装后，Gallery 能找到两个 WorkPulse Widget；添加后读取 production snapshot；kill host、重新启动、睡眠唤醒、schema mismatch、无 App Group 数据、stale/unavailable 均有正确状态；不允许 fixture 写入 Widget。

### Step 4：完成通知设置与路由

- 在用户开启低额度提醒时，带上下文请求授权。
- 读取完整 `UNNotificationSettings`，按 alert/sound/lock-screen 实际设置降级。
- active owner 路由必须把 `userIsActive`、overlay 可见性和 notification settings 纳入决策。
- 同一 transition 只能由一个主动表面承接；overlay 未确认呈现时释放 owner。

**Gate 4**：未决定、拒绝、仅 Notification Center、关闭声音、Focus、前台、离开 60 秒、overlay 关闭、deep link 过期、snooze 后再次触发均完成 E2E；普通 refresh 产生 0 Alert、0 Notification。

### Step 5：最后再接 Needs You / Daily Brief

- 先实现 verified adapter、freshness、terminal transition 和 source conflict。
- transport 与真实来源分开验收。
- 只有两类以上 daily source 稳定后才启用 Large Daily Brief。

**Gate 5**：无 fixture、真实 source、fresh zero、stale、offline、terminal、ID collision、source conflict、通知点击、稍后、移除与来源状态边界全部通过，才能启用 production capability。

### Step 6：分发 Gate

- Developer ID 签名、Hardened Runtime、notarization、stapling。
- 验证从 ZIP/DMG 拖入 Applications 后首次运行、更新安装、Widget 保留、URL scheme 和通知权限。
- 若需要“登录后常驻”，再使用 `SMAppService` 增加由用户控制的 Login Item；不要用隐藏 LaunchAgent 代替。

**Gate 6**：干净账户与另一台 Mac 安装通过；`spctl`、`codesign --deep --strict`、notarization、`.appex` entitlement、Gallery、重启登录后行为均与文案一致。

## 9. 最终技术决策

### Go

- host-only 本机 dogfood：菜单栏、Quota Resident、自绘顶部 Alert/Expanded、手动固定链接。
- 使用公开 `NSScreen` safe area API 做内建刘海定位。
- 使用 `UserNotifications` 做经过授权的本地通知 transport。

### Conditional Go

- Small Quota / Small Pinned：只有完整 `.appex` + App Group + Gallery Gate 通过后才可称已支持。
- quota 系统通知：只有 crossing、完整 notification settings、active owner 与 deep-link E2E 通过后启用。
- 顶部岛全屏/多显示器支持：只能写“已适配并有降级”，不能写“所有场景始终显示”。

### No-Go

- 将自绘 `NSPanel` 宣称为 Apple 原生 Dynamic Island。
- 宣称能在物理刘海黑区内显示或点击。
- 用当前 host-only ZIP 声称 Widget 已安装。
- 宣称 Widget 实时或精确刷新。
- 宣称通知必达、必定横幅/锁屏/有声。
- 在没有 verified adapter 时启用 Needs You、Scheduled、Gmail 或 Daily Brief 生产状态。

最终技术原则：把“系统允许做”与“当前看起来能做到”分开。WorkPulse 可以可靠地成为一个轻量 companion，但它的可靠性来自公开 API、正确签名、明确降级和可验证 Gate，不来自把自绘浮层命名成系统能力。
