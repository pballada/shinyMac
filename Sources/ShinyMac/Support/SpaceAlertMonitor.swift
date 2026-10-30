import ShinyCore
import UserNotifications

/// Checks free space and the Trash every half hour and posts a notification at most once a day per alert.
enum SpaceAlertMonitor {
    static let checkInterval: Duration = .seconds(30 * 60)

    static func start() {
        // Notifications need a real app bundle; skip when run as a bare executable (`swift run`).
        guard Bundle.main.bundleIdentifier != nil else { return }
        Task {
            try? await Task.sleep(for: .seconds(60))
            while !Task.isCancelled {
                await check()
                try? await Task.sleep(for: checkInterval)
            }
        }
    }

    static func check() async {
        guard UserDefaults.standard.bool(forKey: Preferences.Key.spaceAlerts, default: true) else { return }
        let alerts = await runInBackground {
            SpaceAlert.evaluate(volume: VolumeInfo.current(), trashSize: FileSizer.size(of: Paths.trash))
        } ?? []
        for alert in alerts {
            let key = "lastAlert.\(alert.rawValue)"
            guard SpaceAlert.isDue(lastShown: UserDefaults.standard.object(forKey: key) as? Date) else { continue }
            if await post(alert) { UserDefaults.standard.set(Date.now, forKey: key) }
        }
    }

    /// Asks for permission the first time an alert actually needs to be shown.
    private static func post(_ alert: SpaceAlert) async -> Bool {
        let center = UNUserNotificationCenter.current()
        guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return false }
        let content = UNMutableNotificationContent()
        switch alert {
        case .lowDiskSpace:
            let free = VolumeInfo.current().map { ByteFormat.string($0.available) } ?? "Little space"
            content.title = "Your Mac is running out of space"
            content.body = "\(free) left. Open ShinyMac to find junk and large files you can remove."
        case .largeTrash:
            content.title = "Your Trash is getting big"
            content.body = "\(ByteFormat.string(FileSizer.size(of: Paths.trash))) is waiting in the Trash. Empty it to get that space back."
        }
        let request = UNNotificationRequest(identifier: alert.rawValue, content: content, trigger: nil)
        return (try? await center.add(request)) != nil
    }
}
