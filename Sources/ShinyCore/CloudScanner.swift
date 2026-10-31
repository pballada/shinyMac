import FileProvider
import Foundation

/// Finds files from iCloud Drive, Dropbox, Google Drive, OneDrive and other File Provider apps that are
/// downloaded to this Mac. Removing the download frees the space; the file stays in the cloud.
public enum CloudScanner {
    struct Provider {
        let id: String
        let title: String
        let symbol: String
        let root: URL
    }

    static func providers(home: URL) -> [Provider] {
        let library = home.appending(path: "Library", directoryHint: .isDirectory)
        var providers = [Provider(
            id: "icloud", title: "iCloud Drive", symbol: "icloud.fill",
            root: library.appending(path: "Mobile Documents/com~apple~CloudDocs", directoryHint: .isDirectory)
        )]
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
        let known = ["GoogleDrive": "Google Drive", "OneDrive": "OneDrive", "Box": "Box", "Dropbox": "Dropbox", "pCloudDrive": "pCloud"]
        let app = known[parts[0]] ?? parts[0]
        return (app, parts.count > 1 ? parts[1] : nil)
    }

    public static func scan(home: URL = Paths.home, progress: ScanProgress) -> [CleanupGroup] {
        let providers = providers(home: home)
        var groups: [CleanupGroup] = []
        for (index, provider) in providers.enumerated() {
            if Task.isCancelled { break }
            progress.update(detail: provider.title, fraction: Double(index) / Double(providers.count))
            // Only allocated bytes count: files that live only in the cloud take no space here.
            let items = FileSizer.children(of: provider.root)
                .filter { !$0.lastPathComponent.hasPrefix(".") }
                .compactMap { url -> CleanupItem? in
                    if Task.isCancelled { return nil }
                    progress.update(detail: "\(provider.title) › \(url.lastPathComponent)")
                    let item = FileSizer.item(at: url)
                    guard item.size >= minimumSize else { return nil }
                    progress.found(bytes: item.size)
                    return CleanupItem(
                        url: url, size: item.size, modified: item.modified,
                        note: "Downloaded to this Mac · stays in \(provider.title)", removal: .evictDownload
                    )
                }
            guard !items.isEmpty else { continue }
            groups.append(CleanupGroup(
                id: provider.id, title: provider.title, detail: "Local copies of cloud files; they download again when opened",
                symbol: provider.symbol, items: items.sorted { $0.size > $1.size }
            ))
        }
        progress.update(fraction: 1)
        return groups
    }

    /// Tiny items aren't worth a row.
    static let minimumSize: Int64 = 1_000_000

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
