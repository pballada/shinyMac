import Foundation

/// A single file or folder a scanner proposes to remove.
public struct CleanupItem: Identifiable, Hashable, Sendable {
    public var id: URL { url }
    public let url: URL
    public let name: String
    public let size: Int64
    public let modified: Date?
    /// Whether the item starts checked when its group does. Lets one group mix safe and opt-in items.
    public let isRecommended: Bool
    /// Extra context shown under the name, e.g. "iOS 18.1 · not used by any simulator". Defaults to the path.
    public let note: String?
    public let removal: Removal

    public init(
        url: URL, name: String? = nil, size: Int64, modified: Date? = nil, isRecommended: Bool = true,
        note: String? = nil, removal: Removal = .file
    ) {
        self.url = url
        self.name = name ?? url.lastPathComponent
        self.size = size
        self.modified = modified
        self.isRecommended = isRecommended
        self.note = note
        self.removal = removal
    }
}

/// How a single item is removed.
public enum Removal: Hashable, Sendable {
    /// Deleted or trashed according to the module's `RemovalMode`.
    case file
    /// Always moved to the Trash, whatever the module does (e.g. an old copy of Xcode).
    case moveToTrash
    /// A simulator device, deleted with `simctl` so CoreSimulator stays consistent.
    case simulator(udid: String)
    /// A simulator runtime disk image, deleted with `simctl runtime`.
    case simulatorRuntime(identifier: String)
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
