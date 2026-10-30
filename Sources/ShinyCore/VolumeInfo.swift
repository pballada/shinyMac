import Foundation

/// Capacity of a mounted volume, by default the startup disk.
public struct VolumeInfo: Sendable, Equatable {
    public let name: String
    public let total: Int64
    public let available: Int64

    public var used: Int64 { max(0, total - available) }
    public var usedFraction: Double { total > 0 ? Double(used) / Double(total) : 0 }

    public init(name: String, total: Int64, available: Int64) {
        self.name = name
        self.total = total
        self.available = available
    }

    public static func current(for url: URL = URL(filePath: "/")) -> VolumeInfo? {
        let keys: Set<URLResourceKey> = [
            .volumeLocalizedNameKey, .volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey,
        ]
        guard let values = try? url.resourceValues(forKeys: keys), let total = values.volumeTotalCapacity else {
            return nil
        }
        return VolumeInfo(
            name: values.volumeLocalizedName ?? "Macintosh HD",
            total: Int64(total),
            available: values.volumeAvailableCapacityForImportantUsage ?? 0
        )
    }
}
