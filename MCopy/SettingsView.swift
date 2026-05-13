import AppKit
import Combine
import ServiceManagement
import SwiftUI

/// Wraps `SMAppService.mainApp` so the "Open at login" toggle can reflect and mutate the launch-at-login state.
enum LoginItemManager {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        let service = SMAppService.mainApp
        do {
            if enabled {
                if service.status != .enabled {
                    try service.register()
                }
            } else {
                if service.status == .enabled {
                    try service.unregister()
                }
            }
            return true
        } catch {
            NSLog("Failed to update login item: \(error.localizedDescription)")
            return false
        }
    }
}

/// Menu bar apps use `.accessory` activation; SwiftUI settings windows otherwise stay behind other apps.
enum MCopySettingsPresentation {
    private static let settingsContentWidth: CGFloat = 520

    static func activateAndBringToFront() {
        if NSApp.activationPolicy() == .accessory {
            NSApp.setActivationPolicy(.regular)
        }
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            let candidates = NSApp.windows.filter { $0.isVisible && $0.canBecomeKey }
            guard !candidates.isEmpty else { return }
            let target = candidates.min(by: {
                abs($0.frame.width - settingsContentWidth) < abs($1.frame.width - settingsContentWidth)
            })
            target?.makeKeyAndOrderFront(nil)
        }
    }

    static func restoreAccessoryActivationPolicy() {
        NSApp.setActivationPolicy(.accessory)
    }
}

struct SettingsView: View {
    @StateObject private var shortcuts = ShortcutStore.shared
    @AppStorage(PanelPosition.defaultsKey) private var panelPositionRaw: String = PanelPosition.bottom.rawValue

    @State private var openAtLogin = LoginItemManager.isEnabled
    @State private var accessibilityTrusted = AXIsProcessTrusted()
    // Placeholder state — remaining General toggles not yet wired to real settings.
    @State private var iCloudSync = false
    @State private var soundEffects = true

    private let accessibilityRefreshTimer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    private var panelPosition: PanelPosition {
        PanelPosition(rawValue: panelPositionRaw) ?? .bottom
    }

    var body: some View {
        Form {
            Section("General") {
                Toggle("Open at login",    isOn: $openAtLogin)
                    .onChange(of: openAtLogin) { _, newValue in
                        if !LoginItemManager.setEnabled(newValue) {
                            openAtLogin = LoginItemManager.isEnabled
                        }
                    }
                Toggle("iCloud sync",      isOn: $iCloudSync)
                    .disabled(true)
                Toggle("Sound effects",    isOn: $soundEffects)

                LabeledContent("Panel position on screen") {
                    HStack(spacing: 2) {
                        ForEach(PanelPosition.allCases) { pos in
                            Button {
                                panelPositionRaw = pos.rawValue
                            } label: {
                                Image(systemName: pos.icon)
                                    .font(.system(size: 15, weight: .medium))
                                    .frame(width: 32, height: 26)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(panelPosition == pos ? Color.accentColor : .secondary)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(panelPosition == pos ? Color.accentColor.opacity(0.15) : Color.clear)
                            )
                            .accessibilityLabel(pos.accessibilityLabel)
                        }
                    }
                    .padding(.leading, 4)
                }
            }

            Section("Shortcuts") {
                LabeledContent("Activate Paste") {
                    KeyRecorderView(shortcut: shortcuts.binding(for: .activatePaste))
                        .disabled(true)
                }
                LabeledContent("Activate Paste Stack") {
                    KeyRecorderView(shortcut: shortcuts.binding(for: .activatePasteStack))
                        .disabled(true)
                }
            }

            Section("Auto-paste") {
                HStack(spacing: 10) {
                    Image(systemName: accessibilityTrusted
                          ? "checkmark.circle.fill"
                          : "exclamationmark.triangle.fill")
                        .foregroundStyle(accessibilityTrusted ? .green : .orange)
                        .font(.system(size: 16))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(accessibilityTrusted
                             ? "Accessibility access granted"
                             : "Accessibility access required")
                            .font(.headline)
                        Text(accessibilityTrusted
                             ? "MCopy can paste directly into the previous app."
                             : "Without this, selecting a history item copies it to the clipboard but won’t auto-paste.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    if !accessibilityTrusted {
                        Button("Open Settings") {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    }
                }
                .padding(.vertical, 2)
            }

            Section("Subscription") {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Free Plan").font(.headline)
                        Text("Upgrade to unlock cloud sync and unlimited history.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Upgrade") {}
                        .buttonStyle(.borderedProminent)
                }
                .padding(.vertical, 2)
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 560)
        .onAppear {
            openAtLogin = LoginItemManager.isEnabled
            accessibilityTrusted = AXIsProcessTrusted()
            MCopySettingsPresentation.activateAndBringToFront()
        }
        .onReceive(accessibilityRefreshTimer) { _ in
            let trusted = AXIsProcessTrusted()
            if trusted != accessibilityTrusted { accessibilityTrusted = trusted }
        }
        .onDisappear {
            MCopySettingsPresentation.restoreAccessoryActivationPolicy()
        }
    }

}

#Preview {
    SettingsView()
}
