# WorkPulse build 23 用户价值与可用性 Delta 审查

> 审查对象：本机安装版 WorkPulse `0.3.1 (23)`  
> 审查时间：2026-08-13（Europe/Oslo）  
> 方法：当前 build 的 Computer Use 截图、辅助功能树与源码合同交叉检查  
> 限制：本轮成功取得 Resident 与 Expanded 的 build 23 新证据；随后 Mac 再次锁屏，因此控制中心、四个 Widget 的新 GUI 截图和 Light/Dark 切换无法在本轮继续捕获。相关结论严格标记为源码确认或待用户 Gate，不冒充视觉验收。

## 最终结论

**build 23 的核心本机 companion 体验已达到 Conditional Go，但四种 Widget 全量首发仍是 No-Go。首发范围应冻结为 quota-first Resident、Small Quota、Small Pinned，以及 generic 的 terminal/低额度提醒。**

与 build 20 相比，明确进步是：

- Resident 的真实运行态已经证明 quota 始终优先，任务只以 `● 2` 附加。
- Expanded 同时展示两个 quota window，并用任务 A/B、开始时间和运行时长保护隐私。
- 控制中心一级设置从七组收缩为五组，低额度阈值并入“顶部显示”，商业授权卡已删除。
- Privacy 默认开启、任务名默认关闭，任务名不会在隐私态被临时显示绕过。

仍未证明的部分是：

- `● N` 对第一次使用者是否无需解释即可理解为“运行任务数”。
- Small/Medium/Large 四种 Widget 是否都有足够高频、独立的用户任务。
- build 23 的控制中心五组在真实窗口中能否让用户 5 秒内找到高频设置。
- Widget 的 Light/Dark、Increase Contrast、VoiceOver 和真实桌面点击路径。

## 当前 UI 证据

### Step 1：Resident，健康度 Good

![build 23 quota-first Resident](evidence/user_completion_delta_v23/01-resident-quota-tasks.jpeg)

真实辅助功能文本为：`7 天 · 61% 剩余，周四 05:34 重置 · ● 2`。

专家 3 秒扫读判断：

- quota window、剩余比例和 reset 的顺序正确，视觉上形成“61%”与“05:34”两个可立即定位的数字锚点。
- 任务不会抢占 quota，`● 2` 的权重也明显低于额度。
- 深色外壳与物理刘海连成一体，当前截图没有出现白色卡片贴在刘海下方的割裂。
- 风险是 `● 2` 缺少语义。熟悉后简洁，首次使用者可能把它理解为未读通知、排队数或错误数。

结论：quota/reset 已通过专家 glance；任务计数仍需首次用户测试。不要为了补语义把常驻文案改回任务名称，最多在 onboarding/tooltip 中解释一次“● = 运行任务”。

### Step 2：Expanded，健康度 Good with limits

![build 23 quota and privacy expanded](evidence/user_completion_delta_v23/02-expanded-privacy-tasks.jpeg)

真实界面同时展示：

- 主窗口：Codex 7 天窗口，61% 剩余，周四 05:34 重置。
- 第二窗口：7 天，100%，周四 12:12 重置。
- 任务 A：12:05 开始，已运行约 9 分钟。
- 任务 B：11:59 开始，已运行约 15 分钟。
- 数据来源、观察时间、任务总数与刷新动作。

优点：

- Expanded 保持 quota-first，没有因为任务出现而改变主标题。
- 两个窗口身份、百分比和 reset 都可见，解决 Resident 单一窗口的解释不足。
- 隐私态不显示任务名、项目名、工作目录或 prompt；A/B + 开始时间足以区分两个并行任务。
- “刷新”是唯一主要动作，信息与动作一致。

限制：

- A/B 是当前排序标签，不是语义身份。用户可以区分行，但仍不知道哪条是“论文审查”或“代码修复”。这是 Privacy 的合理代价，不应偷偷用目录名补偿。
- 任务行目前只提供观察，不提供打开对应任务的动作。对常驻 glance 足够，对“我要立刻回到某任务”并不闭环。
- Footer 字号与灰度较弱，当前截图可读但接近次要信息的下限，仍需 Increase Contrast/VoiceOver 测试。

结论：Expanded 已满足“看 quota + 知道有哪几条任务在跑”的本机需求；不要把它升级为任务管理器。terminal Alert/Notification 点击具体结果是更合适的行动路径。

## 3 秒 glance 最终判断

| 用户问题 | 当前 build 23 | 判断 |
|---|---|---|
| 还剩多少额度？ | `61% 剩余`，主视觉明确 | **Pass（专家检查）** |
| 什么时候重置？ | `周四 05:34 重置`，与百分比分列 | **Pass（专家检查）** |
| 是哪个 quota window？ | Resident 为 `7 天`，Expanded 显示完整 `Codex 7 天窗口` | **Pass** |
| 有几个任务运行？ | `● 2` | **Conditional**，需首次用户理解测试 |
| 是哪些任务？ | Privacy 下为 A/B + 开始时间 | **符合隐私预期，但非语义身份** |
| 数据是否可信/可刷新？ | Expanded 有来源、观察时间和刷新 | **Pass** |

剩余用户 Gate：至少 5 名首次用户，每人随机看 0、1、2、4 个任务和单/双 quota window 场景各 5 次。

- 3 秒内 quota、reset、window identity 正确率均 `>= 90%`。
- 3 秒内任务数量正确率 `>= 80%`。
- 将 `● N` 误解为通知/错误/排队数量的比例 `< 20%`。
- 若任务计数失败，只补一次 tooltip 或把符号改为 `运行 N`；不得让任务重新抢占 quota。

## 控制中心五组设置

源码确认 build 23 的一级设置已收缩为：

1. 顶部显示：Resident、一次性 Alert、系统通知 fallback、低额度阈值。
2. 隐私：Privacy、显示任务名、显示固定入口名。
3. 外观与启动：System/Light/Dark、五个强调色、登录启动。
4. 固定入口：名称与 HTTPS 链接。
5. 系统通知：授权状态、测试、上次点击回流状态。

### 用户价值判断

五组比七组合逻辑，尤其是：

- 低额度阈值并入顶部提醒，减少一个独立概念。
- 商业授权/未来买断卡已删除，不再占据任务空间。
- Resident、Alert、Notification 保持三个独立开关，符合不同打扰成本。
- 通知 click receipt 放在通知组，便于开发期验证“请求系统”与“用户已点击”的差异。

仍然偏重的部分：

- “外观与启动”同时承载主题、五个强调色和登录启动，仍是最典型的低频设置集合。
- 对普通用户，“一次性顶部提醒”与“系统通知兜底”的触发关系需要阅读说明才能理解。
- 正常情况下长期显示 Widget 同步卡与通知 click receipt，会让 companion 看起来像诊断工具。

### 首发建议

- 五组结构可以保留，但“外观与启动”默认折叠或放到 Advanced。
- 五种强调色不作为 onboarding 决策；默认 Ocean，用户主动进入外观后再选。
- Widget 正常同步状态不常驻概览，只在 stale/失败时出现。
- “上次点击已回流”在本机 dogfood 有价值，面向普通用户首发应移到 Diagnostics。

### 待用户 Gate

首次用户完成五项任务：刷新 quota、关闭 Resident、修改低额度阈值、确认 Privacy、设置固定入口。

- 每项 `<= 5 秒` 找到。
- 首次点击正确率 `>= 80%`。
- 每项错误点击 `<= 1`。
- 无需滚动即可看到 quota、reset、freshness 与 Privacy 当前状态。

本轮因 Mac 再次锁屏，控制中心的新 GUI 视觉、滚动长度、焦点顺序不能记为 Pass。

## 四种 Widget 的真实增量价值

### 1. Small Quota：首发 Must

**独立任务：**桌面一眼查看 quota、reset 与 freshness。

它是产品最明确、最高频的 Widget。源码显示：新鲜时突出百分比与 reset；stale 时隐藏旧百分比的主视觉，只显示“额度需更新”；Light/Dark 使用明确的前景与背景色。

首发 Gate：

- Light、Dark、System 三种主题下 3 秒 quota/reset 正确率 `>= 90%`。
- stale 快照被当成当前额度的误读率 `< 10%`。
- 点击后打开 quota 状态/刷新路径，而不是无反馈。

### 2. Small Pinned：首发 Conditional Must

**独立任务：**一键打开用户明确保存的 ChatGPT/Codex 对话或每日例程。

它对“每日 Gmail 审查”这类固定入口有真实价值，但只承诺打开 HTTPS 链接，不承诺 Gmail 已审查、Scheduled 已执行或 Daily Brief 已生成。Privacy 开启时使用 generic 标题，用户明确允许后才显示自定义名称。

保留 Gate：7 天内至少 4 天使用，或至少 5 次成功打开。低于该频率时仍可提供，但不作为 Gallery 推荐首位。

### 3. Medium Quota + Pinned：验证后开放

**潜在增量：**用一个 Medium 同时替代两个 Small，节省一个 Widget 位，并允许两个区域分别点击。

它不是完全没有价值，但增量只在用户同时需要 quota 和固定入口时成立。目前缺少 7 天桌面行为证据。因此不应与两个 Small 同等首发推荐。

开放 Gate：

- 用户在 7 天中 `>= 5 天` 同时保留/使用两个 Small。
- 用户明确反馈两个 Small 占位过多。
- Medium 的两个点击区域在真机上均准确，误触率 `< 5%`。

### 4. Large 工作概览：首发删除/隐藏

**内容：**两个 quota bucket、运行任务数量、固定入口与快照时间。

它比 Medium 新增任务数量和多 bucket 概览，但有三个问题：

- 大部分内容重复 Resident、Expanded 和控制中心。
- 任务数量来自 Widget snapshot，无法承诺与 5 秒任务轮询同等实时。
- “工作概览”容易让用户以为应用理解任务内容，而实际只展示数量与手动入口。

开放 Gate：至少两个独立分区在 7 天内各被使用 `>= 4 天`，任务计数过期/错误率 `< 5%`，且用户能在 3 秒内说出 Large 相比 Small Quota 的新增价值。任一条件失败就继续隐藏。

### Widget 首发范围

| Widget | 首发决定 | 原因 |
|---|---|---|
| Small Quota | **Must** | 核心高频 glance |
| Small Pinned | **Conditional Must** | 明确固定入口任务，有用户原始需求 |
| Medium Quota + Pinned | **After validation** | 只有节省占位的组合价值 |
| Large 工作概览 | **Hide / No-Go** | 重复、freshness 风险、概览承诺过强 |

虽然源码仍把四个 Widget 全部加入 bundle，但“技术上可选”不等于“四个都应首发推荐”。Gallery 首发推荐位只应突出两个 Small；更严格的产品范围可以暂时从 bundle 移除 Medium/Large。

## 主题与隐私

### 主题

- 当前物理刘海截图证明深色 Resident 与硬件连续，Light 主题不应把物理刘海变白。
- 源码将 Light/Dark/System 应用于控制中心、Widget 与无刘海浮动胶囊，并为 Widget 深色表面显式设置浅色前景。
- 物理刘海截图不能证明 Widget 和控制中心的 Light/Dark 一致性。
- 五个强调色必须保持“品牌强调”与 success/warning/critical 语义色分离，不得让低额度状态因主题变化而失真。

主题 Gate：内置刘海 Light/Dark、外接无刘海 Light/Dark、Small Quota/Pinned Light/Dark 共至少 8 个状态；文字与背景达到可读对比，Increase Contrast 下边界不消失，Reduce Transparency 下不依赖模糊光斑表达层级。

### 隐私

- 新安装默认 Privacy 开启，任务名默认关闭。
- 当前 Expanded 真机证据中任务名、项目名、路径和 prompt 暴露数为 0。
- Privacy 态使用 A/B + 时间，能区分行但不承诺语义身份，这是合理边界。
- 固定入口自定义标题必须继续经过单独授权；Widget 与通知的外部可见表面默认 generic。
- terminal Alert/Notification 点击后可以展示 outcome 与时长，但名称仍受隐私门控，符合“结果可行动、标题不泄露”的预期。

隐私 Gate：Resident、Expanded、四个 Widget、notification banner/center/lock screen、控制中心与 VoiceOver 在 Privacy On 下敏感标题暴露数为 0。

## 剩余用户验证 Gate

| Gate | 必须验证 | 通过标准 |
|---|---|---|
| G1 3 秒 glance | quota、reset、window、`● N` | 前三项 `>= 90%`；任务数 `>= 80%`；符号误解 `< 20%` |
| G2 控制中心 | 五个高频设置任务 | 5 秒内找到；首次点击 `>= 80%`；错误点击 `<= 1` |
| G3 Widget 可读性 | 两个 Small 的 Light/Dark/System/stale | quota/reset `>= 90%`；stale 误读 `< 10%` |
| G4 Pinned 行为 | 设置、打开、无效链接、Privacy | 目标打开成功；失败可恢复；敏感标题默认 0 |
| G5 Medium 价值 | 是否节省真实桌面占位 | 7 天中 `>= 5 天` 同时用两个 Small且明确要求合并 |
| G6 Large 价值 | 多分区频率与任务 freshness | 两分区各 `>= 4/7 天`；任务错误/过期 `< 5%` |
| G7 通知 | authorized/denied、真实呈现、去重、点击回流 | 同一事件一个主动表面；点击到同一 outcome；Privacy 暴露 0 |
| G8 Accessibility | VoiceOver、键盘、Increase Contrast、Reduce Motion | 读序/焦点正确；Expanded 不抢焦点；状态变化可感知 |

## 最终首发范围

**必须首发**

- quota-first Resident：window + remaining + reset。
- 任务数量 `● N`，但只作为次级提示。
- quota-first Expanded：多个 bucket + 隐私化任务 A/B + refresh。
- Small Quota。
- Small Pinned。
- Privacy 默认开、任务名默认关。
- Resident、一次性 Alert、系统通知 fallback 独立控制。
- generic terminal/低额度提醒；点击后以隐私门控展示 outcome/时长。

**验证后开放**

- Medium Quota + Pinned。
- 任务名临时显示与自定义 alias 的更复杂方案。
- 五种强调色作为普通用户设置。

**首发隐藏或删除**

- Large 工作概览。
- 主控制页的长期正常 Widget 同步卡。
- 普通用户可见的 notification click receipt 诊断信息。
- 任何 Daily Brief、Gmail 已处理、Scheduled 已运行等没有真实 adapter 的状态承诺。

## 最终 Go / No-Go

| 范围 | 结论 |
|---|---|
| 本机 quota-first Resident / Expanded | **Go for dogfood；Conditional Go for first-user pilot** |
| Privacy 默认与当前任务展示 | **Go，完整跨表面 Gate 待做** |
| 五组控制中心 | **结构 Conditional Go；真实 5 秒任务与视觉仍待验证** |
| Small Quota | **首发 Must** |
| Small Pinned | **首发 Conditional Must** |
| Medium | **验证后开放** |
| Large | **No-Go / 首发隐藏** |
| 四种 Widget 全量首发 | **No-Go** |

最终建议：**停止扩功能，以两个 Small 为 Widget 首发范围。下一轮只做 G1、G2、G3、G7 四个真人/真机 Gate；这些 Gate 关闭前，不再用更多尺寸、主题或控制项替代真实用户价值证据。**
