import Foundation
import Synchronization

/// Walks a folder tree on all cores. Every folder is a unit of work, so one huge subtree
/// (a game library, a monorepo) is shared across workers instead of pinning a single thread.
enum ParallelWalker {
    static let keys: [URLResourceKey] = [
        .isDirectoryKey, .isPackageKey, .isSymbolicLinkKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey,
        .contentAccessDateKey, .contentModificationDateKey, .creationDateKey, .fileResourceIdentifierKey,
    ]

    private struct Queue {
        var pending: [URL]
        var active = 0
    }

    /// Calls `visit` for every non-hidden, non-symlink item. Returning true descends into a folder.
    /// `visit` runs concurrently and must be thread-safe.
    static func walk(root: URL, progress: ScanProgress, visit: @Sendable (URL, URLResourceValues) -> Bool) {
        let queue = Mutex(Queue(pending: [root]))
        let workers = max(2, min(ProcessInfo.processInfo.activeProcessorCount, 10))

        DispatchQueue.concurrentPerform(iterations: workers) { _ in
            while !progress.isCancelled {
                let next: URL? = queue.withLock { state in
                    guard let url = state.pending.popLast() else { return nil }
                    state.active += 1
                    return url
                }
                guard let folder = next else {
                    if queue.withLock({ $0.pending.isEmpty && $0.active == 0 }) { return }
                    usleep(2_000)
                    continue
                }

                var subfolders: [URL] = []
                let children = (try? FileManager.default.contentsOfDirectory(
                    at: folder, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]
                )) ?? []
                for url in children {
                    guard let values = try? url.resourceValues(forKeys: Set(keys)), values.isSymbolicLink != true else { continue }
                    if visit(url, values), values.isDirectory == true { subfolders.append(url) }
                }
                if !children.isEmpty { progress.update(detail: Paths.abbreviated(folder)) }
                queue.withLock {
                    $0.pending += subfolders
                    $0.active -= 1
                }
            }
        }
    }
}
