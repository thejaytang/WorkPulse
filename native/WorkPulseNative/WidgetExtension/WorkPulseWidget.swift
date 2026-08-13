import SwiftUI
import WidgetKit
import WorkPulseCore

private let snapshotFilename = "widget.json"

struct WorkPulseWidgetEntry: TimelineEntry {
    enum LoadState {
        case available(WidgetSnapshot)
        case empty
        case corrupt
        case unsupported
    }

    let date: Date
    let state: LoadState
}

struct WorkPulseWidgetProvider: TimelineProvider {
    private struct SnapshotSchemaHeader: Decodable {
        let schemaVersion: Int
    }

    func placeholder(in context: Context) -> WorkPulseWidgetEntry {
        let now = Date()
        let routine = PinnedRoutine(
            displayTitle: "每日例程",
            lastRunAt: nil,
            nextRunAt: nil,
            attentionCount: 0,
            state: .manual,
            privacyClass: .generic,
            capability: .manualPin
        )
        let quota = QuotaSnapshot(
            usedPercent: 36,
            windowDurationMinutes: 300,
            resetsAt: now.addingTimeInterval(2 * 3_600),
            sourceLabel: "Widget Gallery",
            provenance: .demo,
            generatedAt: now,
            freshUntil: now.addingTimeInterval(10 * 60)
        )
        return WorkPulseWidgetEntry(
            date: now,
            state: .available(SnapshotFactory.makeWidgetSnapshot(
                routine: routine,
                quota: quota,
                generatedAt: now,
                freshUntil: now.addingTimeInterval(10 * 60),
                hasValidPinnedTarget: true,
                quotaBuckets: [quota],
                runningTasks: RunningTaskSummary(
                    count: 1,
                    observedAt: now,
                    freshUntil: now.addingTimeInterval(10 * 60)
                )
            ))
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (WorkPulseWidgetEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : load())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WorkPulseWidgetEntry>) -> Void) {
        let entry = load()
        let fallback = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now
        var entries = [entry]
        if case .available(let snapshot) = entry.state {
            let quotaDates = snapshot.quotaBuckets.flatMap { [$0.freshUntil, $0.resetsAt] }
            let transitionDates = Array(Set(([
                snapshot.freshUntil,
                snapshot.quota?.freshUntil,
                snapshot.quota?.resetsAt,
                snapshot.runningTasks?.freshUntil
            ] + quotaDates)
                .compactMap { $0 }
                .map { $0.addingTimeInterval(1) }
                .filter { $0 > entry.date && $0 < fallback }))
                .sorted()
            for date in transitionDates {
                entries.append(WorkPulseWidgetEntry(date: date, state: entry.state))
            }
        }
        // Future entries make fresh→stale and reset boundaries visible even if
        // WidgetKit delays the next provider reload. The host still refreshes
        // the underlying snapshot independently.
        completion(Timeline(entries: entries, policy: .after(fallback)))
    }

    private func load() -> WorkPulseWidgetEntry {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: WorkPulseRuntimeConfiguration.appGroupIdentifier()
        ) else {
            return WorkPulseWidgetEntry(date: .now, state: .empty)
        }
        let fileURL = container.appendingPathComponent(snapshotFilename)
        guard let data = try? Data(contentsOf: fileURL) else {
            return WorkPulseWidgetEntry(date: .now, state: .empty)
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let header = try? decoder.decode(SnapshotSchemaHeader.self, from: data) else {
            return WorkPulseWidgetEntry(date: .now, state: .corrupt)
        }
        guard header.schemaVersion == WidgetSnapshot.currentSchemaVersion else {
            return WorkPulseWidgetEntry(date: .now, state: .unsupported)
        }
        guard let snapshot = try? decoder.decode(WidgetSnapshot.self, from: data) else {
            return WorkPulseWidgetEntry(date: .now, state: .corrupt)
        }
        return WorkPulseWidgetEntry(date: .now, state: .available(snapshot))
    }
}

private struct WidgetUnavailableView: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: "waveform.path.ecg")
                .font(.headline)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

private struct QuotaPulseView: View {
    let entry: WorkPulseWidgetEntry

    var body: some View {
        switch entry.state {
        case .available(let snapshot):
            if let quota = snapshot.quota, let remaining = quota.remainingPercent {
                Group {
                    if quota.provenance == .demo || quota.provenance == .deterministicFixture {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("额度示例").font(.headline)
                                Spacer()
                                Text("非实时")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                            Text("示例 \(Int(remaining.rounded()))% 剩余")
                                .font(.system(size: 30, weight: .semibold, design: .rounded))
                            Text("组件库预览 · 添加后由 WorkPulse 写入真实额度")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else if PulseWidgetCopy.isCurrent(quota, at: entry.date) {
                        VStack(alignment: .leading, spacing: 9) {
                        HStack {
                            Text(windowLabel(quota.windowDurationMinutes)).font(.headline)
                            Spacer()
                            Text("已更新")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        Text("\(Int(remaining.rounded()))% 剩余")
                            .font(.system(size: 34, weight: .semibold, design: .rounded))
                        if let reset = quota.resetsAt {
                            Label("\(reset.formatted(date: .omitted, time: .shortened)) 重置", systemImage: "clock")
                                .font(.caption.weight(.medium))
                        } else {
                            Text("重置时间未知")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Text("\(quota.limitID ?? "Codex") · 观察于 \(quota.generatedAt.formatted(date: .omitted, time: .shortened))")
                            .font(.caption2).foregroundStyle(.secondary)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                        Label("Codex 额度", systemImage: "exclamationmark.arrow.triangle.2.circlepath")
                            .font(.headline)
                        Text("额度需更新")
                            .font(.title2.weight(.semibold))
                        Text("上次读数 \(Int(remaining.rounded()))% · 点按打开 WorkPulse 刷新")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
                .widgetURL(URL(string: "workpulse://usage"))
                .containerBackground(.fill.tertiary, for: .widget)
            } else {
                WidgetUnavailableView(title: "额度不可用", detail: "当前来源没有提供 Codex 额度。")
            }
        case .empty:
            WidgetUnavailableView(title: "等待 WorkPulse", detail: "打开应用以生成脱敏快照。")
        case .corrupt:
            WidgetUnavailableView(title: "快照不可用", detail: "打开 WorkPulse 重新生成。")
        case .unsupported:
            WidgetUnavailableView(title: "需要更新", detail: "快照版本与 Widget 不兼容。")
        }
    }

    private func windowLabel(_ minutes: Int?) -> String {
        guard let minutes else { return "窗口未知" }
        if minutes % 1_440 == 0 { return "\(minutes / 1_440) 天窗口" }
        if minutes % 60 == 0 { return "\(minutes / 60) 小时窗口" }
        return "\(minutes) 分钟窗口"
    }
}

private struct QuickView: View {
    let entry: WorkPulseWidgetEntry

    var body: some View {
        switch entry.state {
        case .available(let snapshot):
            HStack(spacing: 16) {
                Link(destination: URL(string: "workpulse://usage")!) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Codex 额度", systemImage: "gauge.with.dots.needle.50percent")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(quotaTitle(snapshot.quota))
                            .font(.title2.weight(.semibold))
                            .monospacedDigit()
                        Text(quotaDetail(snapshot.quota))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                Divider()
                Link(destination: URL(string: "workpulse://routine/\(snapshot.routineID.uuidString)")!) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("固定入口", systemImage: "pin.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(isGalleryPreview(snapshot)
                            ? "示例入口"
                            : snapshot.hasValidPinnedTarget ? snapshot.routineTitle : "设置固定入口")
                            .font(.title3.weight(.semibold))
                            .lineLimit(2)
                        Text(isGalleryPreview(snapshot)
                            ? "组件库预览 · 非实时"
                            : snapshot.hasValidPinnedTarget
                                ? "手动入口 · 不推断 Gmail 或 Scheduled 状态"
                                : "在 WorkPulse 中添加 HTTPS 链接")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
            .containerBackground(.fill.tertiary, for: .widget)
        case .empty:
            WidgetUnavailableView(title: "等待 WorkPulse", detail: "打开应用以生成脱敏快照。")
        case .corrupt:
            WidgetUnavailableView(title: "快照不可用", detail: "打开 WorkPulse 重新生成。")
        case .unsupported:
            WidgetUnavailableView(title: "需要更新", detail: "快照版本与 Widget 不兼容。")
        }
    }

    private func quotaTitle(_ quota: QuotaSnapshot?) -> String {
        guard let quota, let remaining = quota.remainingPercent else { return "尚未连接" }
        if isGalleryPreviewQuota(quota) { return "示例 \(Int(remaining.rounded()))%" }
        guard PulseWidgetCopy.isCurrent(quota, at: entry.date) else { return "需要更新" }
        return "\(Int(remaining.rounded()))% 剩余"
    }

    private func quotaDetail(_ quota: QuotaSnapshot?) -> String {
        guard let quota else { return "打开 WorkPulse 读取额度" }
        if isGalleryPreviewQuota(quota) { return "非实时 · 添加后读取真实额度" }
        guard PulseWidgetCopy.isCurrent(quota, at: entry.date) else { return "快照可能已过期 · 点按刷新" }
        guard let reset = quota.resetsAt else { return "重置时间未知" }
        return "\(windowLabel(quota.windowDurationMinutes)) · \(reset.formatted(date: .omitted, time: .shortened)) 重置"
    }

    private func windowLabel(_ minutes: Int?) -> String {
        guard let minutes else { return "窗口未知" }
        if minutes % 1_440 == 0 { return "\(minutes / 1_440) 天" }
        if minutes % 60 == 0 { return "\(minutes / 60) 小时" }
        return "\(minutes) 分钟"
    }

    private func isGalleryPreview(_ snapshot: WidgetSnapshot) -> Bool {
        snapshot.quota?.provenance == .demo || snapshot.quota?.provenance == .deterministicFixture
    }

    private func isGalleryPreviewQuota(_ quota: QuotaSnapshot) -> Bool {
        quota.provenance == .demo || quota.provenance == .deterministicFixture
    }
}

private struct PinnedRoutineView: View {
    let entry: WorkPulseWidgetEntry

    var body: some View {
        switch entry.state {
        case .available(let snapshot):
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Image(systemName: "pin.fill")
                        .foregroundStyle(.secondary)
                    Text("固定例程")
                        .font(.headline)
                }
                Text(isGalleryPreview(snapshot)
                    ? "示例入口"
                    : snapshot.hasValidPinnedTarget ? snapshot.routineTitle : "设置固定入口")
                    .font(.title3.weight(.semibold))
                    .lineLimit(2)
                Spacer(minLength: 2)
                Text(isGalleryPreview(snapshot)
                    ? "组件库预览 · 非实时"
                    : !snapshot.hasValidPinnedTarget
                        ? "添加 HTTPS 对话链接"
                        : snapshot.routineCapability == .manualPin
                        ? "手动入口 · 未同步运行状态"
                        : "状态以 WorkPulse 为准")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .widgetURL(URL(string: "workpulse://routine/\(snapshot.routineID.uuidString)"))
            .containerBackground(.fill.tertiary, for: .widget)
        case .empty:
            WidgetUnavailableView(title: "等待 WorkPulse", detail: "打开应用设置一个固定例程。")
        case .corrupt:
            WidgetUnavailableView(title: "快照不可用", detail: "打开 WorkPulse 重新生成。")
        case .unsupported:
            WidgetUnavailableView(title: "需要更新", detail: "快照版本与 Widget 不兼容。")
        }
    }

    private func isGalleryPreview(_ snapshot: WidgetSnapshot) -> Bool {
        snapshot.quota?.provenance == .demo || snapshot.quota?.provenance == .deterministicFixture
    }
}

private struct DailyOverviewView: View {
    let entry: WorkPulseWidgetEntry

    var body: some View {
        switch entry.state {
        case .available(let snapshot):
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("今日概览")
                            .font(.title2.weight(.semibold))
                        Text(isGalleryPreview(snapshot) ? "组件库预览 · 非实时" : "本机脱敏状态 · 不读取消息正文")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(snapshot.generatedAt.formatted(date: .omitted, time: .shortened))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Divider()

                statusRow(
                    icon: "bolt.horizontal.circle.fill",
                    title: "Codex 任务",
                    detail: taskDetail(snapshot.runningTasks)
                )

                ForEach(Array(visibleQuotaBuckets(snapshot).enumerated()), id: \.offset) { _, quota in
                    Link(destination: URL(string: "workpulse://usage")!) {
                        statusRow(
                            icon: "gauge.with.dots.needle.50percent",
                            title: quotaWindowLabel(quota.windowDurationMinutes),
                            detail: quotaDetail(quota)
                        )
                    }
                }

                Link(destination: URL(string: "workpulse://routine/\(snapshot.routineID.uuidString)")!) {
                    statusRow(
                        icon: "pin.fill",
                        title: isGalleryPreview(snapshot)
                            ? "示例入口"
                            : snapshot.hasValidPinnedTarget ? snapshot.routineTitle : "设置固定入口",
                        detail: isGalleryPreview(snapshot)
                            ? "非实时示例"
                            : snapshot.hasValidPinnedTarget
                                ? "手动固定 · 点按打开；不推断 Gmail 或 Scheduled 状态"
                                : "添加 HTTPS 对话链接"
                    )
                }

                Spacer(minLength: 0)
                Text("只展示可验证的本机任务、额度与固定入口。")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .containerBackground(.fill.tertiary, for: .widget)
        case .empty:
            WidgetUnavailableView(title: "等待 WorkPulse", detail: "打开应用以生成本机脱敏概览。")
        case .corrupt:
            WidgetUnavailableView(title: "概览不可用", detail: "打开 WorkPulse 重新生成快照。")
        case .unsupported:
            WidgetUnavailableView(title: "需要更新", detail: "快照版本与 Widget 不兼容。")
        }
    }

    private func statusRow(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .frame(width: 24)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func taskDetail(_ summary: RunningTaskSummary?) -> String {
        guard let summary else { return "任务监测尚未连接" }
        guard summary.freshness(at: entry.date) == .fresh else { return "任务快照可能已过期 · 打开 WorkPulse 更新" }
        return summary.count == 0 ? "当前没有正在运行的任务" : "\(summary.count) 个任务正在运行 · 名称仅在刘海显示"
    }

    private func visibleQuotaBuckets(_ snapshot: WidgetSnapshot) -> [QuotaSnapshot] {
        let buckets = snapshot.quotaBuckets.isEmpty ? snapshot.quota.map { [$0] } ?? [] : snapshot.quotaBuckets
        return Array(buckets.prefix(2))
    }

    private func quotaDetail(_ quota: QuotaSnapshot) -> String {
        guard let remaining = quota.remainingPercent else { return "当前来源没有提供额度" }
        if quota.provenance == .demo || quota.provenance == .deterministicFixture {
            return "示例 \(Int(remaining.rounded()))% 剩余 · 非实时"
        }
        guard PulseWidgetCopy.isCurrent(quota, at: entry.date) else {
            return "额度快照可能已过期 · 打开 WorkPulse 更新"
        }
        let reset = quota.resetsAt.map { " · \($0.formatted(date: .omitted, time: .shortened)) 重置" } ?? ""
        return "\(Int(remaining.rounded()))% 剩余\(reset)"
    }

    private func quotaWindowLabel(_ minutes: Int?) -> String {
        guard let minutes else { return "Codex 额度" }
        if minutes % 1_440 == 0 { return "Codex \(minutes / 1_440) 天窗口" }
        if minutes % 60 == 0 { return "Codex \(minutes / 60) 小时窗口" }
        return "Codex \(minutes) 分钟窗口"
    }

    private func isGalleryPreview(_ snapshot: WidgetSnapshot) -> Bool {
        snapshot.quota?.provenance == .demo || snapshot.quota?.provenance == .deterministicFixture
    }
}

// MARK: - WorkPulse visual system

private enum PulseWidgetPalette {
    static let cyan = Color(red: 0.49, green: 0.83, blue: 0.99)
    static let success = Color(red: 0.20, green: 0.72, blue: 0.52)
    static let warning = Color(red: 0.94, green: 0.61, blue: 0.20)
    static let critical = Color(red: 0.91, green: 0.31, blue: 0.35)
}

private extension AccentPreference {
    var widgetColor: Color {
        switch self {
        case .ocean: Color(red: 0.36, green: 0.55, blue: 1.00)
        case .violet: Color(red: 0.61, green: 0.43, blue: 0.96)
        case .mint: Color(red: 0.16, green: 0.69, blue: 0.61)
        case .sunset: Color(red: 0.94, green: 0.48, blue: 0.24)
        case .rose: Color(red: 0.91, green: 0.32, blue: 0.54)
        }
    }
}

private struct PulseWidgetAccentKey: EnvironmentKey {
    static let defaultValue = AccentPreference.ocean.widgetColor
}

private struct PulseWidgetDarkSurfaceKey: EnvironmentKey {
    static let defaultValue = false
}

private extension EnvironmentValues {
    var pulseWidgetAccent: Color {
        get { self[PulseWidgetAccentKey.self] }
        set { self[PulseWidgetAccentKey.self] = newValue }
    }

    var pulseWidgetDarkSurface: Bool {
        get { self[PulseWidgetDarkSurfaceKey.self] }
        set { self[PulseWidgetDarkSurfaceKey.self] = newValue }
    }
}

private struct PulseWidgetAppearance<Content: View>: View {
    @Environment(\.colorScheme) private var systemColorScheme
    let entry: WorkPulseWidgetEntry
    let content: Content

    init(entry: WorkPulseWidgetEntry, @ViewBuilder content: () -> Content) {
        self.entry = entry
        self.content = content()
    }

    var body: some View {
        content
            .environment(\.pulseWidgetAccent, accentPreference.widgetColor)
            .environment(\.pulseWidgetDarkSurface, resolvedColorScheme == .dark)
            .environment(\.colorScheme, resolvedColorScheme)
            .foregroundStyle(resolvedColorScheme == .dark
                ? Color(red: 0.94, green: 0.96, blue: 1.00)
                : Color(red: 0.08, green: 0.10, blue: 0.16))
    }

    private var preferences: (ThemePreference, AccentPreference) {
        guard case .available(let snapshot) = entry.state else { return (.system, .ocean) }
        return (snapshot.themePreference, snapshot.accentPreference)
    }

    private var accentPreference: AccentPreference { preferences.1 }

    private var resolvedColorScheme: ColorScheme {
        switch preferences.0 {
        case .light: .light
        case .dark: .dark
        case .system: systemColorScheme
        }
    }
}

private struct PulseWidgetBackground: View {
    @Environment(\.pulseWidgetAccent) private var accentColor
    let darkSurface: Bool

    var body: some View {
        ZStack {
            darkSurface
                ? Color(red: 0.055, green: 0.075, blue: 0.12)
                : Color(red: 0.965, green: 0.973, blue: 0.99)
            Circle()
                .fill(accentColor.opacity(darkSurface ? 0.16 : 0.10))
                .frame(width: 180, height: 180)
                .blur(radius: 55)
                .offset(x: 85, y: -80)
        }
    }
}

private struct PulseWidgetMark: View {
    var size: CGFloat = 22

    var body: some View {
        Image("WorkPulseLogo")
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
            .accessibilityLabel("WorkPulse")
    }
}

private struct PulseUnavailableWidgetView: View {
    @Environment(\.pulseWidgetDarkSurface) private var darkSurface
    let title: String
    let detail: String
    var recoveryURL = URL(string: "workpulse://usage")!

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                PulseWidgetMark(size: 24)
                Text("WorkPulse")
                    .font(.caption.weight(.semibold))
                Spacer()
            }
            Spacer(minLength: 0)
            Text(title)
                .font(.headline)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
        .containerBackground(for: .widget) { PulseWidgetBackground(darkSurface: darkSurface) }
        .widgetURL(recoveryURL)
    }
}

private struct PulseQuotaWidgetView: View {
    @Environment(\.pulseWidgetAccent) private var accentColor
    @Environment(\.pulseWidgetDarkSurface) private var darkSurface
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let entry: WorkPulseWidgetEntry

    var body: some View {
        switch entry.state {
        case .available(let snapshot):
            if let quota = snapshot.quota, let remaining = quota.remainingPercent {
                quotaContent(quota: quota, remaining: remaining)
                    .widgetURL(URL(string: "workpulse://usage"))
                    .containerBackground(for: .widget) { PulseWidgetBackground(darkSurface: darkSurface) }
            } else {
                PulseUnavailableWidgetView(title: "额度尚未连接", detail: "打开 WorkPulse 读取 Codex 额度。")
            }
        case .empty:
            PulseUnavailableWidgetView(title: "等待 WorkPulse", detail: "打开应用完成首次同步。")
        case .corrupt:
            PulseUnavailableWidgetView(title: "快照不可用", detail: "打开 WorkPulse 重新同步。")
        case .unsupported:
            PulseUnavailableWidgetView(title: "需要更新", detail: "当前 Widget 与快照版本不兼容。")
        }
    }

    private func quotaContent(quota: QuotaSnapshot, remaining: Double) -> some View {
        let preview = PulseWidgetCopy.isPreview(quota)
        let fresh = PulseWidgetCopy.isCurrent(quota, at: entry.date)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                PulseWidgetMark(size: 23)
                Text(preview ? "额度示例" : PulseWidgetCopy.windowLabel(quota.windowDurationMinutes))
                    .font(.caption.weight(.semibold))
                Spacer()
                Text(preview ? "非实时" : fresh ? "已同步" : "需更新")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(preview || !fresh ? .secondary : PulseWidgetPalette.success)
            }

            Spacer(minLength: 0)

            if preview {
                Text("示例 \(Int(remaining.rounded()))%")
                    .font(dynamicTypeSize.isAccessibilitySize ? .title2.weight(.semibold) : .system(size: 29, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text("添加后读取真实额度")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if fresh {
                Text("\(Int(remaining.rounded()))%")
                    .font(dynamicTypeSize.isAccessibilitySize ? .title.weight(.semibold) : .system(size: 34, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                ProgressView(value: remaining, total: 100)
                    .progressViewStyle(.linear)
                    .tint(PulseWidgetCopy.tint(for: remaining, accent: accentColor))
                Label(PulseWidgetCopy.resetLabel(quota.resetsAt), systemImage: "clock")
                    .font(.caption.weight(.medium))
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
            } else {
                Text("额度需更新")
                    .font(.title3.weight(.semibold))
                Text("上次读数不再作为当前额度突出显示")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct PulsePinnedWidgetView: View {
    @Environment(\.pulseWidgetAccent) private var accentColor
    @Environment(\.pulseWidgetDarkSurface) private var darkSurface
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let entry: WorkPulseWidgetEntry

    var body: some View {
        switch entry.state {
        case .available(let snapshot):
            let preview = PulseWidgetCopy.isPreview(snapshot.quota)
            let targetReady = preview || snapshot.hasValidPinnedTarget
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    PulseWidgetMark(size: 23)
                    Text("固定入口")
                        .font(.caption.weight(.semibold))
                    Spacer()
                    Image(systemName: "pin.fill")
                        .font(.caption)
                        .foregroundStyle(accentColor)
                }
                Spacer(minLength: 0)
                Text(preview ? "示例入口" : targetReady ? snapshot.routineTitle : "设置固定入口")
                    .font(dynamicTypeSize.isAccessibilitySize ? .headline : .system(size: 20, weight: .semibold, design: .rounded))
                    .lineLimit(2)
                HStack {
                    Text(preview ? "组件库预览 · 非实时" : targetReady ? "点按打开保存的对话" : "在 WorkPulse 中添加 HTTPS 链接")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                    Spacer()
                    Image(systemName: targetReady ? "arrow.up.forward" : "plus")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(accentColor)
                }
            }
            .widgetURL(URL(string: "workpulse://routine/\(snapshot.routineID.uuidString)"))
            .containerBackground(for: .widget) { PulseWidgetBackground(darkSurface: darkSurface) }
        case .empty:
            PulseUnavailableWidgetView(title: "尚未固定入口", detail: "在 WorkPulse 控制中心保存一个 HTTPS 对话链接。", recoveryURL: URL(string: "workpulse://routine/setup")!)
        case .corrupt:
            PulseUnavailableWidgetView(title: "入口不可用", detail: "打开 WorkPulse 重新同步。", recoveryURL: URL(string: "workpulse://routine/setup")!)
        case .unsupported:
            PulseUnavailableWidgetView(title: "需要更新", detail: "当前 Widget 与快照版本不兼容。", recoveryURL: URL(string: "workpulse://routine/setup")!)
        }
    }
}

private struct PulseQuickWidgetView: View {
    @Environment(\.pulseWidgetAccent) private var accentColor
    @Environment(\.pulseWidgetDarkSurface) private var darkSurface
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let entry: WorkPulseWidgetEntry

    var body: some View {
        switch entry.state {
        case .available(let snapshot):
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(spacing: 7))
                : AnyLayout(HStackLayout(spacing: 14))
            layout {
                Link(destination: URL(string: "workpulse://usage")!) {
                    quotaColumn(snapshot.quota)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                Divider().opacity(0.55)
                Link(destination: URL(string: "workpulse://routine/\(snapshot.routineID.uuidString)")!) {
                    routineColumn(snapshot)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
            .containerBackground(for: .widget) { PulseWidgetBackground(darkSurface: darkSurface) }
        case .empty:
            PulseUnavailableWidgetView(title: "等待 WorkPulse", detail: "打开应用同步额度与固定入口。")
        case .corrupt:
            PulseUnavailableWidgetView(title: "快照不可用", detail: "打开 WorkPulse 重新同步。")
        case .unsupported:
            PulseUnavailableWidgetView(title: "需要更新", detail: "当前 Widget 与快照版本不兼容。")
        }
    }

    private func quotaColumn(_ quota: QuotaSnapshot?) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                PulseWidgetMark(size: 22)
                Text("Codex 额度")
                    .font(.caption.weight(.semibold))
            }
            Spacer(minLength: 0)
            if let quota, let remaining = quota.remainingPercent {
                let preview = PulseWidgetCopy.isPreview(quota)
                let fresh = PulseWidgetCopy.isCurrent(quota, at: entry.date)
                Text(preview ? "示例 \(Int(remaining.rounded()))%" : fresh ? "\(Int(remaining.rounded()))% 剩余" : "额度需更新")
                    .font(.title2.weight(.semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                Text(preview
                    ? "非实时 · 添加后读取"
                    : fresh
                        ? "\(PulseWidgetCopy.windowLabel(quota.windowDurationMinutes)) · \(PulseWidgetCopy.resetLabel(quota.resetsAt))"
                        : "点按打开 WorkPulse 刷新")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            } else {
                Text("尚未连接")
                    .font(.title3.weight(.semibold))
                Text("点按打开 WorkPulse")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func routineColumn(_ snapshot: WidgetSnapshot) -> some View {
        let preview = PulseWidgetCopy.isPreview(snapshot.quota)
        let targetReady = preview || snapshot.hasValidPinnedTarget
        return VStack(alignment: .leading, spacing: 7) {
            HStack {
                Image(systemName: "pin.fill")
                    .foregroundStyle(accentColor)
                Text("固定入口")
                    .font(.caption.weight(.semibold))
            }
            Spacer(minLength: 0)
            Text(preview ? "示例入口" : targetReady ? snapshot.routineTitle : "设置固定入口")
                .font(.title3.weight(.semibold))
                .lineLimit(2)
            Text(preview ? "组件库预览 · 非实时" : targetReady ? "手动固定 · 点按打开" : "添加 HTTPS 对话链接")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

private struct PulseOverviewWidgetView: View {
    @Environment(\.pulseWidgetAccent) private var accentColor
    @Environment(\.pulseWidgetDarkSurface) private var darkSurface
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let entry: WorkPulseWidgetEntry

    var body: some View {
        switch entry.state {
        case .available(let snapshot):
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 9) {
                    PulseWidgetMark(size: 28)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("WorkPulse")
                            .font(.headline)
                        Text(PulseWidgetCopy.isPreview(snapshot.quota) ? "组件库预览 · 非实时" : "本机状态概览")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(snapshot.generatedAt.formatted(date: .omitted, time: .shortened))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                adaptiveCardLayout {
                    ForEach(Array(visibleBuckets(snapshot).enumerated()), id: \.offset) { _, quota in
                        Link(destination: URL(string: "workpulse://usage")!) {
                            overviewQuotaCard(quota)
                        }
                    }
                    if visibleBuckets(snapshot).isEmpty {
                        overviewStatusCard(
                            icon: "gauge.with.dots.needle.50percent",
                            title: "额度尚未连接",
                            detail: "打开 WorkPulse 读取"
                        )
                    }
                }

                adaptiveCardLayout {
                    overviewStatusCard(
                        icon: "bolt.fill",
                        title: taskTitle(snapshot.runningTasks),
                        detail: taskDetail(snapshot.runningTasks)
                    )
                    Link(destination: URL(string: "workpulse://routine/\(snapshot.routineID.uuidString)")!) {
                        overviewStatusCard(
                            icon: "pin.fill",
                            title: PulseWidgetCopy.isPreview(snapshot.quota)
                                ? "示例入口"
                                : snapshot.hasValidPinnedTarget ? snapshot.routineTitle : "设置固定入口",
                            detail: PulseWidgetCopy.isPreview(snapshot.quota)
                                ? "非实时预览"
                                : snapshot.hasValidPinnedTarget ? "点按打开保存的对话" : "添加 HTTPS 对话链接"
                        )
                    }
                }

                Spacer(minLength: 0)
                Text("只展示可验证的本机任务、额度和手动入口。")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .containerBackground(for: .widget) { PulseWidgetBackground(darkSurface: darkSurface) }
        case .empty:
            PulseUnavailableWidgetView(title: "等待 WorkPulse", detail: "打开应用完成首次同步。")
        case .corrupt:
            PulseUnavailableWidgetView(title: "概览不可用", detail: "打开 WorkPulse 重新同步。")
        case .unsupported:
            PulseUnavailableWidgetView(title: "需要更新", detail: "当前 Widget 与快照版本不兼容。")
        }
    }

    private func overviewQuotaCard(_ quota: QuotaSnapshot) -> some View {
        let preview = PulseWidgetCopy.isPreview(quota)
        let remaining = quota.remainingPercent
        let fresh = PulseWidgetCopy.isCurrent(quota, at: entry.date)
        return VStack(alignment: .leading, spacing: 4) {
            Text(PulseWidgetCopy.windowLabel(quota.windowDurationMinutes))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(preview
                ? "示例 \(Int((remaining ?? 0).rounded()))%"
                : fresh && remaining != nil
                    ? "\(Int(remaining!.rounded()))% 剩余"
                    : "额度需更新")
                .font(.title3.weight(.semibold))
                .monospacedDigit()
            Text(preview ? "非实时" : fresh ? PulseWidgetCopy.resetLabel(quota.resetsAt) : "点按刷新")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 62, alignment: .topLeading)
        .padding(10)
        .background(accentColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 11))
    }

    private func adaptiveCardLayout<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 7))
            : AnyLayout(HStackLayout(spacing: 10))
        return layout { content() }
    }

    private func overviewStatusCard(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .foregroundStyle(accentColor)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
        .padding(10)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 11))
    }

    private func visibleBuckets(_ snapshot: WidgetSnapshot) -> [QuotaSnapshot] {
        let buckets = snapshot.quotaBuckets.isEmpty ? snapshot.quota.map { [$0] } ?? [] : snapshot.quotaBuckets
        return Array(buckets.prefix(dynamicTypeSize.isAccessibilitySize ? 1 : 2))
    }

    private func taskTitle(_ summary: RunningTaskSummary?) -> String {
        guard let summary, summary.freshness(at: entry.date) == .fresh else { return "任务状态需更新" }
        return summary.count == 0 ? "没有运行中的任务" : "\(summary.count) 个任务正在运行"
    }

    private func taskDetail(_ summary: RunningTaskSummary?) -> String {
        guard let summary else { return "监测尚未连接" }
        return summary.freshness(at: entry.date) == .fresh ? "本机生命周期元数据" : "打开 WorkPulse 刷新"
    }
}

private enum PulseWidgetCopy {
    static func isPreview(_ quota: QuotaSnapshot?) -> Bool {
        guard let quota else { return false }
        return quota.provenance == .demo || quota.provenance == .deterministicFixture
    }

    static func isCurrent(_ quota: QuotaSnapshot, at date: Date) -> Bool {
        guard quota.freshness(at: date) == .fresh else { return false }
        return quota.resetsAt.map { date < $0 } ?? true
    }

    static func windowLabel(_ minutes: Int?) -> String {
        guard let minutes else { return "Codex 额度" }
        if minutes % 10_080 == 0 { return "\(minutes / 10_080 * 7) 天窗口" }
        if minutes % 1_440 == 0 { return "\(minutes / 1_440) 天窗口" }
        if minutes % 60 == 0 { return "\(minutes / 60) 小时窗口" }
        return "\(minutes) 分钟窗口"
    }

    static func resetLabel(_ reset: Date?) -> String {
        guard let reset else { return "重置时间未知" }
        if Calendar.current.isDateInToday(reset) {
            return "今天 \(reset.formatted(date: .omitted, time: .shortened)) 重置"
        }
        return "\(reset.formatted(.dateTime.weekday(.abbreviated).hour().minute())) 重置"
    }

    static func tint(for remaining: Double, accent: Color) -> Color {
        if remaining <= 10 { return PulseWidgetPalette.critical }
        if remaining <= 20 { return PulseWidgetPalette.warning }
        return accent
    }
}

struct WorkPulseQuotaWidget: Widget {
    let kind = "WorkPulseQuota"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WorkPulseWidgetProvider()) { entry in
            PulseWidgetAppearance(entry: entry) { PulseQuotaWidgetView(entry: entry) }
        }
        .configurationDisplayName("WorkPulse 额度")
        .description("一眼查看 Codex 剩余额度与下次重置时间。")
        .supportedFamilies([.systemSmall])
        .containerBackgroundRemovable(false)
    }
}

struct WorkPulseQuickViewWidget: Widget {
    let kind = "WorkPulseQuickView"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WorkPulseWidgetProvider()) { entry in
            PulseWidgetAppearance(entry: entry) { PulseQuickWidgetView(entry: entry) }
        }
        .configurationDisplayName("WorkPulse 额度与入口")
        .description("并排查看 Codex 额度和固定对话入口，不推断 Gmail 或 Scheduled 状态。")
        .supportedFamilies([.systemMedium])
        .containerBackgroundRemovable(false)
    }
}

struct WorkPulsePinnedRoutineWidget: Widget {
    let kind = "WorkPulsePinnedRoutine"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WorkPulseWidgetProvider()) { entry in
            PulseWidgetAppearance(entry: entry) { PulsePinnedWidgetView(entry: entry) }
        }
        .configurationDisplayName("WorkPulse 固定入口")
        .description("在桌面保留一个 ChatGPT 对话或每日例程入口。")
        .supportedFamilies([.systemSmall])
        .containerBackgroundRemovable(false)
    }
}

struct WorkPulseDailyOverviewWidget: Widget {
    let kind = "WorkPulseDailyOverview"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WorkPulseWidgetProvider()) { entry in
            PulseWidgetAppearance(entry: entry) { PulseOverviewWidgetView(entry: entry) }
        }
        .configurationDisplayName("WorkPulse 工作概览")
        .description("汇总正在运行的 Codex 任务、主要额度窗口和固定入口。")
        .supportedFamilies([.systemLarge])
        .containerBackgroundRemovable(false)
    }
}

@main
struct WorkPulseWidgetBundle: WidgetBundle {
    var body: some Widget {
        WorkPulseQuotaWidget()
        WorkPulsePinnedRoutineWidget()
        WorkPulseQuickViewWidget()
        WorkPulseDailyOverviewWidget()
    }
}
