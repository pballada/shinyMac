import Foundation

/// Well known locations on the user's Mac.
public enum Paths {
    public static let home = FileManager.default.homeDirectoryForCurrentUser
    public static let library = home.appending(path: "Library", directoryHint: .isDirectory)
    public static let trash = home.appending(path: ".Trash", directoryHint: .isDirectory)
    public static let downloads = home.appending(path: "Downloads", directoryHint: .isDirectory)

    /// A path inside the user's home folder.
    public static func home(_ relativePath: String) -> URL {
        home.appending(path: relativePath, directoryHint: .inferFromPath)
    }

    /// A path inside `~/Library`.
    public static func library(_ relativePath: String) -> URL {
        library.appending(path: relativePath, directoryHint: .inferFromPath)
    }

    /// Replaces the home folder prefix with `~` for display.
    public static func abbreviated(_ url: URL) -> String {
        let path = trimmingTrailingSlash(url.path(percentEncoded: false))
        let homePath = trimmingTrailingSlash(home.path(percentEncoded: false))
        if path == homePath { return "~" }
        if path.hasPrefix(homePath + "/") { return "~" + path.dropFirst(homePath.count) }
        return path
    }

    private static func trimmingTrailingSlash(_ path: String) -> String {
        path.count > 1 && path.hasSuffix("/") ? String(path.dropLast()) : path
    }
}
