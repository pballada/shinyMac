import CoreServices
import Foundation

/// An app installed in /Applications or ~/Applications.
public struct InstalledApp: Identifiable, Hashable, Sendable {
    public var id: URL { url }
    public let url: URL
    public let name: String
    public let bundleID: String
    public let version: String?
    /// CFBundleName, which often differs from the display name (e.g. "Code" for Visual Studio Code).
    public let bundleName: String?
    public let isAppStore: Bool
    public let lastUsed: Date?

    public init(url: URL, name: String, bundleID: String, version: String?, bundleName: String?, isAppStore: Bool, lastUsed: Date?) {
        self.url = url
        self.name = name
        self.bundleID = bundleID
        self.version = version
        self.bundleName = bundleName
        self.isAppStore = isAppStore
        self.lastUsed = lastUsed
    }

    public var identity: AppIdentity {
        AppIdentity(bundleID: bundleID, names: [name, bundleName, url.deletingPathExtension().lastPathComponent].compactMap { $0 })
    }
}

public enum AppScanner {
    /// Bundle identifiers that must never be offered for removal.
    static let excludedBundleIDs: Set<String> = ["com.pballada.shinymac", "com.apple.finder"]

    public static func folders(home: URL = Paths.home) -> [URL] {
        [URL(filePath: "/Applications", directoryHint: .isDirectory), home.appending(path: "Applications", directoryHint: .isDirectory)]
    }

    /// Fast listing without sizes, sorted by name. Looks one folder deep (e.g. /Applications/Adobe Photoshop/…).
    public static func installedApps(home: URL = Paths.home) -> [InstalledApp] {
        var seen = Set<String>()
        var apps: [InstalledApp] = []
        for folder in folders(home: home) {
            for url in FileSizer.children(of: folder) {
                let candidates = url.pathExtension == "app"
                    ? [url]
                    : FileSizer.children(of: url).filter { $0.pathExtension == "app" }
                for candidate in candidates {
                    guard let app = app(at: candidate), seen.insert(app.url.path(percentEncoded: false)).inserted else { continue }
                    apps.append(app)
                }
            }
        }
        return apps.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// Reads an app bundle's metadata, or nil for system apps and anything that isn't a real app.
    public static func app(at url: URL) -> InstalledApp? {
        // System apps (and Safari, which lives in a cryptex) are protected by macOS.
        if url.resolvingSymlinksInPath().path(percentEncoded: false).hasPrefix("/System/") { return nil }
        let plistURL = url.appending(path: "Contents/Info.plist")
        guard let data = try? Data(contentsOf: plistURL),
              let info = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let bundleID = info["CFBundleIdentifier"] as? String,
              !excludedBundleIDs.contains(bundleID)
        else { return nil }

        let fileName = url.deletingPathExtension().lastPathComponent
        let displayName = (info["CFBundleDisplayName"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? fileName
        let receipt = url.appending(path: "Contents/_MASReceipt/receipt").path(percentEncoded: false)

        return InstalledApp(
            url: url,
            name: displayName,
            bundleID: bundleID,
            version: info["CFBundleShortVersionString"] as? String ?? info["CFBundleVersion"] as? String,
            bundleName: info["CFBundleName"] as? String,
            isAppStore: FileManager.default.fileExists(atPath: receipt),
            lastUsed: lastUsedDate(of: url)
        )
    }

    /// When the app was last opened, according to Spotlight.
    public static func lastUsedDate(of url: URL) -> Date? {
        guard let item = MDItemCreateWithURL(kCFAllocatorDefault, url as CFURL) else { return nil }
        return MDItemCopyAttribute(item, kMDItemLastUsedDate) as? Date
    }

    /// Measures bundle sizes in parallel, reporting each as soon as it's known.
    public static func measure(_ apps: [InstalledApp], onSize: @escaping @Sendable (URL, Int64) -> Void) {
        DispatchQueue.concurrentPerform(iterations: apps.count) { index in
            guard !Task.isCancelled else { return }
            onSize(apps[index].url, FileSizer.size(of: apps[index].url))
        }
    }
}
