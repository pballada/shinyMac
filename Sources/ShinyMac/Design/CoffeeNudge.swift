import AppKit
import SwiftUI

/// Where tips go. Also linked from About, Help and the GitHub sponsor button.
enum Support {
    static let coffeeURL = URL(string: "https://buymeacoffee.com/pballada")!
    static let repoURL = URL(string: "https://github.com/pballada/shinyMac")!
    static let issuesURL = URL(string: "https://github.com/pballada/shinyMac/issues")!
}

/// A quiet "buy me a coffee" line for the end of a successful clean. Dismissing it, or tipping, hides it for a while.
struct CoffeeNudge: View {
    var tint: Color = .white
    @AppStorage(Preferences.Key.coffeeSnoozedUntil) private var snoozedUntil: Double = 0
    @State private var isHovering = false

    var body: some View {
        if Date.now.timeIntervalSince1970 >= snoozedUntil {
            HStack(spacing: 10) {
                Text("☕").font(.system(size: 15))
                Text("ShinyMac is free and made by one person. If it helped, a coffee keeps it going.")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
                Button("Buy me a coffee") {
                    NSWorkspace.shared.open(Support.coffeeURL)
                    snooze(days: 120)
                }
                .buttonStyle(.glassPill(prominent: true, tint: tint))
                .controlSize(.small)
                .fixedSize()
                Button {
                    withAnimation(.smooth) { snooze(days: 30) }
                } label: {
                    Image(systemName: "xmark").font(.system(size: 10, weight: .bold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(isHovering ? 0.8 : 0.4))
                .help("Hide for a while")
            }
            .padding(.leading, 14)
            .padding(.trailing, 12)
            .padding(.vertical, 8)
            .background(.white.opacity(0.06), in: Capsule())
            .frame(maxWidth: 560)
            .onHover { isHovering = $0 }
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
        }
    }

    private func snooze(days: Double) {
        snoozedUntil = Date.now.addingTimeInterval(days * 86_400).timeIntervalSince1970
    }
}
