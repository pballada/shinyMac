import Foundation

/// Measures how much disk space files and folders really use.
public enum FileSizer {
    private static let sizeKeys: Set<URLResourceKey> = [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey]

    /// Allocated size of a file, or of a folder and everything inside it. Symlinks are not followed.
    /// Stops early (returning a partial total) if the calling task is cancelled.
    public static func size(of url: URL) -> Int64 {
        let keys: Set<URLResourceKey> = sizeKeys.union([.isDirectoryKey, .isSymbolicLinkKey])
        guard let values = try? url.resourceValues(forKeys: keys) else { return 0 }
        if values.isSymbolicLink == true { return 0 }
        guard values.isDirectory == true else { return allocatedSize(values) }

        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: Array(sizeKeys),
            options: [],
            errorHandler: { _, _ in true }
        ) else { return 0 }

        var total: Int64 = 0
        var visited = 0
        for case let child as URL in enumerator {
            visited += 1
            if visited.isMultiple(of: 512), Task.isCancelled { break }
            if let childValues = try? child.resourceValues(forKeys: sizeKeys) {
                total += allocatedSize(childValues)
            }
        }
        return total
    }

    /// Size plus last modification date, used when building cleanup items.
    public static func item(at url: URL, name: String? = nil) -> CleanupItem {
        let modified = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        return CleanupItem(url: url, name: name, size: size(of: url), modified: modified)
    }

    /// Immediate children of a folder (including hidden ones), or an empty list if it is missing or unreadable.
    public static func children(of url: URL) -> [URL] {
        (try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [])) ?? []
    }

    static func allocatedSize(_ values: URLResourceValues) -> Int64 {
        Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
    }
}
