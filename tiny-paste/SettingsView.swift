import AppKit
import SwiftUI

/// Menu bar apps use `.accessory` activation; SwiftUI settings windows otherwise stay behind other apps.
enum TinyPasteSettingsPresentation {
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

    // Placeholder state — General toggles not yet wired to real settings.
    @State private var openAtLogin = false
    @State private var runInBackground = true
    @State private var iCloudSync = false
    @State private var soundEffects = true

    private var panelPosition: PanelPosition {
        PanelPosition(rawValue: panelPositionRaw) ?? .bottom
    }

    var body: some View {
        Form {
            Section("General") {
                Toggle("Open at login",    isOn: $openAtLogin)
                Toggle("Run in background", isOn: $runInBackground)
                Toggle("iCloud sync",      isOn: $iCloudSync)
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
                }
                LabeledContent("Activate Paste Stack") {
                    KeyRecorderView(shortcut: shortcuts.binding(for: .activatePasteStack))
                }
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
            TinyPasteSettingsPresentation.activateAndBringToFront()
        }
        .onDisappear {
            TinyPasteSettingsPresentation.restoreAccessoryActivationPolicy()
        }
    }

}

#Preview {
    SettingsView()
}
