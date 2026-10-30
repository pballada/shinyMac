import Foundation

/// Finds regenerable clutter: caches, logs, developer build products and similar.
public enum JunkScanner {
    /// One kind of junk and how to find it.
    public struct Category: Sendable {
        public let id: String
        public let title: String
        public let detail: String
        public let symbol: String
        public let selectedByDefault: Bool
        let candidates: @Sendable () -> [Candidate]
    }

    struct Candidate: Sendable {
        let url: URL
        var name: String?
    }

    /// Folders inside `~/Library/Caches` that are system-critical, in use by sync services,
    /// or reported by the developer category instead.
    static let excludedCacheNames = Set([
        "CloudKit", "FamilyCircle", "com.apple.HomeKit", "com.apple.akd", "com.apple.ap.adprivacyd",
        "com.apple.bird", "com.apple.containermanagerd", "com.apple.homed", "com.apple.iCloudHelper",
        "com.apple.nsurlsessiond", "com.apple.passd", "com.apple.Safari.SafeBrowsing", "com.apple.cache_delete",
        "com.pballada.shinymac",
    ]).union(developerCacheFolders.map(\.folder))

    /// Package manager and IDE caches that live in `~/Library/Caches`.
    static let developerCacheFolders: [(folder: String, name: String)] = [
        ("Homebrew", "Homebrew downloads"), ("pip", "pip cache"), ("Yarn", "Yarn cache"),
        ("CocoaPods", "CocoaPods cache"), ("org.swift.swiftpm", "Swift Package Manager cache"),
        ("go-build", "Go build cache"), ("pnpm", "pnpm cache"), ("bun", "Bun cache"), ("JetBrains", "JetBrains IDE caches"),
    ]

    /// Developer caches stored elsewhere in the home folder.
    static let developerHomeFolders: [(path: String, name: String)] = [
        (".npm/_cacache", "npm cache"), (".gradle/caches", "Gradle cache"),
        (".cargo/registry/cache", "Cargo registry cache"), (".bun/install/cache", "Bun install cache"),
    ]

    static let installerExtensions: Set<String> = ["dmg", "pkg", "mpkg", "xip"]

    public static func categories(home: URL = Paths.home) -> [Category] {
        let library = home.appending(path: "Library", directoryHint: .isDirectory)
        @Sendable func lib(_ path: String) -> URL { library.appending(path: path, directoryHint: .isDirectory) }
        @Sendable func children(_ url: URL, excluding: Set<String> = []) -> [Candidate] {
            FileSizer.children(of: url)
                .filter { !excluding.contains($0.lastPathComponent) && $0.lastPathComponent != ".DS_Store" }
                .map { Candidate(url: $0) }
        }

        return [
            Category(
                id: "userCaches", title: "User Cache Files", detail: "Temporary data apps rebuild when needed",
                symbol: "archivebox.fill", selectedByDefault: true,
                candidates: { children(lib("Caches"), excluding: excludedCacheNames) }
            ),
            Category(
                id: "logs", title: "Log Files", detail: "Activity logs and crash reports",
                symbol: "doc.plaintext.fill", selectedByDefault: true,
                candidates: { children(lib("Logs")) }
            ),
            Category(
                id: "xcode", title: "Xcode Junk", detail: "DerivedData, device support and simulator caches",
                symbol: "hammer.fill", selectedByDefault: true,
                candidates: {
                    ["Developer/Xcode/DerivedData", "Developer/Xcode/iOS DeviceSupport", "Developer/Xcode/watchOS DeviceSupport",
                     "Developer/Xcode/tvOS DeviceSupport", "Developer/Xcode/visionOS DeviceSupport",
                     "Developer/Xcode/DocumentationCache", "Developer/CoreSimulator/Caches"]
                        .flatMap { children(lib($0)) }
                }
            ),
            Category(
                id: "devCaches", title: "Developer Caches", detail: "Package managers and IDEs re-download these on demand",
                symbol: "shippingbox.fill", selectedByDefault: true,
                candidates: {
                    developerCacheFolders.map { Candidate(url: lib("Caches/\($0.folder)"), name: $0.name) }
                        + developerHomeFolders.map { Candidate(url: home.appending(path: $0.path, directoryHint: .isDirectory), name: $0.name) }
                }
            ),
            Category(
                id: "mail", title: "Mail Downloads", detail: "Copies of attachments you opened in Mail",
                symbol: "paperclip", selectedByDefault: true,
                candidates: { children(lib("Containers/com.apple.mail/Data/Library/Mail Downloads")) }
            ),
            Category(
                id: "brokenPrefs", title: "Broken Preferences", detail: "Settings files that are corrupted and can't be read",
                symbol: "exclamationmark.triangle.fill", selectedByDefault: true,
                candidates: {
                    FileSizer.children(of: lib("Preferences"))
                        .filter { $0.pathExtension == "plist" && isBrokenPropertyList($0) }
                        .map { Candidate(url: $0) }
                }
            ),
            Category(
                id: "installers", title: "Installer Packages", detail: "Disk images and installers in Downloads",
                symbol: "opticaldiscdrive.fill", selectedByDefault: false,
                candidates: {
                    FileSizer.children(of: home.appending(path: "Downloads", directoryHint: .isDirectory))
                        .filter { installerExtensions.contains($0.pathExtension.lowercased()) }
                        .map { Candidate(url: $0) }
                }
            ),
            Category(
                id: "xcodeArchives", title: "Xcode Archives", detail: "Old app builds; keep them if you need crash symbolication",
                symbol: "archivebox", selectedByDefault: false,
                candidates: { children(lib("Developer/Xcode/Archives")) }
            ),
        ]
    }

    /// Scans every category, reporting progress, and returns non-empty groups with items sorted by size.
    public static func scan(home: URL = Paths.home, progress: ScanProgress) -> [CleanupGroup] {
        let categories = categories(home: home)
        var groups: [CleanupGroup] = []

        for (index, category) in categories.enumerated() {
            if Task.isCancelled { break }
            progress.update(detail: category.title, fraction: Double(index) / Double(categories.count))

            var items: [CleanupItem] = []
            for candidate in category.candidates() {
                if Task.isCancelled { break }
                guard FileManager.default.fileExists(atPath: candidate.url.path(percentEncoded: false)) else { continue }
                progress.update(detail: Paths.abbreviated(candidate.url))
                let item = FileSizer.item(at: candidate.url, name: candidate.name)
                guard item.size > 0 else { continue }
                items.append(item)
                if category.selectedByDefault { progress.found(bytes: item.size) }
            }

            if !items.isEmpty {
                groups.append(CleanupGroup(
                    id: category.id, title: category.title, detail: category.detail, symbol: category.symbol,
                    items: items.sorted { $0.size > $1.size }, selectedByDefault: category.selectedByDefault
                ))
            }
        }
        progress.update(fraction: 1)
        return groups
    }

    static func isBrokenPropertyList(_ url: URL) -> Bool {
        guard let data = try? Data(contentsOf: url) else { return false } // unreadable is not the same as broken
        if data.isEmpty { return true }
        return (try? PropertyListSerialization.propertyList(from: data, format: nil)) == nil
    }
}
