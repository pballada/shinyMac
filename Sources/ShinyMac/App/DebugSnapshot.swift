#if DEBUG
import AppKit

/// Debug-only hook used to render screenshots without screen-recording permission:
///   SHINYMAC_MODULE=systemJunk SHINYMAC_ACTION=scan SHINYMAC_SNAPSHOT=/tmp/shot.png ShinyMac
/// Actions are read-only (`scan`, `review`); nothing is ever removed.
enum DebugSnapshot {
    static func scheduleIfRequested(state: AppState) {
        let env = ProcessInfo.processInfo.environment
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
            guard let view = NSApp.windows.first(where: \.isVisible)?.contentView?.superview,
                  let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
            view.cacheDisplay(in: view.bounds, to: rep)
            try? rep.representation(using: .png, properties: [:])?.write(to: URL(filePath: path))
            if env["SHINYMAC_SNAPSHOT_QUIT"] != nil { NSApp.terminate(nil) }
        }
    }
}
#endif
