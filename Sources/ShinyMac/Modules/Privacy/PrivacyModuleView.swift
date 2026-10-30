import AppKit
import ShinyCore
import SwiftUI

/// Privacy: the shared cleanup flow, plus a nudge to grant Full Disk Access so Safari can be included.
struct PrivacyModuleView: View {
    @Bindable var model: CleanupModel
    @State private var hasFullDiskAccess = Permissions.hasFullDiskAccess

    var body: some View {
        CleanupModuleView(model: model)
            .overlay(alignment: .top) {
                if !hasFullDiskAccess, model.phase == .idle || model.phase == .results {
                    PermissionBanner(
                        title: "Safari needs Full Disk Access",
                        message: "macOS protects Safari's history and cookies. Allow access to clean them too."
                    ) {
                        OpenFullDiskAccessButton()
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 52)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                hasFullDiskAccess = Permissions.hasFullDiskAccess
            }
    }

    /// Quits browsers whose data is about to be removed, so they don't keep stale files open.
    static func quitApps(_ bundleIDs: Set<String>) async {
        let running = bundleIDs.flatMap { NSRunningApplication.runningApplications(withBundleIdentifier: $0) }
        guard !running.isEmpty else { return }
        running.forEach { $0.terminate() }
        for _ in 0..<40 where running.contains(where: { !$0.isTerminated }) {
            try? await Task.sleep(for: .milliseconds(100))
        }
    }
}
