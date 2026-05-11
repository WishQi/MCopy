import AppKit
import SwiftUI
import SwiftData

enum PanelPosition: String, CaseIterable, Identifiable {
    case left, bottom, right, top

    var id: String { rawValue }
    static let defaultsKey = "panelPosition"

    static var current: PanelPosition {
        guard let raw = UserDefaults.standard.string(forKey: defaultsKey),
              let v = PanelPosition(rawValue: raw) else { return .bottom }
        return v
    }

    var icon: String {
        switch self {
        case .left:   return "rectangle.lefthalf.filled"
        case .bottom: return "rectangle.bottomhalf.filled"
        case .right:  return "rectangle.righthalf.filled"
        case .top:    return "rectangle.tophalf.filled"
        }
    }

    var label: String {
        switch self {
        case .left: return "Left"
        case .bottom: return "Bottom"
        case .right: return "Right"
        case .top: return "Top"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .left: return "Left side"
        case .bottom: return "Bottom"
        case .right: return "Right side"
        case .top: return "Top"
        }
    }

    var isVertical: Bool { self == .left || self == .right }
}

class ClipboardPanel: NSPanel, NSWindowDelegate {
    private var previousApp: NSRunningApplication?
    weak var monitor: ClipboardMonitor?

    private var isAnimatingClose = false
    private var skipCloseAnimation = false
    private let openDuration: TimeInterval = 0.22
    private let closeDuration: TimeInterval = 0.16
    private let slideOffset: CGFloat = 24

    init(container: ModelContainer) {
        // Placeholder frame — showPanel() resizes & repositions on each open.
        super.init(
            contentRect: .zero,
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false  // system shadow draws a 1px inner edge highlight
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        delegate = self

        let view = ClipboardHistoryView(
            onPaste: { [weak self] item in self?.pasteItem(item) },
            onDismiss: { [weak self] in self?.close() }
        )
        .modelContainer(container)

        contentView = NSHostingView(rootView: view)
    }

    override var canBecomeKey: Bool { true }

    func showPanel() {
        previousApp = NSWorkspace.shared.frontmostApplication

        guard let screen = NSScreen.main else {
            alphaValue = 1
            makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let position = PanelPosition.current
        let panelBarHeight: CGFloat = 230
        let sidePanelWidth: CGFloat = 220
        let sideMargin: CGFloat = 20
        let vf = screen.visibleFrame

        let finalFrame: CGRect
        switch position {
        case .bottom:
            // Keep at least 32pt above the absolute screen bottom (covers the
            // auto-hide-Dock case). When the Dock is shown at the bottom, sit 16pt above it.
            let y = max(vf.minY + 16, screen.frame.minY + 32)
            finalFrame = CGRect(
                x: vf.minX + sideMargin,
                y: y,
                width: vf.width - sideMargin * 2,
                height: panelBarHeight
            )
        case .top:
            let y = vf.maxY - panelBarHeight - 12
            finalFrame = CGRect(
                x: vf.minX + sideMargin,
                y: y,
                width: vf.width - sideMargin * 2,
                height: panelBarHeight
            )
        case .left:
            finalFrame = CGRect(
                x: vf.minX + sideMargin,
                y: vf.minY + sideMargin,
                width: sidePanelWidth,
                height: vf.height - sideMargin * 2
            )
        case .right:
            finalFrame = CGRect(
                x: vf.maxX - sidePanelWidth - sideMargin,
                y: vf.minY + sideMargin,
                width: sidePanelWidth,
                height: vf.height - sideMargin * 2
            )
        }

        let slideIn = Self.slideInOffset(for: position, slideOffset: slideOffset)
        let startFrame = finalFrame.offsetBy(dx: slideIn.width, dy: slideIn.height)

        setFrame(startFrame, display: false)
        alphaValue = 0
        makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = openDuration
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animator().setFrame(finalFrame, display: true)
            animator().alphaValue = 1
        }
    }

    override func close() {
        if skipCloseAnimation {
            super.close()
            return
        }
        if isAnimatingClose { return }
        isAnimatingClose = true

        let slideOut = Self.slideOutOffset(for: PanelPosition.current, slideOffset: slideOffset)
        let endFrame = frame.offsetBy(dx: slideOut.width, dy: slideOut.height)
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = closeDuration
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            animator().setFrame(endFrame, display: true)
            animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            guard let self else { return }
            self.skipCloseAnimation = true
            self.close()
            self.skipCloseAnimation = false
            self.isAnimatingClose = false
            self.alphaValue = 1
        })
    }

    func windowDidResignKey(_ notification: Notification) {
        close()
    }

    private func pasteItem(_ item: ClipboardItem) {
        monitor?.ignoreNextChange()
        item.writeToPasteboard()
        // Skip the close animation here — the panel needs to disappear immediately
        // so the synthesized ⌘V lands in the previous app, not our panel.
        skipCloseAnimation = true
        close()
        skipCloseAnimation = false

        guard let app = previousApp else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            app.activate()
            if AXIsProcessTrusted() {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    Self.simulateCmdV()
                }
            }
        }
    }

    private static func simulateCmdV() {
        let src = CGEventSource(stateID: .hidSystemState)
        let vKey: CGKeyCode = 9
        guard let down = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: true),
              let up   = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: false)
        else { return }
        down.flags = .maskCommand
        up.flags   = .maskCommand
        down.post(tap: .cgSessionEventTap)
        up.post(tap: .cgSessionEventTap)
    }

    /// Offset from `finalFrame` to the pre-animation frame (panel starts off-screen, slides in).
    private static func slideInOffset(for position: PanelPosition, slideOffset: CGFloat) -> CGSize {
        switch position {
        case .bottom: return CGSize(width: 0, height: -slideOffset)
        case .top:    return CGSize(width: 0, height: slideOffset)
        case .left:   return CGSize(width: -slideOffset, height: 0)
        case .right:  return CGSize(width: slideOffset, height: 0)
        }
    }

    /// Offset from current frame toward off-screen when closing.
    private static func slideOutOffset(for position: PanelPosition, slideOffset: CGFloat) -> CGSize {
        switch position {
        case .bottom: return CGSize(width: 0, height: -slideOffset)
        case .top:    return CGSize(width: 0, height: slideOffset)
        case .left:   return CGSize(width: -slideOffset, height: 0)
        case .right:  return CGSize(width: slideOffset, height: 0)
        }
    }
}
