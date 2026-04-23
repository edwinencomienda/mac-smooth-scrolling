import Foundation
import Combine
import CoreGraphics

/// User-selected CGEventFlags bitmask that must be held while scrolling to trigger
/// the jump-to-top/bottom gesture. A value of 0 disables the jump (no modifier set).
enum JumpModifierFlagsDefaults {
    static let defaultFlags: UInt64 = CGEventFlags.maskAlternate.rawValue
}

func modifierDisplayString(_ flags: CGEventFlags) -> String {
    var s = ""
    if flags.contains(.maskControl)   { s += "⌃" }
    if flags.contains(.maskAlternate) { s += "⌥" }
    if flags.contains(.maskShift)     { s += "⇧" }
    if flags.contains(.maskCommand)   { s += "⌘" }
    return s
}

final class Settings: ObservableObject {
    static let shared = Settings()

    private let defaults = UserDefaults.standard
    private enum Keys {
        static let enabled = "smoothEnabled"
        static let reverse = "reverseMouse"
        static let speed = "scrollSpeed"
        static let jumpShortcut = "jumpShortcutEnabled"
        static let jumpFlags = "jumpShortcutFlags"
        static let hideMenuBarIcon = "hideMenuBarIcon"
    }

    @Published var enabled: Bool {
        didSet { defaults.set(enabled, forKey: Keys.enabled) }
    }
    @Published var reverse: Bool {
        didSet { defaults.set(reverse, forKey: Keys.reverse) }
    }
    @Published var speed: Double {
        didSet { defaults.set(speed, forKey: Keys.speed) }
    }
    @Published var jumpShortcutEnabled: Bool {
        didSet { defaults.set(jumpShortcutEnabled, forKey: Keys.jumpShortcut) }
    }
    /// CGEventFlags bitmask. 0 means "no modifier chosen" (jump effectively disabled).
    @Published var jumpModifierFlags: UInt64 {
        didSet { defaults.set(Int64(bitPattern: jumpModifierFlags), forKey: Keys.jumpFlags) }
    }
    @Published var hideMenuBarIcon: Bool {
        didSet { defaults.set(hideMenuBarIcon, forKey: Keys.hideMenuBarIcon) }
    }

    private init() {
        self.enabled = defaults.object(forKey: Keys.enabled) as? Bool ?? true
        self.reverse = defaults.bool(forKey: Keys.reverse)
        let rawSpeed = defaults.double(forKey: Keys.speed)
        self.speed = rawSpeed == 0 ? 3.0 : rawSpeed
        self.jumpShortcutEnabled = defaults.object(forKey: Keys.jumpShortcut) as? Bool ?? true
        if let storedFlags = defaults.object(forKey: Keys.jumpFlags) as? Int64 {
            self.jumpModifierFlags = UInt64(bitPattern: storedFlags)
        } else if let storedFlags = defaults.object(forKey: Keys.jumpFlags) as? Int {
            self.jumpModifierFlags = UInt64(bitPattern: Int64(storedFlags))
        } else {
            self.jumpModifierFlags = JumpModifierFlagsDefaults.defaultFlags
        }
        self.hideMenuBarIcon = defaults.bool(forKey: Keys.hideMenuBarIcon)
    }
}
