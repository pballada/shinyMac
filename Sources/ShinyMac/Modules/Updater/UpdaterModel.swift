import AppKit
import ShinyCore
import Synchronization
import SwiftUI

@Observable
final class UpdaterModel {
    enum Phase: Equatable { case idle, checking, ready }

    private(set) var phase: Phase = .idle
    private(set) var updates: [AppUpdate] = []
    private(set) var feedCount = 0
    private(set) var checkedCount = 0
    private(set) var lastChecked: Date?

    static let appStoreUpdates = URL(string: "macappstore://showUpdatesPage")!

    var badge: String? { phase == .ready && !updates.isEmpty ? "\(updates.count)" : nil }

    func check() {
        withAnimation(.smooth) { phase = .checking }
        checkedCount = 0
        Task {
            let apps = await runInBackground { AppScanner.installedApps() } ?? []
            feedCount = await runInBackground { UpdateChecker.feeds(for: apps).count } ?? 0
            let counter = Atomic<Int>(0)
            let poll = Task {
                while !Task.isCancelled {
                    checkedCount = counter.load(ordering: .relaxed)
                    try? await Task.sleep(for: .milliseconds(100))
                }
            }
            let found = await UpdateChecker.check(apps) { counter.add(1, ordering: .relaxed) }
            poll.cancel()
            checkedCount = feedCount
            updates = found
            lastChecked = .now
            withAnimation(.smooth) { phase = .ready }
        }
    }

    /// Adopts results gathered by Smart Care.
    func apply(_ found: [AppUpdate], feedCount: Int) {
        updates = found
        self.feedCount = feedCount
        checkedCount = feedCount
        lastChecked = .now
        withAnimation(.smooth) { phase = .ready }
    }

    /// Opening the app lets its built-in updater take over.
    func open(_ update: AppUpdate) {
        NSWorkspace.shared.openApplication(at: update.app.url, configuration: NSWorkspace.OpenConfiguration())
    }
}
