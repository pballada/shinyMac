import Foundation

/// Conditions worth a gentle notification.
public enum SpaceAlert: String, Sendable, CaseIterable {
    case lowDiskSpace
    case largeTrash

    public static let lowSpaceFraction = 0.10
    public static let lowSpaceBytes: Int64 = 10_000_000_000
    public static let largeTrashBytes: Int64 = 5_000_000_000

    /// Which alerts apply, given the startup volume and the Trash's size.
    public static func evaluate(volume: VolumeInfo?, trashSize: Int64) -> [SpaceAlert] {
        var alerts: [SpaceAlert] = []
        if let volume, volume.total > 0,
           volume.available < lowSpaceBytes || Double(volume.available) / Double(volume.total) < lowSpaceFraction {
            alerts.append(.lowDiskSpace)
        }
        if trashSize >= largeTrashBytes { alerts.append(.largeTrash) }
        return alerts
    }

    /// Whether enough time has passed since this alert was last shown.
    public static func isDue(lastShown: Date?, now: Date = .now, interval: TimeInterval = 86_400) -> Bool {
        guard let lastShown else { return true }
        return now.timeIntervalSince(lastShown) >= interval
    }
}
