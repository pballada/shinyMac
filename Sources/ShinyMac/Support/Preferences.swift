import Foundation

/// User settings shared between views (via `@AppStorage`) and models.
enum Preferences {
    enum Key {
        static let alwaysUseTrash = "alwaysUseTrash"
        static let showMenuBarMonitor = "showMenuBarMonitor"
    }

    /// Move everything to the Trash, even regenerable junk that is normally deleted outright.
    static var alwaysUseTrash: Bool { UserDefaults.standard.bool(forKey: Key.alwaysUseTrash) }
}

extension UserDefaults {
    func bool(forKey key: String, default defaultValue: Bool) -> Bool {
        object(forKey: key) == nil ? defaultValue : bool(forKey: key)
    }
}
