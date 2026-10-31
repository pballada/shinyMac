import Foundation
import Testing
@testable import ShinyCore

@Suite struct CareScheduleTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private func daysAgo(_ days: Double) -> Date { now.addingTimeInterval(-days * 86_400) }

    @Test func offIsNeverDue() {
        #expect(!CareSchedule.off.isDue(lastScan: nil, lastReminder: nil, firstLaunch: daysAgo(400), now: now))
    }

    @Test func dueAfterTheIntervalSinceTheLastScanOrReminder() {
        #expect(CareSchedule.weekly.isDue(lastScan: daysAgo(8), lastReminder: nil, firstLaunch: daysAgo(30), now: now))
        #expect(!CareSchedule.weekly.isDue(lastScan: daysAgo(3), lastReminder: nil, firstLaunch: daysAgo(30), now: now))
        #expect(!CareSchedule.weekly.isDue(lastScan: daysAgo(20), lastReminder: daysAgo(2), firstLaunch: daysAgo(30), now: now),
                "A recent reminder resets the clock")
        #expect(!CareSchedule.monthly.isDue(lastScan: daysAgo(20), lastReminder: nil, firstLaunch: daysAgo(90), now: now))
    }

    @Test func newInstallsWaitForTheFirstInterval() {
        #expect(!CareSchedule.weekly.isDue(lastScan: nil, lastReminder: nil, firstLaunch: daysAgo(1), now: now))
        #expect(CareSchedule.weekly.isDue(lastScan: nil, lastReminder: nil, firstLaunch: daysAgo(7), now: now))
    }

    @Test func estimatesRecommendedJunkPlusTrash() throws {
        let home = try TempFolder()
        try home.file("Library/Caches/com.example/data", bytes: 40_000)
        try home.file("Downloads/Setup.dmg", bytes: 50_000) // unchecked by default, not counted
        try home.file(".Trash/old.zip", bytes: 20_000)
        let estimate = CareSchedule.cleanableEstimate(home: home.url)
        #expect(estimate >= 60_000 && estimate < 110_000)
    }
}
