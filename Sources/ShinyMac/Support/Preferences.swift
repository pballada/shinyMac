import Foundation
import ShinyCore

/// User settings shared between views (via `@AppStorage`) and models.
enum Preferences {
    enum Key {
        static let alwaysUseTrash = "alwaysUseTrash"
        static let showMenuBarMonitor = "showMenuBarMonitor"
        static let hasOnboarded = "hasOnboarded"
        static let spaceAlerts = "spaceAlerts"
        static let careSchedule = "careSchedule"
        static let lastSmartCareScan = "lastSmartCareScan"
        static let lastCareReminder = "lastCareReminder"
        static let firstLaunch = "firstLaunch"
    }

    /// Move everything to the Trash, even regenerable junk that is normally deleted outright.
    static var alwaysUseTrash: Bool { UserDefaults.standard.bool(forKey: Key.alwaysUseTrash) }

    /// Smart Care reminders default to weekly.
    static var careSchedule: CareSchedule {
        let stored = UserDefaults.standard.object(forKey: Key.careSchedule) as? Int
        return stored.flatMap(CareSchedule.init(rawValue:)) ?? .weekly
    }
}

extension UserDefaults {
    func bool(forKey key: String, default defaultValue: Bool) -> Bool {
        object(forKey: key) == nil ? defaultValue : bool(forKey: key)
    }
}
