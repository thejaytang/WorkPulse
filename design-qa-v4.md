# WorkPulse V4 Design QA

> 日期：2026-08-11  
> 范围：HTML Mac desktop review demo + SwiftUI native shell

## 结论

视觉方向通过，真实性与交互门控已明显改善。HTML Demo 可用于评审形态、主题和状态切换；Native Shell 可用于本机验证主题、Privacy、Manual Pin、Verified Demo 与 quota probe。两者都不能替代正式 Widget Extension / signed Pilot build。

## HTML Desktop Demo

| 场景 | 结果 | 证据 |
|---|---|---|
| Light + Manual Pin | Pass | `output/html-v4/manual-light.jpeg` |
| Dark + Verified Demo | Pass | `output/html-v4/verified-dark.jpeg` |
| Dark + direct Notch Alert | Pass | `output/html-v4/approval-dark.jpeg` |
| Privacy title override | Pass | Browser DOM + screenshot review |
| Notification generic off/on | Pass | Browser DOM review |
| Alert direct “打开审批” | Pass | Browser DOM review |
| HTML semantic invariants | Pass | 14 automated checks |

已修复：

- Manual routine 默认不再显示 Scheduled / 邮件数 / 自动运行时间。
- 单项标题 opt-in 与 Privacy Mode 分开。
- Verified source 只能由演示开关主动开启，且显式标“演示状态”。
- 通知始终 generic。
- Notch Alert primary action 一步直达“打开审批”。
- Medium Widget 不再承诺“打开当前线程”。
- Light / Dark / System 仍可切换并持久化。

## Native Shell

| 场景 | 结果 | 证据 |
|---|---|---|
| Dark + Manual + Privacy | Pass | `output/native/native-manual-privacy-dark.jpeg` |
| Dark + Verified Demo + Privacy | Pass | `output/native/native-verified-privacy-dark.jpeg` |
| Dark + item title opt-in | Pass | `output/native/native-verified-title-dark.jpeg` |
| Light + Privacy | Pass | `output/native/native-verified-privacy-light.jpeg` |
| Missing URL protection | Pass | CTA disabled in latest implementation |
| Live quota protocol | Pass | redacted App Server probe |

## 尚未通过的视觉 / 平台矩阵

- Latest live quota button GUI：因本轮 Mac 锁屏，待解锁后补图。
- 130% 字号、Increase Contrast、Differentiate Without Color。
- 真 Widget Gallery、Small / Medium desktop rendering。
- 无刘海、刘海、外接显示器、clamshell、Stage Manager、全屏 overlay。
- Notification permission denied / Focus / foreground / background。

## 评审用法

- 评审“长什么样、在哪里出现、如何切换”使用 HTML Demo。
- 评审“macOS 原生控件、主题、隐私和真实 quota 读取”使用 Native Shell。
- 评审 Widget、签名、分发与 Notch overlay 必须等待完整 Xcode 和真机 Gate D。

