import Cocoa
import ApplicationServices
import ServiceManagement
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var contextMenu: NSMenu?
    private var settingsWindowController: SettingsWindowController?
    private var cancellables: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        ensureAccessibilityPermission()
        applyMenuBarVisibility()
        observeSettings()
        ScrollEngine.shared.start()

        // If the menu bar icon is hidden, surface settings so the user isn't stranded.
        // But stay silent on a likely boot launch — popping a window during login is jarring.
        if Settings.shared.hideMenuBarIcon && !isLikelyLoginLaunch() {
            showSettingsWindow()
        }
    }

    /// Heuristic: if the system has only just finished booting, this launch is almost
    /// certainly a "launch at login" auto-start rather than an explicit user action.
    /// macOS doesn't expose a first-class API for this with `SMAppService.mainApp`.
    private func isLikelyLoginLaunch() -> Bool {
        ProcessInfo.processInfo.systemUptime < 120
    }

    func applicationWillTerminate(_ notification: Notification) {
        ScrollEngine.shared.stop()
    }

    /// Called when the app is relaunched (Spotlight, Raycast, `open -a`, Dock click).
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettingsWindow()
        return true
    }

    // MARK: - Permission

    private func ensureAccessibilityPermission() {
        let key = "AXTrustedCheckOptionPrompt" as CFString
        let opts = [key: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(opts)
        if !trusted {
            NSLog("Accessibility permission not granted. Grant it in System Settings → Privacy & Security → Accessibility, then relaunch.")
        }
    }

    // MARK: - Settings observation

    private func observeSettings() {
        Settings.shared.$hideMenuBarIcon
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.applyMenuBarVisibility() }
            .store(in: &cancellables)
    }

    private func applyMenuBarVisibility() {
        if Settings.shared.hideMenuBarIcon {
            removeStatusItem()
        } else {
            buildStatusItemIfNeeded()
        }
    }

    private func removeStatusItem() {
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
        }
        statusItem = nil
    }

    // MARK: - Menu bar UI

    private func buildStatusItemIfNeeded() {
        guard statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            if let url = Bundle.module.url(forResource: "mouse", withExtension: "svg"),
               let image = NSImage(contentsOf: url) {
                image.size = NSSize(width: 18, height: 18)
                image.isTemplate = true
                button.image = image
            } else {
                button.title = "↕"
            }
            button.toolTip = "MacSmoothScroll — click for settings, right-click for menu"
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        let menu = NSMenu()
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
        self.contextMenu = menu

        self.statusItem = item
    }

    @objc private func statusItemClicked(_ sender: Any?) {
        guard let event = NSApp.currentEvent else {
            showSettingsWindow()
            return
        }
        let isRightClick = event.type == .rightMouseUp
            || (event.type == .leftMouseUp && event.modifierFlags.contains(.control))
        if isRightClick {
            presentContextMenu()
        } else {
            showSettingsWindow()
        }
    }

    private func presentContextMenu() {
        guard let item = statusItem, let button = item.button, let menu = contextMenu else { return }
        // Attach temporarily so the system positions the menu under the status item; detach after.
        item.menu = menu
        button.performClick(nil)
        item.menu = nil
    }

    @objc private func showSettings() {
        showSettingsWindow()
    }

    // MARK: - Settings window

    private func showSettingsWindow() {
        if settingsWindowController == nil {
            let controller = SettingsWindowController()
            controller.onClose = { [weak self] in self?.settingsWindowDidClose() }
            settingsWindowController = controller
        }
        NSApp.setActivationPolicy(.regular)
        settingsWindowController?.show()
    }

    private func settingsWindowDidClose() {
        NSApp.setActivationPolicy(.accessory)
    }
}
