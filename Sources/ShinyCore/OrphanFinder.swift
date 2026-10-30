import CoreServices
import Foundation

/// Finds support files left behind by apps that are no longer installed.
///
/// Deliberately conservative: only reverse-DNS names (`com.vendor.app`) are considered, Apple's own are skipped,
/// and anything from a vendor that still has an app installed, or that LaunchServices still knows, is left alone.
public enum OrphanFinder {
    struct Root {
        let path: String
        let kind: LeftoverKind
        let title: String
        let symbol: String
        /// Safe-to-lose data starts selected; anything that might hold user data starts unchecked.
        let selectedByDefault: Bool
    }

    static let roots: [Root] = [
        Root(path: "Application Support", kind: .support, title: "Application Support", symbol: "folder.fill", selectedByDefault: false),
        Root(path: "Containers", kind: .containers, title: "Containers", symbol: "shippingbox.fill", selectedByDefault: false),
        Root(path: "Group Containers", kind: .containers, title: "Group Containers", symbol: "square.stack.3d.up.fill", selectedByDefault: false),
        Root(path: "Preferences", kind: .preferences, title: "Preferences", symbol: "gearshape.fill", selectedByDefault: false),
        Root(path: "LaunchAgents", kind: .launchItems, title: "Launch Agents", symbol: "power", selectedByDefault: false),
        Root(path: "Caches", kind: .caches, title: "Caches", symbol: "archivebox.fill", selectedByDefault: true),
        Root(path: "HTTPStorages", kind: .webData, title: "Web Storage", symbol: "globe", selectedByDefault: true),
        Root(path: "WebKit", kind: .webData, title: "WebKit Data", symbol: "safari.fill", selectedByDefault: true),
        Root(path: "Saved Application State", kind: .savedState, title: "Saved Window State", symbol: "macwindow", selectedByDefault: true),
        Root(path: "Logs", kind: .logs, title: "Logs", symbol: "doc.plaintext.fill", selectedByDefault: true),
    ]

    /// Apple, developer tools, and analytics SDKs that write shared data on behalf of installed apps.
    static let ignoredPrefixes = [
        "com.apple.", "systemgroup.", "apple.", "is.workflow.", "org.swift.", "org.cups.", "com.pballada.shinymac",
        "com.crashlytics", "com.firebase", "com.google.firebase", "com.segment", "io.branch", "io.sentry",
    ]

    /// The bundle-identifier-like part of a file name, or nil if it doesn't look like one.
    /// Strips extensions such as `.plist`, and `group.` / team-ID prefixes used by group containers.
    static func identifier(from fileName: String) -> String? {
        var name = AppIdentity.stripSuffixes(fileName)
        if let teamRange = name.range(of: #"^[A-Z0-9]{10}\."#, options: .regularExpression) {
            name.removeSubrange(teamRange)
        }
        for prefix in ["group.", "groups."] where name.hasPrefix(prefix) {
            name = String(name.dropFirst(prefix.count))
        }
        let components = name.split(separator: ".", omittingEmptySubsequences: false)
        guard components.count >= 3,
              components.allSatisfy({ !$0.isEmpty && $0.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" } })
        else { return nil }
        return name
    }

    static func vendor(of identifier: String) -> String {
        identifier.lowercased().split(separator: ".").prefix(2).joined(separator: ".")
    }

    /// Whether an identifier belongs to nothing that is installed.
    /// `installedNames` are normalized app names; an identifier mentioning one (e.g. `com.dropbox.agent`
    /// while Dropbox is installed under `com.getdropbox.dropbox`) is assumed to belong to it.
    static func isOrphan(_ identifier: String, installedIDs: Set<String>, installedVendors: Set<String>, installedNames: Set<String> = []) -> Bool {
        let lower = identifier.lowercased()
        if ignoredPrefixes.contains(where: { lower.hasPrefix($0.lowercased()) }) { return false }
        if installedVendors.contains(vendor(of: lower)) { return false }
        if installedIDs.contains(where: { lower == $0 || lower.hasPrefix($0 + ".") }) { return false }
        let components = lower.split(separator: ".").map { AppIdentity.normalize(String($0)) }
        if components.contains(where: { $0.count >= 4 && installedNames.contains($0) }) { return false }
        return true
    }

    /// LaunchServices knows about apps installed anywhere, including inside other bundles.
    static func isRegisteredApp(_ identifier: String) -> Bool {
        guard let urls = LSCopyApplicationURLsForBundleIdentifier(identifier as CFString, nil)?.takeRetainedValue() as? [URL] else {
            return false
        }
        return !urls.isEmpty
    }

    public static func scan(installed: [InstalledApp], home: URL = Paths.home, checkLaunchServices: Bool = true, progress: ScanProgress) -> [CleanupGroup] {
        let installedIDs = Set(installed.map { $0.bundleID.lowercased() })
        let installedVendors = Set(installed.map { vendor(of: $0.bundleID) })
        let installedNames = Set(installed.flatMap { $0.identity.normalizedNames })
        let library = home.appending(path: "Library", directoryHint: .isDirectory)

        var groups: [CleanupGroup] = []
        for (index, root) in roots.enumerated() {
            if Task.isCancelled { break }
            progress.update(detail: "~/Library/\(root.path)", fraction: Double(index) / Double(roots.count))

            var items: [CleanupItem] = []
            for url in FileSizer.children(of: library.appending(path: root.path, directoryHint: .isDirectory)) {
                if Task.isCancelled { break }
                guard let identifier = identifier(from: url.lastPathComponent),
                      isOrphan(identifier, installedIDs: installedIDs, installedVendors: installedVendors, installedNames: installedNames),
                      !checkLaunchServices || !isRegisteredApp(identifier)
                else { continue }
                progress.update(detail: Paths.abbreviated(url))
                let item = FileSizer.item(at: url, name: identifier)
                guard item.size > 0 else { continue }
                items.append(item)
                if root.selectedByDefault { progress.found(bytes: item.size) }
            }

            if !items.isEmpty {
                groups.append(CleanupGroup(
                    id: root.path, title: root.title, detail: "From apps that are no longer installed",
                    symbol: root.symbol, items: items.sorted { $0.size > $1.size }, selectedByDefault: root.selectedByDefault
                ))
            }
        }
        progress.update(fraction: 1)
        return groups
    }
}
