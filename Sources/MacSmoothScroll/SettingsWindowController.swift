import AppKit
import SwiftUI

final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    var onClose: (() -> Void)?
    private var keyMonitor: Any?

    convenience init() {
        let hosting = NSHostingController(rootView: SettingsView())
        let window = NSWindow(contentViewController: hosting)
        window.title = "MacSmoothScroll"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 440, height: 480))
        window.center()
        self.init(window: window)
        window.delegate = self
    }

    func show() {
        guard let window = window else { return }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        installKeyMonitor()
    }

    // Accessory-mode apps don't get a standard "Window > Close" menu, so ⌘W has no default
    // handler. Install a local monitor that routes ⌘W to performClose while the window is key.
    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard
                let self = self,
                let window = self.window,
                window.isKeyWindow,
                event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
                event.charactersIgnoringModifiers == "w"
            else {
                return event
            }
            window.performClose(nil)
            return nil
        }
    }

    private func removeKeyMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }

    func windowWillClose(_ notification: Notification) {
        removeKeyMonitor()
        onClose?()
    }
}
