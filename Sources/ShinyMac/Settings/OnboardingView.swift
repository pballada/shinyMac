import AppKit
import ShinyCore
import SwiftUI

/// First-launch welcome that explains what ShinyMac does and asks for Full Disk Access.
struct OnboardingView: View {
    let onFinish: () -> Void
    @State private var hasFullDiskAccess = Permissions.hasFullDiskAccess
    @State private var appeared = false

    private let theme = SidebarSection.home.theme

    var body: some View {
        ZStack {
            VStack(spacing: 22) {
                HeroIllustration(symbol: "sparkles", theme: theme, size: 190)
                VStack(spacing: 8) {
                    Text("Welcome to ShinyMac").font(.display(32))
                    Text("Clean up junk, uninstall apps completely and keep your Mac fast. Nothing is removed without you seeing it first.")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 440)
                }

                HStack(spacing: 14) {
                    Image(systemName: hasFullDiskAccess ? "checkmark.shield.fill" : "lock.shield.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(hasFullDiskAccess ? Color(hex: 0x4BE3A8) : Color(hex: 0xFFD479))
                        .frame(width: 44, height: 44)
                        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(hasFullDiskAccess ? "Full Disk Access granted" : "Allow Full Disk Access")
                            .font(.system(size: 14, weight: .semibold))
                        Text(hasFullDiskAccess
                             ? "ShinyMac can see everything it needs for a thorough scan."
                             : "Needed for Safari, Mail, the Trash and protected caches. Add ShinyMac in Privacy & Security, then come back.")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.65))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    if !hasFullDiskAccess {
                        OpenFullDiskAccessButton()
                    }
                }
                .padding(14)
                .background(.black.opacity(0.15), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shinyGlass(in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .frame(maxWidth: 520)

                Button(hasFullDiskAccess ? "Get Started" : "Continue Without It", action: onFinish)
                    .buttonStyle(.glassPill(prominent: hasFullDiskAccess, tint: theme.accent))
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(36)
            .background(
                LinearGradient(colors: [theme.deep, Color(hex: 0x2A0F55)], startPoint: .top, endPoint: .bottom)
                    .opacity(0.92),
                in: RoundedRectangle(cornerRadius: 30, style: .continuous)
            )
            .shinyGlass(in: RoundedRectangle(cornerRadius: 30, style: .continuous))
            .shadow(color: .black.opacity(0.5), radius: 40, y: 20)
            .scaleEffect(appeared ? 1 : 0.94)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear { withAnimation(.spring(duration: 0.5)) { appeared = true } }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            withAnimation(.smooth) { hasFullDiskAccess = Permissions.hasFullDiskAccess }
        }
    }
}
