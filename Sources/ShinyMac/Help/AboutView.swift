import AppKit
import SwiftUI

/// The About window. Click the orb to polish it; things get out of hand quickly.
struct AboutView: View {
    @Environment(\.openWindow) private var openWindow
    @State private var polishes = 0
    @State private var quip = Int.random(in: 0..<AboutView.quips.count)
    @State private var burst = 0

    private let theme = SidebarSection.home.theme

    static let quips = [
        "Certified 0% bloatware. We checked twice.",
        "Removes junk, never your vacation photos.",
        "Made with SwiftUI, coffee and an unreasonable love of gradients.",
        "No caches were harmed in the making of this app. Okay, a few. They grew back.",
        "Your Mac does not need 14 copies of the same installer. We asked.",
        "Like a Roomba for your Library folder, minus the cat riding it.",
        "Every byte freed is a byte that can finally rest.",
        "Spark joy? Spark gigabytes.",
        "Tested on real Macs with real clutter. So much clutter.",
        "Fun fact: DerivedData is Latin for \"where your disk space went\".",
    ]

    private var shine: (label: String, emoji: String) {
        switch polishes {
        case 0: ("Shiny", "✨")
        case 1...3: ("Shinier", "🌟")
        case 4...7: ("Shiniest", "💫")
        case 8...14: ("Dazzling", "🪩")
        case 15...24: ("Blinding. Sunglasses advised", "😎")
        case 25...49: ("Visible from space", "🛰️")
        default: ("You've polished it to a new dimension", "🌌")
        }
    }

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                HeroIllustration(symbol: "sparkles", theme: theme, size: 190, isBusy: polishes > 7)
                    .scaleEffect(1 + min(Double(polishes), 30) * 0.004)
                    .rotationEffect(.degrees(polishes > 24 ? Double(polishes) * 9 : 0))
                    .onTapGesture { polish() }
                    .help("Polish me")
                SparkleBurst(trigger: burst, color: theme.accent)
                    .allowsHitTesting(false)
            }
            .frame(height: 200)
            .padding(.top, 26)

            VStack(spacing: 4) {
                Text("ShinyMac").font(.display(30))
                Text("Version \(SettingsView.version)")
                    .font(.system(size: 12, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.55))
            }

            HStack(spacing: 6) {
                Text(shine.emoji)
                Text("Shine level: \(shine.label)")
                    .contentTransition(.opacity)
            }
            .font(.system(size: 12.5, weight: .semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(theme.accent.opacity(0.18), in: Capsule())
            .animation(.smooth, value: shine.label)

            Text(Self.quips[quip])
                .font(.system(size: 13))
                .italic()
                .foregroundStyle(.white.opacity(0.72))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 340, minHeight: 36)
                .contentTransition(.opacity)
                .onTapGesture { withAnimation(.smooth) { quip = (quip + 1) % Self.quips.count } }
                .help("Click for another")

            HStack(spacing: 8) {
                Button("Help") { openWindow(id: "help") }
                    .buttonStyle(.glassPill)
                Button("GitHub") { NSWorkspace.shared.open(Support.repoURL) }
                    .buttonStyle(.glassPill)
                Button("☕  Buy Me a Coffee") { NSWorkspace.shared.open(Support.coffeeURL) }
                    .buttonStyle(.glassPill(prominent: true, tint: theme.accent))
            }
            .padding(.top, 4)

            Text("Free and open source, made with care by Pau Ballada.\nNo ads, no tracking, no subscriptions. Just shine.")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.45))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
                .padding(.bottom, 22)
        }
        .frame(width: 420)
        .background(
            LinearGradient(colors: [theme.deep, Color(hex: 0x2A0F55)], startPoint: .top, endPoint: .bottom)
        )
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
    }

    private func polish() {
        withAnimation(.spring(duration: 0.35, bounce: 0.5)) { polishes += 1 }
        burst += 1
        if polishes % 3 == 0 { withAnimation(.smooth) { quip = (quip + 1) % Self.quips.count } }
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
    }
}

/// A ring of sparkles that flies outward each time `trigger` changes.
private struct SparkleBurst: View {
    let trigger: Int
    let color: Color
    @State private var fly = false

    var body: some View {
        ZStack {
            ForEach(0..<10, id: \.self) { index in
                let angle = Double(index) / 10 * 2 * .pi + Double(trigger)
                Image(systemName: index.isMultiple(of: 2) ? "sparkle" : "star.fill")
                    .font(.system(size: index.isMultiple(of: 2) ? 14 : 8))
                    .foregroundStyle(index.isMultiple(of: 3) ? .white : color)
                    .offset(x: fly ? cos(angle) * 120 : 0, y: fly ? sin(angle) * 120 : 0)
                    .opacity(fly ? 0 : 1)
                    .scaleEffect(fly ? 0.4 : 1.1)
            }
        }
        .opacity(trigger == 0 ? 0 : 1)
        .onChange(of: trigger) {
            var reset = Transaction()
            reset.disablesAnimations = true
            withTransaction(reset) { fly = false }
            DispatchQueue.main.async {
                withAnimation(.easeOut(duration: 0.8)) { fly = true }
            }
        }
    }
}
