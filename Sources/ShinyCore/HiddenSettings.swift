import Foundation

/// macOS options that exist as `defaults` keys but have no switch in System Settings.
/// Values are read and written with CFPreferences; choosing the system default removes the key.
public enum HiddenSettings {
    public enum Category: String, CaseIterable, Identifiable, Sendable {
        case finder = "Finder"
        case dock = "Dock"
        case screenshots = "Screenshots"
        case system = "System"
        public var id: Self { self }

        public var symbol: String {
            switch self {
            case .finder: "folder.fill"
            case .dock: "dock.rectangle"
            case .screenshots: "camera.viewfinder"
            case .system: "gearshape.fill"
            }
        }
    }

    /// A stored preference value.
    public enum Value: Hashable, Sendable {
        case bool(Bool)
        case double(Double)
        case string(String)

        var propertyList: CFPropertyList {
            switch self {
            case .bool(let value): value as CFBoolean
            case .double(let value): value as CFNumber
            case .string(let value): value as CFString
            }
        }
    }

    public struct Option: Hashable, Sendable, Identifiable {
        public let title: String
        /// nil means "remove the key", i.e. the macOS default.
        public let value: Value?
        public var id: String { title }
    }

    public enum Kind: Hashable, Sendable {
        /// On when the stored bool differs from `inverted`. `systemDefault` is the stored bool's meaning when the key is missing.
        case toggle(systemDefault: Bool, inverted: Bool = false)
        /// One of several values; the first option is the system default.
        case choice([Option])
    }

    /// The process that has to restart before a change shows up.
    public enum Restart: String, Sendable {
        case finder = "Finder"
        case dock = "Dock"
        case screenshots = "SystemUIServer"
    }

    public struct Tweak: Identifiable, Hashable, Sendable {
        public let id: String
        public let category: Category
        public let title: String
        public let detail: String
        public let domain: String
        public let key: String
        public let kind: Kind
        public let restart: Restart?
    }

    // MARK: Catalog

    public static let tweaks: [Tweak] = [
        Tweak(id: "finderHiddenFiles", category: .finder, title: "Show hidden files",
              detail: "Shows dot files and system folders. ⌘⇧. toggles them in any Finder window.",
              domain: "com.apple.finder", key: "AppleShowAllFiles", kind: .toggle(systemDefault: false), restart: .finder),
        Tweak(id: "finderExtensions", category: .finder, title: "Show all filename extensions",
              detail: "Always shows .pdf, .jpg and the rest.",
              domain: global, key: "AppleShowAllExtensions", kind: .toggle(systemDefault: false), restart: .finder),
        Tweak(id: "finderPathBar", category: .finder, title: "Show path bar",
              detail: "The folder trail at the bottom of each window.",
              domain: "com.apple.finder", key: "ShowPathbar", kind: .toggle(systemDefault: false), restart: .finder),
        Tweak(id: "finderStatusBar", category: .finder, title: "Show status bar",
              detail: "Item count and free space at the bottom of each window.",
              domain: "com.apple.finder", key: "ShowStatusBar", kind: .toggle(systemDefault: false), restart: .finder),
        Tweak(id: "finderPosixTitle", category: .finder, title: "Full path in window title",
              detail: "Shows /Users/you/Documents instead of Documents.",
              domain: "com.apple.finder", key: "_FXShowPosixPathInTitle", kind: .toggle(systemDefault: false), restart: .finder),
        Tweak(id: "finderFoldersFirst", category: .finder, title: "Keep folders on top",
              detail: "Folders sort before files when sorting by name.",
              domain: "com.apple.finder", key: "_FXSortFoldersFirst", kind: .toggle(systemDefault: false), restart: .finder),
        Tweak(id: "finderExtensionWarning", category: .finder, title: "Warn before changing an extension",
              detail: "Turn off to rename file.txt to file.md without a dialog.",
              domain: "com.apple.finder", key: "FXEnableExtensionChangeWarning", kind: .toggle(systemDefault: true), restart: .finder),
        Tweak(id: "finderQuit", category: .finder, title: "Allow quitting Finder",
              detail: "Adds Quit Finder (⌘Q) to the Finder menu.",
              domain: "com.apple.finder", key: "QuitMenuItem", kind: .toggle(systemDefault: false), restart: .finder),
        Tweak(id: "dsStoreNetwork", category: .finder, title: "Don't write .DS_Store on network drives",
              detail: "Keeps shared folders free of Finder's hidden layout files.",
              domain: "com.apple.desktopservices", key: "DSDontWriteNetworkStores", kind: .toggle(systemDefault: false), restart: .finder),
        Tweak(id: "dsStoreUSB", category: .finder, title: "Don't write .DS_Store on USB drives",
              detail: "Keeps thumb drives and cards clean for other computers.",
              domain: "com.apple.desktopservices", key: "DSDontWriteUSBStores", kind: .toggle(systemDefault: false), restart: .finder),

        Tweak(id: "dockAutohideDelay", category: .dock, title: "Auto-hide delay",
              detail: "How long the pointer rests at the edge before a hidden Dock appears.",
              domain: "com.apple.dock", key: "autohide-delay",
              kind: .choice([Option(title: "Default", value: nil), Option(title: "None", value: .double(0)),
                             Option(title: "0.5 s", value: .double(0.5)), Option(title: "1 s", value: .double(1))]),
              restart: .dock),
        Tweak(id: "dockAutohideSpeed", category: .dock, title: "Show and hide animation",
              detail: "Speed of the Dock sliding in and out.",
              domain: "com.apple.dock", key: "autohide-time-modifier",
              kind: .choice([Option(title: "Default", value: nil), Option(title: "Instant", value: .double(0)),
                             Option(title: "Fast", value: .double(0.25)), Option(title: "Slow", value: .double(1))]),
              restart: .dock),
        Tweak(id: "dockHiddenApps", category: .dock, title: "Dim hidden apps",
              detail: "Apps hidden with ⌘H show a translucent icon.",
              domain: "com.apple.dock", key: "showhidden", kind: .toggle(systemDefault: false), restart: .dock),
        Tweak(id: "dockStaticOnly", category: .dock, title: "Only show open apps",
              detail: "Hides pinned apps that aren't running.",
              domain: "com.apple.dock", key: "static-only", kind: .toggle(systemDefault: false), restart: .dock),
        Tweak(id: "dockScrollToOpen", category: .dock, title: "Scroll on an icon to show its windows",
              detail: "Scrolling up on a Dock icon opens that app's windows in App Exposé.",
              domain: "com.apple.dock", key: "scroll-to-open", kind: .toggle(systemDefault: false), restart: .dock),
        Tweak(id: "spacesReorder", category: .dock, title: "Rearrange Spaces by recent use",
              detail: "Turn off to keep desktops in the order you set them.",
              domain: "com.apple.dock", key: "mru-spaces", kind: .toggle(systemDefault: true), restart: .dock),

        Tweak(id: "screenshotFormat", category: .screenshots, title: "File format",
              detail: "JPEG and HEIC files are much smaller than PNG.",
              domain: "com.apple.screencapture", key: "type",
              kind: .choice([Option(title: "PNG", value: nil), Option(title: "JPEG", value: .string("jpg")),
                             Option(title: "HEIC", value: .string("heic")), Option(title: "PDF", value: .string("pdf")),
                             Option(title: "TIFF", value: .string("tiff"))]),
              restart: .screenshots),
        Tweak(id: "screenshotShadow", category: .screenshots, title: "Window shadow",
              detail: "Window captures include the drop shadow around the window.",
              domain: "com.apple.screencapture", key: "disable-shadow", kind: .toggle(systemDefault: false, inverted: true),
              restart: .screenshots),
        Tweak(id: "screenshotDate", category: .screenshots, title: "Date and time in file names",
              detail: "Turn off for names like “Screenshot.png”, “Screenshot 1.png”.",
              domain: "com.apple.screencapture", key: "include-date", kind: .toggle(systemDefault: true), restart: .screenshots),
        Tweak(id: "screenshotThumbnail", category: .screenshots, title: "Floating thumbnail",
              detail: "The preview in the corner. Turning it off saves files right away.",
              domain: "com.apple.screencapture", key: "show-thumbnail", kind: .toggle(systemDefault: true), restart: .screenshots),

        Tweak(id: "expandSavePanel", category: .system, title: "Expand save dialogs",
              detail: "Save dialogs open with the full folder browser.",
              domain: global, key: "NSNavPanelExpandedStateForSaveMode", kind: .toggle(systemDefault: false), restart: nil),
        Tweak(id: "expandPrintPanel", category: .system, title: "Expand print dialogs",
              detail: "Print dialogs open with all options showing.",
              domain: global, key: "PMPrintingExpandedStateForPrint", kind: .toggle(systemDefault: false), restart: nil),
        Tweak(id: "saveToICloud", category: .system, title: "Save new documents to iCloud",
              detail: "Turn off to default to your Mac instead of iCloud Drive.",
              domain: global, key: "NSDocumentSaveNewDocumentsToCloud", kind: .toggle(systemDefault: true), restart: nil),
        Tweak(id: "pressAndHold", category: .system, title: "Press and hold for accents",
              detail: "Turn off to make held keys repeat instead, handy for coding and games.",
              domain: global, key: "ApplePressAndHoldEnabled", kind: .toggle(systemDefault: true), restart: nil),
        Tweak(id: "windowAnimations", category: .system, title: "Window opening animations",
              detail: "Turn off for snappier new windows and sheets.",
              domain: global, key: "NSAutomaticWindowAnimationsEnabled", kind: .toggle(systemDefault: true), restart: nil),
        Tweak(id: "textEditPlain", category: .system, title: "TextEdit starts in plain text",
              detail: "New TextEdit documents are .txt instead of rich text.",
              domain: "com.apple.TextEdit", key: "RichText", kind: .toggle(systemDefault: true, inverted: true), restart: nil),
    ]

    /// The domain shared by every app (`defaults write -g`).
    public static let global = "NSGlobalDomain"

    // MARK: Reading and writing

    static func cfDomain(_ domain: String) -> CFString {
        domain == global ? kCFPreferencesAnyApplication : domain as CFString
    }

    static func stored(_ tweak: Tweak) -> Value? {
        guard let raw = CFPreferencesCopyAppValue(tweak.key as CFString, cfDomain(tweak.domain)) else { return nil }
        if CFGetTypeID(raw) == CFBooleanGetTypeID() { return .bool(raw as! Bool) }
        if let string = raw as? String { return .string(string) }
        if let number = raw as? NSNumber {
            // `defaults write … -int 1` and `-bool true` both read back as numbers for toggles.
            if case .toggle = tweak.kind { return .bool(number.boolValue) }
            return .double(number.doubleValue)
        }
        return nil
    }

    /// Whether a toggle is currently on, falling back to the macOS default when the key isn't set.
    public static func isOn(_ tweak: Tweak) -> Bool {
        guard case .toggle(let systemDefault, let inverted) = tweak.kind else { return false }
        guard case .bool(let value)? = stored(tweak) else { return systemDefault != inverted }
        return value != inverted
    }

    /// The selected option of a choice; unknown stored values count as the default.
    public static func selectedOption(_ tweak: Tweak) -> Option? {
        guard case .choice(let options) = tweak.kind else { return nil }
        let value = stored(tweak)
        return options.first { $0.value == value } ?? options.first
    }

    public static func setToggle(_ tweak: Tweak, on: Bool) {
        guard case .toggle(let systemDefault, let inverted) = tweak.kind else { return }
        let value = on != inverted
        // Matching the system default removes the key so macOS behaves exactly as it shipped.
        write(tweak, value == systemDefault ? nil : .bool(value))
    }

    public static func select(_ tweak: Tweak, option: Option) {
        write(tweak, option.value)
    }

    /// True when the tweak differs from what macOS does out of the box.
    public static func isCustomized(_ tweak: Tweak) -> Bool {
        switch tweak.kind {
        case .toggle(let systemDefault, let inverted): isOn(tweak) != (systemDefault != inverted)
        case .choice(let options): selectedOption(tweak) != options.first
        }
    }

    public static func reset(_ tweak: Tweak) {
        write(tweak, nil)
    }

    static func write(_ tweak: Tweak, _ value: Value?) {
        let domain = cfDomain(tweak.domain)
        CFPreferencesSetAppValue(tweak.key as CFString, value?.propertyList, domain)
        CFPreferencesAppSynchronize(domain)
    }

    /// Restarts Finder, the Dock or SystemUIServer so they pick up new values. macOS relaunches them right away.
    public static func restart(_ target: Restart) {
        _ = try? Shell.run("/usr/bin/killall", [target.rawValue])
    }
}
