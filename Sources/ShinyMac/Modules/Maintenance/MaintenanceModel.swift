import ShinyCore
import SwiftUI

@Observable
final class MaintenanceModel {
    enum Phase: Equatable { case idle, list }

    enum Status: Equatable {
        case waiting, running, done, failed(String), skipped
    }

    let tasks = Maintenance.tasks
    private(set) var phase: Phase = .idle
    var selected: Set<String>
    private(set) var statuses: [String: Status] = [:]
    private(set) var isRunning = false
    private(set) var lastRun: [String: Date]

    private static let lastRunKey = "maintenanceLastRun"

    init() {
        selected = Set(Maintenance.tasks.filter(\.recommended).map(\.id))
        let stored = UserDefaults.standard.dictionary(forKey: Self.lastRunKey) as? [String: Date]
        lastRun = stored ?? [:]
    }

    var badge: String? { selected.isEmpty || phase == .idle ? nil : "\(selected.count)" }

    var completedCount: Int { statuses.values.count { $0 == .done } }

    func showTasks() {
        withAnimation(.smooth) { phase = .list }
    }

    func toggle(_ task: MaintenanceTask) {
        guard !isRunning else { return }
        if selected.contains(task.id) { selected.remove(task.id) } else { selected.insert(task.id) }
    }

    /// Unprivileged tasks run one by one; privileged ones are batched behind a single password prompt.
    func run() {
        Task { await runNow() }
    }

    /// Runs the selected tasks and returns how many succeeded.
    @discardableResult
    func runNow() async -> Int {
        let chosen = tasks.filter { selected.contains($0.id) }
        guard !chosen.isEmpty, !isRunning else { return 0 }
        isRunning = true
        statuses = Dictionary(uniqueKeysWithValues: chosen.map { ($0.id, Status.waiting) })

        do {
            for task in chosen where !task.needsAdmin {
                statuses[task.id] = .running
                let outcome = await runInBackground(minimumDuration: .seconds(0.6)) { Maintenance.run(task) } ?? .cancelled
                record(outcome, for: task)
            }

            let privileged = chosen.filter(\.needsAdmin)
            if !privileged.isEmpty {
                privileged.forEach { statuses[$0.id] = .running }
                let outcomes = await runInBackground(minimumDuration: .seconds(0.6)) { Maintenance.runAsAdmin(privileged) } ?? [:]
                for task in privileged { record(outcomes[task.id] ?? .cancelled, for: task) }
            }

            UserDefaults.standard.set(lastRun, forKey: Self.lastRunKey)
            isRunning = false
        }
        return chosen.count { statuses[$0.id] == .done }
    }

    var selectedTasks: [MaintenanceTask] { tasks.filter { selected.contains($0.id) } }

    private func record(_ outcome: MaintenanceOutcome, for task: MaintenanceTask) {
        withAnimation(.smooth) {
            switch outcome {
            case .success:
                statuses[task.id] = .done
                lastRun[task.id] = .now
            case .failed(let message):
                statuses[task.id] = .failed(message)
            case .cancelled:
                statuses[task.id] = .skipped
            }
        }
    }
}
