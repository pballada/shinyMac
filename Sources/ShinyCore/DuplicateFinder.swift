import CryptoKit
import Foundation
import Synchronization

/// Finds files with identical contents: grouped by size, narrowed by a hash of the first 64 KB,
/// then confirmed with a full SHA-256. The oldest copy in each set is the one to keep.
public enum DuplicateFinder {
    struct Candidate: Sendable {
        let url: URL
        let size: Int64
        let created: Date?
        let modified: Date?
    }

    static let skippedFolderNames: Set<String> = LargeFileFinder.skippedFolderNames.union(["Photos Library.photoslibrary"])

    public static func scan(root: URL = Paths.home, minimumSize: Int64 = 1_000_000, progress: ScanProgress) -> [CleanupGroup] {
        let skipped: Set<String> = [
            root.appending(path: "Library").path(percentEncoded: false),
            root.appending(path: "Applications").path(percentEncoded: false),
        ]
        let found = Mutex<[Candidate]>([])
        let seenFiles = Mutex<Set<String>>([])

        progress.update(detail: "Looking for files…", fraction: 0)
        ParallelWalker.walk(root: root, progress: progress) { url, values in
            if values.isDirectory == true {
                // Packages (apps, libraries) are managed by their owners; never look inside them.
                guard values.isPackage != true else { return false }
                return !skipped.contains(url.path(percentEncoded: false).trimmingSuffix("/"))
                    && !skippedFolderNames.contains(url.lastPathComponent)
            }
            let size = FileSizer.allocatedSize(values)
            guard size >= minimumSize else { return false }
            // Hard links share one file; count it once.
            if let identifier = values.fileResourceIdentifier.map({ "\($0)" }),
               !seenFiles.withLock({ $0.insert(identifier).inserted }) {
                return false
            }
            found.withLock {
                $0.append(Candidate(url: url, size: size, created: values.creationDate, modified: values.contentModificationDate))
            }
            return false
        }
        guard !progress.isCancelled else { return [] }

        // Only files sharing a size can be duplicates.
        let sameSize = Dictionary(grouping: found.withLock { $0 }, by: \.size).values.filter { $0.count > 1 }
        let quick = refine(Array(sameSize), progress: progress, label: "Comparing", fraction: 0.4) { hash($0.url, limit: 65_536) }
        let full = refine(quick, progress: progress, label: "Verifying", fraction: 0.7) { hash($0.url, limit: nil) }
        progress.update(fraction: 1)

        return full
            .map(makeGroup)
            .sorted { wasted($0) > wasted($1) }
    }

    /// Splits each set by a content hash, keeping only subsets that still have two or more files.
    static func refine(_ sets: [[Candidate]], progress: ScanProgress, label: String, fraction: Double,
                       hasher: @Sendable (Candidate) -> String?) -> [[Candidate]] {
        let files = sets.flatMap { $0 }
        let hashes = Mutex<[URL: String]>([:])
        let done = Atomic<Int>(0)
        DispatchQueue.concurrentPerform(iterations: files.count) { index in
            guard !progress.isCancelled else { return }
            if let digest = hasher(files[index]) {
                hashes.withLock { $0[files[index].url] = digest }
            }
            let count = done.add(1, ordering: .relaxed).newValue
            if count.isMultiple(of: 20) {
                progress.update(detail: "\(label) \(count) of \(files.count) files", fraction: fraction + 0.3 * Double(count) / Double(max(files.count, 1)))
            }
        }
        let digests = hashes.withLock { $0 }
        return sets.flatMap { set in
            Dictionary(grouping: set.filter { digests[$0.url] != nil }) { digests[$0.url]! }
                .values
                .filter { $0.count > 1 }
        }
    }

    /// SHA-256 of a file, or of its first `limit` bytes.
    static func hash(_ url: URL, limit: Int?) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        var hasher = SHA256()
        var remaining = limit ?? .max
        while remaining > 0 {
            guard let chunk = try? handle.read(upToCount: min(1 << 20, remaining)), !chunk.isEmpty else { break }
            hasher.update(data: chunk)
            remaining -= chunk.count
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    /// The oldest copy (then the shortest path) is the original to keep; the rest are recommended for removal.
    static func makeGroup(_ set: [Candidate]) -> CleanupGroup {
        let ordered = set.sorted {
            let lhs = $0.created ?? $0.modified ?? .distantFuture
            let rhs = $1.created ?? $1.modified ?? .distantFuture
            return lhs != rhs ? lhs < rhs : $0.url.path.count < $1.url.path.count
        }
        let items = ordered.enumerated().map { index, candidate in
            CleanupItem(url: candidate.url, size: candidate.size, modified: candidate.modified, isRecommended: index > 0)
        }
        let first = ordered[0]
        return CleanupGroup(
            id: first.url.path(percentEncoded: false),
            title: first.url.lastPathComponent,
            detail: "\(ordered.count) copies · \(ByteFormat.string(first.size)) each",
            symbol: FileKind.of(first.url).symbol,
            items: items
        )
    }

    static func wasted(_ group: CleanupGroup) -> Int64 {
        group.items.filter(\.isRecommended).reduce(0) { $0 + $1.size }
    }
}
