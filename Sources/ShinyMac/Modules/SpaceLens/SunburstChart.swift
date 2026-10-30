import ShinyCore
import SwiftUI

/// One ring segment in the sunburst.
struct SunburstArc {
    let node: DiskNode
    let depth: Int
    let start: Double
    let end: Double
    let colorIndex: Int
}

enum SunburstLayout {
    static let depthLimit = 4
    /// Segments thinner than this (in radians) aren't drawn.
    static let minimumAngle = 0.006

    static func arcs(for focus: DiskNode) -> [SunburstArc] {
        var arcs: [SunburstArc] = []
        func layout(_ node: DiskNode, depth: Int, start: Double, span: Double, colorIndex: Int?) {
            guard depth <= depthLimit, node.size > 0 else { return }
            var cursor = start
            for (index, child) in node.children.enumerated() {
                let childSpan = span * Double(child.size) / Double(node.size)
                defer { cursor += childSpan }
                guard childSpan >= minimumAngle else { continue }
                let color = colorIndex ?? index
                arcs.append(SunburstArc(node: child, depth: depth, start: cursor, end: cursor + childSpan, colorIndex: color))
                if child.isDirectory {
                    layout(child, depth: depth + 1, start: cursor, span: childSpan, colorIndex: color)
                }
            }
        }
        layout(focus, depth: 1, start: 0, span: 2 * .pi, colorIndex: nil)
        return arcs
    }
}

/// Interactive sunburst: hover to inspect, click a folder to zoom in, click the centre to zoom out.
struct SunburstChart: View {
    let model: SpaceLensModel
    let focus: DiskNode

    static let palette: [Color] = [
        Color(hex: 0xFF9F43), Color(hex: 0xFF6B81), Color(hex: 0xC56CF0), Color(hex: 0x7D5FFF),
        Color(hex: 0x4BCFFA), Color(hex: 0x34E7B4), Color(hex: 0xFFD32A), Color(hex: 0xFF5E57),
    ]

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let geometry = Geometry(side: side)
            let arcs = SunburstLayout.arcs(for: focus)
            let _ = model.revision

            ZStack {
                Canvas { context, size in
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    for arc in arcs {
                        let path = geometry.path(for: arc, center: center)
                        let isHovered = model.hovered === arc.node
                        let isSelected = model.isSelected(arc.node)
                        context.fill(path, with: .color(color(for: arc).opacity(isHovered ? 1 : 0.92)))
                        if isHovered || isSelected {
                            context.fill(path, with: .color(.white.opacity(isSelected ? 0.35 : 0.22)))
                        }
                        context.stroke(path, with: .color(.black.opacity(0.35)), lineWidth: 1)
                    }
                }
                .frame(width: side, height: side)
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let location):
                        let hit = geometry.hitTest(location, arcs: arcs)
                        if model.hovered !== hit { model.hovered = hit }
                    case .ended:
                        model.hovered = nil
                    }
                }
                .gesture(SpatialTapGesture().onEnded { value in
                    if let node = geometry.hitTest(value.location, arcs: arcs) {
                        if node.canDrillDown { model.zoom(into: node) } else { model.toggleSelection(node) }
                    } else if geometry.isInCenter(value.location) {
                        model.zoomOut()
                    }
                })

                centerLabel
                    .frame(width: geometry.innerRadius * 1.7)
                    .allowsHitTesting(false)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var centerLabel: some View {
        let shown = model.hovered ?? focus
        return VStack(spacing: 3) {
            if focus.parent != nil, model.hovered == nil {
                Image(systemName: "arrow.up.left.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.6))
            }
            Text(shown.name)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(2)
                .multilineTextAlignment(.center)
            Text(ByteFormat.string(shown.size))
                .font(.display(22))
                .monospacedDigit()
            if shown !== focus, focus.size > 0 {
                Text(Double(shown.size) / Double(focus.size), format: .percent.precision(.fractionLength(1)))
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
    }

    private func color(for arc: SunburstArc) -> Color {
        if arc.node.isAggregate { return Color(white: 0.45) }
        let base = Self.palette[arc.colorIndex % Self.palette.count]
        return base.mix(with: .white, by: Double(arc.depth - 1) * 0.16)
    }

    struct Geometry {
        let side: CGFloat
        var innerRadius: CGFloat { side * 0.17 }
        var ringWidth: CGFloat { (side / 2 - innerRadius - 4) / CGFloat(SunburstLayout.depthLimit) }

        func radii(depth: Int) -> (inner: CGFloat, outer: CGFloat) {
            let inner = innerRadius + CGFloat(depth - 1) * ringWidth
            return (inner + 1, inner + ringWidth - 1)
        }

        func path(for arc: SunburstArc, center: CGPoint) -> Path {
            let (inner, outer) = radii(depth: arc.depth)
            // Rotate so 0 is at 12 o'clock and angles run clockwise.
            let start = Angle(radians: arc.start - .pi / 2)
            let end = Angle(radians: arc.end - .pi / 2)
            var path = Path()
            path.addArc(center: center, radius: outer, startAngle: start, endAngle: end, clockwise: false)
            path.addArc(center: center, radius: inner, startAngle: end, endAngle: start, clockwise: true)
            path.closeSubpath()
            return path
        }

        func polar(_ point: CGPoint) -> (radius: CGFloat, angle: Double) {
            let dx = point.x - side / 2
            let dy = point.y - side / 2
            var angle = atan2(Double(dy), Double(dx)) + .pi / 2
            if angle < 0 { angle += 2 * .pi }
            return (sqrt(dx * dx + dy * dy), angle)
        }

        func isInCenter(_ point: CGPoint) -> Bool { polar(point).radius < innerRadius }

        func hitTest(_ point: CGPoint, arcs: [SunburstArc]) -> DiskNode? {
            let (radius, angle) = polar(point)
            guard radius >= innerRadius else { return nil }
            let depth = Int((radius - innerRadius) / ringWidth) + 1
            return arcs.first { $0.depth == depth && angle >= $0.start && angle < $0.end }?.node
        }
    }
}
