import AppKit
import SwiftUI

@main
struct ShinyMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var state = AppState()

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
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Needed when launched as a bare executable (`swift run`) rather than an .app bundle.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
