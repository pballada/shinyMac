import SwiftUI

extension Module {
    /// Highlights shown on each module's start screen.
    var features: [Feature] {
        switch self {
        case .smartCare:
            [
                Feature(symbol: "bubbles.and.sparkles", title: "Cleanup", detail: "Caches, logs and Trash you don't need."),
                Feature(symbol: "bolt.fill", title: "Speed", detail: "Tune-up tasks that keep macOS snappy."),
                Feature(symbol: "square.stack.3d.up.fill", title: "Clutter", detail: "Large files and leftovers worth a look."),
            ]
        case .systemJunk:
            [
                Feature(symbol: "archivebox.fill", title: "Caches & logs", detail: "Temporary data apps and macOS rebuild on demand."),
                Feature(symbol: "hammer.fill", title: "Developer junk", detail: "Xcode DerivedData, simulators, npm, Homebrew and more."),
                Feature(symbol: "photo.stack.fill", title: "Photo & Mail junk", detail: "Photos analysis caches and copies of attachments you already opened."),
            ]
        case .cloud:
            [
                Feature(symbol: "icloud.fill", title: "Every cloud", detail: "iCloud Drive, Dropbox, Google Drive, OneDrive and Box."),
                Feature(symbol: "arrow.down.to.line.compact", title: "Downloads only", detail: "Files stay in the cloud and download again when you open them."),
            ]
        case .trash:
            [
                Feature(symbol: "trash.fill", title: "Every Trash", detail: "Your Trash and the ones on external drives."),
                Feature(symbol: "eye.fill", title: "Look before you empty", detail: "Review what's inside before it's gone."),
            ]
        case .privacy:
            [
                Feature(symbol: "safari.fill", title: "Browsers", detail: "History, cookies and caches for Safari, Chrome, Firefox, Edge, Brave and Arc."),
                Feature(symbol: "clock.arrow.circlepath", title: "Recent items", detail: "Lists of documents and apps you opened recently."),
            ]
        case .appPermissions:
            [
                Feature(symbol: "camera.fill", title: "Camera, mic & screen", detail: "Every app allowed to see or hear what you do."),
                Feature(symbol: "accessibility", title: "Powerful access", detail: "Accessibility, Input Monitoring, Full Disk Access and Automation."),
                Feature(symbol: "app.badge.checkmark", title: "Stale grants", detail: "Permissions still held by apps you've deleted."),
            ]
        case .maintenance:
            [
                Feature(symbol: "memorychip.fill", title: "Free up RAM", detail: "Release inactive memory in one click."),
                Feature(symbol: "network", title: "Flush DNS", detail: "Fix sites that refuse to load."),
                Feature(symbol: "magnifyingglass", title: "Reindex Spotlight", detail: "Get search results back on track."),
            ]
        case .loginItems:
            [
                Feature(symbol: "power", title: "Launch agents", detail: "See everything that starts with your Mac."),
                Feature(symbol: "bandage.fill", title: "Broken items", detail: "Find agents pointing to apps that no longer exist."),
            ]
        case .uninstaller:
            [
                Feature(symbol: "trash.slash.fill", title: "Complete removal", detail: "Apps plus their support files, caches and preferences."),
                Feature(symbol: "arrow.counterclockwise", title: "Reset apps", detail: "Keep the app, wipe its settings to start fresh."),
                Feature(symbol: "clock.fill", title: "Forgotten apps", detail: "Apps you haven't opened in months, and Intel-only apps that need Rosetta."),
            ]
        case .updater:
            [
                Feature(symbol: "arrow.down.circle.fill", title: "Version check", detail: "Compares installed versions with each app's update feed."),
                Feature(symbol: "bag.fill", title: "App Store", detail: "Jump straight to pending App Store updates."),
            ]
        case .leftovers:
            [
                Feature(symbol: "questionmark.folder.fill", title: "Orphaned files", detail: "Support files from apps that are no longer installed."),
                Feature(symbol: "checkmark.shield.fill", title: "Careful matching", detail: "Anything from a vendor you still use is left alone."),
            ]
        case .extensions:
            [
                Feature(symbol: "puzzlepiece.extension.fill", title: "Everything that plugs in", detail: "Quick Look, Spotlight, preference panes, screen savers, internet plug-ins."),
                Feature(symbol: "trash.fill", title: "Remove leftovers", detail: "Add-ons often outlive the apps that installed them."),
            ]
        case .largeFiles:
            [
                Feature(symbol: "film.fill", title: "By kind", detail: "Videos, archives, disk images and more."),
                Feature(symbol: "calendar", title: "By age", detail: "Files you haven't opened in a long time."),
            ]
        case .duplicates:
            [
                Feature(symbol: "checkmark.seal.fill", title: "Byte-for-byte", detail: "Copies are confirmed with a full SHA-256, not just names or sizes."),
                Feature(symbol: "star.fill", title: "Keeps the original", detail: "The oldest copy stays; extras go to the Trash."),
            ]
        case .shredder:
            [
                Feature(symbol: "hand.draw.fill", title: "Drag and drop", detail: "Drop files or folders to queue them."),
                Feature(symbol: "flame.fill", title: "No Trash detour", detail: "Gone immediately, including stubborn locked items."),
            ]
        case .xcode:
            [
                Feature(symbol: "square.stack.3d.down.right.fill", title: "Simulator runtimes", detail: "Old iOS and visionOS images, several GB each."),
                Feature(symbol: "ipad.and.iphone", title: "Simulators", detail: "Devices left behind by runtimes you removed."),
                Feature(symbol: "hammer.fill", title: "Builds & archives", detail: "DerivedData per project, device support and old archives."),
            ]
        case .spaceLens:
            [
                Feature(symbol: "chart.pie.fill", title: "Visual map", detail: "An interactive sunburst of your folders."),
                Feature(symbol: "cursorarrow.click.2", title: "Drill down", detail: "Click any slice to explore deeper."),
            ]
        }
    }
}
