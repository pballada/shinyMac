import SwiftUI

/// The big round, glowing primary action ("Scan", "Clean", "Run").
struct OrbButton: View {
    let title: String
    let theme: ModuleTheme
    var size: CGFloat = 96
    var isEnabled = true
    let action: () -> Void

    @State private var isHovering = false
    @State private var pulse = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(theme.accent.opacity(0.5))
                    .blur(radius: 22)
                    .scaleEffect(pulse ? 1.28 : 1.0)
                    .opacity(pulse ? 0.45 : 0.9)
                    .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: pulse)

                Circle()
                    .fill(LinearGradient(colors: [.white.opacity(0.30), .white.opacity(0.05)], startPoint: .top, endPoint: .bottom))
                    .overlay {
                        Circle().strokeBorder(AngularGradient(colors: theme.ring, center: .center), lineWidth: 2.5)
                    }
                    .shinyGlass(in: Circle(), tint: theme.accent.opacity(0.25), interactive: true)

                Text(title)
                    .font(.display(size * 0.19, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
            }
            .frame(width: size, height: size)
            .contentShape(Circle())
            .scaleEffect(isHovering && isEnabled ? 1.05 : 1)
        }
        .buttonStyle(PressScaleStyle())
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
        .onHover { hovering in
            withAnimation(.spring(duration: 0.3)) { isHovering = hovering }
        }
        .onAppear { pulse = true }
    }
}

/// Shrinks slightly while pressed.
struct PressScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(duration: 0.25), value: configuration.isPressed)
    }
}

/// Secondary capsule button on glass, e.g. "Review Details".
struct GlassPillButtonStyle: ButtonStyle {
    var prominent = false
    var tint: Color = .white

    func makeBody(configuration: Configuration) -> some View {
        PillBody(configuration: configuration, prominent: prominent, tint: tint)
    }

    private struct PillBody: View {
        let configuration: Configuration
        let prominent: Bool
        let tint: Color
        @State private var isHovering = false
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(prominent ? AnyShapeStyle(tint.gradient) : AnyShapeStyle(.white.opacity(isHovering ? 0.16 : 0.08)))
                )
                .shinyGlass(in: Capsule())
                .opacity(isEnabled ? (configuration.isPressed ? 0.75 : 1) : 0.45)
                .scaleEffect(configuration.isPressed ? 0.97 : 1)
                .onHover { isHovering = $0 }
                .animation(.easeOut(duration: 0.15), value: isHovering)
        }
    }
}

extension ButtonStyle where Self == GlassPillButtonStyle {
    static var glassPill: GlassPillButtonStyle { GlassPillButtonStyle() }
    static func glassPill(prominent: Bool, tint: Color) -> GlassPillButtonStyle {
        GlassPillButtonStyle(prominent: prominent, tint: tint)
    }
}
