import Foundation

/// A folder or file in a Space Lens map.
///
/// Trees are built on a background thread and then handed to the main actor, which is the only place
/// they are mutated afterwards (when items are removed); hence `@unchecked Sendable`.
public final class DiskNode: Identifiable, @unchecked Sendable {
    public let url: URL
    public let name: String
    public let isDirectory: Bool
    /// Stands in for many small items folded together to keep the tree light.
    public let isAggregate: Bool
    public fileprivate(set) var size: Int64
    public private(set) var children: [DiskNode] = []
    public private(set) weak var parent: DiskNode?

    public var id: ObjectIdentifier { ObjectIdentifier(self) }

    init(url: URL, name: String? = nil, isDirectory: Bool, isAggregate: Bool = false, size: Int64 = 0) {
        self.url = url
        self.name = name ?? url.lastPathComponent
        self.isDirectory = isDirectory
        self.isAggregate = isAggregate
        self.size = size
    }

    /// Root first, ending with this node.
    public var ancestry: [DiskNode] {
        var chain: [DiskNode] = [self]
        while let parent = chain.last?.parent { chain.append(parent) }
        return chain.reversed()
    }

    public var canDrillDown: Bool { isDirectory && !children.isEmpty }

    func setChildren(_ nodes: [DiskNode]) {
        children = nodes.sorted { $0.size > $1.size }
        children.forEach { $0.parent = self }
    }

    /// Detaches a removed child and shrinks every ancestor accordingly.
    public func remove(_ child: DiskNode) {
        guard let index = children.firstIndex(where: { $0 === child }) else { return }
        children.remove(at: index)
        var node: DiskNode? = self
        while let current = node {
            current.size -= child.size
            node = current.parent
        }
    }
}

public enum DiskTree {
    static let keys: Set<URLResourceKey> = [
        .isDirectoryKey, .isSymbolicLinkKey, .isVolumeKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey,
    ]

    /// Builds a size tree for `root`. Items smaller than `foldBelow` are folded into one "smaller items" node
    /// per folder; folders are always measured fully. Mount points and symlinks are skipped.
    public static func build(root: URL, foldBelow: Int64 = 1_000_000, progress: ScanProgress) -> DiskNode {
        var visited = 0
        let node = DiskNode(url: root, name: displayName(for: root), isDirectory: true)
        populate(node, foldBelow: foldBelow, progress: progress, visited: &visited)
        progress.update(fraction: 1)
        return node
    }

    private static func populate(_ node: DiskNode, foldBelow: Int64, progress: ScanProgress, visited: inout Int) {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: node.url, includingPropertiesForKeys: Array(keys), options: []
        ) else { return }

        var kept: [DiskNode] = []
        var foldedSize: Int64 = 0
        var foldedCount = 0
        var total: Int64 = 0

        for url in contents {
            if Task.isCancelled { return }
            visited += 1
            if visited.isMultiple(of: 400) { progress.update(detail: Paths.abbreviated(node.url)) }
            guard let values = try? url.resourceValues(forKeys: keys), values.isSymbolicLink != true else { continue }

            let child: DiskNode
            if values.isDirectory == true {
                if values.isVolume == true { continue }
                child = DiskNode(url: url, isDirectory: true)
                populate(child, foldBelow: foldBelow, progress: progress, visited: &visited)
            } else {
                let size = FileSizer.allocatedSize(values)
                progress.found(bytes: size)
                child = DiskNode(url: url, isDirectory: false, size: size)
            }

            total += child.size
            if child.size < foldBelow {
                foldedSize += child.size
                foldedCount += 1
            } else {
                kept.append(child)
            }
        }

        if foldedCount > 0, foldedSize > 0 {
            kept.append(DiskNode(
                url: node.url, name: "\(foldedCount) smaller item\(foldedCount == 1 ? "" : "s")",
                isDirectory: false, isAggregate: true, size: foldedSize
            ))
        }
        node.size = total
        node.setChildren(kept)
    }

    static func displayName(for url: URL) -> String {
        url.standardizedFileURL == Paths.home.standardizedFileURL
            ? "Home"
            : FileManager.default.displayName(atPath: url.path(percentEncoded: false))
    }
}
