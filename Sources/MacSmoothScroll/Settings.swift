import Foundation
import Combine

final class Settings: ObservableObject {
    static let shared = Settings()

    private let defaults = UserDefaults.standard
    private enum Keys {
        static let enabled = "smoothEnabled"
        static let reverse = "reverseMouse"
        static let speed = "scrollSpeed"
        static let jumpShortcut = "jumpShortcutEnabled"
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
    @Published var hideMenuBarIcon: Bool {
        didSet { defaults.set(hideMenuBarIcon, forKey: Keys.hideMenuBarIcon) }
    }

    private init() {
        self.enabled = defaults.object(forKey: Keys.enabled) as? Bool ?? true
        self.reverse = defaults.bool(forKey: Keys.reverse)
        let rawSpeed = defaults.double(forKey: Keys.speed)
        self.speed = rawSpeed == 0 ? 3.0 : rawSpeed
        self.jumpShortcutEnabled = defaults.object(forKey: Keys.jumpShortcut) as? Bool ?? true
        self.hideMenuBarIcon = defaults.bool(forKey: Keys.hideMenuBarIcon)
    }
}
