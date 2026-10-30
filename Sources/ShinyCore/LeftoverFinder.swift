import Foundation

/// The names an app goes by, used to recognise files that belong to it.
public struct AppIdentity: Sendable, Hashable {
    public let bundleID: String
    public let names: [String]

    /// Words too generic to identify a single app by name alone.
    static let genericNames: Set<String> = [
        "adobe", "agent", "apple", "app", "application", "cache", "caches", "common", "data", "default", "google",
        "helper", "library", "logs", "microsoft", "mozilla", "plugins", "settings", "shared", "support", "temp",
        "tmp", "update", "updater", "user",
    ]

    /// File suffixes stripped before comparing names.
    static let strippedSuffixes = [".plist", ".savedState", ".binarycookies", ".sfl2", ".sfl3", ".log", ".lockfile"]

    public init(bundleID: String, names: [String]) {
        self.bundleID = bundleID
        self.names = names
    }

    /// Lowercased alphanumeric forms of the app's names, ignoring ones that are too short or generic.
    var normalizedNames: Set<String> {
        Set(names.map(Self.normalize).filter { $0.count >= 3 && !Self.genericNames.contains($0) })
    }

    static func normalize(_ string: String) -> String {
        string.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    static func stripSuffixes(_ fileName: String) -> String {
        var name = fileName
        for suffix in strippedSuffixes where name.lowercased().hasSuffix(suffix.lowercased()) {
            name = String(name.dropLast(suffix.count))
        }
        return name
    }

    /// Whether a file or folder name refers to this app.
    ///
    /// Bundle identifiers match on component boundaries, so `com.foo.app` matches `com.foo.app.helper`,
    /// `TEAMID.com.foo.app` and `com.foo.app.plist`, but not `com.foo.application`.
    /// Plain names must match exactly (ignoring case, spaces and punctuation).
    public func matches(fileName: String) -> Bool {
        let name = Self.stripSuffixes(fileName)
        let lower = name.lowercased()
        let id = bundleID.lowercased()
        if lower == id || lower.hasPrefix(id + ".") || lower.hasSuffix("." + id) || lower.contains("." + id + ".") {
            return true
        }
        return normalizedNames.contains(Self.normalize(name))
    }

    /// For vendor folders such as `Google` (for Google Chrome), the remainder of the name to look for inside.
    func vendorRemainder(forFolder folderName: String) -> String? {
        let folder = Self.normalize(folderName)
        guard folder.count >= 3 else { return nil }
        for name in normalizedNames where name.hasPrefix(folder) && name.count >= folder.count + 3 {
            return String(name.dropFirst(folder.count))
        }
        return nil
    }
}

/// What part of the system a leftover lives in.
public enum LeftoverKind: String, Sendable, CaseIterable {
    case application = "Application"
    case support = "Application Support"
    case caches = "Caches"
    case preferences = "Preferences"
    case containers = "Containers"
    case savedState = "Saved State"
    case webData = "Web Data"
    case logs = "Logs"
    case launchItems = "Launch Items"
    case receipts = "Install Receipts"

    public var symbol: String {
        switch self {
        case .application: "app.fill"
        case .support: "folder.fill"
        case .caches: "archivebox.fill"
        case .preferences: "gearshape.fill"
        case .containers: "shippingbox.fill"
        case .savedState: "macwindow"
        case .webData: "globe"
        case .logs: "doc.plaintext.fill"
        case .launchItems: "power"
        case .receipts: "doc.text.fill"
        }
    }
}

/// A file that belongs to an app.
public struct Leftover: Identifiable, Hashable, Sendable {
    public var id: URL { url }
    public let url: URL
    public let kind: LeftoverKind
    public let size: Int64

    public init(url: URL, kind: LeftoverKind, size: Int64) {
        self.url = url
        self.kind = kind
        self.size = size
    }

    /// Whether removing this needs administrator rights (it lives outside the home folder).
    public var isSystemWide: Bool {
        !url.path(percentEncoded: false).hasPrefix(Paths.home.path(percentEncoded: false))
    }
}

/// Finds the files an app spreads across the system, Pearcleaner-style.
public enum LeftoverFinder {
    public static func searchRoots(home: URL = Paths.home) -> [(url: URL, kind: LeftoverKind)] {
        let user: [(String, LeftoverKind)] = [
            ("Application Support", .support), ("Application Scripts", .support), ("Caches", .caches),
            ("HTTPStorages", .webData), ("WebKit", .webData), ("Cookies", .webData),
            ("Preferences", .preferences), ("Preferences/ByHost", .preferences),
            ("Containers", .containers), ("Group Containers", .containers),
            ("Saved Application State", .savedState), ("Logs", .logs), ("LaunchAgents", .launchItems),
            ("Internet Plug-Ins", .support),
        ]
        let system: [(String, LeftoverKind)] = [
            ("/Library/Application Support", .support), ("/Library/Caches", .caches), ("/Library/Preferences", .preferences),
            ("/Library/Logs", .logs), ("/Library/LaunchAgents", .launchItems), ("/Library/LaunchDaemons", .launchItems),
            ("/Library/PrivilegedHelperTools", .launchItems), ("/private/var/db/receipts", .receipts),
        ]
        let library = home.appending(path: "Library", directoryHint: .isDirectory)
        return user.map { (library.appending(path: $0.0, directoryHint: .isDirectory), $0.1) }
            + system.map { (URL(filePath: $0.0, directoryHint: .isDirectory), $0.1) }
    }

    /// Every file that belongs to the app, excluding the app bundle itself, largest first.
    public static func find(for identity: AppIdentity, home: URL = Paths.home) -> [Leftover] {
        var found: [URL: LeftoverKind] = [:]
        for root in searchRoots(home: home) {
            if Task.isCancelled { break }
            for child in FileSizer.children(of: root.url) {
                let name = child.lastPathComponent
                if identity.matches(fileName: name) {
                    found[child] = root.kind
                } else if let remainder = identity.vendorRemainder(forFolder: name) {
                    for nested in FileSizer.children(of: child)
                    where AppIdentity.normalize(nested.lastPathComponent) == remainder || identity.matches(fileName: nested.lastPathComponent) {
                        found[nested] = root.kind
                    }
                }
            }
        }
        return found
            .map { Leftover(url: $0.key, kind: $0.value, size: FileSizer.size(of: $0.key)) }
            .sorted { $0.size > $1.size }
    }
}
