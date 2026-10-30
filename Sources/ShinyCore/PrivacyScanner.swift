import Foundation

/// Finds browsing traces: history, cookies and recent-item lists.
/// Saved passwords, autofill, bookmarks and extensions are never touched.
public enum PrivacyScanner {
    struct ChromiumBrowser {
        let name: String
        let bundleID: String
        /// Folder under ~/Library/Application Support that holds the profiles.
        let dataPath: String
    }

    static let chromiumBrowsers = [
        ChromiumBrowser(name: "Google Chrome", bundleID: "com.google.Chrome", dataPath: "Google/Chrome"),
        ChromiumBrowser(name: "Microsoft Edge", bundleID: "com.microsoft.edgemac", dataPath: "Microsoft Edge"),
        ChromiumBrowser(name: "Brave", bundleID: "com.brave.Browser", dataPath: "BraveSoftware/Brave-Browser"),
        ChromiumBrowser(name: "Arc", bundleID: "company.thebrowser.Browser", dataPath: "Arc/User Data"),
        ChromiumBrowser(name: "Vivaldi", bundleID: "com.vivaldi.Vivaldi", dataPath: "Vivaldi"),
        ChromiumBrowser(name: "Opera", bundleID: "com.operasoftware.Opera", dataPath: "com.operasoftware.Opera"),
    ]

    static let chromiumHistoryFiles = [
        "History", "History-journal", "Visited Links", "Top Sites", "Top Sites-journal", "Shortcuts", "Shortcuts-journal",
        "Network Action Predictor", "Network Action Predictor-journal",
    ]
    static let chromiumCookieFiles = ["Cookies", "Cookies-journal", "Network/Cookies", "Network/Cookies-journal"]

    public static func scan(home: URL = Paths.home, progress: ScanProgress) -> [CleanupGroup] {
        let library = home.appending(path: "Library", directoryHint: .isDirectory)
        let support = library.appending(path: "Application Support", directoryHint: .isDirectory)
        var groups: [CleanupGroup] = []

        progress.update(detail: "Safari", fraction: 0)
        groups.append(contentsOf: [safari(library: library)].compactMap { $0 })

        for (index, browser) in chromiumBrowsers.enumerated() {
            if Task.isCancelled { break }
            progress.update(detail: browser.name, fraction: Double(index + 1) / Double(chromiumBrowsers.count + 3))
            if let group = chromium(browser, root: support.appending(path: browser.dataPath, directoryHint: .isDirectory)) {
                groups.append(group)
            }
        }

        progress.update(detail: "Firefox")
        if let firefox = firefox(support: support) { groups.append(firefox) }

        progress.update(detail: "Recent items")
        if let recents = recentItems(support: support) { groups.append(recents) }

        for group in groups {
            for item in group.items where item.isRecommended { progress.found(bytes: item.size) }
        }
        progress.update(fraction: 1)
        return groups
    }

    // MARK: Browsers

    static func chromium(_ browser: ChromiumBrowser, root: URL) -> CleanupGroup? {
        let profiles = FileSizer.children(of: root).filter {
            let name = $0.lastPathComponent
            return name == "Default" || name.hasPrefix("Profile ")
        }
        var items: [CleanupItem] = []
        for profile in profiles.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            let suffix = profiles.count > 1 ? " (\(profile.lastPathComponent))" : ""
            items += bundle(chromiumHistoryFiles, in: profile, name: "Browsing history\(suffix)", recommended: true)
            items += bundle(chromiumCookieFiles, in: profile, name: "Cookies\(suffix)", recommended: false)
        }
        return group(id: browser.bundleID, title: browser.name, symbol: "globe", items: items)
    }

    static func safari(library: URL) -> CleanupGroup? {
        let safari = library.appending(path: "Safari", directoryHint: .isDirectory)
        let history = bundle(["History.db", "History.db-shm", "History.db-wal"], in: safari, name: "Browsing history", recommended: true)
        let cookies = bundle(
            ["Containers/com.apple.Safari/Data/Library/Cookies/Cookies.binarycookies", "Cookies/Cookies.binarycookies"],
            in: library, name: "Cookies", recommended: false
        )
        return group(id: "com.apple.Safari", title: "Safari", symbol: "safari.fill", items: history + cookies)
    }

    static func firefox(support: URL) -> CleanupGroup? {
        let profiles = FileSizer.children(of: support.appending(path: "Firefox/Profiles", directoryHint: .isDirectory))
        var items: [CleanupItem] = []
        for profile in profiles {
            // History shares places.sqlite with bookmarks, so only form history is cleared.
            items += bundle(["formhistory.sqlite"], in: profile, name: "Form history (\(profile.lastPathComponent))", recommended: true)
            items += bundle(["cookies.sqlite", "cookies.sqlite-wal"], in: profile, name: "Cookies (\(profile.lastPathComponent))", recommended: false)
        }
        return group(id: "org.mozilla.firefox", title: "Firefox", symbol: "flame.fill", items: items)
    }

    static func recentItems(support: URL) -> CleanupGroup? {
        let folder = support.appending(path: "com.apple.sharedfilelist", directoryHint: .isDirectory)
        let items = FileSizer.children(of: folder)
            .filter { $0.lastPathComponent.contains("Recent") }
            .map { url -> CleanupItem in
                let name = url.lastPathComponent
                    .replacingOccurrences(of: "com.apple.LSSharedFileList.", with: "")
                    .replacingOccurrences(of: ".sfl3", with: "")
                    .replacingOccurrences(of: ".sfl2", with: "")
                return FileSizer.item(at: url, name: readable(name))
            }
            .filter { $0.size > 0 }
        guard !items.isEmpty else { return nil }
        return CleanupGroup(
            id: "recentItems", title: "Recent Items", detail: "Lists of recently opened documents, apps and servers",
            symbol: "clock.arrow.circlepath", items: items
        )
    }

    // MARK: Helpers

    /// Existing files from `names` inside `folder`, each as its own item sharing a friendly name.
    static func bundle(_ names: [String], in folder: URL, name: String, recommended: Bool) -> [CleanupItem] {
        names.compactMap { relative in
            let url = folder.appending(path: relative, directoryHint: .notDirectory)
            guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else { return nil }
            let size = FileSizer.size(of: url)
            let label = relative.hasSuffix("-journal") || relative.hasSuffix("-wal") || relative.hasSuffix("-shm")
                ? "\(name) · journal" : name
            return CleanupItem(url: url, name: label, size: size, isRecommended: recommended)
        }
    }

    static func group(id: String, title: String, symbol: String, items: [CleanupItem]) -> CleanupGroup? {
        guard !items.isEmpty else { return nil }
        let hasCookies = items.contains { !$0.isRecommended }
        return CleanupGroup(
            id: id, title: title, detail: hasCookies ? "History and cookies" : "Browsing history",
            symbol: symbol, items: items
        )
    }

    /// "RecentDocuments" → "Recent Documents"
    static func readable(_ camelCase: String) -> String {
        camelCase.reduce(into: "") { result, character in
            if character.isUppercase, let last = result.last, last.isLowercase { result.append(" ") }
            result.append(character)
        }
    }
}
