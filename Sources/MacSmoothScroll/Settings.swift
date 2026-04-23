import Foundation

final class Settings {
    static let shared = Settings()

    private let defaults = UserDefaults.standard
    private enum Keys {
        static let enabled = "smoothEnabled"
        static let reverse = "reverseMouse"
        static let speed = "scrollSpeed"
        static let jumpShortcut = "jumpShortcutEnabled"
    }

    var onChange: (() -> Void)?

    var enabled: Bool {
        get { defaults.object(forKey: Keys.enabled) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Keys.enabled); onChange?() }
    }

    var reverse: Bool {
        get { defaults.bool(forKey: Keys.reverse) }
        set { defaults.set(newValue, forKey: Keys.reverse); onChange?() }
    }

    // 1.0 ... 6.0, default 3.0
    var speed: Double {
        get {
            let v = defaults.double(forKey: Keys.speed)
            return v == 0 ? 3.0 : v
        }
        set { defaults.set(newValue, forKey: Keys.speed); onChange?() }
    }

    // Cmd+Shift+scroll → jump to top/bottom. Default on.
    var jumpShortcutEnabled: Bool {
        get { defaults.object(forKey: Keys.jumpShortcut) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Keys.jumpShortcut); onChange?() }
    }
}
