import SwiftUI
import AppKit
import ServiceManagement

struct SettingsView: View {
    @ObservedObject var settings = Settings.shared
    @State private var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled
    @State private var launchAtLoginError: String?

    var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: launchAtLoginBinding)
                Toggle("Hide menu bar icon", isOn: $settings.hideMenuBarIcon)
                if settings.hideMenuBarIcon {
                    Text("Relaunch the app (Spotlight, Raycast, etc.) to reopen this window.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let err = launchAtLoginError {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            } header: {
                Text("General")
            }

            Section {
                Toggle("Enable smooth scroll", isOn: $settings.enabled)
                Toggle("Reverse mouse scroll", isOn: $settings.reverse)
                Toggle("Jump to top / bottom  (⌘⇧ + Scroll)", isOn: $settings.jumpShortcutEnabled)
                LabeledContent("Scrolling Speed") {
                    Slider(value: $settings.speed, in: 1...6, step: 1) {
                        EmptyView()
                    } minimumValueLabel: {
                        Text("Slow").font(.caption).foregroundStyle(.secondary)
                    } maximumValueLabel: {
                        Text("Fast").font(.caption).foregroundStyle(.secondary)
                    }
                    .frame(minWidth: 220)
                }
            } header: {
                Text("Scrolling")
            }

            Section {
                HStack {
                    Spacer()
                    Button(role: .destructive) {
                        NSApp.terminate(nil)
                    } label: {
                        Text("Quit MacSmoothScroll")
                    }
                    .keyboardShortcut("q", modifiers: .command)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { launchAtLogin },
            set: { newValue in
                let service = SMAppService.mainApp
                do {
                    if newValue {
                        try service.register()
                    } else {
                        try service.unregister()
                    }
                    launchAtLogin = service.status == .enabled
                    launchAtLoginError = nil
                } catch {
                    launchAtLoginError = "Couldn't change login item. This requires running the bundled .app (make install)."
                    launchAtLogin = service.status == .enabled
                }
            }
        )
    }
}
