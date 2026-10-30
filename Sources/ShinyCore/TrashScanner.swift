import Foundation

/// Lists what's inside every Trash on the Mac: the user's own and the per-user Trash on each mounted volume.
public enum TrashScanner {
    public struct Location: Sendable {
        public let url: URL
        public let name: String
        public let isExternal: Bool
    }

    public static func locations(home: URL = Paths.home) -> [Location] {
        var result = [Location(url: home.appending(path: ".Trash", directoryHint: .isDirectory), name: "Your Trash", isExternal: false)]
        let volumes = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: [.volumeLocalizedNameKey],
            options: [.skipHiddenVolumes]
        ) ?? []
        for volume in volumes where volume.path(percentEncoded: false) != "/" {
            let trash = volume.appending(path: ".Trashes/\(getuid())", directoryHint: .isDirectory)
            guard FileManager.default.fileExists(atPath: trash.path(percentEncoded: false)) else { continue }
            let name = (try? volume.resourceValues(forKeys: [.volumeLocalizedNameKey]).volumeLocalizedName) ?? volume.lastPathComponent
            result.append(Location(url: trash, name: "Trash on \(name)", isExternal: true))
        }
        return result
    }

    /// macOS hides `~/.Trash` from apps without Full Disk Access.
    public static func isUserTrashReadable(home: URL = Paths.home) -> Bool {
        (try? FileManager.default.contentsOfDirectory(atPath: home.appending(path: ".Trash").path(percentEncoded: false))) != nil
    }

    public static func scan(home: URL = Paths.home, progress: ScanProgress) -> [CleanupGroup] {
        let locations = locations(home: home)
        return locations.enumerated().compactMap { index, location in
            progress.update(detail: location.name, fraction: Double(index) / Double(locations.count))
            let items = FileSizer.children(of: location.url)
                .filter { $0.lastPathComponent != ".DS_Store" }
                .map { url -> CleanupItem in
                    progress.update(detail: Paths.abbreviated(url))
                    let item = FileSizer.item(at: url)
                    progress.found(bytes: item.size)
                    return item
                }
                .sorted { $0.size > $1.size }
            guard !items.isEmpty else { return nil }
            return CleanupGroup(
                id: location.url.path(percentEncoded: false), title: location.name,
                detail: location.isExternal ? "Deleted files still using space on this drive" : "Files you moved to the Trash",
                symbol: location.isExternal ? "externaldrive.fill" : "trash.fill", items: items
            )
        }
    }

    /// Fallback when the Trash can't be read: ask Finder to empty it (macOS asks once for Automation permission).
    public static func emptyWithFinder() throws -> Shell.Result {
        try Shell.run("/usr/bin/osascript", ["-e", #"tell application "Finder" to empty the trash"#])
    }
}
