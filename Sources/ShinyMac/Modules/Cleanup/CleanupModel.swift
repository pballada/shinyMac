import ShinyCore
import SwiftUI

/// Scan → review → clean state machine shared by every "find files and remove them" module.
@Observable
final class CleanupModel {
    enum Phase: Equatable {
        case idle, scanning, results, cleaning, done
    }

    /// Wording for the primary action.
    enum Verb {
        case clean, remove, empty

        var title: String {
            switch self {
            case .clean: "Clean"
            case .remove: "Remove"
            case .empty: "Empty"
            }
        }

        var progressive: String {
            switch self {
            case .clean: "Cleaning…"
            case .remove: "Removing…"
            case .empty: "Emptying…"
            }
        }
    }

    let module: Module
    let removalMode: RemovalMode
    let verb: Verb
    /// Asked before cleaning when set (e.g. for privacy data, which can log you out of sites).
    let confirmation: String?
    private let scanner: @Sendable (ScanProgress) -> [CleanupGroup]

    private(set) var phase: Phase = .idle
    private(set) var groups: [CleanupGroup] = []
    var selected: Set<URL> = []
    var focusedGroupID: String?
    var isReviewing = false
    private(set) var progress = ScanProgress.Snapshot()
    private(set) var report = Cleaner.Report()
    private(set) var lastScan: Date?
    private(set) var lastMode: RemovalMode = .delete
    private var work: Task<Void, Never>?

    init(
        module: Module,
        removalMode: RemovalMode,
        verb: Verb = .clean,
        confirmation: String? = nil,
        scanner: @escaping @Sendable (ScanProgress) -> [CleanupGroup]
    ) {
        self.module = module
        self.removalMode = removalMode
        self.verb = verb
        self.confirmation = confirmation
        self.scanner = scanner
    }

    // MARK: Derived values

    var totalSize: Int64 { groups.reduce(0) { $0 + $1.size } }

    var cleanVerb: String { verb.title }

    /// Size to surface in the sidebar once a scan has run.
    var badge: String? {
        switch phase {
        case .results, .done: totalSize > 0 ? ByteFormat.string(totalSize) : nil
        default: nil
        }
    }

    var selectedItems: [CleanupItem] { groups.flatMap(\.items).filter { selected.contains($0.url) } }

    var selectedSize: Int64 { selectedItems.reduce(0) { $0 + $1.size } }

    var focusedGroup: CleanupGroup? {
        groups.first { $0.id == focusedGroupID } ?? groups.first
    }

    var adminFailures: [Cleaner.Failure] { report.failures.filter(\.needsAdmin) }

    func checkState(of group: CleanupGroup) -> CheckState {
        CheckState(selected: group.items.count { selected.contains($0.url) }, total: group.items.count)
    }

    func selectedSize(of group: CleanupGroup) -> Int64 {
        group.items.filter { selected.contains($0.url) }.reduce(0) { $0 + $1.size }
    }

    // MARK: Actions

    func scan() {
        work?.cancel()
        progress = .init()
        isReviewing = false
        withAnimation(.smooth) { phase = .scanning }
        let scanner = scanner
        let box = ScanProgress()
        work = Task {
            let found = await runInBackground(progress: box, minimumDuration: .seconds(1.2), onProgress: {
                self.progress = $0
            }) { scanner(box) }
            guard let found else { return }
            apply(scanResult: found)
        }
    }

    /// Adopts results produced elsewhere (Smart Care runs several scanners at once).
    func apply(scanResult found: [CleanupGroup]) {
        groups = found.filter { !$0.items.isEmpty }
        selected = Set(groups.filter(\.selectedByDefault).flatMap { $0.items.map(\.url) })
        focusedGroupID = groups.first?.id
        lastScan = .now
        withAnimation(.smooth) { phase = .results }
    }

    func stop() {
        work?.cancel()
        work = nil
        withAnimation(.smooth) { phase = groups.isEmpty ? .idle : .results }
    }

    func clean() {
        let items = selectedItems
        guard !items.isEmpty else { return }
        let mode = Preferences.alwaysUseTrash ? .trash : removalMode
        lastMode = mode
        progress = .init()
        withAnimation(.smooth) { phase = .cleaning }
        let box = ScanProgress()
        work = Task {
            let result = await runInBackground(progress: box, minimumDuration: .seconds(1), onProgress: {
                self.progress = $0
            }) { Cleaner.remove(items, mode: mode, progress: box) }
            guard let result else { return }
            finish(with: result)
        }
    }

    /// Retries items that failed for permission reasons as administrator.
    func retryFailuresAsAdmin() {
        let urls = adminFailures.map(\.url)
        guard !urls.isEmpty else { return }
        withAnimation(.smooth) { phase = .cleaning }
        work = Task {
            let result = await runInBackground { () -> Result<Cleaner.Report, Error> in
                Result { try Cleaner.removeWithPrivileges(urls) }
            }
            var merged = report
            merged.failures.removeAll { urls.contains($0.url) }
            switch result {
            case .success(let adminReport)?:
                merged.merge(adminReport)
            case .failure?, nil:
                merged.failures += adminFailures
            }
            finish(with: merged)
        }
    }

    func finishReview() {
        withAnimation(.smooth) { isReviewing = false }
    }

    /// Back to the start screen after a clean.
    func reset() {
        withAnimation(.smooth) {
            phase = groups.isEmpty ? .idle : .results
            report = .init()
        }
    }

    func toggle(_ item: CleanupItem) {
        if selected.contains(item.url) { selected.remove(item.url) } else { selected.insert(item.url) }
    }

    func toggle(_ group: CleanupGroup) {
        let urls = group.items.map(\.url)
        if checkState(of: group) == .on { selected.subtract(urls) } else { selected.formUnion(urls) }
    }

    private func finish(with result: Cleaner.Report) {
        report = result
        let removed = Set(result.removed)
        groups = groups.compactMap { group in
            var group = group
            group.items.removeAll { removed.contains($0.url) }
            return group.items.isEmpty ? nil : group
        }
        selected.subtract(removed)
        if !groups.contains(where: { $0.id == focusedGroupID }) { focusedGroupID = groups.first?.id }
        isReviewing = false
        withAnimation(.smooth) { phase = .done }
    }
}
