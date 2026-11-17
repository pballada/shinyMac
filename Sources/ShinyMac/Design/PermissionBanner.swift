import ShinyCore
import SwiftUI

/// Glass banner explaining a missing permission, with a deep link to System Settings.
struct PermissionBanner<Actions: View>: View {
    let title: String
    let message: String
    var symbol = "lock.shield.fill"
    var tint: Color = Color(hex: 0xFFD479)
    @ViewBuilder var actions: Actions

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 40, height: 40)
                .background(tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            actions
        }
        .padding(12)
        .background(.black.opacity(0.15), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shinyGlass(in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .frame(maxWidth: 720)
    }
}

/// Opens the Full Disk Access pane in System Settings.
struct OpenFullDiskAccessButton: View {
    var body: some View {
        Button("Open Settings") { NSWorkspace.shared.open(Permissions.fullDiskAccessSettings) }
            .buttonStyle(.glassPill)
    }
}

/// Small, dismissible tip at the top of the main window while Full Disk Access is off. ShinyMac works without it,
/// so it never blocks anything; Settings keeps a permanent link for later.
struct FullDiskAccessBanner: View {
    @AppStorage(Preferences.Key.fullDiskAccessBannerDismissed) private var isDismissed = false
    @State private var hasAccess = Permissions.hasFullDiskAccess

    var body: some View {
        Group {
            if !hasAccess && !isDismissed {
                HStack(spacing: 12) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color(hex: 0xFFD479))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Full Disk Access is off").font(.system(size: 12.5, weight: .semibold))
                        Text("Everything works, but Safari, Mail, the Trash and some caches stay hidden. Allow it for a complete scan.")
                            .font(.system(size: 11.5))
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(1)
                    }
                    .layoutPriority(1)
                    Spacer(minLength: 8)
                    HStack(spacing: 8) {
                        Button("Not Now") { withAnimation(.smooth) { isDismissed = true } }
                            .buttonStyle(.glassPill)
                        OpenFullDiskAccessButton()
                    }
                    .controlSize(.small)
                    .fixedSize()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.black.opacity(0.15), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shinyGlass(in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            withAnimation(.smooth) { hasAccess = Permissions.hasFullDiskAccess }
        }
    }
}
