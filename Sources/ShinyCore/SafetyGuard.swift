import Foundation

/// Last line of defence: no matter what a scanner proposes, these locations are never removed.
public enum SafetyGuard {
    static let protectedSystemPaths: Set<String> = [
        "/", "/Applications", "/Library", "/System", "/Users", "/Volumes", "/bin", "/cores", "/dev",
        "/etc", "/opt", "/private", "/sbin", "/tmp", "/usr", "/var",
        "/Library/Application Support", "/Library/Caches", "/Library/LaunchAgents", "/Library/LaunchDaemons",
        "/Library/Logs", "/Library/Preferences", "/Library/PrivilegedHelperTools",
    ]

    static let protectedHomeFolders: [String] = [
        "", ".Trash", "Applications", "Desktop", "Documents", "Downloads", "Library", "Movies", "Music", "Pictures", "Public",
        "Library/Application Support", "Library/Caches", "Library/Containers", "Library/Cookies",
        "Library/Group Containers", "Library/HTTPStorages", "Library/LaunchAgents", "Library/Logs",
        "Library/Mail", "Library/Preferences", "Library/Saved Application State", "Library/WebKit",
        "Library/Developer", "Library/Mobile Documents",
    ]

    static let protectedPrefixes = ["/System/", "/bin/", "/sbin/", "/usr/", "/dev/", "/private/etc/", "/etc/"]

    /// Whether `url` may be moved to the Trash or deleted.
    public static func canRemove(_ url: URL, home: URL = Paths.home) -> Bool {
        guard url.isFileURL else { return false }
        let path = normalized(url.standardizedFileURL.path(percentEncoded: false))
        guard path.hasPrefix("/"), !path.contains("/../") else { return false }

        if protectedSystemPaths.contains(path) { return false }
        if protectedPrefixes.contains(where: { path.hasPrefix($0) }) { return false }

        let homePath = normalized(home.path(percentEncoded: false))
        for folder in protectedHomeFolders {
            let protectedPath = folder.isEmpty ? homePath : homePath + "/" + folder
            if path == protectedPath { return false }
        }

        let components = URL(filePath: path).pathComponents
        // Something at least two levels deep, and never a user's home folder itself.
        if components.count < 3 { return false }
        if components.count == 3, components[1] == "Users" { return false }
        return true
    }

    private static func normalized(_ path: String) -> String {
        path.count > 1 && path.hasSuffix("/") ? String(path.dropLast()) : path
    }
}
