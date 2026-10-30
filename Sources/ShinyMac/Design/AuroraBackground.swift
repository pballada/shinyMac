import SwiftUI

/// Full-window animated mesh gradient that cross-fades between section themes.
struct AuroraBackground: View {
    let section: SidebarSection

    var body: some View {
        ZStack {
            Color.black
            AuroraLayer(theme: section.theme)
                .id(section)
                .transition(.opacity)
        }
        .animation(.easeInOut(duration: 0.8), value: section)
        .overlay {
            // Keeps the lower half calm so bottom controls stay readable.
            LinearGradient(colors: [.clear, .black.opacity(0.35)], startPoint: .center, endPoint: .bottom)
        }
        .ignoresSafeArea()
    }
}

private struct AuroraLayer: View {
    let theme: ModuleTheme
    @Environment(\.appearsActive) private var appearsActive

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20, paused: !appearsActive)) { timeline in
            MeshGradient(
                width: 3,
                height: 3,
                points: points(at: timeline.date.timeIntervalSinceReferenceDate),
                colors: [
                    theme.deep, theme.deep, theme.mid,
                    theme.mid, theme.deep, theme.bright,
                    theme.deep, theme.mid, theme.deep,
                ]
            )
        }
    }

    /// Slowly drifting control points; edges stay pinned so the mesh always fills the window.
    private func points(at time: TimeInterval) -> [SIMD2<Float>] {
        func wave(_ speed: Double, _ phase: Double, _ amount: Float) -> Float {
            Float(sin(time * speed + phase)) * amount
        }
        return [
            SIMD2(0, 0), SIMD2(0.5 + wave(0.11, 0, 0.15), 0), SIMD2(1, 0),
            SIMD2(0, 0.5 + wave(0.09, 1, 0.12)),
            SIMD2(0.5 + wave(0.13, 2, 0.18), 0.5 + wave(0.10, 3, 0.16)),
            SIMD2(1, 0.5 + wave(0.12, 4, 0.14)),
            SIMD2(0, 1), SIMD2(0.5 + wave(0.08, 5, 0.16), 1), SIMD2(1, 1),
        ]
    }
}
