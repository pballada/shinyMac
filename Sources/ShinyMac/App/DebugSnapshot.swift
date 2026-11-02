#if DEBUG
import AppKit

/// Debug-only hook used to render screenshots without screen-recording permission:
///   SHINYMAC_MODULE=systemJunk SHINYMAC_ACTION=scan SHINYMAC_SNAPSHOT=/tmp/shot.png ShinyMac
/// With SHINYMAC_SNAPSHOT_EXTERNAL=1 it prints `SHINYMAC_WINDOW_ID <n>` instead, for `screencapture -o -l <n>`.
/// Actions are read-only (`scan`, `review`); nothing is ever removed.
enum DebugSnapshot {
    static func scheduleIfRequested(state: AppState) {
        let env = ProcessInfo.processInfo.environment
        guard env.keys.contains(where: { $0.hasPrefix("SHINYMAC_") }) else { return }
        // Screenshots skip the welcome screen unless SHINYMAC_ONBOARDING asks for it.
        UserDefaults.standard.set(env["SHINYMAC_ONBOARDING"] == nil, forKey: Preferences.Key.hasOnboarded)
        if let raw = env["SHINYMAC_MODULE"], let module = Module(rawValue: raw) {
            state.selection = module
        }
        if let action = env["SHINYMAC_ACTION"] {
            state.performDebugAction(action)
        }
        guard let path = env["SHINYMAC_SNAPSHOT"] else { return }
        let delay = Double(env["SHINYMAC_SNAPSHOT_DELAY"] ?? "") ?? 2.5
        Task {
            // Occluded windows aren't rendered, so keep ours on top while the snapshot is pending.
            try? await Task.sleep(for: .milliseconds(100))
            NSApp.activate(ignoringOtherApps: true)
            for window in NSApp.windows where window.isVisible {
                window.level = .floating
                window.makeKeyAndOrderFront(nil)
            }
            try? await Task.sleep(for: .seconds(delay))
            // Long scans give other apps time to take focus, and a background window can render blank. Bring it back.
            NSApp.activate(ignoringOtherApps: true)
            NSApp.windows.first(where: \.isVisible)?.makeKeyAndOrderFront(nil)
            try? await Task.sleep(for: .seconds(1))
            if let width = Double(env["SHINYMAC_WIDTH"] ?? ""), let window = NSApp.windows.first(where: \.isVisible) {
                // Layout check: shrink the window, then report the width the content actually needs.
                window.setContentSize(NSSize(width: width, height: window.frame.height))
                try? await Task.sleep(for: .seconds(1))
                print("SHINYMAC_WINDOW \(Int(window.frame.width))x\(Int(window.frame.height))")
            }
            if env["SHINYMAC_SNAPSHOT_EXTERNAL"] != nil, let window = NSApp.windows.first(where: \.isVisible) {
                // Idle SwiftUI layers can come out blank with cacheDisplay; let `screencapture -l` grab the window instead.
                print("SHINYMAC_WINDOW_ID \(window.windowNumber)")
                fflush(stdout)
                try? await Task.sleep(for: .seconds(4))
                NSApp.terminate(nil)
                return
            }
            guard let view = NSApp.windows.first(where: \.isVisible)?.contentView?.superview,
                  let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
            view.cacheDisplay(in: view.bounds, to: rep)
            try? rep.representation(using: .png, properties: [:])?.write(to: URL(filePath: path))
            if env["SHINYMAC_SNAPSHOT_QUIT"] != nil { NSApp.terminate(nil) }
        }
    }
}
#endif
