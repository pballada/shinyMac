import SwiftUI

extension View {
    /// Liquid Glass on macOS 26, a frosted material with a hairline highlight before that.
    @ViewBuilder
    func shinyGlass<S: Shape>(in shape: S, tint: Color? = nil, interactive: Bool = false) -> some View {
        if #available(macOS 26, *) {
            glassEffect(Glass.regular.tint(tint).interactive(interactive), in: shape)
        } else {
            background(.ultraThinMaterial, in: shape)
                .background(tint.map { AnyShapeStyle($0.opacity(0.25)) } ?? AnyShapeStyle(.clear), in: shape)
                .overlay(shape.stroke(.white.opacity(0.14), lineWidth: 1))
        }
    }
}

/// A rounded glass panel that hosts grouped content.
struct GlassCard<Content: View>: View {
    var cornerRadius: CGFloat = 20
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.black.opacity(0.12), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shinyGlass(in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}
