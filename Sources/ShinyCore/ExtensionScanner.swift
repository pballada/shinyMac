import Foundation

/// Lists add-ons that plug into macOS: Quick Look and Spotlight plug-ins, preference panes,
/// screen savers and internet plug-ins, from both the user and the system-wide Library.
public enum ExtensionScanner {
    struct Kind {
        let id: String
        let title: String
        let detail: String
        let symbol: String
        let folder: String
        let extensions: Set<String>
    }

    static let kinds = [
        Kind(id: "quickLook", title: "Quick Look Plug-ins", detail: "Previews for file types in Finder",
             symbol: "eye.fill", folder: "QuickLook", extensions: ["qlgenerator"]),
        Kind(id: "spotlight", title: "Spotlight Importers", detail: "Teach Spotlight to index file types",
             symbol: "magnifyingglass", folder: "Spotlight", extensions: ["mdimporter"]),
        Kind(id: "prefPanes", title: "Preference Panes", detail: "Third-party panels in System Settings",
             symbol: "gearshape.fill", folder: "PreferencePanes", extensions: ["prefpane"]),
        Kind(id: "screenSavers", title: "Screen Savers", detail: "Installed screen savers",
             symbol: "sparkles.tv.fill", folder: "Screen Savers", extensions: ["saver", "qtz"]),
        Kind(id: "internetPlugins", title: "Internet Plug-ins", detail: "Legacy browser plug-ins",
             symbol: "puzzlepiece.extension.fill", folder: "Internet Plug-Ins", extensions: ["plugin", "webplugin"]),
    ]

    public static func scan(home: URL = Paths.home, progress: ScanProgress) -> [CleanupGroup] {
        let libraries = [
            home.appending(path: "Library", directoryHint: .isDirectory),
            URL(filePath: "/Library", directoryHint: .isDirectory),
        ]
        return kinds.enumerated().compactMap { index, kind in
            progress.update(detail: kind.title, fraction: Double(index) / Double(kinds.count))
            let items = libraries
                .flatMap { FileSizer.children(of: $0.appending(path: kind.folder, directoryHint: .isDirectory)) }
                .filter { kind.extensions.contains($0.pathExtension.lowercased()) }
                .map { FileSizer.item(at: $0, name: displayName(of: $0)) }
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            guard !items.isEmpty else { return nil }
            return CleanupGroup(
                id: kind.id, title: kind.title, detail: kind.detail, symbol: kind.symbol,
                items: items, selectedByDefault: false
            )
        }
    }

    /// Bundle name and version from Info.plist, e.g. "QLMarkdown 1.0.5".
    static func displayName(of bundle: URL) -> String {
        let fallback = bundle.deletingPathExtension().lastPathComponent
        guard let data = try? Data(contentsOf: bundle.appending(path: "Contents/Info.plist")),
              let info = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return fallback }
        let name = (info["CFBundleDisplayName"] as? String) ?? (info["CFBundleName"] as? String) ?? fallback
        guard let version = info["CFBundleShortVersionString"] as? String, !version.isEmpty else { return name }
        return "\(name) \(version)"
    }
}
