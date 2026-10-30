import SwiftUI

/// Layered illustration for a module: glow, orbits, a glass disc and a gradient core with the module symbol.
/// While `isBusy` a fast comet circles the core; `progress` draws a determinate ring.
struct HeroIllustration: View {
    let symbol: String
    let theme: ModuleTheme
    var size: CGFloat = 260
    var isBusy = false
    var progress: Double?

    @State private var spin = false
    @State private var breathe = false

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [theme.accent.opacity(0.55), .clear], center: .center, startRadius: 0, endRadius: size * 0.55))
                .scaleEffect(breathe ? 1.08 : 0.94)
                .animation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true), value: breathe)

            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .stroke(.white.opacity(0.10 - Double(index) * 0.028), lineWidth: 1)
                    .frame(width: size * (0.66 + CGFloat(index) * 0.16))
            }

            orbitDots
                .rotationEffect(.degrees(spin ? 360 : 0))
                .animation(.linear(duration: 40).repeatForever(autoreverses: false), value: spin)

            comet(length: 0.2, opacity: 0.55)
                .frame(width: size * 0.82)
                .rotationEffect(.degrees(spin ? 360 : 0))
                .animation(.linear(duration: 16).repeatForever(autoreverses: false), value: spin)

            if isBusy {
                comet(length: 0.32, opacity: 1)
                    .frame(width: size * 0.66)
                    .rotationEffect(.degrees(spin ? -360 : 0))
                    .animation(.linear(duration: 1.3).repeatForever(autoreverses: false), value: spin)
                    .transition(.opacity)
            }

            Circle()
                .fill(.white.opacity(0.05))
                .frame(width: size * 0.56)
                .shinyGlass(in: Circle())

            if let progress {
                Circle()
                    .trim(from: 0, to: max(0.005, min(progress, 1)))
                    .stroke(AngularGradient(colors: theme.ring, center: .center), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: size * 0.56)
                    .animation(.smooth, value: progress)
            }

            Circle()
                .fill(theme.iconGradient)
                .overlay(Circle().stroke(.white.opacity(0.4), lineWidth: 1))
                .overlay(alignment: .top) {
                    // Specular highlight
                    Ellipse()
                        .fill(LinearGradient(colors: [.white.opacity(0.45), .clear], startPoint: .top, endPoint: .bottom))
                        .frame(width: size * 0.3, height: size * 0.16)
                        .offset(y: size * 0.02)
                }
                .frame(width: size * 0.42)
                .shadow(color: theme.accent.opacity(0.7), radius: 28, y: 10)

            Image(systemName: symbol)
                .font(.system(size: size * 0.17, weight: .semibold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
                .symbolEffect(.pulse, options: .repeating, isActive: isBusy)
        }
        .frame(width: size, height: size)
        .animation(.easeInOut(duration: 0.4), value: isBusy)
        .onAppear {
            spin = true
            breathe = true
        }
    }

    private func comet(length: CGFloat, opacity: Double) -> some View {
        Circle()
            .trim(from: 0, to: length)
            .stroke(
                AngularGradient(colors: [.white.opacity(0), .white.opacity(opacity)], center: .center,
                                startAngle: .degrees(0), endAngle: .degrees(360 * length)),
                style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
            )
    }

    private var orbitDots: some View {
        ZStack {
            ForEach(0..<5, id: \.self) { index in
                let ring = 0.66 + CGFloat(index % 3) * 0.16
                Circle()
                    .fill(index.isMultiple(of: 2) ? theme.accent : .white)
                    .frame(width: index.isMultiple(of: 2) ? 6 : 4)
                    .shadow(color: theme.accent, radius: 4)
                    .offset(y: -size * ring / 2)
                    .rotationEffect(.degrees(Double(index) * 72 + Double(index * 17)))
            }
        }
    }
}

/// Small rounded-square icon with the module's gradient, as shown in the sidebar.
struct ModuleIcon: View {
    let module: Module
    var size: CGFloat = 24

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            .fill(module.theme.iconGradient)
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                    .stroke(.white.opacity(0.25), lineWidth: 0.5)
            )
            .overlay {
                Image(systemName: module.symbol)
                    .font(.system(size: size * 0.5, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: size, height: size)
            .shadow(color: module.theme.accent.opacity(0.35), radius: 3, y: 1)
    }
}
