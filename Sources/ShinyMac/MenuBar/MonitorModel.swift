import AppKit
import ShinyCore
import SwiftUI

/// Samples system stats every couple of seconds while the menu bar panel is open.
@Observable
final class MonitorModel {
    private(set) var snapshot = SystemSnapshot()
    private(set) var cpuHistory: [Double] = []
    private(set) var isFreeingMemory = false
    private(set) var freedMemory: Int64?
    private(set) var topProcesses: [ProcessUsage] = []
    var topMetric: ProcessList.Metric = .cpu {
        didSet { Task { await refreshProcesses() } }
    }
    @ObservationIgnored private let monitor = SystemMonitor()

    func run() async {
        refresh()
        await refreshProcesses()
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(2))
            refresh()
            await refreshProcesses()
        }
    }

    func refreshProcesses() async {
        let metric = topMetric
        topProcesses = await runInBackground { ProcessList.top(by: metric) } ?? topProcesses
    }

    /// The regular app behind a process group, if any, for its icon and the Quit button.
    func app(for usage: ProcessUsage) -> NSRunningApplication? {
        let running = NSWorkspace.shared.runningApplications
        return running.first { usage.pids.contains($0.processIdentifier) && $0.activationPolicy == .regular }
            ?? running.first { $0.localizedName == usage.name && $0.activationPolicy == .regular }
    }

    func quit(_ usage: ProcessUsage) {
        app(for: usage)?.terminate()
        Task {
            try? await Task.sleep(for: .seconds(1))
            await refreshProcesses()
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
