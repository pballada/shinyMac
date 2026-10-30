import AppKit
import ShinyCore
import SwiftUI

@Observable
final class SpaceLensModel {
    enum Phase: Equatable { case idle, scanning, ready }

    private(set) var phase: Phase = .idle
    private(set) var root: DiskNode?
    private(set) var focus: DiskNode?
    var hovered: DiskNode?
    private(set) var selection: [DiskNode] = []
    private(set) var progress = ScanProgress.Snapshot()
    private(set) var rootURL = Paths.home
    private(set) var isRemoving = false
    private(set) var lastReport: Cleaner.Report?
    /// Bumped whenever the (non-observable) tree changes so views redraw.
    private(set) var revision = 0
    private var work: Task<Void, Never>?

    var selectedSize: Int64 { selection.reduce(0) { $0 + $1.size } }

    var badge: String? { root.map { ByteFormat.string($0.size) } }

    func scan(_ url: URL? = nil) {
        if let url { rootURL = url }
        let target = rootURL
        work?.cancel()
        progress = .init()
        lastReport = nil
        withAnimation(.smooth) { phase = .scanning }
        let box = ScanProgress()
        work = Task {
            let tree = await runInBackground(progress: box, minimumDuration: .seconds(1.2), onProgress: {
                self.progress = $0
            }) { DiskTree.build(root: target, progress: box) }
            guard let tree else { return }
            root = tree
            focus = tree
            selection = []
            hovered = nil
            revision += 1
            withAnimation(.smooth) { phase = .ready }
        }
    }

    func stop() {
        work?.cancel()
        withAnimation(.smooth) { phase = root == nil ? .idle : .ready }
    }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = rootURL
        panel.prompt = "Scan"
        if panel.runModal() == .OK, let url = panel.url { scan(url) }
    }

    func zoom(into node: DiskNode) {
        guard node.canDrillDown else { return }
        hovered = nil
        withAnimation(.smooth(duration: 0.35)) { focus = node }
    }

    func zoomOut() {
        guard let parent = focus?.parent else { return }
        zoom(into: parent)
    }

    func isSelected(_ node: DiskNode) -> Bool { selection.contains { $0 === node } }

    func toggleSelection(_ node: DiskNode) {
        guard !node.isAggregate, node.parent != nil else { return }
        if let index = selection.firstIndex(where: { $0 === node }) {
            selection.remove(at: index)
        } else {
            // Selecting a folder supersedes anything already selected inside it.
            selection.removeAll { $0.ancestry.contains { $0 === node } }
            guard !node.ancestry.dropLast().contains(where: isSelected) else { return }
            selection.append(node)
        }
    }

    func removeSelected() {
        let nodes = selection
        let items = nodes.map { CleanupItem(url: $0.url, size: $0.size) }
        guard !items.isEmpty else { return }
        isRemoving = true
        Task {
            let report = await runInBackground { Cleaner.remove(items, mode: .trash) } ?? Cleaner.Report()
            let removed = Set(report.removed)
            for node in nodes where removed.contains(node.url) {
                node.parent?.remove(node)
            }
            selection.removeAll { removed.contains($0.url) }
            if let focus, focus.ancestry.contains(where: { removed.contains($0.url) && $0 !== root }) {
                self.focus = root
            }
            isRemoving = false
            revision += 1
            withAnimation(.smooth) { lastReport = report }
        }
    }
}
