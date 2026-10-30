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

        Settings {
            SettingsView()
        }

        MenuBarExtra("ShinyMac", systemImage: "sparkles", isInserted: $showMenuBarMonitor) {
            MenuBarMonitorView()
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Needed when launched as a bare executable (`swift run`) rather than an .app bundle.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
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
