import fs from "node:fs";

const source = fs.readFileSync(new URL("../workpulse_mac_desktop_demo.html", import.meta.url), "utf8");
let checks = 0;

function expect(condition, message) {
  if (!condition) throw new Error(`HTML verification failed: ${message}`);
  checks += 1;
}

const script = source.match(/<script>([\s\S]*?)<\/script>/)?.[1];
expect(Boolean(script), "inline script must exist");
new Function(script);
checks += 1;

expect(source.includes('data-theme-choice="light"') && source.includes('data-theme-choice="dark"'), "light and dark choices must exist");
expect(source.includes('id="privacy-toggle"'), "Privacy Mode control must exist");
expect(source.includes('id="routine-title-toggle"'), "item title opt-in must exist");
expect(source.includes('id="verified-source-toggle"'), "verified demo gate must exist");
expect(source.includes("手动固定 · 未同步状态"), "manual truth copy must exist");
expect(source.includes("交互演示 · 未连接真实来源"), "verified preview must state that it is not a real connection");
expect(source.includes('data-action="open">查看提醒'), "notch alert must route to a truthful local detail action");
expect(!source.includes('data-action="open">打开审批') && !source.includes('data-action="open">前往审批'), "simulation must not imply it can execute or reach a real approval");
expect(source.includes("一个任务正在等待操作。打开 WorkPulse 查看。"), "notification must use generic copy");
expect(!source.includes("固定对话 · Scheduled"), "manual routine must not claim Scheduled");
expect(!source.includes("<small>封邮件</small>"), "external surfaces must not expose Gmail units");
expect(!source.includes('widget.dataset.widget === "medium" ? "打开当前线程"'), "unverified medium widget must not promise exact return");
expect(source.includes("已发送打开固定入口的请求；演示不会声称已到达正确对话"), "manual open result must stay truthful");
expect(source.includes("Design simulation · 非实时数据"), "prototype must carry an always-visible simulation badge");
expect(source.includes('.widget.large.visible { display: flex; flex-direction: column; }'), "large widget must use the full vertical canvas");
expect(source.includes('grid-template-rows: repeat(2, minmax(0, 1fr))'), "Daily Brief cards must distribute across both rows");
expect(source.includes('.routine-card > .manual-only.next-card { margin-top: 20px; }'), "manual routine must keep deliberate spacing without a fixed empty card height");
expect(source.includes('.privacy .brief-card strong.private-generic'), "privacy-safe Daily Brief titles must remain block-level and readable");
expect(!source.includes("操作返回同一对话"), "prototype must not promise exact thread return");
expect(!source.includes("已打开审批上下文"), "prototype must not count a navigation request as confirmed arrival");

console.log(`WorkPulse HTML verification passed: ${checks} checks`);
