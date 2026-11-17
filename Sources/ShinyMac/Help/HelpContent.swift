import Foundation

/// A page in the Help window: either a general guide or one module.
enum HelpTopic: Hashable, Identifiable {
    case welcome, safety, module(Module), settings, faq, support

    var id: Self { self }

    static let guides: [HelpTopic] = [.welcome, .safety]
    static let more: [HelpTopic] = [.settings, .faq, .support]

    var title: String {
        switch self {
        case .welcome: "Getting Started"
        case .safety: "Safety"
        case .module(let module): module.title
        case .settings: "Settings"
        case .faq: "Questions & Answers"
        case .support: "Support & Feedback"
        }
    }

    var symbol: String {
        switch self {
        case .welcome: "hand.wave.fill"
        case .safety: "checkmark.shield.fill"
        case .module(let module): module.symbol
        case .settings: "gearshape.fill"
        case .faq: "questionmark.bubble.fill"
        case .support: "heart.fill"
        }
    }
}

/// A titled block of prose on a help page.
struct HelpParagraph: Identifiable {
    let title: String?
    let body: String
    var id: String { (title ?? "") + body.prefix(24) }
}

extension HelpTopic {
    var paragraphs: [HelpParagraph] {
        switch self {
        case .welcome:
            [
                HelpParagraph(title: nil, body: "ShinyMac cleans up junk, removes apps completely and keeps macOS fast. Every tool lives in the sidebar, grouped by what it helps with."),
                HelpParagraph(title: "The everyday flow", body: "1. Pick a tool in the sidebar and press Scan.\n2. Look at the summary, then press Review to see every file that was found.\n3. Uncheck anything you want to keep.\n4. Press the action button (Clean, Remove, Empty…) and confirm.\n\nNothing is removed before step 4."),
                HelpParagraph(title: "Not sure where to start?", body: "Run Smart Care. It scans the most useful areas at once, shows you exactly what it would remove, and only acts after you confirm."),
                HelpParagraph(title: "Full Disk Access", body: "macOS hides some folders (Safari data, Mail downloads, the Trash) from every app until you allow it. Open System Settings › Privacy & Security › Full Disk Access and turn on ShinyMac for the most thorough scan. Everything else works without it; a small banner at the top of the window reminds you until you allow it or choose Not Now."),
                HelpParagraph(title: "Seeing what's running", body: "While a tool scans or cleans, a small spinning ring appears next to it in the sidebar. You can switch to other tools while it works."),
            ]
        case .safety:
            [
                HelpParagraph(title: "You see everything first", body: "Scans never remove anything. After a scan you always get a list of every file, and a final confirmation that says how many items go and where they go."),
                HelpParagraph(title: "Recoverable by default", body: "Apps, leftovers, duplicates and large files go to the Trash, so you can put them back. Only data that apps rebuild on their own (caches, logs, build products) is deleted right away. Turn on Settings › Move everything to the Trash to send that to the Trash too."),
                HelpParagraph(title: "A hard safety net", body: "Whatever a scanner proposes, ShinyMac refuses to touch system folders, top-level folders in your home, or anything too close to the root of the disk."),
                HelpParagraph(title: "Careful defaults", body: "Anything that could matter to you, such as cookies, installer packages, Xcode archives, cloud files you used recently or possible user data, starts unchecked."),
                HelpParagraph(title: "Permanent actions are labelled", body: "Emptying the Trash deletes for good, and say so before you confirm."),
            ]
        case .module(let module):
            [
                HelpParagraph(title: nil, body: module.tagline),
                module.helpSteps.map { HelpParagraph(title: "How to use it", body: $0) },
                module.helpNotes.map { HelpParagraph(title: "Good to know", body: $0) },
            ].compactMap { $0 }
        case .settings:
            [
                HelpParagraph(title: "Open Settings", body: "Choose ShinyMac › Settings… or press ⌘,."),
                HelpParagraph(title: "Move everything to the Trash", body: "Sends caches and other regenerable junk to the Trash instead of deleting it. Safer, but the space only comes back once you empty the Trash."),
                HelpParagraph(title: "Menu bar monitor", body: "CPU, memory, disk, battery and network in the menu bar. ShinyMac keeps running there after you close the window."),
                HelpParagraph(title: "Notifications", body: "A note when free space drops below 10% or the Trash passes 5 GB (at most once a day), and an optional Smart Care reminder."),
                HelpParagraph(title: "Updates", body: "ShinyMac checks GitHub for new versions once a day. When one is out, a banner appears at the top of the window. Only releases signed by the ShinyMac developer are installed."),
            ]
        case .faq:
            [
                HelpParagraph(title: "Is it safe to delete caches?", body: "Yes. Caches are copies apps keep to go faster. They rebuild them when needed; the first launch afterwards can be a little slower."),
                HelpParagraph(title: "I removed something by mistake", body: "Open the Trash in the Dock and choose Put Back. Items from emptying the Trash and regenerable junk can't be recovered (unless you have a Time Machine backup)."),
                HelpParagraph(title: "Why does the space not show up right away?", body: "Items moved to the Trash still take space until you empty it. macOS can also take a moment to update the free space it reports, especially with local Time Machine snapshots."),
                HelpParagraph(title: "Does Cloud Cleanup delete my files?", body: "No. It removes only the copy downloaded to this Mac. The file stays in iCloud Drive, Dropbox or your other cloud and downloads again when you open it."),
                HelpParagraph(title: "Why does it ask for my password?", body: "Some tasks touch system-wide files or settings (system launch daemons, Spotlight, DNS). macOS asks for an administrator password for those; ShinyMac never sees or stores it."),
                HelpParagraph(title: "Does ShinyMac collect data?", body: "No. There is no account, analytics or tracking. The only network requests check for app updates (GitHub, Sparkle feeds and the App Store)."),
            ]
        case .support:
            [
                HelpParagraph(title: "Found a bug or have an idea?", body: "Open an issue on GitHub. Screenshots and your macOS version help a lot."),
                HelpParagraph(title: "Free and open source", body: "ShinyMac has no ads, subscriptions or upsells, and its source code is public. If it saved you some space or time, a coffee is a lovely way to say thanks and keeps the project going."),
            ]
        }
    }
}

extension Module {
    /// Step-by-step use, shown in Help.
    var helpSteps: String? {
        switch self {
        case .smartCare:
            "Press Scan. Smart Care looks at system junk, the Trash, apps and large files at the same time. Turn essentials on or off, then press Review (or the arrow next to an essential). The review page lists every category on the left and its files on the right; uncheck anything to keep and press Run Smart Care. The Worth a look tiles open their tools, with a button at the top to come back."
        case .systemJunk, .xcode, .homebrew, .devTools, .leftovers, .extensions, .privacy:
            "Press Scan, then Review. Click a category on the left to see its files on the right and uncheck anything you want to keep. Press the action button and confirm."
        case .cloud:
            "Press Scan. ShinyMac lists files downloaded from your cloud services, grouped by service. Files you haven't opened in 6 months start checked; big files you used recently are shown but left unchecked. Press Review, check the list, then Offload and confirm."
        case .trash:
            "Press Scan to see what's in every Trash, including those on external drives. Press Review to look through the files, then Empty and confirm."
        case .duplicates:
            "Press Scan. Each group is a set of identical files. The oldest copy is marked Original and is always kept, even if you select every copy. Review, then Remove to move the extras to the Trash. Use the location button next to Scan Again to look on an external disk or in any folder."
        case .appPermissions:
            "Press View. Each permission lists the apps that hold it. Use Change in Settings to turn one off in System Settings, where macOS keeps these switches."
        case .maintenance:
            "Press View, pick the tasks you want and press Run. Tasks that need an administrator password ask for it once, together."
        case .loginItems:
            "Press View to see everything that starts with your Mac. Use the switch to stop an item, or the trash button to remove it. Broken items point to apps that no longer exist and are safe to remove."
        case .hiddenSettings:
            "Flip the switches you like. Changes apply immediately (Finder or the Dock may restart). Restore Defaults puts every option back."
        case .uninstaller:
            "Pick an app, or drop one on the window or the Dock icon. ShinyMac lists the app and every file it left around your Library. Uncheck anything to keep, then Uninstall. Reset keeps the app but wipes its settings and data. To remove several apps at once, click the circles next to them (or ⌘-click); while apps are checked, clicking a row adds or removes it, and Clear Selection goes back."
        case .updater:
            "Press Check. Apps with a newer version are listed with a button to update or open their App Store page, and What's New shows the release notes."
        case .largeFiles:
            "Press Scan, then filter by kind, last opened date and size. Check files you don't need and press Remove; they go to the Trash. The location button scans an external disk or any folder instead of your Home folder."
        case .spaceLens:
            "Press Map to chart your Home folder, or use the location button to map an external disk or any folder. Hover a slice to see its size, click to drill in, and use the list on the right to select items to move to the Trash."
        }
    }

    /// Caveats and tips, shown in Help.
    var helpNotes: String? {
        switch self {
        case .smartCare: "Smart Care only removes junk and empties the Trash. Updates, leftovers and large files are suggestions you review in their own tools."
        case .systemJunk: "Caches and logs are deleted rather than trashed because apps rebuild them. Risky items such as installer packages start unchecked."
        case .cloud: "Only the local copy is removed. Files stay in the cloud and show a download icon in Finder until you open them again."
        case .trash: "Emptying the Trash is permanent. Without Full Disk Access ShinyMac can't list your Trash; Empty with Finder lets you check it in Finder first."
        case .privacy: "Browsers are quit before their data is cleared. Cookies log you out of websites, so they start unchecked. Passwords and bookmarks are never touched."
        case .leftovers: "Files from a vendor whose apps you still use are left alone, and everything goes to the Trash."
        case .xcode: "Build data and caches are deleted outright since Xcode rebuilds them. Archives start unchecked and go to the Trash."
        case .homebrew: "Old versions and unused dependencies are removed by brew itself, so Homebrew stays consistent. Pinned formulae are never touched. Unused dependencies start unchecked."
        case .devTools: "Docker items are removed with Docker's own prune commands. Project folders are only suggested when the project hasn't changed in a while."
        case .uninstaller: "Running apps are quit first. Everything goes to the Trash, so you can still put an app back."
        default: nil
        }
    }
}
