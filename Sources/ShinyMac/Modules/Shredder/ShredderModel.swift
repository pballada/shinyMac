import ShinyCore
import SwiftUI

@Observable
final class ShredderModel {
    private(set) var items: [CleanupItem] = []
    private(set) var isMeasuring = false
    private(set) var isShredding = false
    private(set) var report: Cleaner.Report?

    var totalSize: Int64 { items.reduce(0) { $0 + $1.size } }
    var adminFailures: [Cleaner.Failure] { report?.failures.filter(\.needsAdmin) ?? [] }

    func add(_ urls: [URL]) {
        let fresh = urls.filter { url in url.isFileURL && !items.contains { $0.url == url } }
        guard !fresh.isEmpty else { return }
        report = nil
        isMeasuring = true
        Task {
            let measured = await runInBackground { fresh.map { FileSizer.item(at: $0) } } ?? []
            withAnimation(.smooth) { items += measured }
            isMeasuring = false
        }
    }

    func chooseFiles() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = "Add"
        if panel.runModal() == .OK { add(panel.urls) }
    }

    func remove(_ item: CleanupItem) {
        withAnimation(.smooth) { items.removeAll { $0.id == item.id } }
    }

    func clear() {
        withAnimation(.smooth) { items = [] }
    }

    func shred() {
        let targets = items
        guard !targets.isEmpty else { return }
        isShredding = true
        Task {
            let result = await runInBackground(minimumDuration: .seconds(0.8)) { Cleaner.remove(targets, mode: .delete) }
                ?? Cleaner.Report()
            finish(with: result)
        }
    }

    /// Locked or root-owned items can be deleted with the administrator password.
    func shredFailuresAsAdmin() {
        guard var current = report else { return }
        let urls = adminFailures.map(\.url)
        isShredding = true
        Task {
            let result = await runInBackground { () -> Result<Cleaner.Report, Error> in
                Result { try Cleaner.removeWithPrivileges(urls) }
            }
            if case .success(let adminReport)? = result {
                current.failures.removeAll { urls.contains($0.url) }
                current.merge(adminReport)
            }
            finish(with: current)
        }
    }

    private func finish(with result: Cleaner.Report) {
        let removed = Set(result.removed)
        isShredding = false
        withAnimation(.smooth) {
            items.removeAll { removed.contains($0.url) }
            report = result
        }
    }
}
