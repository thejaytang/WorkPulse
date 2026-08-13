# WorkPulse build 20 用户价值与可用性收尾审查

> 审查对象：本机安装版 WorkPulse `0.3.1 (20)` 与最终产品 ZIP  
> 最终 ZIP SHA-256：`ef94a3d2078545506f0a53f522fdd9812683a0213e5f40b60c83d8a51142444e`  
> 审查视角：真实用户任务、3 秒扫读、隐私预期、打扰成本与首发范围  
> 证据边界：Mac 当前锁屏。本轮确认安装元数据、ZIP hash 与源码合同，但没有取得 build 20 的新 GUI 截图。深色 Widget、真实 Resident 布局、通知横幅及点击回流均列为解锁后手工 Gate，不冒充已通过。

## 最终结论

**build 20 对“个人本机 companion”的核心方向是 Conditional Go；对“四种 Widget 的完整首发”和未经手工 Gate 的通知能力仍是 No-Go。**

已经成立的核心价值链是：

1. Resident 始终把 quota 放在第一位，任务只显示 `● N`，不再抢占最重要的信息。
2. 默认开启隐私，默认不显示任务名；隐私态只显示任务 A/B、开始时间和运行时长。
3. Small Quota 回答“还剩多少、什么时候重置、数据是否需更新”。
4. Small Pinned 提供一个明确的固定对话入口，不伪装成 Gmail、Daily Brief 或 Scheduled 状态。
5. 任务终态通知保持 generic；点击后可在 WorkPulse 展开该任务的 outcome 与运行时长，本机存在允许展示名称时才显示名称。

尚未成立的首发范围是：

- Widget bundle 仍同时暴露 Small、Medium、Large 四种形态，其中 Medium 与 Large 没有经真实使用证明独立价值。
- 控制中心仍承担状态、设置、诊断、外观与商业说明，设置负担高于轻量 companion 所需。
- 通知代码具备 request、generic payload、callback receipt 与任务结果回流合同，但锁屏状态下没有完成 build 20 的真实授权、横幅、点击和去重手工 Gate。

因此建议冻结产品承诺为：**quota-first Resident + Small Quota + Small Pinned + 经过手工验证的 terminal/低额度通知 fallback。** Medium 与 Large 不进入首发承诺。

## 1. quota-first Resident 与 `● N`

### 已确认的源码合同

- Resident 标题固定取 `notchQuotaTitle`，不再因任务运行而改成任务标题。
- Resident 副行固定先显示重置时间；有运行任务时只追加 `● N`。
- live quota 新鲜时显示剩余比例；过期时显示“额度需更新”，不可用时显示“点击刷新”。
- 多 quota bucket 时，Resident 使用窗口身份加百分比，例如 `7 天 · 93% 剩余`；展开态列出其他窗口。

这与用户最初的高价值问题一致：

> 3 秒内知道剩余额度、下次重置时间，并顺带知道是否有任务运行。

### 仍需解锁后验证

源码正确不等于 3 秒扫读通过。尤其要验证文字是否被物理刘海宽度压缩、`● N` 是否被误解为通知数量，以及多窗口身份是否足够清楚。

### 手工验收标准

在 0、1、2、4 个任务与单/双 quota bucket 组合中随机展示 10 次：

- 3 秒内正确说出主要 quota 剩余比例：`>= 90%`。
- 3 秒内正确说出重置时间：`>= 90%`。
- 3 秒内正确说出运行任务数量：`>= 90%`。
- 将 `● N` 误解为未读通知、失败数或排队数：`0 次`。
- 任务启动或结束时，quota 文案位置不得发生明显跳动或被替换。

### 决策

**必须首发。** 若 3 秒测试中 quota 或 reset 正确率低于 90%，先缩短窗口文案或弱化任务计数，不得恢复“任务优先”。

## 2. 任务身份与隐私

### 已确认的正确方向

- 新安装默认 `privacyMode = true`。
- 新安装默认 `showTaskNamesInNotch = false`。
- 隐私开启时任务名称不会通过 Resident 或展开态显示。
- 展开态用稳定的 `任务 A/B + 开始时间 + 运行时长` 提供非语义区分。
- 临时显示任务名只有在 Privacy 关闭时才可用；Privacy 开启时不会被“显示名称 10 秒”绕过。
- terminal Alert 的 Expanded 显示任务 outcome 与运行时长；任务名是否展示继续经过同一隐私门控。

这比“两个任务都叫任务名称已隐藏”更可用，也避免拿项目名、工作目录或 prompt 充当匿名身份。

### 仍存在的用户预期冲突

Small Pinned 默认只能显示 generic 的“每日例程”。用户若希望桌面明确写“每日 Gmail 审查”，必须关闭 Privacy 并单独允许固定入口标题。安全默认值正确，但首次用户可能以为“我明确保存的标题为何仍不显示”。

首发不应暗中放宽隐私，而应在固定入口设置旁直接解释：

> Privacy 开启时，桌面 Widget 只显示“每日例程”；关闭 Privacy 并允许显示固定入口名称后，才会显示自定义标题。

### 手工验收标准

- 干净安装后，Resident、Expanded、所有 Widget、通知与辅助功能文本中的任务名、prompt、路径、命令及自定义固定入口标题暴露数为 `0`。
- 两个并行任务在隐私态可凭开始时间区分，A/B 顺序在同一任务生命周期内保持稳定。
- Privacy 开启时不存在临时显示名称入口；关闭 Privacy 且任务名仍未授权时，临时显示 10 秒后在 `10 ± 1 秒` 自动恢复。
- terminal Alert/通知点击回流在 Privacy 开启时显示 generic 任务名，但 outcome 和运行时长仍可理解。

### 决策

**隐私合同可保留。** 不为“知道具体哪个任务”引入目录名或项目名旁路。若用户需要语义身份，应明确选择关闭 Privacy 或未来使用本机自定义 alias，而不是伪装匿名。

## 3. 四种 Widget 是否有真实价值

### Small Quota：明确 Go

独立 **Job To Be Done**：无需打开 Codex，查看 quota、reset 与 freshness。

build 20 源码为深色表面显式设置浅色主文字，并为 Widget 固定背景，stale 时不再把旧百分比突出为当前值。这解决了信息可信度与深色文字消失的主要结构风险。

但当前锁屏，不能把深色可读性记为视觉 Pass。解锁后必须在真实桌面验证：

- Light、Dark、跟随系统三种模式下，标题、百分比、重置时间与 freshness 均清晰可读。
- 60 cm 观看距离、3 秒内，百分比和 reset 正确率均 `>= 90%`。
- stale 状态不得被误读为仍有某个剩余百分比，误读率 `< 10%`。
- VoiceOver 一次读出窗口、freshness、百分比与 reset，顺序符合视觉层级。

### Small Pinned：Conditional Go

独立 **Job To Be Done**：一键打开用户明确保存的对话或每日例程。

它不声称知道 Gmail 是否已审查、Scheduled 是否运行或 Daily Brief 是否生成，边界正确。保留条件是用户确实存在高频固定入口。

手工 Gate：

- 点击后打开保存的 HTTPS 目标；无效或已移除链接提供可恢复提示。
- 7 天内至少 4 天使用，或至少 5 次成功打开；否则不作为 Gallery 推荐项。
- generic 标题与自定义标题的 Privacy 行为符合设置说明。

### Medium Quota + Pinned：首发删除

Medium 只是把两个 Small 并排，没有新增任务或更强数据能力。它唯一可能的价值是节省一个桌面 Widget 位，但当前没有 diary 证据证明用户会同时长期保留两个 Small。

开放条件：7 天内用户在 `>= 5 天` 同时使用 Small Quota 与 Small Pinned，并明确认为两个 Small 占位过多。否则停止发布 Medium。

### Large 工作概览：首发删除

Large 汇总 quota、运行任务数量与固定入口，实质是控制中心的桌面复制。任务数量来自快照，不能承诺与 Resident 的 5 秒轮询同等实时；“工作概览”容易让用户误以为应用理解任务内容或能持续更新。

开放条件：

- 至少两个分区各在 7 天内被使用 `>= 4 天`。
- 任务计数过期/错误率 `< 5%`。
- 用户能在 3 秒内说出 Large 相比 Small Quota 新增的独立价值。

任何条件不满足即停止 Large。

### 首发尺寸结论

**Gallery 首发只保留两个 Small：Small Quota 与 Small Pinned。** build 20 源码仍把四个 Widget 全部加入 bundle，因此“四种 Widget 全首发”不能通过本轮用户价值审查。

## 4. 控制中心设置负担

控制页仍包含七组内容：

1. 顶部显示：Resident、一次性 Alert、系统通知 fallback。
2. 隐私：Privacy、任务名、固定入口名。
3. 外观与启动：三种外观、五个强调色、登录启动。
4. 低额度提醒阈值。
5. 固定入口名称与 URL。
6. 系统通知授权、测试与上次点击 receipt。
7. 授权/本机开发版/未来买断说明。

对一个常驻 companion 来说，这仍然过载。用户高频目的只有：看/刷新 quota、设置固定入口、调整隐私、选择提醒方式。

### 必须收缩

- 主控制页只保留 quota + refresh、固定入口、Privacy 状态与三个表面开关。
- 低额度阈值归入“提醒”的二级设置。
- 登录启动归入“高级设置”。
- 五个强调色移除首发，或放入高级外观。
- 通知测试与 click receipt 放入 Diagnostics，不作为日常主设置。
- “本机开发版/一次买断”移到 About；它不帮助用户完成任何当前任务。
- Widget 同步卡只在失败或 stale 时出现，正常状态不长期占位。

### 手工验收标准

首次使用者在不被提示的情况下完成以下任务：刷新 quota、关闭 Resident、更换固定入口、确认 Privacy、允许通知。

- 每项在 `<= 5 秒` 内找到。
- 首次点击正确率 `>= 80%`。
- 每项错误点击不超过 1 次。
- 第一屏无需滚动即可看到 quota、reset、freshness、Privacy 与固定入口状态。

### 决策

**控制中心不阻止个人开发者继续 dogfood，但阻止把 build 20 称为精简首发体验。** 在用户测试前至少移走强调色、授权商业说明和常驻诊断项。

## 5. 通知 generic 与隐私授权

### 已确认的源码合同

- 任务 terminal 通知始终使用 generic 标题，例如“Codex 任务已完成/运行失败”，不写任务名称。
- 通知 payload 包含 outcome、运行时长与安全的本机 task deep link。
- 用户点击通知后，WorkPulse 用 task ID 查找近期本机 terminal 结果并展开具体 outcome 与时长。
- Expanded 只有在本机隐私授权允许时显示任务名；否则显示“任务名称已隐藏”。
- build 20 会移除旧版本遗留的 task terminal pending/delivered 通知，避免历史敏感标题继续留在通知中心。
- 代码记录 request/action receipt，并在控制页区分“尚未记录系统通知点击”。

这个 privacy 取舍符合通知作为锁屏/旁观者可见表面的用户预期。设置中的“显示任务名称”不应影响系统通知，建议在文案中明确写“系统通知始终不显示任务名称”。

### 通知是否真的有用

通知只在以下情境有明显增量价值：

- 用户已离开 Codex；
- 顶部 Alert 不可达或用户不活跃；
- 事件是任务完成、失败、中止或真实低额度 crossing；
- 点击后 outcome/时长足以帮助用户决定是否回到 Codex。

如果用户正在看 Codex、只是普通 refresh，或通知只说“状态已更新”，则不值得打扰。generic 不等于无价值，前提是标题包含明确 outcome，body 包含时长或 quota + reset，并且点击能回到该条结果。当前源码合同满足这一方向，但系统呈现仍未验收。

### 解锁后必须完成的手工 Gate

1. `notDetermined`：用户明确点击“允许”才请求授权；不在启动时突袭弹窗。
2. `denied`：不声称通知可用，Resident/菜单栏仍能工作。
3. authorized + app foreground：预览通知真实出现；不重复触发顶部 Alert 与通知。
4. app background / 用户不活跃：terminal 通知横幅或 Notification Center 条目出现，文案 generic 且含明确 outcome。
5. 点击默认通知或“查看”：回到 WorkPulse，展开同一 task 的 outcome 与时长；Privacy 开启时任务名暴露为 0。
6. 同一 terminal transition 最多一个主动表面，重复通知率为 0。
7. 普通 quota refresh 产生 0 条通知；只有 fresh threshold crossing 触发。
8. `UNUserNotificationCenter.add` 成功只记录“系统已接收请求”，不得等同“用户已看到”。

### 停止条件

- 若 10 个工作日任务 terminal/低额度事件少于 2 次，或用户从未通过通知回到任务结果，不继续扩展通知体系，只保留基础 fallback。
- 任一敏感任务名在 Privacy 开启时出现在通知/锁屏，通知发布 Gate 立即失败。
- 通知点击无法稳定对应同一 task outcome，停止宣称“打开这条任务结果”，降级为 generic WorkPulse 状态入口。

## 6. 必须修、可以删、手工 Gate

### 必须修或必须在首发前关闭

- Widget Gallery 从四种收缩为 Small Quota + Small Pinned。
- 控制中心主设置移走五色强调、授权/买断说明与常驻诊断信息。
- 设置文案明确：系统通知始终 generic；固定入口自定义标题受 Privacy 影响。
- 解锁后完成 Dark Widget 与通知 click/open 手工 Gate。

### 可以删除

- Medium Quota + Pinned，除非用户 diary 证明占位需求。
- Large 工作概览，除非多分区使用频率与任务 freshness 证明价值。
- 主控制页的通知测试/receipt、Widget 正常同步卡、商业授权说明。
- 首发五种强调色。

### 已可保留

- quota-first Resident 与 `● N`。
- 多 bucket 的窗口身份与展开明细。
- Privacy 默认开启、任务名默认关闭。
- 隐私态 A/B + 开始时间 + 运行时长。
- Small Quota 的 stale 降级。
- Small Pinned 的手动 HTTPS 入口边界。
- generic terminal 通知 + 隐私门控的任务结果 Expanded。
- Resident、一次性 Alert、系统通知 fallback 三个独立开关。

## 7. 发布边界

本轮已确认：

- 最终 ZIP hash 与提供值一致。
- 本机安装版本为 `0.3.1 (20)`。
- Widget runtime flag 存在。

这些只支持“本机安装包身份已核对”，不等于视觉和系统交互验收完成。

**外部分发不在本机完成范围。** App Store 上架、Developer ID 外部分发、notarization、stapling、其他 Mac 安装与升级迁移均未在本轮审查，也不阻止用户把它作为个人本机 companion 使用。若未来面向他人分发，应另设独立 Release Gate，不能复用本机安装成功作为证据。

## 最终 Go / No-Go

| 范围 | 决定 | 条件 |
|---|---|---|
| 个人本机继续使用 Resident/菜单栏 | **Conditional Go** | 解锁后完成一次 3 秒 glance smoke |
| Small Quota | **Conditional Go** | Dark/Light 真机可读性与 stale 语义通过 |
| Small Pinned | **Conditional Go** | 链接可打开；7 天有真实使用；Privacy 文案清楚 |
| Medium / Large Widget 首发 | **No-Go** | 缺少独立用户任务与 diary 证据 |
| terminal / quota 系统通知 | **Conditional No-Go** | 必须完成授权、真实呈现、去重、点击回流与隐私手工 Gate |
| 四种 Widget + 当前控制中心作为精简首发 | **No-Go** | 先收缩 Gallery 与主设置 |
| 外部分发 | **Out of scope** | 另做签名、公证、安装与迁移 Gate |

最终建议：**不要再增加功能。解锁后只做三项手工验收：Resident 3 秒扫读、两个 Small 的 Light/Dark 可读性、通知真实点击回流。随后以两个 Small 作为首发范围，Medium、Large 与低频设置继续关闭。**
