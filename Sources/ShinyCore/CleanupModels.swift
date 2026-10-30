import Foundation

/// A single file or folder a scanner proposes to remove.
public struct CleanupItem: Identifiable, Hashable, Sendable {
    public var id: URL { url }
    public let url: URL
    public let name: String
    public let size: Int64
    public let modified: Date?

    public init(url: URL, name: String? = nil, size: Int64, modified: Date? = nil) {
        self.url = url
        self.name = name ?? url.lastPathComponent
        self.size = size
        self.modified = modified
    }
}

/// A themed bucket of cleanup items, e.g. "User Caches".
public struct CleanupGroup: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let detail: String
    public let symbol: String
    public var items: [CleanupItem]
    /// Whether the group starts checked after a scan.
    public let selectedByDefault: Bool

    public var size: Int64 { items.reduce(0) { $0 + $1.size } }

    public init(id: String, title: String, detail: String, symbol: String, items: [CleanupItem], selectedByDefault: Bool = true) {
        self.id = id
        self.title = title
        self.detail = detail
        self.symbol = symbol
        self.items = items
        self.selectedByDefault = selectedByDefault
    }
}

/// How removed items leave the disk.
public enum RemovalMode: Sendable {
    /// Recoverable: moved to the user's Trash.
    case trash
    /// Permanent. Used for regenerable data such as caches.
    case delete
}
