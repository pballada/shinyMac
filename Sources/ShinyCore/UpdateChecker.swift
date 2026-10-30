import Foundation

/// A newer version published in an app's Sparkle update feed.
public struct AppUpdate: Identifiable, Hashable, Sendable {
    public var id: URL { app.url }
    public let app: InstalledApp
    public let installedVersion: String
    public let latestVersion: String
    public let releaseNotes: URL?
    public let download: URL?
}

/// One `<item>` in a Sparkle appcast.
struct AppcastItem: Equatable {
    var shortVersion: String?
    var build: String?
    var channel: String?
    var releaseNotes: URL?
    var download: URL?

    /// The version users see, falling back to the build number.
    var displayVersion: String? { shortVersion ?? build }
}

/// Checks Sparkle appcasts (`SUFeedURL`), which most apps distributed outside the App Store use.
public enum UpdateChecker {
    /// Apps that declare a Sparkle feed, paired with it.
    public static func feeds(for apps: [InstalledApp]) -> [(InstalledApp, URL)] {
        apps.compactMap { app in
            guard let info = infoPlist(of: app),
                  let raw = info["SUFeedURL"] as? String,
                  let url = URL(string: raw.trimmingCharacters(in: .whitespaces)),
                  url.scheme == "https" || url.scheme == "http"
            else { return nil }
            return (app, url)
        }
    }

    /// Fetches every feed concurrently and returns apps with a newer stable release.
    public static func check(_ apps: [InstalledApp], onChecked: @escaping @Sendable () -> Void = {}) async -> [AppUpdate] {
        let feeds = feeds(for: apps)
        let session = URLSession(configuration: {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 15
            return configuration
        }())
        return await withTaskGroup(of: AppUpdate?.self) { group in
            for (app, feed) in feeds {
                group.addTask {
                    defer { onChecked() }
                    guard let (data, _) = try? await session.data(from: feed) else { return nil }
                    return update(for: app, appcast: parseAppcast(data))
                }
            }
            var updates: [AppUpdate] = []
            for await update in group {
                if let update { updates.append(update) }
            }
            return updates.sorted { $0.app.name.localizedStandardCompare($1.app.name) == .orderedAscending }
        }
    }

    static func update(for app: InstalledApp, appcast items: [AppcastItem]) -> AppUpdate? {
        guard let info = infoPlist(of: app) else { return nil }
        let installedShort = info["CFBundleShortVersionString"] as? String
        let installedBuild = info["CFBundleVersion"] as? String

        let stable = items.filter { $0.channel == nil || $0.channel?.isEmpty == true }
        guard let latest = stable.max(by: { isNewer($1, than: $0) }) else { return nil }

        let newer: Bool
        if let short = latest.shortVersion, let installedShort {
            newer = isNewer(short, than: installedShort)
        } else if let build = latest.build, let installedBuild {
            newer = isNewer(build, than: installedBuild)
        } else {
            newer = false
        }
        guard newer, let latestVersion = latest.displayVersion else { return nil }
        return AppUpdate(
            app: app, installedVersion: installedShort ?? installedBuild ?? "?", latestVersion: latestVersion,
            releaseNotes: latest.releaseNotes, download: latest.download
        )
    }

    /// Numeric-aware comparison: "1.10" is newer than "1.9".
    public static func isNewer(_ candidate: String, than current: String) -> Bool {
        normalized(candidate).compare(normalized(current), options: .numeric) == .orderedDescending
    }

    static func isNewer(_ a: AppcastItem, than b: AppcastItem) -> Bool {
        if let aBuild = a.build, let bBuild = b.build, aBuild != bBuild { return isNewer(aBuild, than: bBuild) }
        return isNewer(a.displayVersion ?? "", than: b.displayVersion ?? "")
    }

    /// Drops suffixes like " (1234)" or "-beta" noise so numeric comparison stays meaningful.
    static func normalized(_ version: String) -> String {
        String(version.trimmingCharacters(in: .whitespaces).prefix { $0.isNumber || $0 == "." })
    }

    static func parseAppcast(_ data: Data) -> [AppcastItem] {
        let delegate = AppcastParser()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.parse()
        return delegate.items
    }

    private static func infoPlist(of app: InstalledApp) -> [String: Any]? {
        guard let data = try? Data(contentsOf: app.url.appending(path: "Contents/Info.plist")) else { return nil }
        return try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
    }
}

private final class AppcastParser: NSObject, XMLParserDelegate {
    var items: [AppcastItem] = []
    private var current: AppcastItem?
    private var text = ""

    func parser(_ parser: XMLParser, didStartElement element: String, namespaceURI: String?, qualifiedName: String?,
                attributes: [String: String] = [:]) {
        text = ""
        switch element {
        case "item":
            current = AppcastItem()
        case "enclosure":
            guard var item = current else { break }
            item.shortVersion = item.shortVersion ?? attributes["sparkle:shortVersionString"]
            item.build = item.build ?? attributes["sparkle:version"]
            item.download = attributes["url"].flatMap(URL.init(string:))
            current = item
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        text += string
    }

    func parser(_ parser: XMLParser, didEndElement element: String, namespaceURI: String?, qualifiedName: String?) {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        switch element {
        case "item":
            if let current { items.append(current) }
            current = nil
        case "sparkle:shortVersionString" where !value.isEmpty:
            current?.shortVersion = value
        case "sparkle:version" where !value.isEmpty:
            current?.build = value
        case "sparkle:channel":
            current?.channel = value
        case "sparkle:releaseNotesLink", "sparkle:fullReleaseNotesLink":
            if current?.releaseNotes == nil { current?.releaseNotes = URL(string: value) }
        default:
            break
        }
        text = ""
    }
}
