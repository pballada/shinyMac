import AppKit
import SwiftUI

@main
struct ShinyMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var state = AppState()
    @AppStorage(Preferences.Key.showMenuBarMonitor) private var showMenuBarMonitor = true

    var body: some Scene {
        WindowGroup("ShinyMac", id: "main") {
            RootView()
                .environment(state)
                .frame(minWidth: 980, minHeight: 660)
                #if DEBUG
                .onAppear { DebugSnapshot.scheduleIfRequested(state: state) }
                #endif
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1120, height: 740)
        .windowBackgroundDragBehavior(.enabled)
        .commands { AppCommands() }

        Settings {
            SettingsView()
        }

        Window("About ShinyMac", id: "about") {
            AboutView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)

        #if DEBUG
        // Screenshot hook for the menu bar panel (SHINYMAC_WINDOW=menubar).
        Window("Menu Bar Preview", id: "menubar") {
            MenuBarMonitorView()
        }
        .windowResizability(.contentSize)
        #endif

        Window("ShinyMac Help", id: "help") {
            HelpView()
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 920, height: 640)

        MenuBarExtra("ShinyMac", systemImage: "sparkles", isInserted: $showMenuBarMonitor) {
            MenuBarMonitorView()
        }
        .menuBarExtraStyle(.window)
    }
}

/// App menu additions: a custom About window, update check, and a real Help menu.
struct AppCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About ShinyMac") { openWindow(id: "about") }
            Button("Check for Updates…") {
                Task { await SelfUpdateModel.shared.check() }
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
        }
        CommandGroup(replacing: .help) {
            Button("ShinyMac Help") { openWindow(id: "help") }
                .keyboardShortcut("?", modifiers: .command)
            Divider()
            Button("Report an Issue…") { NSWorkspace.shared.open(Support.issuesURL) }
            Button("ShinyMac on GitHub") { NSWorkspace.shared.open(Support.repoURL) }
            Divider()
            Button("Buy Me a Coffee…") { NSWorkspace.shared.open(Support.coffeeURL) }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Needed when launched as a bare executable (`swift run`) rather than an .app bundle.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
        SpaceAlertMonitor.start()
        SelfUpdateModel.shared.startAutomaticChecks()
    }

    /// Apps dragged onto the Dock icon.
    func application(_ application: NSApplication, open urls: [URL]) {
        NotificationCenter.default.post(name: .shinyMacOpenApps, object: urls)
    }

    /// Keep running for the menu bar monitor when it's enabled.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        !UserDefaults.standard.bool(forKey: Preferences.Key.showMenuBarMonitor, default: true)
    }
}
