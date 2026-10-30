import SwiftUI

/// Groups shown in the sidebar, in display order.
enum SidebarSection: String, CaseIterable, Identifiable {
    case home, cleanup, protection, performance, applications, files

    var id: Self { self }

    var title: String? {
        switch self {
        case .home: nil
        case .cleanup: "Cleanup"
        case .protection: "Protection"
        case .performance: "Performance"
        case .applications: "Applications"
        case .files: "Files"
        }
    }

    var modules: [Module] { Module.allCases.filter { $0.section == self } }
}

/// Every feature screen in the app.
enum Module: String, CaseIterable, Identifiable, Hashable {
    case smartCare
    case systemJunk, trash
    case privacy
    case maintenance, loginItems
    case uninstaller, updater, leftovers
    case largeFiles, spaceLens, shredder

    var id: Self { self }

    var section: SidebarSection {
        switch self {
        case .smartCare: .home
        case .systemJunk, .trash: .cleanup
        case .privacy: .protection
        case .maintenance, .loginItems: .performance
        case .uninstaller, .updater, .leftovers: .applications
        case .largeFiles, .spaceLens, .shredder: .files
        }
    }

    var title: String {
        switch self {
        case .smartCare: "Smart Care"
        case .systemJunk: "System Junk"
        case .trash: "Trash Bins"
        case .privacy: "Privacy"
        case .maintenance: "Maintenance"
        case .loginItems: "Login Items"
        case .uninstaller: "Uninstaller"
        case .updater: "Updater"
        case .leftovers: "Leftovers"
        case .largeFiles: "Large & Old Files"
        case .spaceLens: "Space Lens"
        case .shredder: "Shredder"
        }
    }

    var symbol: String {
        switch self {
        case .smartCare: "sparkles"
        case .systemJunk: "bubbles.and.sparkles.fill"
        case .trash: "trash.fill"
        case .privacy: "hand.raised.fill"
        case .maintenance: "wrench.and.screwdriver.fill"
        case .loginItems: "power.circle.fill"
        case .uninstaller: "shippingbox.fill"
        case .updater: "arrow.down.app.fill"
        case .leftovers: "questionmark.folder.fill"
        case .largeFiles: "doc.text.magnifyingglass"
        case .spaceLens: "chart.pie.fill"
        case .shredder: "flame.fill"
        }
    }

    /// One line pitch shown under the title on the module's start screen.
    var tagline: String {
        switch self {
        case .smartCare: "One scan to clean, speed up and tidy your Mac."
        case .systemJunk: "Clear caches, logs and developer clutter that pile up over time."
        case .trash: "Empty every Trash on your Mac, all at once."
        case .privacy: "Wipe browsing history, cookies and recent items."
        case .maintenance: "Run tune-up tasks that keep macOS fast and healthy."
        case .loginItems: "Control what launches quietly in the background."
        case .uninstaller: "Remove apps completely, along with every file they left behind."
        case .updater: "Find apps with new versions available."
        case .leftovers: "Find files left behind by apps you already deleted."
        case .largeFiles: "Spot big files and things you haven't opened in ages."
        case .spaceLens: "See what takes up space, at a glance."
        case .shredder: "Delete files right away, skipping the Trash."
        }
    }
}
