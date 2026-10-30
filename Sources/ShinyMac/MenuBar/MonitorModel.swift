import ShinyCore
import SwiftUI

/// Samples system stats every couple of seconds while the menu bar panel is open.
@Observable
final class MonitorModel {
    private(set) var snapshot = SystemSnapshot()
    private(set) var cpuHistory: [Double] = []
    private(set) var isFreeingMemory = false
    private(set) var freedMemory: Int64?
    @ObservationIgnored private let monitor = SystemMonitor()

    func run() async {
        refresh()
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(2))
            refresh()
        }
    }

    func refresh() {
        snapshot = monitor.sample()
        cpuHistory = Array((cpuHistory + [snapshot.cpuUsage]).suffix(30))
    }

    func freeUpMemory() {
        guard let task = Maintenance.tasks.first(where: { $0.id == "freeRAM" }) else { return }
        let before = snapshot.memoryUsed
        isFreeingMemory = true
        freedMemory = nil
        Task {
            _ = await runInBackground { Maintenance.runAsAdmin([task]) }
            refresh()
            isFreeingMemory = false
            freedMemory = max(0, before - snapshot.memoryUsed)
        }
    }
}
