# WorkPulse 用户需求复审 V1：高频价值、3 秒扫读与能力门槛

> 日期：2026-08-12  
> 角色：用户需求研究智能体  
> 范围：Quota Resident、一次性顶部 Alert、Widget 首发组合、Daily Brief 与 Needs You  
> 证据：本轮当前运行态、`product_reaudit_v1.md`、`uiux_reaudit_v1.md`、`challenge_v1.md`、当前 Widget 与投递源码  
> 约束：本轮只复审需求，不修改产品源码，也不以竞品数量替代用户价值证据

## 1. 结论先行

四个争议的结论如下：

1. **Resident 在存在多个 quota bucket 时必须显示 bucket/window 身份。** 当前常驻态显示 `Codex 54% 剩余 / 周二 09:58 重置`，点击后才知道是 `Codex 7 天窗口`。这会让用户把某个窗口误认为 Codex 总额度。推荐常驻改为 `7 天 · 54% 剩余 / 周二 09:58 重置`。只有来源确实只有一个 bucket 时，才允许退化为 `Codex · 54%`。
2. **首发只开放 Small Quota 与 Small Pinned Routine 两只 Widget。** 两者分别解决“是否适合继续工作”和“如何最快回到高频对话”，是两个互不重复、已有真实数据或可靠本机入口支撑的任务。Medium Now & Next 和 Large Daily Brief 当前不应进入 Gallery。
3. **Resident 与一次性 Alert 必须独立开关。** “我愿意长期看额度”与“我愿意被事件打断”是两种不同偏好。当前 `overlayEnabled` 同时控制常驻与提醒，迫使用户接受不需要的打扰或放弃需要的提醒。
4. **Daily Brief 与 Needs You 目前都不足以作为真实产品能力上线。** 用户对“每日 Gmail 审查对话的固定入口”有直接需求，但这不等于用户需要 WorkPulse 生成一张 Daily Brief。Needs You 有潜在高损失价值，但当前没有真实 adapter，只有 fixture 与 domain state。两者均须先通过需求门槛和数据门槛。

当前用户价值排序：

1. Quota Resident：高频扫读，已有 live multi-bucket 数据。
2. Small Pinned Routine：用户已明确提出“每日 Gmail 审查对话”常驻桌面，且手动 HTTPS 入口可形成最短闭环。
3. Small Quota Widget：信息价值明确，但与 Resident 有一定重复，需要通过 7 天使用数据验证是否仍值得占桌面位置。
4. Quota Alert：低频、可行动，但必须用户 opt-in，且与 Resident 分离。
5. Needs You：潜在损失最高，但需求频率和真实数据能力均未证明。
6. Daily Brief：概念吸引力高，当前净新增价值和数据能力最低。

## 2. 本轮事实与证据边界

### 2.1 当前运行态

本轮真实运行态的辅助功能文本为：

- Resident：`WorkPulse 常驻状态，Codex 54% 剩余，周二 09:58 重置`。
- Expanded：`Codex 7 天窗口 54% 剩余 · 周二 09:58 重置`，同时混入 `固定入口 未设置`。

这证明 remaining 与 reset 已进入常驻主层级，也证明 bucket 身份目前被推迟到了点击之后。对于同时存在 5 小时和 7 天窗口的用户，点击前仍不能无歧义判断当前读数属于哪个约束。

### 2.2 当前能力

- Quota：可读取 live Codex rate-limit buckets，当前设计允许用户选择 bucket，具备 remaining、window、reset、generatedAt 与 freshness。
- Pinned Routine：只保存用户提供的 HTTPS 入口，不读取 Gmail 内容，不同步 Scheduled 运行状态。
- Needs You：production Widget snapshot 当前固定写入 `needsYou: nil`；真实 adapter 尚未接通。
- Daily Brief：当前只能聚合 quota、手动固定入口和未连接的 Needs You，不具备可信的 Gmail/Scheduled 日次摘要来源。
- Widget 安装：当前 `build/WorkPulse.app` 中没有 `.appex`，所以本轮无法取得 Widget Gallery、桌面驻留或真实点击数据。下面的 Widget 结论是发布组合建议，不是可用性验收结果。

### 2.3 研究限制

本轮没有自然使用 telemetry、7–10 天 diary、真实 Notification Center 投递或安装后的 Widget 行为。用户此前的明确表达可作为强烈的定性信号，但不能推断所有用户的普遍频率。

## 3. 争议一：Resident 是否必须显示 quota bucket 身份

### 决策

**多 bucket 时必须；单 bucket 时可简化。对于当前产品，默认应显示。**

### 为什么这是决策信息，而不是技术元数据

用户看到 `54%` 后真正要决定的是：

- 是否现在开始一个长任务；
- 是短周期窗口先耗尽，还是周周期窗口成为约束；
- 应等待哪个 reset。

如果只显示 `Codex 54%`，用户无法知道 54% 属于 5 小时还是 7 天窗口。`Codex` 只说明来源，不说明约束；在 WorkPulse 的 Codex quota 表面上，它的信息增量低于 `5 小时` 或 `7 天`。

### 推荐信息结构

| 状态 | 左侧主信息 | 右侧信息 |
|---|---|---|
| live，多 bucket | `7 天 · 54% 剩余` | `周二 09:58 重置` |
| live，单 bucket 且窗口已知 | `5 小时 · 54% 剩余` | `今日 16:30 重置` |
| live，窗口未知 | `Codex · 54% 剩余` | `重置时间未知` |
| stale | `7 天额度可能已过期` | `点击刷新` |
| unavailable | `Codex 额度不可用` | `点击重试` |

不要把内部 `limitID` 直接展示给普通用户。窗口身份应使用来源可解释的时长或用户选择的短名称。VoiceOver 需朗读完整来源、窗口、remaining、reset 与 freshness。

### 失效边界

- 若来源长期只返回一个 bucket，且用户在 3 秒测试中不会误解，则视觉上可以省略窗口，但 VoiceOver 和 Expanded 仍保留完整身份。
- 如果显示 bucket 导致 reset 被截断，优先缩短来源词 `Codex`，不能删除 bucket 或 reset。
- 自动切换“最紧张 bucket”若没有解释，可能比固定选择更困惑。V1.1 应默认保留用户选择；如果未来自动切换，必须显示切换原因。

## 4. 争议二：哪两个 Widget 最值得首发

### 决策

**Small Quota + Small Pinned Routine。首发是“只进入 Gallery 的两个选项”，不是要求用户同时添加。**

### Small Quota

用户任务：不打开菜单或 Codex，2 秒内知道哪个窗口还剩多少、何时 reset。

必须只保留三层：

1. bucket/window；
2. remaining；
3. reset 与 freshness 的最短可信表达。

当前 Widget 中“根据来源用量换算、来源、limitID、观察于”等内容抢占 reset 之前的空间，应移入点击后的 quota Expanded 或 VoiceOver。

它与 Resident 存在重复，因此发布后必须验证增量价值。若用户主要在无刘海外屏、隐藏 Resident 或桌面概览中工作，Small Quota 可能仍有独立价值；若 Resident 已满足所有查看需求，Quota Widget 应保留为可选而非默认推荐。

### Small Pinned Routine

用户任务：一次点击返回一个高频 ChatGPT/Codex 对话，例如“每日 Gmail 审查”。

用户已明确表达这一具体需求，这是当前最强的 Pinned 定性证据。它无需 Gmail/Scheduled adapter，只需要：

- 用户自定义名称；
- 有效 HTTPS 目标；
- 一次点击发起打开；
- 清楚标注“本机固定入口”，不展示 last run、next run、未读数或同步成功。

### 为什么不首发 Medium 或 Large

- Medium Now & Next 的 `Needs You` 在 production snapshot 中为 `nil`，一半区域会永久显示“尚未连接”。
- Medium Quota + Pinned 虽能复用两项真实能力，但会把两个点击意图压进一个卡片，且没有证明它比两只 Small 更节省时间。
- Large Daily Brief 当前不是 Brief，而是“未连接 Needs You + 手动入口 + quota”的导航汇总，持续展示能力缺口会降低信任。

### Widget 发布顺序

1. 先完成签名 `.appex`、App Group、Gallery 添加与 live/stale/unavailable E2E。
2. 同一 build 只暴露 Small Quota 和 Small Pinned。
3. 运行 7 天 diary，再决定哪一只成为 Gallery 推荐位；不要预设两者同等高频。

## 5. 争议三：Resident 与一次性 Alert 是否独立开关

### 决策

**必须拆分。** 推荐设置结构：

1. `常驻显示额度`：只控制 Resident。
2. `在顶部显示重要提醒`：只控制一次性 Alert。
3. `系统通知`：独立授权与偏好；当顶部提醒关闭或不可达时，可成为主动表面。
4. `低额度提醒`：事件类别/阈值偏好，不应等同于是否显示 Resident。

### 用户为什么会选择不同组合

| 组合 | 合理用户意图 |
|---|---|
| Resident 开，Alert 关 | 想自行查看额度，不接受顶部被动打断 |
| Resident 关，Alert 开 | 不想长期占据刘海，但愿意接收重要事件 |
| 两者都开 | 高频依赖额度，也希望即时响应事件 |
| 两者都关 | 只用 Widget/Menu Bar，或正在演示、共享屏幕 |

当前单一 `overlayEnabled` 同时进入 `setResident`、事件 DeliveryContext 和 quota threshold 路由，无法表达上述偏好。通知授权状态也不等同于用户希望它承担所有事件。

### 最小交互原则

- 同一事件只能有一个主动 owner。顶部 Alert 可见时不再发 banner；不可达时才 handoff 给通知。
- “系统接受通知请求”不等于“用户已看到”，因此不能用 accepted 状态吞掉后续的持久 Menu Bar/Inbox 可发现性。
- 关闭 Resident 后，Alert 超时应回到 hidden，而不是恢复 Resident；关闭 Alert 不得改变 Resident。
- 第一次开启 Alert 时再解释事件类别与隐私，不在首次启动就请求通知权限。

## 6. 争议四：Daily Brief / Needs You 是否有足够真实需求和数据能力

### 6.1 Daily Brief

**当前结论：需求未被证明，数据能力不成立，No-Go。**

已证明的是：用户希望把“每日 Gmail 审查对话”作为桌面常驻入口。未证明的是：

- 用户需要 WorkPulse 再生成一份日次摘要；
- 一张 Large 卡片比直接打开固定对话更省时间；
- WorkPulse 能读取今天最新一次 Scheduled/Gmail 结果；
- 内容生成时间、覆盖范围、缺失来源和 freshness 可被可信表达。

在 verified adapter 出现前，正确方案是 Small Pinned 打开用户指定的对话，不是把手动入口包装成 Daily Brief。

Daily Brief 的能力门槛至少为：

- 一个经过验证的日次结果来源，能够定位“今天这一次”的结果，而非只打开管理页；
- 明确 generatedAt、freshUntil、覆盖范围和部分失败；
- 至少两个真实且可行动的信息项，或一个真实来源中至少两个可独立处理的摘要项；
- 每一项点击都有可靠下一步；缺失来源时隐藏，不用 `0` 或“尚未连接”伪装健康。

### 6.2 Needs You

**当前结论：潜在价值高，但自然发生频率和 live 数据能力都未证明，No-Go。**

Needs You 解决的是错过 approval、input、work-loss-risk failure 或 quota-paused 造成的等待与损失。它可能不高频，但一次遗漏的损失可能很高，因此不能只按日均点击排序。

当前 domain ledger、去重、snooze 和 fixture 只能证明状态模型可以被测试，不能证明：

- WorkPulse 能从真实 Codex 状态准确识别 transition；
- 能可靠回到正确任务上下文；
- 用户实际经常错过这些事件；
- 顶部 Alert 比 Codex 自带提示或系统通知更快且更少打扰。

生产启用前必须同时通过：

1. 需求门槛：自然 diary 证明存在可避免的等待或损失。
2. 数据门槛：真实 adapter 能区分四类事件、fresh/terminal/conflict，并提供可审计 evidence。
3. 投递门槛：overlay requested、visibly presented、notification handed off、user opened 分离；不可见的 Overlay 不得吞掉 fallback。
4. 价值门槛：提醒减少发现延迟，且误报、重复和无行动通知没有抵消收益。

## 7. 关键假设

| ID | 假设 | 当前信心 | 若错误的影响 |
|---|---|---|---|
| H1 | 用户需要在不展开的 3 秒内区分 5 小时与 7 天 bucket | 高；当前 multi-bucket + 旧文案歧义直接支持 | 错判可用 headroom，Resident 失去决策价值 |
| H2 | remaining + reset 会改变用户是否启动长任务的决定 | 中高；用户明确指出这两项有价值 | 若只浏览不行动，quota 不应复制到所有表面 |
| H3 | “每日 Gmail 审查”固定入口至少每周使用 4 天 | 中；有明确表达但无 diary | Pinned Widget 占桌面但很少点击 |
| H4 | Resident 与 Alert 的偏好存在真实分离 | 高；两种形态、打扰成本和当前耦合矛盾明显 | 若不存在，设置复杂度被高估 |
| H5 | Daily Brief 比固定入口提供净新增价值 | 低 | Large Widget 成为重复导航和空态集合 |
| H6 | Needs You 虽低频但能显著减少等待或工作损失 | 中低；问题合理但无本机自然数据 | 高成本 adapter 与提醒系统无人使用 |
| H7 | Small Quota 在已有 Resident 后仍有独立场景 | 中低 | 首发第二个 quota 表面只是重复信息 |

## 8. 最小可验证实验与停止条件

### E1：Resident 3 秒扫读测试

方法：用 live-like 的 5 小时/7 天双 bucket、fresh/stale/unavailable 共 8 张状态，比较 `Codex 54%` 与 `7 天 · 54%`。每张只显示 3 秒，要求回答“哪个窗口、剩多少、何时重置、下一步是什么”。

通过条件：

- 至少 20 个 fresh 双 bucket 试次中，bucket/remaining/reset 三项全对率 ≥90%；
- fresh 状态的 bucket 误认 = 0；
- stale/unavailable 状态中，用户不把旧数值当当前值；
- 加入 bucket 后没有出现截断或明显增加扫读时间。

停止/回退条件：若来源只能稳定提供一个 bucket，且省略身份的全对率与显示身份相同，同时显示身份造成 reset 截断，允许单 bucket 态省略；多 bucket 态不允许回退。

### E2：两只 Small Widget 的 7 天 diary

方法：完成可安装 `.appex` 后，让目标用户自由添加 Small Quota 和 Small Pinned；仅本地记录打开次数、时间和成功/失败，不记录对话标题或内容。每天用一句话记录“这次查看是否改变决定”。

通过条件：

- Small Pinned：7 天中至少 4 天使用，目标打开请求成功率 100%，且没有把“已交给系统”误解为“已到达正确对话”；
- Small Quota：至少 3 次主动查看，并至少 1 次改变开始、缩小或等待任务的决定；
- 任一 Widget 的错误目标、伪 fresh、敏感信息暴露 = 0。

停止条件：

- Small Pinned 少于 3 个不同日期使用，或多数时候仍从 Codex 历史列表进入，则不占首发推荐位；
- Small Quota 14 天内没有一次决策变化，且 Resident 已覆盖全部查看，则保留为可选 Widget，不继续投入更多尺寸；
- 任一 Widget 无法稳定安装或点击闭环失败，停止做 Medium/Large，先修复载体。

### E3：Resident / Alert 偏好分离测试

方法：用四种组合的设置原型和 6 个明确标注的模拟事件，测试用户能否预测“平时是否常驻、事件从哪里出现、Alert 超时后回到哪里”。

通过条件：

- 设置完成时间 ≤30 秒；
- 行为预测正确率 ≥90%；
- 四种组合均可持久化且行为符合预期；
- 同一事件主动表面重复率 = 0。

停止/合并条件：只有当至少 80% 目标用户始终选择同一耦合组合、且没有人需要“仅 Resident”或“仅 Alert”时，才考虑在 UI 上提供简化预设；底层偏好仍应分离。当前已有明确形态区分，不满足合并条件。

### E4：Daily Brief 需求验证

方法：先不接 Gmail 权限。连续 7 天让用户在“直接打开固定对话”和“查看一张明确标注为研究模拟的 Brief”之间自由选择，并记录 Brief 中实际想看到的信息以及是否产生下一步行动。

通过条件：

- 7 天至少 4 天主动选择 Brief；
- 至少 2 次从 Brief 直接进入可执行下一步；
- 用户能够明确说出 Brief 比固定入口多解决的一个问题；
- 随后才评估 verified adapter，而不是先申请 Gmail 权限。

停止条件：若用户主要使用固定入口、Brief 只是重复同一对话输出，或 7 天内没有两次可行动结果，则停止 Large Daily Brief，保留 Small Pinned。

### E5：Needs You 需求与数据双门槛

方法：先做 10 个工作日自然 diary，不主动制造提醒。记录 Codex 因 approval/input/failure/quota pause 等待的次数、发现延迟、是否已在 Codex 前台、实际损失。通过需求门槛后，再用已标注 transition 做 adapter replay 与小规模 live shadow mode，shadow 期间不主动提醒。

需求通过条件：以下任一成立：

- 10 个工作日出现 ≥3 次可行动等待，且其中至少 1 次发现延迟 >5 分钟；
- 出现 ≥1 次导致 >15 分钟可避免等待或有工作丢失风险的事件。

数据与价值通过条件：

- approval/input/work-loss-risk/quota-paused 分类可审计；高风险误报 = 0；
- terminal/stale/conflict 不触发主动提醒；
- exact return 或明确 fallback 的成功率达到预先定义的 Pilot 门槛；
- Pilot 中提醒显著缩短发现延迟，且重复主动投递 = 0。

停止条件：若 10 个工作日少于 2 次事件且没有明显损失，不建设全套主动提醒，只保留未来 capability；若 shadow mode 不能可靠区分 fresh transition 与历史/冲突状态，不进入 Alert 或 Notification。

## 9. 给团队的产品调整顺序

1. 先把 Resident 改为 bucket + remaining + reset，并正确处理 stale。
2. 将 `overlayEnabled` 拆为 Resident、Alert 与 Notification 三类偏好/能力状态。
3. Quota Expanded 只解释 quota；固定入口不再占额度详情的一行。
4. 完成真正可安装的 Widget Extension，只暴露 Small Quota 与 Small Pinned。
5. 用 7 天 diary 决定两只 Widget 的推荐顺序，而不是继续扩 Medium/Large。
6. Daily Brief 和 Needs You 保持 capability-gated；先通过 E4/E5，再讨论 UI 完成度。

本轮最终判断：**Quota Resident 与两只 Small Widget 的用户问题成立，但仍需安装与自然使用验证；Resident/Alert 必须拆分；Daily Brief 与 Needs You 当前均 No-Go。**
