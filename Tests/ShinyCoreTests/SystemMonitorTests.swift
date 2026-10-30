import Foundation
import Testing
@testable import ShinyCore

@Suite struct SystemMonitorTests {
    @Test func samplesPlausibleValues() async throws {
        let monitor = SystemMonitor()
        _ = monitor.sample()
        try await Task.sleep(for: .milliseconds(300))
        let snapshot = monitor.sample()

        #expect((0...1).contains(snapshot.cpuUsage))
        #expect(snapshot.memoryUsed > 0)
        #expect(snapshot.memoryUsed <= snapshot.memoryTotal)
        #expect(snapshot.volume != nil)
        #expect(snapshot.networkIn >= 0 && snapshot.networkOut >= 0)
        if let battery = snapshot.battery { #expect((0...1).contains(battery.level)) }
    }
}
