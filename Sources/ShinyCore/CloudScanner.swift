import FileProvider
import Foundation
import Synchronization

/// Finds big and long-unused files from iCloud Drive, Dropbox, Google Drive, OneDrive and other File Provider apps
/// that are downloaded to this Mac. Removing the download frees the space; the file stays in the cloud.
public enum CloudScanner {
    struct Provider: Sendable {
        let id: String
        let title: String
        let symbol: String
        let root: URL
        var detail = "Local copies of cloud files; they download again when opened"
        /// Folders under `root` that aren't items, e.g. iCloud Drive inside Mobile Documents.
        var skipped: Set<String> = []
        /// Display name for a top-level folder.
        var itemName: @Sendable (String) -> String = { $0 }
        /// Top-level folders are app containers named with `itemName`.
        var namesContainers = false
    }

    static let iCloudDrive = "com~apple~CloudDocs"

    static func providers(home: URL) -> [Provider] {
        let library = home.appending(path: "Library", directoryHint: .isDirectory)
        let mobileDocuments = library.appending(path: "Mobile Documents", directoryHint: .isDirectory)
        var providers = [
            Provider(
                id: "icloud", title: "iCloud Drive", symbol: "icloud.fill",
                root: mobileDocuments.appending(path: iCloudDrive, directoryHint: .isDirectory)
            ),
            // Each app that syncs documents through iCloud (Pages, Numbers, Keynote, many others) has its own container.
            Provider(
                id: "icloud-apps", title: "iCloud App Documents", symbol: "icloud.and.arrow.down.fill",
                root: mobileDocuments, detail: "Documents apps keep in iCloud; they download again when opened",
                skipped: [iCloudDrive], itemName: containerName, namesContainers: true
            ),
        ]
        // ~/Library/CloudStorage/<App>-<account>, e.g. "GoogleDrive-me@example.com" or "OneDrive-Personal".
        for folder in FileSizer.children(of: library.appending(path: "CloudStorage", directoryHint: .isDirectory)) {
            let name = folder.lastPathComponent
            guard !name.hasPrefix(".") else { continue }
            let (app, account) = splitProviderFolder(name)
            providers.append(Provider(
                id: "cloud-\(name)", title: account.map { "\(app) · \($0)" } ?? app, symbol: "externaldrive.fill.badge.icloud",
                root: folder
            ))
        }
        return providers
    }

    /// "GoogleDrive-me@example.com" → ("Google Drive", "me@example.com"); "Dropbox" → ("Dropbox", nil).
    static func splitProviderFolder(_ name: String) -> (app: String, account: String?) {
        let parts = name.split(separator: "-", maxSplits: 1).map(String.init)
        let known = [
            "GoogleDrive": "Google Drive", "OneDrive": "OneDrive", "Box": "Box", "Dropbox": "Dropbox", "pCloudDrive": "pCloud",
            "ProtonDrive": "Proton Drive", "SynologyDrive": "Synology Drive", "Nextcloud": "Nextcloud", "ownCloud": "ownCloud",
            "Egnyte": "Egnyte", "SharePoint": "SharePoint", "MEGA": "MEGA", "Tresorit": "Tresorit", "Seafile": "Seafile",
        ]
        let app = known[parts[0]] ?? parts[0]
        return (app, parts.count > 1 ? parts[1] : nil)
    }

    /// "com~apple~Pages" → "Pages", "iCloud~md~obsidian" → "obsidian" (the app's own name is the last part).
    static func containerName(_ folder: String) -> String {
        folder.split(separator: "~").last.map(String.init) ?? folder
    }

    /// What counts as worth a look: big downloads, and smaller ones nobody has opened in a long time.
    public struct Thresholds: Sendable {
        /// Downloads at least this big are always listed.
        public var big: Int64 = 100_000_000
        /// Downloads at least this big are listed once they go unused for `staleAge`.
        public var stale: Int64 = 10_000_000
        /// Unused this long, a download is pre-selected to free up.
        public var staleAge: TimeInterval = 182 * 86_400
        /// Most items shown per provider, largest first.
        public var limit = 400

        public init() {}
    }

    /// Lists big or long-unused files that are downloaded to this Mac. Only files untouched for `staleAge` start
    /// checked: big files you opened recently stay unchecked, so a clean never offloads everything at once.
    public static func scan(
        home: URL = Paths.home, thresholds: Thresholds = .init(), now: Date = .now, progress: ScanProgress
    ) -> [CleanupGroup] {
        let providers = providers(home: home)
        var groups: [CleanupGroup] = []
        for (index, provider) in providers.enumerated() {
            if progress.isCancelled || Task.isCancelled { break }
            progress.update(detail: provider.title, fraction: Double(index) / Double(providers.count))
            let found = Mutex<[CleanupItem]>([])
            let rootPath = provider.root.path(percentEncoded: false).trimmingSuffix("/")
            ParallelWalker.walk(root: provider.root, progress: progress) { url, values in
                let isFolder = values.isDirectory == true && values.isPackage != true
                if isFolder {
                    // Top-level folders that belong to another provider (iCloud Drive inside Mobile Documents).
                    let isTopLevel = url.deletingLastPathComponent().path(percentEncoded: false).trimmingSuffix("/") == rootPath
                    return !(isTopLevel && provider.skipped.contains(url.lastPathComponent))
                }
                // Only allocated bytes count: files that live only in the cloud take no space here.
                let size = values.isPackage == true ? FileSizer.size(of: url) : FileSizer.allocatedSize(values)
                guard size >= thresholds.stale else { return false }
                let lastUsed = [values.contentAccessDate, values.contentModificationDate].compactMap { $0 }.max()
                let idle = lastUsed.map { now.timeIntervalSince($0) } ?? .infinity
                let isStale = idle >= thresholds.staleAge
                guard isStale || size >= thresholds.big else { return false }
                progress.found(bytes: size)
                let item = CleanupItem(
                    url: url, size: size, modified: lastUsed, isRecommended: isStale,
                    note: note(for: url, provider: provider, rootPath: rootPath, lastUsed: lastUsed, isStale: isStale, now: now),
                    removal: .evictDownload
                )
                found.withLock { $0.append(item) }
                return false
            }
            let items = found.withLock { $0 }.sorted { $0.size > $1.size }.prefix(thresholds.limit)
            guard !items.isEmpty else { continue }
            groups.append(CleanupGroup(
                id: provider.id, title: provider.title, detail: provider.detail,
                symbol: provider.symbol, items: Array(items)
            ))
        }
        progress.update(fraction: 1)
        return groups.sorted { $0.size > $1.size }
    }

    /// "Projects/Client · not opened in 8 months", so a big file can be found in its folder.
    static func note(for url: URL, provider: Provider, rootPath: String, lastUsed: Date?, isStale: Bool, now: Date) -> String {
        let parent = url.deletingLastPathComponent().path(percentEncoded: false).trimmingSuffix("/")
        var parts = parent.hasPrefix(rootPath) ? parent.dropFirst(rootPath.count).split(separator: "/").map(String.init) : []
        // Name the app for iCloud app containers: "Pages/Documents", not "com~apple~Pages/Documents".
        if provider.namesContainers, !parts.isEmpty { parts[0] = provider.itemName(parts[0]) }
        let folder = parts.joined(separator: "/")
        let usage: String
        if let lastUsed {
            let relative = lastUsed.formatted(.relative(presentation: .named, unitsStyle: .wide))
            usage = isStale ? "not opened since \(relative)" : "used \(relative)"
        } else {
            usage = "never opened"
        }
        return [folder.isEmpty ? provider.title : folder, usage].joined(separator: " · ")
    }

    /// Removes the local copy of a cloud item through its File Provider, falling back to the iCloud API.
    static func evict(_ url: URL) throws {
        if evictWithFileProvider(url) != nil {
            try FileManager.default.evictUbiquitousItem(at: url)
        }
    }

    /// Returns nil on success, or the error to report.
    private static func evictWithFileProvider(_ url: URL) -> Error? {
        let done = DispatchSemaphore(value: 0)
        nonisolated(unsafe) var failure: Error?
        NSFileProviderManager.getIdentifierForUserVisibleFile(at: url) { identifier, domainIdentifier, error in
            guard let identifier, let domainIdentifier else {
                failure = error ?? CocoaError(.fileNoSuchFile)
                done.signal()
                return
            }
            NSFileProviderManager.getDomainsWithCompletionHandler { domains, error in
                guard let domain = domains.first(where: { $0.identifier == domainIdentifier }),
                      let manager = NSFileProviderManager(for: domain) else {
                    failure = error ?? CocoaError(.fileNoSuchFile)
                    done.signal()
                    return
                }
                manager.evictItem(identifier: identifier) { error in
                    failure = error
                    done.signal()
                }
            }
        }
        if done.wait(timeout: .now() + 120) == .timedOut { return CocoaError(.fileWriteUnknown) }
        return failure
    }
}
