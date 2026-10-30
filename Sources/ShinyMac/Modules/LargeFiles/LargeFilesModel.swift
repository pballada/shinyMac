import ShinyCore
import SwiftUI

@Observable
final class LargeFilesModel {
    enum Phase: Equatable { case idle, scanning, ready }

    enum Age: String, CaseIterable, Identifiable {
        case any = "Any time"
        case month = "Over a month ago"
        case halfYear = "Over 6 months ago"
        case year = "Over a year ago"
        var id: Self { self }

        var interval: TimeInterval? {
            switch self {
            case .any: nil
            case .month: 30 * 86_400
            case .halfYear: 182 * 86_400
            case .year: 365 * 86_400
            }
        }
    }

    enum SizeFloor: Int64, CaseIterable, Identifiable {
        case mb50 = 50_000_000
        case mb250 = 250_000_000
        case gb1 = 1_000_000_000
        var id: Self { self }
        var title: String { "Over \(ByteFormat.string(rawValue))" }
    }

    enum Sort: String, CaseIterable, Identifiable {
        case size = "Size"
        case name = "Name"
        case lastUsed = "Last Used"
        var id: Self { self }
    }

    private(set) var phase: Phase = .idle
    private(set) var files: [LargeFile] = []
    private(set) var progress = ScanProgress.Snapshot()
    var selection: Set<URL> = []
    var kind: FileKind?
    var age: Age = .any
    var sizeFloor: SizeFloor = .mb50
    var sort: Sort = .size
    private(set) var isRemoving = false
    private(set) var lastReport: Cleaner.Report?
    private var work: Task<Void, Never>?

    var visibleFiles: [LargeFile] {
        let now = Date.now
        var result = files.filter { file in
            guard file.size >= sizeFloor.rawValue else { return false }
            if let kind, file.kind != kind { return false }
            if let interval = age.interval {
                guard let lastUsed = file.lastUsed, now.timeIntervalSince(lastUsed) > interval else { return false }
            }
            return true
        }
        switch sort {
        case .size: break
        case .name: result.sort { $0.url.lastPathComponent.localizedStandardCompare($1.url.lastPathComponent) == .orderedAscending }
        case .lastUsed: result.sort { ($0.lastUsed ?? .distantPast) < ($1.lastUsed ?? .distantPast) }
        }
        return result
    }

    var totalSize: Int64 { files.reduce(0) { $0 + $1.size } }
    var selectedFiles: [LargeFile] { files.filter { selection.contains($0.url) } }
    var selectedSize: Int64 { selectedFiles.reduce(0) { $0 + $1.size } }

    func stats(for kind: FileKind?) -> (count: Int, size: Int64) {
        let matching = files.filter { kind == nil || $0.kind == kind }
        return (matching.count, matching.reduce(0) { $0 + $1.size })
    }

    var badge: String? { phase == .ready && !files.isEmpty ? ByteFormat.string(totalSize) : nil }

    func scan() {
        work?.cancel()
        progress = .init()
        lastReport = nil
        withAnimation(.smooth) { phase = .scanning }
        let box = ScanProgress()
        // Always gather from the smallest floor so filters can loosen without rescanning.
        let floor = SizeFloor.mb50.rawValue
        work = Task {
            let found = await runInBackground(progress: box, minimumDuration: .seconds(1.2), onProgress: {
                self.progress = $0
            }) { LargeFileFinder.scan(minimumSize: floor, progress: box) }
            guard let found else { return }
            files = found
            selection = []
            withAnimation(.smooth) { phase = .ready }
        }
    }

    func stop() {
        work?.cancel()
        withAnimation(.smooth) { phase = files.isEmpty ? .idle : .ready }
    }

    func toggle(_ file: LargeFile) {
        if selection.contains(file.url) { selection.remove(file.url) } else { selection.insert(file.url) }
    }

    func toggleAllVisible() {
        let visible = Set(visibleFiles.map(\.url))
        if visible.isSubset(of: selection) { selection.subtract(visible) } else { selection.formUnion(visible) }
    }

    func removeSelected() {
        let items = selectedFiles.map { CleanupItem(url: $0.url, size: $0.size) }
        guard !items.isEmpty else { return }
        isRemoving = true
        Task {
            let report = await runInBackground { Cleaner.remove(items, mode: .trash) } ?? Cleaner.Report()
            let removed = Set(report.removed)
            files.removeAll { removed.contains($0.url) }
            selection.subtract(removed)
            isRemoving = false
            withAnimation(.smooth) { lastReport = report }
        }
    }
}
