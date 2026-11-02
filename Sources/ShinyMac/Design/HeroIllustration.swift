import SwiftUI

/// Layered illustration for a module: drifting mist, orbits, a glass disc and a gradient core with the module symbol.
/// Glowing motes orbit the core on tilted rings, passing behind and in front of it. While `isBusy` the halo swirls
/// faster and brighter; `progress` draws a determinate ring.
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
                .fill(RadialGradient(colors: [theme.accent.opacity(0.45), .clear], center: .center, startRadius: 0, endRadius: size * 0.55))
                .scaleEffect(breathe ? 1.08 : 0.94)
                .animation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true), value: breathe)

            MagicHalo(theme: theme, size: size, isBusy: isBusy, layer: .back)
                .allowsHitTesting(false)

            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .stroke(.white.opacity(0.10 - Double(index) * 0.028), lineWidth: 1)
                    .frame(width: size * (0.66 + CGFloat(index) * 0.16))
            }

            orbitDots
                .rotationEffect(.degrees(spin ? 360 : 0))
                .animation(.linear(duration: 40).repeatForever(autoreverses: false), value: spin)

            comet(length: 0.2, opacity: isBusy ? 0.7 : 0.4)
                .frame(width: size * 0.82)
                .blur(radius: 1.2)
                .rotationEffect(.degrees(spin ? 360 : 0))
                .animation(.linear(duration: isBusy ? 6 : 16).repeatForever(autoreverses: false), value: spin)

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

            MagicHalo(theme: theme, size: size, isBusy: isBusy, layer: .front)
                .allowsHitTesting(false)
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

/// A glowing, vaporous halo: soft mist swirling in a ring around the core, motes of light on tilted orbits and a few
/// twinkling sparkles. Drawn as two layers so motes pass behind the core and in front of it.
struct MagicHalo: View {
    enum Layer { case back, front }

    let theme: ModuleTheme
    let size: CGFloat
    var isBusy = false
    let layer: Layer

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate * (isBusy ? 2.4 : 1)
            ZStack {
                if layer == .back {
                    Canvas { context, canvas in drawMist(in: &context, canvas: canvas, time: time) }
                        .blur(radius: size * 0.07)
                }
                // Blurred copy for the glow, crisp copy for the bright centres.
                Canvas { context, canvas in drawMotes(in: &context, canvas: canvas, time: time, glow: true) }
                    .blur(radius: size * 0.022)
                Canvas { context, canvas in
                    drawMotes(in: &context, canvas: canvas, time: time, glow: false)
                    drawSparkles(in: &context, canvas: canvas, time: time)
                }
            }
            .blendMode(.plusLighter)
        }
        .frame(width: size * 1.4, height: size * 1.4)
    }

    private var palette: [Color] { [theme.accent, .white] + theme.symbolGradient + [theme.bright] }

    /// Fixed pseudo-random value in 0..<1 per index and salt.
    private func hash(_ index: Int, _ salt: Double) -> Double {
        let value = sin(Double(index) * 12.9898 + salt * 78.233) * 43_758.5453
        return value - value.rounded(.down)
    }

    /// Mist blobs circling the core in a slow ring, breathing in and out.
    private func drawMist(in context: inout GraphicsContext, canvas: CGSize, time: TimeInterval) {
        let center = CGPoint(x: canvas.width / 2, y: canvas.height / 2)
        for index in 0..<7 {
            let angle = time * 0.22 * (index.isMultiple(of: 2) ? 1 : -0.7) + Double(index) * .pi * 2 / 7
            let orbit = size * (0.36 + 0.04 * sin(time * 0.5 + Double(index)))
            let radius = size * (0.13 + 0.04 * sin(time * 0.7 + Double(index) * 1.7))
            let point = CGPoint(x: center.x + cos(angle) * orbit, y: center.y + sin(angle) * orbit * 0.8)
            let rect = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
            context.fill(Path(ellipseIn: rect), with: .color(palette[index % palette.count].opacity(isBusy ? 0.42 : 0.28)))
        }
    }

    /// Motes on tilted elliptical orbits. The half of each orbit nearer the viewer is drawn on the front layer.
    private func drawMotes(in context: inout GraphicsContext, canvas: CGSize, time: TimeInterval, glow: Bool) {
        let center = CGPoint(x: canvas.width / 2, y: canvas.height / 2)
        for index in 0..<34 {
            let orbit = size * (0.34 + 0.24 * hash(index, 1))
            let speed = (0.25 + 0.5 * hash(index, 2)) * (hash(index, 3) < 0.25 ? -1 : 1)
            let tilt = (hash(index, 4) - 0.5) * 1.2
            let angle = time * speed + hash(index, 5) * .pi * 2
            let depth = sin(angle)
            guard (depth > 0) == (layer == .front) else { continue }
            let x = cos(angle) * orbit
            let y = depth * orbit * 0.32
            let point = CGPoint(x: center.x + x * cos(tilt) - y * sin(tilt), y: center.y + x * sin(tilt) + y * cos(tilt))
            let twinkle = 0.55 + 0.45 * sin(time * (2 + 3 * hash(index, 6)) + Double(index))
            let nearness = 0.65 + 0.35 * depth
            let radius = size * (0.006 + 0.01 * hash(index, 7)) * nearness * (glow ? 3.2 : 1)
            let rect = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
            let color = glow ? palette[index % palette.count] : .white
            context.fill(Path(ellipseIn: rect), with: .color(color.opacity(twinkle * (glow ? 0.55 : 0.9) * (isBusy ? 1 : 0.8))))
        }
    }

    /// Four-point stars that swell and fade at spots around the halo.
    private func drawSparkles(in context: inout GraphicsContext, canvas: CGSize, time: TimeInterval) {
        let center = CGPoint(x: canvas.width / 2, y: canvas.height / 2)
        for index in 0..<5 {
            let cycle = 3.4 + hash(index, 8) * 2
            let phase = (time / cycle + hash(index, 9)).truncatingRemainder(dividingBy: 1)
            let slot = Int(time / cycle + hash(index, 9))
            // Each appearance lands somewhere new on the ring; split between the two layers.
            guard (slot + index).isMultiple(of: 2) == (layer == .front) else { continue }
            let angle = hash(index * 31 + slot, 10) * .pi * 2
            let orbit = size * (0.3 + 0.26 * hash(index * 17 + slot, 11))
            let point = CGPoint(x: center.x + cos(angle) * orbit, y: center.y + sin(angle) * orbit * 0.85)
            let scale = sin(phase * .pi)
            let arm = size * 0.035 * scale
            guard arm > 0.5 else { continue }
            var star = Path()
            star.move(to: CGPoint(x: point.x, y: point.y - arm))
            star.addQuadCurve(to: CGPoint(x: point.x + arm, y: point.y), control: point)
            star.addQuadCurve(to: CGPoint(x: point.x, y: point.y + arm), control: point)
            star.addQuadCurve(to: CGPoint(x: point.x - arm, y: point.y), control: point)
            star.addQuadCurve(to: CGPoint(x: point.x, y: point.y - arm), control: point)
            context.fill(star, with: .color(.white.opacity(0.9 * scale)))
        }
    }
}
