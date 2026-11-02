import ShinyCore
import SwiftUI

/// One scan across modules, then one Run that works through the essentials in order: remove junk, empty the Trash,
/// run the speed-up tasks. Anything that needs judgement (updates, leftovers, large files) is only suggested.
/// Results land in each module's own model, so opening a module shows the same data.
@Observable
final class SmartCareModel {
    enum Phase: Equatable { case idle, scanning, ready, running, done }

    /// Scan areas, shown as chips while scanning.
    enum Area: String, CaseIterable, Identifiable {
        case cleanup = "Cleanup"
        case speed = "Speed"
        case applications = "Applications"
        case clutter = "Clutter"
        var id: Self { self }

        var module: Module {
            switch self {
            case .cleanup: .systemJunk
            case .speed: .maintenance
            case .applications: .updater
            case .clutter: .largeFiles
            }
        }
    }

    /// The essentials Run performs, in this order.
    enum Essential: String, CaseIterable, Identifiable {
        case junk, trash, speed
        var id: Self { self }

        var title: String {
            switch self {
            case .junk: "Remove system junk"
            case .trash: "Empty the Trash"
            case .speed: "Speed up your Mac"
            }
        }

        var symbol: String {
            switch self {
            case .junk: "bubbles.and.sparkles.fill"
            case .trash: "trash.fill"
            case .speed: "bolt.fill"
            }
        }

        var module: Module {
            switch self {
            case .junk: .systemJunk
            case .trash: .trash
            case .speed: .maintenance
            }
        }
    }

    enum Status: Equatable {
        case waiting, working, done(String), failed(String), skipped
    }

    private(set) var phase: Phase = .idle
    private(set) var finished: Set<Area> = []
    var enabled: Set<Essential> = Set(Essential.allCases)
    private(set) var statuses: [Essential: Status] = [:]
    private(set) var runDetail = ""
    private(set) var freedBytes: Int64 = 0
    private(set) var tasksCompleted = 0

    let junk: CleanupModel
    let trash: CleanupModel
    let leftovers: CleanupModel
    let largeFiles: LargeFilesModel
    let updater: UpdaterModel
    let maintenance: MaintenanceModel

    init(junk: CleanupModel, trash: CleanupModel, leftovers: CleanupModel, largeFiles: LargeFilesModel,
         updater: UpdaterModel, maintenance: MaintenanceModel) {
        self.junk = junk
        self.trash = trash
        self.leftovers = leftovers
        self.largeFiles = largeFiles
        self.updater = updater
        self.maintenance = maintenance
    }

    // MARK: Summary values

    /// Bytes Run would free with the current choices.
    var freeableBytes: Int64 {
        (enabled.contains(.junk) ? junk.selectedSize : 0) + (enabled.contains(.trash) ? trash.selectedSize : 0)
    }

    var largeFileBytes: Int64 { largeFiles.files.reduce(0) { $0 + $1.size } }

    /// Essentials that are switched on and have something to do.
    var plannedEssentials: [Essential] {
        Essential.allCases.filter { enabled.contains($0) && hasWork($0) }
    }

    func hasWork(_ essential: Essential) -> Bool {
        switch essential {
        case .junk: !junk.selectedItems.isEmpty
        case .trash: !trash.selectedItems.isEmpty
        case .speed: !maintenance.selectedTasks.isEmpty
        }
    }

    func headline(for essential: Essential) -> String {
        switch essential {
        case .junk: ByteFormat.string(junk.selectedSize)
        case .trash: ByteFormat.string(trash.selectedSize)
        case .speed: "\(maintenance.selectedTasks.count) task\(maintenance.selectedTasks.count == 1 ? "" : "s")"
        }
    }

    func detail(for essential: Essential) -> String {
        switch essential {
        case .junk:
            let names = junk.groups.filter { junk.selectedSize(of: $0) > 0 }.prefix(3).map(\.title)
            return names.isEmpty ? "Nothing to remove" : names.joined(separator: " · ")
        case .trash:
            return trash.selectedItems.isEmpty ? "Already empty" : "Deleted permanently"
        case .speed:
            let tasks = maintenance.selectedTasks
            if tasks.isEmpty { return "No tasks chosen" }
            let names = tasks.prefix(3).map(\.title).joined(separator: " · ")
            return tasks.contains(where: \.needsAdmin) ? names + " · asks for your password" : names
        }
    }

    func toggle(_ essential: Essential) {
        guard phase == .ready else { return }
        if enabled.contains(essential) { enabled.remove(essential) } else { enabled.insert(essential) }
    }

    // MARK: Actions

    func scan() {
        // Speed needs no scan: it recommends the selected maintenance tasks.
        finished = [.speed]
        statuses = [:]
        freedBytes = 0
        tasksCompleted = 0
        junkScanned = false
        trashScanned = false
        withAnimation(.smooth) { phase = .scanning }
        Task {
            await withTaskGroup(of: ScanResult.self) { group in
                group.addTask { .junk(await runInBackground { JunkScanner.scan(progress: ScanProgress()) } ?? []) }
                group.addTask { .trash(await runInBackground { TrashScanner.scan(progress: ScanProgress()) } ?? []) }
                group.addTask {
                    let apps = AppScanner.installedApps()
                    let orphans = await runInBackground { OrphanFinder.scan(installed: apps, progress: ScanProgress()) } ?? []
                    let updates = await UpdateChecker.check(apps)
                    return .applications(leftovers: orphans, updates: updates, feeds: UpdateChecker.checkableCount(apps))
                }
                group.addTask {
                    .largeFiles(await runInBackground {
                        LargeFileFinder.scan(minimumSize: LargeFilesModel.SizeFloor.mb50.rawValue, progress: ScanProgress())
                    } ?? [])
                }
                for await result in group { apply(result) }
            }
            try? await Task.sleep(for: .milliseconds(400))
            UserDefaults.standard.set(Date.now, forKey: Preferences.Key.lastSmartCareScan)
            withAnimation(.smooth) { phase = .ready }
        }
    }

    /// Works through the planned essentials one after the other. Every step ends in a status, and the run always
    /// reaches the summary, even when a step fails or the password prompt is cancelled.
    func run() {
        guard phase == .ready else { return }
        let plan = plannedEssentials
        freedBytes = 0
        tasksCompleted = 0
        statuses = Dictionary(uniqueKeysWithValues: Essential.allCases.map { ($0, plan.contains($0) ? .waiting : .skipped) })
        withAnimation(.smooth) { phase = .running }
        Task {
            for essential in plan {
                withAnimation(.smooth) { statuses[essential] = .working }
                let status = await perform(essential)
                runDetail = ""
                withAnimation(.smooth) { statuses[essential] = status }
            }
            try? await Task.sleep(for: .milliseconds(600))
            withAnimation(.smooth) { phase = .done }
        }
    }

    func finish() {
        withAnimation(.smooth) { phase = .idle }
    }

    private func perform(_ essential: Essential) async -> Status {
        switch essential {
        case .junk, .trash:
            let model = essential == .junk ? junk : trash
            runDetail = essential == .junk ? "Clearing caches and logs…" : "Emptying every Trash…"
            await model.cleanNow()
            let report = model.report
            freedBytes += report.removedBytes
            if report.removedBytes == 0, !report.failures.isEmpty {
                return .failed("\(report.failures.count) item\(report.failures.count == 1 ? "" : "s") couldn't be removed")
            }
            let note = report.failures.isEmpty ? "" : " · \(report.failures.count) skipped"
            return .done("\(ByteFormat.string(report.removedBytes)) freed" + note)
        case .speed:
            let total = maintenance.selectedTasks.count
            runDetail = maintenance.selectedTasks.contains(where: \.needsAdmin)
                ? "Running tune-up tasks · enter your password when asked" : "Running tune-up tasks…"
            tasksCompleted = await maintenance.runNow()
            if tasksCompleted == 0 { return .failed("No tasks completed") }
            return .done("\(tasksCompleted) of \(total) task\(total == 1 ? "" : "s") done")
        }
    }

    private enum ScanResult: Sendable {
        case junk([CleanupGroup])
        case trash([CleanupGroup])
        case applications(leftovers: [CleanupGroup], updates: [AppUpdate], feeds: Int)
        case largeFiles([LargeFile])
    }

    private func apply(_ result: ScanResult) {
        withAnimation(.smooth) {
            switch result {
            case .junk(let groups):
                junk.apply(scanResult: groups)
                junkScanned = true
            case .trash(let groups):
                trash.apply(scanResult: groups)
                trashScanned = true
            case .applications(let orphanGroups, let updates, let feeds):
                leftovers.apply(scanResult: orphanGroups)
                updater.apply(updates, feedCount: feeds)
                finished.insert(.applications)
            case .largeFiles(let files):
                largeFiles.apply(files)
                finished.insert(.clutter)
            }
            if junkScanned && trashScanned { finished.insert(.cleanup) }
        }
    }

    private var junkScanned = false
    private var trashScanned = false
}
