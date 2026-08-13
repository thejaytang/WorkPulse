import AppKit
import SwiftUI
import WorkPulseCore

enum NotchSurfaceMode: Equatable {
    case hidden
    case resident(title: String, detail: String, systemImage: String, tone: NotchSurfaceTone)
    case alert(title: String, detail: String, systemImage: String, tone: NotchSurfaceTone)
    case expanded(NotchExpandedContent)
}

enum NotchSurfaceTone: Equatable {
    case neutral
    case success
    case warning
    case critical

    var color: Color {
        switch self {
        case .neutral: Color(red: 0.49, green: 0.70, blue: 1.00)
        case .success: Color(red: 0.32, green: 0.86, blue: 0.65)
        case .warning: Color(red: 0.98, green: 0.68, blue: 0.30)
        case .critical: Color(red: 1.00, green: 0.38, blue: 0.43)
        }
    }
}

struct NotchExpandedContent: Equatable {
    var title: String
    var primaryLabel: String
    var primaryValue: String
    var secondaryLabel: String
    var secondaryValue: String
    var primarySystemImage: String = "gauge.with.dots.needle.50percent"
    var secondarySystemImage: String = "pin.fill"
    var additionalRows: [NotchExpandedRow] = []
    var source: String
    var primaryAction: NotchExpandedAction?
    var secondaryAction: NotchExpandedAction?
}

struct NotchExpandedRow: Equatable {
    var label: String
    var value: String
    var systemImage: String
}

enum NotchExpandedAction: Equatable {
    case refreshQuota
    case openPinned
    case revealTaskNames
    case snoozeEvent(UUID)
    case removeEvent(UUID)

    var title: String {
        switch self {
        case .refreshQuota: "刷新"
        case .openPinned: "打开入口"
        case .revealTaskNames: "显示名称 10 秒"
        case .snoozeEvent: "稍后 1 小时"
        case .removeEvent: "从本机移除"
        }
    }
}

extension Notification.Name {
    static let workPulseDeepLink = Notification.Name("workpulse.deep-link")
    static let workPulseOpenPinned = Notification.Name("workpulse.open-pinned")
    static let workPulseRefreshQuota = Notification.Name("workpulse.refresh-quota")
    static let workPulseNotchAction = Notification.Name("workpulse.notch-action")
}

@MainActor
final class NotchOverlayController: ObservableObject {
    static let shared = NotchOverlayController()

    @Published private(set) var mode: NotchSurfaceMode = .hidden
    @Published private(set) var isNotchScreen = false
    @Published private(set) var contentTopInset: CGFloat = 0
    @Published private(set) var physicalNotchWidth: CGFloat = 0
    @Published private(set) var accentColor = AccentPreference.ocean.workPulseColor
    @Published private(set) var isDarkSurface = true

    var isReachable: Bool {
        guard !NSScreen.screens.isEmpty else { return false }
        if let session = CGSessionCopyCurrentDictionary() as? [String: Any] {
            if session["CGSSessionScreenIsLocked"] as? Bool == true { return false }
            if session[kCGSessionOnConsoleKey as String] as? Bool == false { return false }
        }
        return true
    }

    private var panel: NSPanel?
    private var dismissTask: Task<Void, Never>?
    private var residentMode: NotchSurfaceMode = .hidden
    private var residentExpandedContent = NotchExpandedContent(
        title: "WorkPulse",
        primaryLabel: "额度",
        primaryValue: "等待来源",
        secondaryLabel: "固定入口",
        secondaryValue: "每日例程",
        source: "尚未连接",
        primaryAction: .refreshQuota,
        secondaryAction: nil
    )
    private var alertExpandedContent: NotchExpandedContent?
    private var alertRemaining: TimeInterval = 0
    private var alertStartedAt: Date?
    private var alertHovering = false
    private var alertKeyboardInteractionActive = false
    private var expandedExitTask: Task<Void, Never>?
    private var expandedKeyboardInteractionActive = false
    private var expandedKeyboardProtectionTask: Task<Void, Never>?
    private var expandedHovering = false
    private var localEventMonitor: Any?
    private var globalEventMonitor: Any?
    private var appearanceObservation: NSKeyValueObservation?
    private var themePreference: ThemePreference = .system
    private var accentPreference: AccentPreference = .ocean
    private var usesAccessibilityTextLayout = false

    private init() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.repositionCurrentMode() }
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.sessionDidResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.panel?.orderOut(nil) }
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.sessionDidBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.restoreResident() }
        }
        appearanceObservation = NSApplication.shared.observe(
            \.effectiveAppearance,
            options: [.new]
        ) { [weak self] _, _ in
            Task { @MainActor in
                guard let self, self.themePreference == .system else { return }
                self.setAppearance(theme: .system, accent: self.accentPreference)
            }
        }
    }

    func setAppearance(theme: ThemePreference, accent: AccentPreference) {
        themePreference = theme
        accentPreference = accent
        accentColor = accent.workPulseColor
        isDarkSurface = switch theme {
        case .dark: true
        case .light: false
        case .system:
            NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        }
    }

    func color(for tone: NotchSurfaceTone) -> Color {
        tone == .neutral ? accentColor : tone.color
    }

    func setAccessibilityTextLayout(_ enabled: Bool) {
        guard usesAccessibilityTextLayout != enabled else { return }
        usesAccessibilityTextLayout = enabled
        repositionCurrentMode()
    }

    var primaryTextColor: Color {
        usesDarkSurface ? .white : Color(red: 0.08, green: 0.10, blue: 0.16)
    }

    var surfaceColor: Color {
        usesDarkSurface
            ? Color(red: 0.025, green: 0.035, blue: 0.060)
            : Color(red: 0.965, green: 0.973, blue: 0.99)
    }

    /// A real notch is black hardware. Keeping its attached surface dark makes
    /// the overlay read as an extension of the notch instead of a white card
    /// pasted over the menu bar. Theme preference still applies to the control
    /// center and to the floating capsule used on displays without a notch.
    var usesDarkSurface: Bool {
        isNotchScreen || isDarkSurface
    }

    func configureExpanded(_ content: NotchExpandedContent) {
        residentExpandedContent = content
        if case .expanded = mode, alertExpandedContent == nil {
            mode = .expanded(content)
        }
    }

    func setResident(
        enabled: Bool,
        title: String,
        detail: String,
        systemImage: String,
        tone: NotchSurfaceTone
    ) {
        guard enabled else {
            dismissTask?.cancel()
            residentMode = .hidden
            hide()
            return
        }
        residentMode = .resident(title: title, detail: detail, systemImage: systemImage, tone: tone)

        // Polling updates the resident content frequently. Keep an alert or an
        // expanded panel on screen while only refreshing what will be restored
        // underneath it; otherwise every poll looks like an unexpected collapse.
        switch mode {
        case .alert, .expanded:
            return
        case .hidden, .resident:
            break
        }

        dismissTask?.cancel()
        mode = residentMode
        present(size: residentSize)
    }

    @discardableResult
    func showAlert(
        title: String,
        detail: String,
        systemImage: String,
        tone: NotchSurfaceTone = .warning,
        duration: TimeInterval = 6,
        expandedContent: NotchExpandedContent? = nil
    ) -> Bool {
        dismissTask?.cancel()
        guard isReachable else { return false }
        alertExpandedContent = expandedContent
        alertHovering = false
        alertKeyboardInteractionActive = false
        mode = .alert(title: title, detail: detail, systemImage: systemImage, tone: tone)
        let presented = present(size: alertSize)
        guard presented else {
            alertExpandedContent = nil
            restoreResident()
            return false
        }
        alertRemaining = duration
        if !NSWorkspace.shared.isVoiceOverEnabled && !NSWorkspace.shared.isSwitchControlEnabled {
            scheduleAlertDismissal()
        }
        return true
    }

    func dismissAlert() {
        dismissTask?.cancel()
        dismissTask = nil
        alertExpandedContent = nil
        restoreResident()
    }

    func setAlertHovering(_ hovering: Bool) {
        guard case .alert = mode else { return }
        alertHovering = hovering
        updateAlertDismissalProtection()
    }

    func setAlertKeyboardInteracting(_ interacting: Bool) {
        guard case .alert = mode else { return }
        alertKeyboardInteractionActive = interacting
        updateAlertDismissalProtection()
    }

    private func updateAlertDismissalProtection() {
        guard case .alert = mode else { return }
        if NSWorkspace.shared.isVoiceOverEnabled || NSWorkspace.shared.isSwitchControlEnabled {
            dismissTask?.cancel()
            dismissTask = nil
            alertStartedAt = nil
            return
        }
        if alertHovering || alertKeyboardInteractionActive {
            if let started = alertStartedAt {
                alertRemaining = max(0.5, alertRemaining - Date().timeIntervalSince(started))
            }
            dismissTask?.cancel()
            dismissTask = nil
            alertStartedAt = nil
        } else if dismissTask == nil {
            scheduleAlertDismissal()
        }
    }

    func toggleExpanded() {
        dismissTask?.cancel()
        dismissTask = nil
        expandedKeyboardInteractionActive = false
        switch mode {
        case .expanded:
            restoreResident()
        case .alert:
            let content = alertExpandedContent ?? residentExpandedContent
            mode = .expanded(content)
            startExpandedEventMonitors()
            present(size: expandedSize(for: content), makeKey: true)
        default:
            let content = residentExpandedContent
            mode = .expanded(content)
            startExpandedEventMonitors()
            present(size: expandedSize(for: content), makeKey: true)
        }
    }

    func dismissExpanded() {
        expandedExitTask?.cancel()
        expandedExitTask = nil
        expandedKeyboardInteractionActive = false
        stopExpandedEventMonitors()
        restoreResident()
    }

    func setExpandedHovering(_ hovering: Bool) {
        guard case .expanded = mode else { return }
        expandedHovering = hovering
        expandedExitTask?.cancel()
        expandedExitTask = nil
        guard !hovering else { return }
        guard !expandedKeyboardInteractionActive,
              !NSWorkspace.shared.isVoiceOverEnabled,
              !NSWorkspace.shared.isSwitchControlEnabled else { return }

        // A short grace period prevents a one-frame leave event while the panel
        // resizes from feeling like a flicker. Re-entering cancels the collapse.
        expandedExitTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            self?.dismissExpanded()
        }
    }

    func hide() {
        dismissTask?.cancel()
        dismissTask = nil
        expandedExitTask?.cancel()
        expandedExitTask = nil
        stopExpandedEventMonitors()
        mode = .hidden
        panel?.orderOut(nil)
    }

    private func restoreResident() {
        expandedExitTask?.cancel()
        expandedExitTask = nil
        alertExpandedContent = nil
        alertHovering = false
        alertKeyboardInteractionActive = false
        mode = residentMode
        stopExpandedEventMonitors()
        switch residentMode {
        case .resident:
            present(size: residentSize)
        case .hidden, .alert, .expanded:
            panel?.orderOut(nil)
        }
    }

    private func scheduleAlertDismissal() {
        alertStartedAt = Date()
        let remaining = alertRemaining
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(remaining))
            guard !Task.isCancelled else { return }
            self?.alertStartedAt = nil
            self?.restoreResident()
        }
    }

    private func repositionCurrentMode() {
        switch mode {
        case .hidden:
            break
        case .resident:
            present(size: residentSize)
        case .alert:
            present(size: alertSize)
        case .expanded(let content):
            present(size: expandedSize(for: content), makeKey: true)
        }
    }

    private func expandedSize(for content: NotchExpandedContent) -> NSSize {
        // The extra vertical allowance keeps semantic text styles and two-line
        // accessibility values inside the panel instead of clipping them.
        if usesAccessibilityTextLayout {
            return NSSize(width: 520, height: 360 + CGFloat(content.additionalRows.count) * 58)
        }
        return NSSize(width: 430, height: 280 + CGFloat(content.additionalRows.count) * 42)
    }

    private var residentSize: NSSize {
        usesAccessibilityTextLayout ? NSSize(width: 380, height: 92) : NSSize(width: 320, height: 58)
    }
    private var alertSize: NSSize {
        usesAccessibilityTextLayout ? NSSize(width: 460, height: 150) : NSSize(width: 390, height: 112)
    }

    private func startExpandedEventMonitors() {
        stopExpandedEventMonitors()
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .leftMouseDown, .rightMouseDown, .mouseMoved]) { [weak self] event in
            if event.type == .keyDown, event.keyCode == 53 {
                Task { @MainActor in self?.dismissExpanded() }
                return nil
            }
            if event.type == .keyDown {
                Task { @MainActor in self?.protectExpandedKeyboardInteraction() }
            }
            if event.type == .mouseMoved {
                let point = NSEvent.mouseLocation
                let hovering = self?.panel?.frame.contains(point) == true
                Task { @MainActor in
                    self?.setExpandedHovering(hovering)
                }
            }
            if event.type == .leftMouseDown || event.type == .rightMouseDown {
                let point = NSEvent.mouseLocation
                if let frame = self?.panel?.frame, !frame.contains(point) {
                    Task { @MainActor in self?.dismissExpanded() }
                }
            }
            return event
        }
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .mouseMoved]) { [weak self] event in
            let point = NSEvent.mouseLocation
            if event.type == .mouseMoved {
                let hovering = self?.panel?.frame.contains(point) == true
                Task { @MainActor in
                    self?.setExpandedHovering(hovering)
                }
                return
            }
            if let frame = self?.panel?.frame, !frame.contains(point) {
                Task { @MainActor in self?.dismissExpanded() }
            }
        }
    }

    private func stopExpandedEventMonitors() {
        if let localEventMonitor { NSEvent.removeMonitor(localEventMonitor) }
        if let globalEventMonitor { NSEvent.removeMonitor(globalEventMonitor) }
        localEventMonitor = nil
        globalEventMonitor = nil
        expandedKeyboardProtectionTask?.cancel()
        expandedKeyboardProtectionTask = nil
        expandedKeyboardInteractionActive = false
        expandedHovering = false
    }

    private func protectExpandedKeyboardInteraction() {
        expandedKeyboardInteractionActive = true
        expandedKeyboardProtectionTask?.cancel()
        expandedKeyboardProtectionTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(15))
            guard !Task.isCancelled, let self else { return }
            self.expandedKeyboardInteractionActive = false
            if !self.expandedHovering { self.setExpandedHovering(false) }
        }
    }

    @discardableResult
    private func present(size: NSSize, makeKey: Bool = false) -> Bool {
        let targetScreen = preferredScreen()
        guard let screen = targetScreen else { return false }
        isNotchScreen = screen.safeAreaInsets.top > 0
        contentTopInset = isNotchScreen ? screen.safeAreaInsets.top : 0
        if isNotchScreen,
           let leftArea = screen.auxiliaryTopLeftArea,
           let rightArea = screen.auxiliaryTopRightArea {
            physicalNotchWidth = max(0, rightArea.minX - leftArea.maxX)
        } else {
            physicalNotchWidth = 0
        }

        let presentedSize = NSSize(
            width: size.width,
            height: size.height + contentTopInset
        )

        let panel = panel ?? makePanel()
        self.panel = panel
        panel.setContentSize(presentedSize)
        let x = screen.frame.midX - presentedSize.width / 2
        let topGap: CGFloat = isNotchScreen ? 0 : 6
        let y = screen.frame.maxY - presentedSize.height - topGap
        panel.setFrameOrigin(NSPoint(x: x, y: y))
        if makeKey {
            panel.makeKeyAndOrderFront(nil)
        } else {
            panel.orderFrontRegardless()
        }
        return panel.isVisible && screen.frame.intersects(panel.frame)
    }

    private func preferredScreen() -> NSScreen? {
        let screens = NSScreen.screens
        let mainDisplayID = NSScreen.main.flatMap(displayID(for:))
        let candidates = screens.compactMap { screen -> DisplayPlacementCandidate? in
            guard let displayID = displayID(for: screen) else { return nil }
            return DisplayPlacementCandidate(
                displayID: displayID,
                isBuiltIn: CGDisplayIsBuiltin(displayID) != 0,
                hasNotch: screen.safeAreaInsets.top > 0,
                isMain: displayID == mainDisplayID
            )
        }
        guard let preferredID = DisplayPlacementPolicy.preferredDisplayID(from: candidates) else {
            return NSScreen.main ?? screens.first
        }
        return screens.first { displayID(for: $0) == preferredID }
            ?? NSScreen.main
            ?? screens.first
    }

    #if DEBUG
    func placementDiagnostic() -> String {
        guard let screen = preferredScreen(), let selectedID = displayID(for: screen) else {
            return "screens=\(NSScreen.screens.count); selected=none"
        }
        let mainID = NSScreen.main.flatMap(displayID(for:))
        let panelDisplayID = panel.flatMap { panel in
            let center = NSPoint(x: panel.frame.midX, y: panel.frame.midY)
            return NSScreen.screens.first(where: { $0.frame.contains(center) }).flatMap(displayID(for:))
        }
        let modeLabel = switch mode {
        case .hidden: "hidden"
        case .resident: "resident"
        case .alert: "alert"
        case .expanded: "expanded"
        }
        return [
            "screens=\(NSScreen.screens.count)",
            "mode=\(modeLabel)",
            "selectedBuiltIn=\(CGDisplayIsBuiltin(selectedID) != 0)",
            "selectedHasNotch=\(screen.safeAreaInsets.top > 0)",
            "selectedIsMain=\(selectedID == mainID)",
            "panelOnSelected=\(panelDisplayID == selectedID)",
            "contentTopInset=\(Int(contentTopInset.rounded()))"
        ].joined(separator: "; ")
    }
    #endif

    private func displayID(for screen: NSScreen) -> CGDirectDisplayID? {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return (screen.deviceDescription[key] as? NSNumber)?.uint32Value
    }

    private func makePanel() -> NSPanel {
        let panel = WorkPulsePanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        panel.acceptsMouseMovedEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.becomesKeyOnlyIfNeeded = true
        panel.contentView = NSHostingView(rootView: NotchSurfaceView(controller: self))
        return panel
    }
}

private final class WorkPulsePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

private struct NotchSurfaceView: View {
    @ObservedObject var controller: NotchOverlayController
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @FocusState private var alertHasKeyboardFocus: Bool

    var body: some View {
        Group {
            switch controller.mode {
            case .hidden:
                EmptyView()
            case .resident(let title, let detail, let systemImage, let tone):
                Button {
                    controller.toggleExpanded()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: systemImage)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(controller.color(for: tone))
                            .frame(width: 23, height: 23)
                            .background(controller.color(for: tone).opacity(0.14), in: Circle())
                        Text(title)
                            .font(.callout.weight(.semibold))
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                        Spacer(minLength: 4)
                        Text(detail)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(controller.primaryTextColor.opacity(0.62))
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                    }
                    .padding(.horizontal, 13)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("WorkPulse 常驻状态，\(title)，\(detail)")
            case .alert(let title, let detail, let systemImage, let tone):
                Button {
                    controller.toggleExpanded()
                } label: {
                    HStack(spacing: 13) {
                        Image(systemName: systemImage)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(controller.color(for: tone))
                            .frame(width: 34, height: 34)
                            .background(controller.color(for: tone).opacity(0.14), in: Circle())
                        VStack(alignment: .leading, spacing: 3) {
                            Text(title)
                                .font(.headline)
                            Text(detail)
                                .font(.callout)
                                .foregroundStyle(controller.primaryTextColor.opacity(0.68))
                                .lineLimit(2)
                        }
                        Spacer(minLength: 4)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(controller.primaryTextColor.opacity(0.42))
                    }
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("WorkPulse 提醒，\(title)，\(detail)，按下查看")
                .focused($alertHasKeyboardFocus)
                .onChange(of: alertHasKeyboardFocus) { _, focused in
                    controller.setAlertKeyboardInteracting(focused)
                }
                .onHover(perform: controller.setAlertHovering)
            case .expanded(let content):
                VStack(alignment: .leading, spacing: 11) {
                    HStack {
                        Image("WorkPulseLogo")
                            .resizable()
                            .interpolation(.high)
                            .frame(width: 24, height: 24)
                        Text(content.title)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                        Spacer()
                        Button {
                            controller.dismissExpanded()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(controller.primaryTextColor.opacity(0.52))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("关闭顶部状态详情")
                    }
                    VStack(spacing: 6) {
                        expandedRow(content.primaryLabel, value: content.primaryValue, icon: content.primarySystemImage)
                        expandedRow(content.secondaryLabel, value: content.secondaryValue, icon: content.secondarySystemImage)
                        ForEach(Array(content.additionalRows.enumerated()), id: \.offset) { _, row in
                            expandedRow(row.label, value: row.value, icon: row.systemImage)
                        }
                    }
                    HStack {
                        Text(content.source)
                            .font(.caption2)
                            .foregroundStyle(controller.primaryTextColor.opacity(secondaryTextOpacity))
                            .lineLimit(1)
                        Spacer()
                        if let action = content.primaryAction {
                            Button(action.title) { perform(action) }
                        }
                        if let action = content.secondaryAction {
                            Button(action.title) { perform(action) }
                        }
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .buttonStyle(.bordered)
                    .tint(controller.accentColor)
                    .controlSize(.small)
                }
                .padding(.horizontal, 17)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .contentShape(Rectangle())
                .onHover(perform: controller.setExpandedHovering)
            }
        }
        .padding(.top, controller.contentTopInset)
        .foregroundStyle(controller.primaryTextColor)
        .background {
            if controller.isNotchScreen {
                NotchIslandShape(
                    topInset: controller.contentTopInset,
                    notchWidth: controller.physicalNotchWidth
                )
                .fill(controller.surfaceColor)
            } else {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(controller.surfaceColor)
            }
        }
        .overlay {
            if controller.isNotchScreen {
                NotchIslandShape(
                    topInset: controller.contentTopInset,
                    notchWidth: controller.physicalNotchWidth
                )
                .stroke(controller.primaryTextColor.opacity(colorSchemeContrast == .increased ? 0.24 : 0.12), lineWidth: 1)
            } else {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(controller.primaryTextColor.opacity(colorSchemeContrast == .increased ? 0.24 : 0.12), lineWidth: 1)
            }
        }
        .padding(controller.isNotchScreen
            ? EdgeInsets(top: 0, leading: 2, bottom: 2, trailing: 2)
            : EdgeInsets(top: 2, leading: 2, bottom: 2, trailing: 2))
        .onAppear {
            controller.setAccessibilityTextLayout(dynamicTypeSize.isAccessibilitySize)
        }
        .onChange(of: dynamicTypeSize) { _, size in
            controller.setAccessibilityTextLayout(size.isAccessibilitySize)
        }
    }

    private func expandedRow(_ label: String, value: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(controller.accentColor)
                .frame(width: 20)
            Text(label)
                .font(.caption)
                .foregroundStyle(controller.primaryTextColor.opacity(rowLabelOpacity))
            Spacer()
            Text(value)
                .font(.callout.weight(.semibold))
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(controller.primaryTextColor.opacity(controller.usesDarkSurface ? 0.055 : 0.06), in: RoundedRectangle(cornerRadius: 9))
    }

    private func perform(_ action: NotchExpandedAction) {
        NotificationCenter.default.post(name: .workPulseNotchAction, object: action)
    }

    private var secondaryTextOpacity: Double {
        if colorSchemeContrast == .increased { return 0.82 }
        return controller.usesDarkSurface ? 0.62 : 0.70
    }

    private var rowLabelOpacity: Double {
        if colorSchemeContrast == .increased { return 0.86 }
        return controller.usesDarkSurface ? 0.68 : 0.72
    }
}

private struct NotchIslandShape: Shape {
    let topInset: CGFloat
    let notchWidth: CGFloat

    func path(in rect: CGRect) -> Path {
        let bottomRadius: CGFloat = 22
        let shoulderRadius: CGFloat = 12
        let resolvedNotchWidth = min(
            rect.width - shoulderRadius * 4,
            max(notchWidth, min(190, rect.width * 0.58))
        )
        let notchLeft = rect.midX - resolvedNotchWidth / 2
        let notchRight = rect.midX + resolvedNotchWidth / 2
        let shoulderY = min(max(topInset, 0), rect.height - bottomRadius)

        var path = Path()
        path.move(to: CGPoint(x: notchLeft, y: rect.minY))
        path.addLine(to: CGPoint(x: notchRight, y: rect.minY))
        path.addLine(to: CGPoint(x: notchRight, y: max(rect.minY, shoulderY - shoulderRadius)))
        path.addQuadCurve(
            to: CGPoint(x: notchRight + shoulderRadius, y: shoulderY),
            control: CGPoint(x: notchRight, y: shoulderY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - bottomRadius, y: shoulderY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: shoulderY + bottomRadius),
            control: CGPoint(x: rect.maxX, y: shoulderY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottomRadius))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - bottomRadius, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX + bottomRadius, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - bottomRadius),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX, y: shoulderY + bottomRadius))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + bottomRadius, y: shoulderY),
            control: CGPoint(x: rect.minX, y: shoulderY)
        )
        path.addLine(to: CGPoint(x: notchLeft - shoulderRadius, y: shoulderY))
        path.addQuadCurve(
            to: CGPoint(x: notchLeft, y: max(rect.minY, shoulderY - shoulderRadius)),
            control: CGPoint(x: notchLeft, y: shoulderY)
        )
        path.closeSubpath()
        return path
    }
}
