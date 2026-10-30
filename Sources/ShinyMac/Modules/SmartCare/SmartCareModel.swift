import ShinyCore
import SwiftUI

/// One-click scan across modules. Results land in each module's own model, so "Review" shows the same data.
@Observable
final class SmartCareModel {
    enum Phase: Equatable { case idle, scanning, results, running, done }

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

        var symbol: String {
            switch self {
            case .cleanup: "bubbles.and.sparkles.fill"
            case .speed: "bolt.fill"
            case .applications: "square.grid.2x2.fill"
            case .clutter: "doc.on.doc.fill"
            }
        }

        /// Areas whose results can be acted on directly by Run.
        var isActionable: Bool { self == .cleanup || self == .speed }
    }

    private(set) var phase: Phase = .idle
    private(set) var finished: Set<Area> = []
    var included: Set<Area> = [.cleanup, .speed]
    private(set) var runStep = ""
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

    var cleanableBytes: Int64 { junk.selectedSize + trash.selectedSize }
    var largeFileBytes: Int64 { largeFiles.files.reduce(0) { $0 + $1.size } }

    func headline(for area: Area) -> String {
        switch area {
        case .cleanup: ByteFormat.string(cleanableBytes)
        case .speed: "\(maintenance.selectedTasks.count) tasks"
        case .applications: updater.updates.isEmpty ? "Up to date" : "\(updater.updates.count) updates"
        case .clutter: "\(largeFiles.files.count) large files"
        }
    }

    func detail(for area: Area) -> String {
        switch area {
        case .cleanup:
            "System junk \(ByteFormat.string(junk.selectedSize)) · Trash \(ByteFormat.string(trash.selectedSize))"
        case .speed:
            maintenance.selectedTasks.prefix(3).map(\.title).joined(separator: " · ")
        case .applications:
            leftovers.totalSize > 0 ? "\(ByteFormat.string(leftovers.totalSize)) of leftovers from deleted apps" : "No leftovers found"
        case .clutter:
            "\(ByteFormat.string(largeFileBytes)) worth reviewing"
        }
    }

    // MARK: Actions

    func scan() {
        // Speed needs no scan: it recommends the selected maintenance tasks.
        finished = [.speed]
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
                    return .applications(leftovers: orphans, updates: updates, feeds: UpdateChecker.feeds(for: apps).count)
                }
                group.addTask {
                    .largeFiles(await runInBackground {
                        LargeFileFinder.scan(minimumSize: LargeFilesModel.SizeFloor.mb50.rawValue, progress: ScanProgress())
                    } ?? [])
                }
                for await result in group { apply(result) }
            }
            try? await Task.sleep(for: .milliseconds(400))
            withAnimation(.smooth) { phase = .results }
        }
    }

    func run() {
        freedBytes = 0
        tasksCompleted = 0
        withAnimation(.smooth) { phase = .running }
        Task {
            if included.contains(.cleanup) {
                for (model, step) in [(junk, "Removing system junk…"), (trash, "Emptying the Trash…")] {
                    guard !model.selectedItems.isEmpty else { continue }
                    runStep = step
                    await model.cleanNow()
                    freedBytes += model.report.removedBytes
                }
            }
            if included.contains(.speed) {
                runStep = "Running maintenance tasks…"
                tasksCompleted = await maintenance.runNow()
            }
            withAnimation(.smooth) { phase = .done }
        }
    }

    func finish() {
        withAnimation(.smooth) { phase = .idle }
    }

    func toggle(_ area: Area) {
        guard area.isActionable else { return }
        if included.contains(area) { included.remove(area) } else { included.insert(area) }
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
