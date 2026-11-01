import ShinyCore
import SwiftUI

/// A short "what this does" line on a module's start screen.
struct Feature: Identifiable {
    let symbol: String
    let title: String
    let detail: String
    var id: String { title }
}

struct FeatureRow: View {
    let feature: Feature
    let theme: ModuleTheme

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: feature.symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(theme.iconGradient)
                .frame(width: 34, height: 34)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(feature.title).font(.system(size: 14, weight: .semibold))
                Text(feature.detail)
                    .font(.system(size: 12.5))
                    .foregroundStyle(.white.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

enum CheckState {
    case off, mixed, on

    init(selected: Int, total: Int) {
        self = selected == 0 ? .off : (selected == total ? .on : .mixed)
    }
}

/// Round checkbox matching the module accent.
struct CheckCircle: View {
    let state: CheckState
    var tint: Color = .white
    var size: CGFloat = 18

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(.white.opacity(state == .off ? 0.45 : 0), lineWidth: 1.5)
            if state != .off {
                Circle().fill(tint.gradient)
                Image(systemName: state == .on ? "checkmark" : "minus")
                    .font(.system(size: size * 0.5, weight: .heavy))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
        .contentShape(Circle())
        .animation(.spring(duration: 0.2), value: state)
    }
}

/// Hero sized byte count, e.g. a huge "3.2" next to a smaller "GB".
struct BigSize: View {
    let bytes: Int64
    var size: CGFloat = 64

    var body: some View {
        let parts = ByteFormat.parts(bytes)
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(parts.value)
                .font(.display(size, weight: .bold))
                .contentTransition(.numericText())
            Text(parts.unit)
                .font(.display(size * 0.42, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
        }
        .monospacedDigit()
        .foregroundStyle(LinearGradient(colors: [.white, .white.opacity(0.82)], startPoint: .top, endPoint: .bottom))
        .animation(.smooth, value: bytes)
    }
}

/// Lays children out left to right, wrapping onto new lines when the width runs out.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = rows(for: subviews, width: proposal.width ?? .infinity)
        let width = rows.map { $0.reduce(0) { $0 + $1.width } + spacing * CGFloat($0.count - 1) }.max() ?? 0
        let height = rows.map { $0.map(\.height).max() ?? 0 }.reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var index = 0
        var y = bounds.minY
        for row in rows(for: subviews, width: bounds.width) {
            var x = bounds.minX
            for size in row {
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
                index += 1
            }
            y += (row.map(\.height).max() ?? 0) + spacing
        }
    }

    private func rows(for subviews: Subviews, width: CGFloat) -> [[CGSize]] {
        var rows: [[CGSize]] = [[]]
        var x: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width {
                rows.append([])
                x = 0
            }
            rows[rows.count - 1].append(size)
            x += size.width + spacing
        }
        return rows
    }
}

/// The start screen every module shares: title, pitch, features, illustration and the orb action.
struct ModuleStartView: View {
    let module: Module
    let features: [Feature]
    var actionTitle = "Scan"
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 12)
            HStack(spacing: 44) {
                VStack(alignment: .leading, spacing: 14) {
                    Text(module.title)
                        .font(.display(36))
                    Text(module.tagline)
                        .font(.system(size: 16))
                        .foregroundStyle(.white.opacity(0.75))
                        .fixedSize(horizontal: false, vertical: true)
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(features) { FeatureRow(feature: $0, theme: module.theme) }
                    }
                    .padding(.top, 14)
                }
                .frame(maxWidth: 380, alignment: .leading)

                HeroIllustration(symbol: module.symbol, theme: module.theme, size: 270)
            }
            Spacer(minLength: 12)
            OrbButton(title: actionTitle, theme: module.theme, isEnabled: isEnabled, action: action)
                .padding(.bottom, 34)
        }
        .padding(.horizontal, 40)
    }
}

/// Spinning-illustration screen shown while a scan or clean is in flight.
struct ModuleBusyView: View {
    let module: Module
    let title: String
    var detail: String = ""
    var progress: Double?
    var foundBytes: Int64?
    var stopTitle = "Stop"
    var onStop: (() -> Void)?

    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            HeroIllustration(symbol: module.symbol, theme: module.theme, size: 300, isBusy: true, progress: progress)
            VStack(spacing: 8) {
                Text(title).font(.display(26, weight: .semibold))
                if let foundBytes {
                    Text("\(ByteFormat.string(foundBytes)) found so far")
                        .font(.system(size: 14, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.75))
                        .contentTransition(.numericText())
                        .animation(.smooth, value: foundBytes)
                }
                Text(detail.isEmpty ? " " : detail)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 520)
            }
            Spacer()
            if let onStop {
                OrbButton(title: stopTitle, theme: module.theme, size: 76, action: onStop)
                    .padding(.bottom, 44)
            }
        }
        .padding(.horizontal, 40)
    }
}
