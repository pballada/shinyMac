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
