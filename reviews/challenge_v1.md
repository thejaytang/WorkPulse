# WorkPulse 质疑智能体独立审查 V1

> 审查日期：2026-08-12  
> 角色：质疑智能体，职责是反证现有方案，而不是为既有结论背书  
> 审查范围：当前运行中的 WorkPulse、本地安装包、Notch Resident / Expanded、Widget 源码与安装状态、Notification 投递合同、PRD 与自动验收  
> 约束：本轮只审查，不修改产品源码

## 1. 独立结论

**当前方案不能作为“Widget + 刘海 + 通知已经形成闭环”的产品通过评审。**

可以继续 dogfood 的只有：菜单栏宿主、实时 Codex quota 读取、刘海常驻 quota 的视觉原型。其余关键能力存在三类根本问题：

1. 团队验证了“代码中存在某个字段或形态”，没有验证用户能否在 3 秒内做出正确判断。用户指出“7 天窗口已更新没有价值”，正是这种假阳性的直接结果。
2. Resident、Alert 和 Notification 的设置与投递边界没有真正分开；代码可能把“尝试展示”错误记录为“已展示”，从而阻断 fallback。
3. Widget 有工程 target 和源码，但当前安装包没有 `.appex`，应用也不向用户展示该能力不可用，形成虚假可用性。

当前决策：

| 范围 | 判定 |
|---|---|
| 当前机器上的 quota + Menu Bar dogfood | **Conditional Go** |
| Notch Resident 视觉原型 | **Conditional Go**，只限当前硬件与当前状态 |
| Notch Alert / Notification 可靠提醒 | **No-Go** |
| Widget 用户测试 | **No-Go** |
| “完整 WorkPulse MVP”或外部分发 | **No-Go** |

## 2. 当前流程证据

### Step 1：刘海常驻态，部分健康

![当前刘海常驻态](../output/challenge-v1/01-current-resident.png)

当前 AX 文本为：`WorkPulse 常驻状态，Codex 55% 剩余，周二 09:58 重置`。这次改动比“Codex 7 天窗口 · 已更新”更有决策价值，且当前截图中没有截断。

但它仍没有说明这是哪个 quota bucket。点击后才发现当前是 `Codex 7 天窗口`，因此常驻态的 55% 仍可能被理解为 Codex 总额度。

### Step 2：刘海展开态，部分健康

![当前刘海展开态](../output/challenge-v1/02-current-expanded.png)

展开态可读到 `Codex 7 天窗口`、`55% 剩余`、重置时间、来源和刷新动作，Esc 可收起。

问题是第二行固定显示“固定入口 / 未设置”。用户从 quota 常驻态进入时，这一行既不帮助判断额度，也挤占了展示其他 quota bucket、观察时间和 freshness 的空间。

### Step 3：Widget 安装链路，不健康

当前 `native/WorkPulseNative/build/WorkPulse.app` 内没有 `.appex`；本机只有 Command Line Tools，`xcodebuild` 不可用。Widget 源码和 Xcode target 存在，不等于用户能在 Widget Gallery 找到组件。

### Step 4：Alert / Notification，只能做源码审查

本轮没有取得真实 Notification Center 投递、点击、Focus、全屏 fallback 或系统“已呈现”证据。因此下面关于主动提醒的结论只能依据当前实现合同，不能宣称系统 E2E 已通过。

## 3. 必须挑战的事项

### C-01：验收体系验证“有字段”，没有验证“有用”

- **严重度：P0**
- **证据**：最早 PRD 已明确 Quota Pulse 的主信息应为“最紧张窗口剩余百分比”，次信息为“重置时间”；但当前 `verify_system_surfaces.sh` 只用固定字符串检查 `title: notchQuotaTitle`、`detail: notchQuotaResetLabel` 和 `formattedResetTime` 是否存在。此前“7 天窗口 · 已更新”依然能通过结构性 smoke test。用户而不是团队首先发现其信息价值不足。
- **用户影响**：自动验证全绿会制造错误完成感；团队会继续优化形状、签名和状态机，却错过最基本的扫视任务。
- **必须调整**：把验证单位从源码 token 改为用户任务。Resident 的首要 **JTBD** 必须写成：“用户在 3 秒内识别所看 bucket、剩余比例和重置时间，并能决定是否开始长任务。”
- **验收标准**：
  1. 至少覆盖 5 小时与 7 天双 bucket、fresh、stale、unavailable 四类状态的真实渲染截图与 AX 文本。
  2. ≥90% 受测者无需展开即可正确回答“哪个窗口、剩多少、何时重置”。
  3. 自动测试必须断言最终可见字符串和状态分支，单纯 `rg` 到属性名不能算通过。
  4. 任何主要位置只显示“已更新”而不显示剩余与重置，直接失败。

### C-02：常驻态仍丢失 multi-bucket 身份

- **严重度：P0**
- **证据**：当前截图只显示 `Codex 55% 剩余`；展开后才显示 `Codex 7 天窗口`。源码 `selectedQuotaDisplayName` 优先返回 bucket 的 `displayName`，当前多个 bucket 可以都显示为 Codex，窗口时长没有进入 Resident 标题。
- **用户影响**：用户可能把 7 天窗口的 55% 当成全部 Codex headroom，或在 5 小时窗口更紧张时做出错误决策。
- **必须调整**：Resident 必须保留紧凑 bucket 标识，例如 `7 天 · 55%` / `周二 09:58 重置`；或者明确显示 `5h`、`7d`。默认选择规则应是“最紧张的可行动窗口”，也可允许用户固定 bucket，但不能只写 Codex。
- **验收标准**：
  1. 双 bucket 情况下，无需展开即可区分 5 小时与 7 天窗口。
  2. 用户选择的 bucket 在重启和后台刷新后保持不变；若系统自动切换，必须解释切换原因。
  3. Resident、Widget、Menu Bar 对同一 selected bucket 的值、reset 和 identity 100% 一致。

### C-03：Overlay 的“可达”和“已呈现”是虚假判定，可能吞掉通知 fallback

- **严重度：P0 / Safety**
- **证据**：`NotchOverlayController.isReachable` 只判断 `NSScreen.screens` 非空；这在全屏、面板被遮挡、空间切换或 panel 实际未显示时仍为 true。Panel 又声明 `.fullScreenAuxiliary`。事件路径调用 `showEventAlert` 后立即 `markPresented`，没有可见性确认。通知路径在 `UNUserNotificationCenter.add` 成功后也立即 `markPresented`，但系统接受请求不等于通知已呈现或用户已看到。
- **用户影响**：高价值事件可能被记作已提醒，实际用户什么都没看到；因为 single-owner 已被占用，Notification fallback 可能不会发生。
- **必须调整**：
  1. 分离 `requested / handedOff / visiblyPresented / userOpened`。
  2. `showAlert` 返回明确的 presentation result；全屏、无 active session、panel 不在目标屏幕可见区域时不得写 `Presented`。
  3. 系统通知 `center.add` 只能记为 `handedOff`，不能记 `Presented`。
  4. Overlay 在规定时间内没有可验证呈现时，释放 owner 并转移到 Notification 或持久 Menu Bar 状态。
- **验收标准**：内屏刘海、无刘海、外屏主屏、clamshell、全屏、Space 切换、锁屏、Focus、通知 denied 的矩阵中，关键事件受控 recall ≥95%，同事件主动投递最多一次，且“未显示却记 Presented”必须为 0。

### C-04：一个开关同时控制 Resident 和 Alert，违背用户明确区分的两种形态

- **严重度：P0**
- **证据**：设置只有一个 `顶部常驻状态` 开关，对应同一 `overlayEnabled`。该值既传给 `setResident(enabled:)`，也进入事件 `DeliveryContext` 和低额度 Alert 路由。关闭常驻 quota 会同时失去一次性顶部提醒；开启一次性提醒则被迫长期显示 quota。
- **用户影响**：用户无法选择“不要常驻，但重要事件从刘海弹出”，也无法选择“只看常驻额度，事件统一走系统通知”。
- **必须调整**：至少拆为：`常驻额度`、`一次性顶部提醒`、`系统通知 fallback` 三个独立偏好；投递策略再根据全屏、前台应用和通知权限决定 active owner。
- **验收标准**：以下四种组合都可独立工作并持久化：两者都关、仅 Resident、仅 Alert、Resident + Alert。关闭 Resident 不得自动关闭 Alert；关闭 Alert 不得隐藏 Resident。

### C-05：Widget 对用户是“完全不可用”，不是“待验证”

- **严重度：P0**
- **证据**：当前安装包只有 `WorkPulse.app`，没有 `Contents/PlugIns/WorkPulseWidget.appex`。`publishWidgetSnapshotIfAvailable()` 会把 App Group 失败写入 `widgetSnapshotError`，但菜单栏从未展示该错误。PRD 同时列出四个 Widget 和 “Xcode target + source verified”，容易被理解为组件已交付。
- **用户影响**：用户在 Widget Gallery 反复搜索仍找不到 WorkPulse，不知道是安装包能力缺失，而会认为自己操作错误。
- **必须调整**：在完整签名 `.appex` 未交付前，所有用户可见状态统一称为“Widget 尚不可安装”；菜单栏增加只读的“此构建不包含桌面组件”能力状态。不要把 source target 当作产品完成度。
- **验收标准**：
  1. 发布包解压后存在签名有效的 `WorkPulseWidget.appex`。
  2. Host 与 extension 使用同一 Team 和 App Group，Gallery 可添加，host-write / extension-read 成功。
  3. 若任一条件不成立，UI 必须明确说明当前构建不含 Widget，而不是静默失败。

### C-06：stale 状态仍把精确百分比作为主要事实

- **严重度：P1，进入外部 Pilot 前为 P0**
- **证据**：`notchQuotaTitle` 在 `.live` 时始终返回精确剩余百分比，不先检查 freshness；过期只在右侧次信息写“可能过期”。Small Quota Widget 同样先用 38pt 显示百分比，再用较小的 freshness 标签标示“缓存/可能过期”。
- **用户影响**：扫视时用户只读到醒目的旧数值，弱化的过期提示不足以阻止错误决策。
- **必须调整**：stale 时主信息改为 `额度可能已过期`；若保留旧值，只能作为明确标注“上次读数”的次级信息，并停止 reset 倒计时和阈值提醒。
- **验收标准**：时间推进超过 `freshUntil` 后，Resident 和 Widget 都不能把旧百分比以当前值语气作为最大或最醒目的文本；stale 触发主动提醒次数为 0。

### C-07：Quota Expanded 混入固定入口，破坏 **One surface, one job**

- **严重度：P1**
- **证据**：从 quota Resident 点击后，Expanded 固定显示“固定入口 / 未设置”；当前截图中它占据整整一行。与此同时，多 bucket 只能去 Menu Bar 查看，Expanded 没有观察时间的清晰层级。
- **用户影响**：展开动作没有完成“解释当前 quota”这一单一任务；未设置入口的负信息反而抢占视觉空间。
- **必须调整**：Quota Expanded 只展示当前 bucket、其他 bucket 摘要、remaining、reset、observed time、freshness、source 和刷新动作。Pinned Routine 只从其 Widget 或 Menu Bar 入口进入独立的顶部详情内容。
- **验收标准**：从 `workpulse://usage` 或 quota Resident 进入时不出现固定入口；用户可在同一 Expanded 中识别所有 live bucket，并知道当前选择哪一个。

### C-08：四个 Widget 的产品组合早于真实能力，属于过度设计

- **严重度：P1**
- **证据**：Host 发布的 snapshot 当前固定 `needsYou: nil`；Scheduled / Gmail adapter 仍是 Later；Manual Pin 不提供运行状态。与此同时 WidgetBundle 暴露 Quota、Pinned、Now & Next、Daily Brief 四个组件。Large Daily Brief 在当前能力下主要聚合“尚未连接 Needs You + 手动入口 + 已在别处显示的 quota”。
- **用户影响**：Gallery 中出现看似完整、实际大量空态或重复信息的组件，降低对核心 Quota Widget 的信任，也增加维护和测试矩阵。
- **必须调整**：第一阶段只交付 Small Quota；Small Pinned 必须先证明 7 天高频价值。Medium / Large 只有在真实 Needs You 或 Scheduled capability 通过 Gate 后再进入发布 target，而不是先用空态占位。
- **验收标准**：每个上线 Widget 都能回答一个不可替代的高频问题；7 天 diary 中达到预设使用阈值。没有 live capability 的 Widget 不进入用户构建的 Gallery。

### C-09：全屏、无刘海和主题行为与 PRD 承诺不一致

- **严重度：P1**
- **证据**：PRD 写明全屏应 suppress / 自动降级，但当前没有全屏状态监听，Panel 反而配置 `.fullScreenAuxiliary`。Overlay 无论 Light / Dark、带刘海或无刘海都固定使用黑色背景；主题设置只应用于 Menu Bar 内容。
- **用户影响**：全屏演示、视频或共享屏幕中可能持续遮挡内容；无刘海外屏上的黑色胶囊未必符合用户选择的浅色模式。
- **必须调整**：明确两条设计规则：带刘海屏为与物理刘海融合可固定黑色；无刘海 fallback 应响应 Light / Dark 或只使用 Menu Bar。全屏默认 suppress，只有用户显式允许才显示关键 Alert。
- **验收标准**：Light / Dark × 刘海 / 无刘海 × 内外屏 × 全屏 / 普通空间矩阵均有当前 build 截图；默认全屏 Resident 不可见，退出全屏后正确恢复且不跨屏重复。

### C-10：辅助功能与大字号尚未进入组件设计

- **严重度：P1**
- **证据**：Notch 使用固定 13pt / 11pt 字号；Expanded source 使用固定 10pt；关闭按钮没有明确最小点击区域。Small Widget 在小尺寸内同时放标题、freshness、38pt 百分比、window、source、observed time 和 reset，尚无 130% 字号实机证据。
- **用户影响**：系统放大文字或使用 VoiceOver 的用户可能遇到裁切、小目标和信息顺序不清；“当前截图没截断”不能外推到可访问性通过。
- **必须调整**：使用语义字体与可压缩层级，给关闭和主要动作定义可见的最小点击区域；先决定 Small Widget 的三层信息优先级，再删除无法在大字号保留的次要字段。
- **验收标准**：100% / 130% 字号、Increase Contrast、Differentiate Without Color、Reduce Motion、VoiceOver、全键盘操作全部完成；核心 remaining、bucket、reset 不裁切，关闭和刷新可被正确朗读与触发。

### C-11：通知 copy 过度 generic，且投递状态合同自相矛盾

- **严重度：P1；高风险提醒为 P0**
- **证据**：所有 Needs You 通知都写“一个任务正在等待操作”，无法区分等待确认、等待输入和高风险失败。PRD 强调不同事件有不同重要性，却又固定 generic title/body。代码还把系统接受 request 写成 Presented，与文档中的真实性合同冲突。
- **用户影响**：用户无法判断是否值得打断当前工作；频繁收到无差别通知后会关闭权限。高风险提醒又可能因虚假 Presented 丢失 fallback。
- **必须调整**：保持隐私 generic，但允许事件类别有信息价值，例如“有一项任务等待确认”“有一项任务需要补充输入”“有一项高风险失败需要检查”，不展示项目名、路径或内容。
- **验收标准**：受测者只看通知即可正确判断行动类别，准确率 ≥90%；敏感信息暴露为 0；系统接受、实际展示、用户打开三个状态不得混写。

### C-12：当前文档与验收结论已经漂移，团队没有单一事实源

- **严重度：P1**
- **证据**：文件名是 `PRD_V5_FINAL.md`，正文标题却是 V6；`FINAL_ACCEPTANCE_V8.md` 仍写 Notch 没有 Native 实现，而当前源码和运行截图已经存在 Resident / Alert / Expanded。旧审查仍被当作“最终”证据，新实现没有统一替换状态表。
- **用户影响**：不同智能体会基于不同版本做判断；“完成”“待验证”“不可安装”被混在一起，用户需要反复指出已知问题。
- **必须调整**：建立一个当前状态清单，按 `implemented / source-only / packaged / runtime-verified / user-valuable / release-ready` 六级记录每个 surface，并绑定 build hash 与证据日期。旧评审只归档，不再作为当前结论入口。
- **验收标准**：任何一项能力都只有一个当前状态；状态必须指向同一 build 的源码、安装包、截图和测试结果。无法绑定同一 build 的证据不得用于 Go 判定。

## 4. 建议团队立即收缩的 V1.1 范围

团队下一轮不应继续增加功能数量，而应按以下顺序关闭问题：

1. **Quota Resident**：显示 bucket + remaining + reset；stale 不显示伪当前值。
2. **偏好拆分**：Resident、Alert、Notification fallback 三个独立控制。
3. **投递真实性**：修正 overlay reachability 和 requested / presented 状态合同。
4. **Quota Expanded**：移除无关固定入口，补多 bucket、observed time、freshness。
5. **Small Quota Widget**：先产出真正可安装的 `.appex` 并通过 Gallery；在此之前 UI 明示不可用。
6. **Small Pinned**：只有用户 diary 证明高频才进入第二个 Widget。
7. **Medium / Large / Daily Brief / 真实 Needs You**：继续 gated，不进入当前用户包。

## 5. 质疑智能体的放行条件

下一轮团队即使构建、签名和自动测试全部绿色，我仍不会仅凭这些结果放行。至少还要同时满足：

- 当前 build 的 Resident / Expanded / Alert / Notification / Widget Gallery 真实证据链完整。
- 用户在 3 秒内正确读出 bucket、remaining、reset。
- Resident 和 Alert 可独立开启与关闭。
- 全屏或不可见 Overlay 不会吞掉 Notification fallback。
- `.appex` 真正存在并可添加，否则 UI 明确声明此构建不含 Widget。
- stale quota 不以当前值语气呈现。
- 每个上线 surface 都回答一个不可替代的问题，不用空态和重复信息凑齐产品矩阵。

## 6. 证据限制

- 本轮只在当前带刘海内屏上取得 Resident 与 Expanded 运行截图。
- 未取得当前 build 的无刘海、clamshell、全屏、Stage Manager、Light / Dark 切换、130% 字号、VoiceOver、Notification Center 或 Widget Gallery 运行证据。
- 因此没有对这些场景作“通过”结论；源码中存在对应 API 也不等于运行行为已成立。
