import Foundation
import Testing
@testable import ShinyCore

@Suite struct SpaceAlertTests {
    let terabyte: Int64 = 1_000_000_000_000

    @Test func lowSpaceByFractionOrAbsoluteFloor() {
        #expect(SpaceAlert.evaluate(volume: VolumeInfo(name: "HD", total: terabyte, available: 50_000_000_000), trashSize: 0) == [.lowDiskSpace])
        #expect(SpaceAlert.evaluate(volume: VolumeInfo(name: "HD", total: 50_000_000_000, available: 8_000_000_000), trashSize: 0) == [.lowDiskSpace])
        #expect(SpaceAlert.evaluate(volume: VolumeInfo(name: "HD", total: terabyte, available: 300_000_000_000), trashSize: 0).isEmpty)
    }

    @Test func largeTrash() {
        let roomy = VolumeInfo(name: "HD", total: terabyte, available: 500_000_000_000)
        #expect(SpaceAlert.evaluate(volume: roomy, trashSize: 6_000_000_000) == [.largeTrash])
        #expect(SpaceAlert.evaluate(volume: nil, trashSize: 1_000).isEmpty)
    }

    @Test func throttlesToOncePerDay() {
        let now = Date.now
        #expect(SpaceAlert.isDue(lastShown: nil, now: now))
        #expect(!SpaceAlert.isDue(lastShown: now.addingTimeInterval(-3_600), now: now))
        #expect(SpaceAlert.isDue(lastShown: now.addingTimeInterval(-90_000), now: now))
    }
}
