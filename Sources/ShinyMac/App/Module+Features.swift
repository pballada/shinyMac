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
                Feature(symbol: "paperclip", title: "Mail downloads", detail: "Local copies of attachments you already opened."),
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
                Feature(symbol: "clock.fill", title: "Unused apps", detail: "Spot apps you haven't opened in months."),
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
        case .largeFiles:
            [
                Feature(symbol: "film.fill", title: "By kind", detail: "Videos, archives, disk images and more."),
                Feature(symbol: "calendar", title: "By age", detail: "Files you haven't opened in a long time."),
            ]
        case .shredder:
            [
                Feature(symbol: "hand.draw.fill", title: "Drag and drop", detail: "Drop files or folders to queue them."),
                Feature(symbol: "flame.fill", title: "No Trash detour", detail: "Gone immediately, including stubborn locked items."),
            ]
        case .spaceLens:
            [
                Feature(symbol: "chart.pie.fill", title: "Visual map", detail: "An interactive sunburst of your folders."),
                Feature(symbol: "cursorarrow.click.2", title: "Drill down", detail: "Click any slice to explore deeper."),
            ]
        }
    }
}
