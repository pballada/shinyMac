import Foundation

/// User settings shared between views (via `@AppStorage`) and models.
enum Preferences {
    enum Key {
        static let alwaysUseTrash = "alwaysUseTrash"
    }

    /// Move everything to the Trash, even regenerable junk that is normally deleted outright.
    static var alwaysUseTrash: Bool { UserDefaults.standard.bool(forKey: Key.alwaysUseTrash) }
}
