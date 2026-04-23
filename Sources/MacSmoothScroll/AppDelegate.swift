import Cocoa
import ApplicationServices
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var speedSlider: NSSlider!
    private var speedLabel: NSTextField!

    func applicationDidFinishLaunching(_ notification: Notification) {
        ensureAccessibilityPermission()
        buildStatusItem()
        ScrollEngine.shared.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        ScrollEngine.shared.stop()
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

    // MARK: - Menu bar UI

    private func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            if let url = Bundle.module.url(forResource: "mouse", withExtension: "svg"),
               let image = NSImage(contentsOf: url) {
                image.size = NSSize(width: 18, height: 18)
                image.isTemplate = true
                button.image = image
            } else {
                button.title = "↕"
            }
            button.toolTip = "Smooth Scroll"
        }

        let menu = NSMenu()

        let enableItem = NSMenuItem(title: "Enable smooth scroll", action: #selector(toggleEnabled), keyEquivalent: "")
        enableItem.target = self
        enableItem.state = Settings.shared.enabled ? .on : .off
        menu.addItem(enableItem)

        let reverseItem = NSMenuItem(title: "Reverse mouse scroll", action: #selector(toggleReverse), keyEquivalent: "")
        reverseItem.target = self
        reverseItem.state = Settings.shared.reverse ? .on : .off
        menu.addItem(reverseItem)

        menu.addItem(.separator())

        menu.addItem(makeSpeedItem())

        menu.addItem(.separator())

        let loginItem = NSMenuItem(title: "Launch at login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        loginItem.target = self
        loginItem.state = isLaunchAtLoginEnabled() ? .on : .off
        menu.addItem(loginItem)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)

        statusItem.menu = menu
    }

    private func makeSpeedItem() -> NSMenuItem {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 260, height: 68))

        let title = NSTextField(labelWithString: "Scrolling Speed")
        title.frame = NSRect(x: 14, y: 46, width: 232, height: 18)
        title.font = .menuFont(ofSize: 0)
        container.addSubview(title)
        self.speedLabel = title

        let slider = NSSlider(
            value: Settings.shared.speed,
            minValue: 1.0,
            maxValue: 6.0,
            target: self,
            action: #selector(speedChanged(_:))
        )
        slider.frame = NSRect(x: 14, y: 22, width: 232, height: 20)
        slider.isContinuous = true
        slider.numberOfTickMarks = 6
        slider.allowsTickMarkValuesOnly = true
        slider.tickMarkPosition = .below
        container.addSubview(slider)
        self.speedSlider = slider

        let slow = NSTextField(labelWithString: "Slow")
        slow.frame = NSRect(x: 14, y: 2, width: 60, height: 14)
        slow.font = .systemFont(ofSize: 10)
        slow.textColor = .secondaryLabelColor
        container.addSubview(slow)

        let fast = NSTextField(labelWithString: "Fast")
        fast.frame = NSRect(x: 186, y: 2, width: 60, height: 14)
        fast.font = .systemFont(ofSize: 10)
        fast.textColor = .secondaryLabelColor
        fast.alignment = .right
        container.addSubview(fast)

        let item = NSMenuItem()
        item.view = container
        return item
    }

    // MARK: - Actions

    @objc private func toggleEnabled(_ sender: NSMenuItem) {
        Settings.shared.enabled.toggle()
        sender.state = Settings.shared.enabled ? .on : .off
    }

    @objc private func toggleReverse(_ sender: NSMenuItem) {
        Settings.shared.reverse.toggle()
        sender.state = Settings.shared.reverse ? .on : .off
    }

    @objc private func speedChanged(_ sender: NSSlider) {
        Settings.shared.speed = sender.doubleValue
    }

    // MARK: - Launch at login

    private func isLaunchAtLoginEnabled() -> Bool {
        SMAppService.mainApp.status == .enabled
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
            sender.state = isLaunchAtLoginEnabled() ? .on : .off
        } catch {
            NSLog("Launch at login toggle failed: \(error.localizedDescription). This only works when running the bundled .app (make run-app / make install).")
            let alert = NSAlert()
            alert.messageText = "Can't change Launch at Login"
            alert.informativeText = "This feature requires running the bundled app (from /Applications). Build with `make bundle` or `make install` first.\n\n\(error.localizedDescription)"
            alert.alertStyle = .warning
            alert.runModal()
        }
    }
}
