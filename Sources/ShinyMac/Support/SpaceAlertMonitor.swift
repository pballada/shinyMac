import ShinyCore
import UserNotifications

/// Every half hour: checks free space and the Trash (at most one notification a day per alert),
/// and reminds the user to run Smart Care on their chosen schedule.
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
        await remindIfDue()
        await checkSpace()
    }

    private static func remindIfDue() async {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: Preferences.Key.firstLaunch) == nil { defaults.set(Date.now, forKey: Preferences.Key.firstLaunch) }
        guard Preferences.careSchedule.isDue(
            lastScan: defaults.object(forKey: Preferences.Key.lastSmartCareScan) as? Date,
            lastReminder: defaults.object(forKey: Preferences.Key.lastCareReminder) as? Date,
            firstLaunch: defaults.object(forKey: Preferences.Key.firstLaunch) as? Date ?? .now
        ) else { return }
        let cleanable = await runInBackground { CareSchedule.cleanableEstimate() } ?? 0
        let content = UNMutableNotificationContent()
        content.title = "Time for a Smart Care checkup"
        content.body = cleanable >= 100_000_000
            ? "About \(ByteFormat.string(cleanable)) of junk is ready to clean. Open ShinyMac to review it."
            : "Open ShinyMac for a quick scan to keep your Mac clean and fast."
        if await post(content, id: "smartCareReminder") { defaults.set(Date.now, forKey: Preferences.Key.lastCareReminder) }
    }

    private static func checkSpace() async {
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
        return await post(content, id: alert.rawValue)
    }

    private static func post(_ content: UNNotificationContent, id: String) async -> Bool {
        let center = UNUserNotificationCenter.current()
        guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return false }
        return (try? await center.add(UNNotificationRequest(identifier: id, content: content, trigger: nil))) != nil
    }
}
