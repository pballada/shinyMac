import AppKit
import ShinyCore
import SwiftUI

/// Friendly names and icons for paths. Folders named after a bundle identifier
/// (e.g. `~/Library/Caches/com.spotify.client`) show the owning app's name and icon.
enum FileIcons {
    private static var appCache: [String: URL?] = [:]
    private static var iconCache: [String: NSImage] = [:]

    static func displayName(for url: URL) -> String {
        if let app = owningApp(for: url) {
            return FileManager.default.displayName(atPath: app.path(percentEncoded: false))
                .replacingOccurrences(of: ".app", with: "")
        }
        return url.lastPathComponent
    }

    static func icon(for url: URL) -> NSImage {
        let path = (owningApp(for: url) ?? url).path(percentEncoded: false)
        if let cached = iconCache[path] { return cached }
        let image = NSWorkspace.shared.icon(forFile: path)
        iconCache[path] = image
        return image
    }

    /// The installed app whose bundle identifier matches the file name, if any.
    static func owningApp(for url: URL) -> URL? {
        var name = url.lastPathComponent
        for suffix in [".plist", ".savedState", ".binarycookies", ".ShipIt"] where name.hasSuffix(suffix) {
            name = String(name.dropLast(suffix.count))
        }
        guard name.split(separator: ".").count >= 3 else { return nil }
        if let cached = appCache[name] { return cached }
        let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: name)
        appCache[name] = app
        return app
    }

    static func reveal(_ urls: [URL]) {
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }
}

/// File or app icon at a fixed size.
struct FileIconView: View {
    let url: URL
    var size: CGFloat = 22

    var body: some View {
        Image(nsImage: FileIcons.icon(for: url))
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
    }
}
