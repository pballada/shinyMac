import Foundation

/// How often to remind the user to run Smart Care.
public enum CareSchedule: Int, CaseIterable, Identifiable, Sendable {
    case off = 0
    case weekly = 7
    case everyTwoWeeks = 14
    case monthly = 30

    public var id: Self { self }

    public var title: String {
        switch self {
        case .off: "Never"
        case .weekly: "Every week"
        case .everyTwoWeeks: "Every two weeks"
        case .monthly: "Every month"
        }
    }

    /// Due once the interval has passed since both the last Smart Care scan and the last reminder.
    /// A Mac that has never been scanned is due once the first reminder interval has passed since `firstLaunch`.
    public func isDue(lastScan: Date?, lastReminder: Date?, firstLaunch: Date, now: Date = .now) -> Bool {
        guard self != .off else { return false }
        let reference = [lastScan, lastReminder].compactMap { $0 }.max() ?? firstLaunch
        return now.timeIntervalSince(reference) >= TimeInterval(rawValue) * 86_400
    }

    /// Bytes Smart Care would clean by default: recommended junk plus the Trash.
    public static func cleanableEstimate(home: URL = Paths.home) -> Int64 {
        let progress = ScanProgress()
        let junk = JunkScanner.scan(home: home, progress: progress)
            .filter(\.selectedByDefault)
            .flatMap(\.items)
            .filter(\.isRecommended)
            .reduce(0) { $0 + $1.size }
        return junk + FileSizer.size(of: home.appending(path: ".Trash", directoryHint: .isDirectory))
    }
}
