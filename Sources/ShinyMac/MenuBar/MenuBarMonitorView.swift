import AppKit
import ShinyCore
import SwiftUI

/// The panel shown from the menu bar icon.
struct MenuBarMonitorView: View {
    @State private var model = MonitorModel()
    @Environment(\.openWindow) private var openWindow

    private let theme = SidebarSection.home.theme

    var body: some View {
        let snapshot = model.snapshot
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous).fill(theme.iconGradient)
                    Image(systemName: "sparkles").font(.system(size: 11, weight: .bold))
                }
                .frame(width: 22, height: 22)
                Text("ShinyMac").font(.display(15))
                Spacer()
                Text("Up \(Self.uptime(snapshot.uptime))")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.55))
            }

            Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                GridRow {
                    GaugeCard(title: "CPU", value: snapshot.cpuUsage, caption: percent(snapshot.cpuUsage),
                              colors: [Color(hex: 0x5CC8FF), Color(hex: 0x7D5FFF)]) {
                        Sparkline(values: model.cpuHistory).stroke(Color(hex: 0x5CC8FF).opacity(0.8), lineWidth: 1.5)
                    }
                    GaugeCard(title: "Memory", value: snapshot.memoryFraction,
                              caption: "\(ByteFormat.string(snapshot.memoryUsed)) of \(ByteFormat.string(snapshot.memoryTotal))",
                              colors: [Color(hex: 0xFF8AD8), Color(hex: 0xC56CF0)]) { EmptyView() }
                }
                GridRow {
                    if let volume = snapshot.volume {
                        GaugeCard(title: "Disk", value: volume.usedFraction, caption: "\(ByteFormat.string(volume.available)) free",
                                  colors: [Color(hex: 0x4BE3A8), Color(hex: 0x1FB58A)]) { EmptyView() }
                    }
                    if let battery = snapshot.battery {
                        GaugeCard(title: "Battery", value: battery.level,
                                  caption: battery.isCharging ? "Charging" : (battery.isPluggedIn ? "Plugged in" : "On battery"),
                                  colors: [Color(hex: 0xFFE29A), Color(hex: 0xFF7A1A)]) { EmptyView() }
                    } else {
                        NetworkCard(snapshot: snapshot)
                    }
                }
            }

            if snapshot.battery != nil {
                NetworkCard(snapshot: snapshot)
            }

            HStack(spacing: 8) {
                Button {
                    model.freeUpMemory()
                } label: {
                    Label(model.isFreeingMemory ? "Freeing…" : freedLabel, systemImage: "memorychip")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassPill)
                .disabled(model.isFreeingMemory)

                Button {
                    openWindow(id: "main")
                    NSApp.activate()
                } label: {
                    Label("Open ShinyMac", systemImage: "macwindow").frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassPill(prominent: true, tint: theme.accent))
            }
        }
        .padding(16)
        .frame(width: 330)
        .background {
            LinearGradient(colors: [theme.deep, Color(hex: 0x241046), theme.deep], startPoint: .topLeading, endPoint: .bottomTrailing)
                .overlay(RadialGradient(colors: [theme.bright.opacity(0.35), .clear], center: .topTrailing, startRadius: 0, endRadius: 260))
                .ignoresSafeArea()
        }
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
        .task { await model.run() }
    }

    private var freedLabel: String {
        if let freed = model.freedMemory, freed > 0 { return "Freed \(ByteFormat.string(freed))" }
        return "Free Up RAM"
    }

    private func percent(_ value: Double) -> String {
        value.formatted(.percent.precision(.fractionLength(0)))
    }

    static func uptime(_ interval: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = interval > 86_400 ? [.day, .hour] : [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: interval) ?? ""
    }
}

private struct GaugeCard<Accessory: View>: View {
    let title: String
    let value: Double
    let caption: String
    let colors: [Color]
    @ViewBuilder var accessory: Accessory

    var body: some View {
        HStack(spacing: 12) {
            RingGauge(value: value, colors: colors)
                .frame(width: 46, height: 46)
            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased())
                    .font(.system(size: 9.5, weight: .bold))
                    .tracking(0.7)
                    .foregroundStyle(.white.opacity(0.55))
                Text(value, format: .percent.precision(.fractionLength(0)))
                    .font(.display(17))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text(caption)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
                accessory.frame(height: 12)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .animation(.smooth, value: value)
    }
}

private struct NetworkCard: View {
    let snapshot: SystemSnapshot

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "network")
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 32, height: 32)
                .background(LinearGradient(colors: [Color(hex: 0x5CC8FF), Color(hex: 0x2A7BFF)], startPoint: .top, endPoint: .bottom),
                            in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            rate("arrow.down", snapshot.networkIn)
            rate("arrow.up", snapshot.networkOut)
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func rate(_ symbol: String, _ bytesPerSecond: Double) -> some View {
        Label("\(ByteFormat.string(Int64(bytesPerSecond)))/s", systemImage: symbol)
            .font(.system(size: 11.5, weight: .semibold))
            .monospacedDigit()
    }
}

/// Circular progress with a gradient stroke.
struct RingGauge: View {
    let value: Double
    let colors: [Color]
    var lineWidth: CGFloat = 6

    var body: some View {
        ZStack {
            Circle().stroke(.white.opacity(0.1), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.01, min(value, 1)))
                .stroke(AngularGradient(colors: colors + [colors[0]], center: .center),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .animation(.smooth, value: value)
    }
}

/// Tiny line chart of recent values in 0...1.
nonisolated struct Sparkline: Shape {
    let values: [Double]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard values.count > 1 else { return path }
        let step = rect.width / CGFloat(values.count - 1)
        for (index, value) in values.enumerated() {
            let point = CGPoint(x: CGFloat(index) * step, y: rect.maxY - CGFloat(min(max(value, 0), 1)) * rect.height)
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        return path
    }
}
