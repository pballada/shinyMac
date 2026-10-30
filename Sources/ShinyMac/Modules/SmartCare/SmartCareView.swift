import ShinyCore
import SwiftUI

struct SmartCareView: View {
    @Bindable var model: SmartCareModel

    var body: some View {
        ZStack {
            switch model.phase {
            case .idle:
                ModuleStartView(module: .smartCare, features: Module.smartCare.features) { model.scan() }
            case .scanning:
                SmartCareScanning(model: model)
            case .results:
                SmartCareResults(model: model)
            case .running:
                ModuleBusyView(module: .smartCare, title: "Running Smart Care…", detail: model.runStep)
            case .done:
                SmartCareDone(model: model)
            }
        }
        .transition(.opacity)
    }
}

private struct SmartCareScanning: View {
    let model: SmartCareModel

    var body: some View {
        VStack(spacing: 26) {
            Spacer()
            HeroIllustration(symbol: Module.smartCare.symbol, theme: Module.smartCare.theme, size: 290, isBusy: true,
                             progress: Double(model.finished.count) / Double(SmartCareModel.Area.allCases.count))
            Text("Looking after your Mac…").font(.display(26, weight: .semibold))
            HStack(spacing: 10) {
                ForEach(SmartCareModel.Area.allCases) { area in
                    let done = model.finished.contains(area)
                    HStack(spacing: 7) {
                        Group {
                            if done {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(area.module.theme.accent)
                            } else {
                                ProgressView().controlSize(.mini)
                            }
                        }
                        .frame(width: 16)
                        Text(area.rawValue).font(.system(size: 12.5, weight: .semibold))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .shinyGlass(in: Capsule())
                    .opacity(done ? 1 : 0.75)
                }
            }
            Spacer()
        }
    }
}

private struct SmartCareResults: View {
    let model: SmartCareModel
    @Environment(AppState.self) private var state
    @State private var isConfirming = false

    private var theme: ModuleTheme { Module.smartCare.theme }

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                Spacer()
                Button("Scan Again", systemImage: "arrow.clockwise") { model.scan() }
                    .buttonStyle(.glassPill)
            }
            .padding(.top, 6)

            VStack(spacing: 6) {
                Text("Your Mac is ready for a tune-up")
                    .font(.system(size: 12.5, weight: .bold))
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(theme.iconGradient)
                BigSize(bytes: model.included.contains(.cleanup) ? model.cleanableBytes : 0, size: 58)
                Text("ready to clean")
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.7))
            }

            Grid(horizontalSpacing: 14, verticalSpacing: 14) {
                GridRow {
                    AreaTile(model: model, area: .cleanup) { state.selection = .systemJunk }
                    AreaTile(model: model, area: .speed) { state.selection = .maintenance }
                }
                GridRow {
                    AreaTile(model: model, area: .applications) {
                        state.selection = model.updater.updates.isEmpty ? .leftovers : .updater
                    }
                    AreaTile(model: model, area: .clutter) { state.selection = .largeFiles }
                }
            }
            .frame(maxWidth: 760)

            Spacer(minLength: 0)
            OrbButton(title: "Run", theme: theme, isEnabled: !model.included.isEmpty) { isConfirming = true }
                .padding(.bottom, 26)
        }
        .padding(.horizontal, 28)
        .confirmationDialog("Run Smart Care?", isPresented: $isConfirming, titleVisibility: .visible) {
            Button("Run") { model.run() }
        } message: {
            Text(confirmationText)
        }
    }

    private var confirmationText: String {
        var parts: [String] = []
        if model.included.contains(.cleanup) {
            parts.append("Removes \(ByteFormat.string(model.junk.selectedSize)) of junk and permanently empties \(ByteFormat.string(model.trash.selectedSize)) from the Trash.")
        }
        if model.included.contains(.speed) {
            let needsPassword = model.maintenance.selectedTasks.contains(where: \.needsAdmin)
            parts.append("Runs \(model.maintenance.selectedTasks.count) maintenance tasks\(needsPassword ? " (asks for your password)" : "").")
        }
        return parts.joined(separator: " ")
    }
}

private struct AreaTile: View {
    let model: SmartCareModel
    let area: SmartCareModel.Area
    let review: () -> Void
    @State private var isHovering = false

    var body: some View {
        let theme = area.module.theme
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: area.symbol)
                .font(.system(size: 20, weight: .semibold))
                .frame(width: 48, height: 48)
                .background(theme.iconGradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: theme.accent.opacity(0.5), radius: 10, y: 4)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(area.rawValue.uppercased())
                        .font(.system(size: 10.5, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(.white.opacity(0.55))
                    Spacer()
                    if area.isActionable {
                        Button { model.toggle(area) } label: {
                            CheckCircle(state: model.included.contains(area) ? .on : .off, tint: theme.accent, size: 18)
                        }
                        .buttonStyle(.plain)
                        .help("Include in Run")
                    }
                }
                Text(model.headline(for: area))
                    .font(.display(22))
                    .monospacedDigit()
                Text(model.detail(for: area))
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Review", systemImage: "chevron.right", action: review)
                    .labelStyle(TrailingIconLabelStyle())
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.iconGradient)
                    .padding(.top, 2)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 140, alignment: .topLeading)
        .background(.white.opacity(isHovering ? 0.06 : 0.02), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shinyGlass(in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.15), value: isHovering)
    }
}

private struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 3) {
            configuration.title
            configuration.icon.imageScale(.small)
        }
    }
}

private struct SmartCareDone: View {
    let model: SmartCareModel

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            HeroIllustration(symbol: "checkmark", theme: Module.smartCare.theme, size: 240)
            BigSize(bytes: model.freedBytes, size: 58)
            Text(summary)
                .font(.system(size: 16))
                .foregroundStyle(.white.opacity(0.7))
            Spacer()
            Button("Done") { model.finish() }
                .buttonStyle(.glassPill(prominent: true, tint: Module.smartCare.theme.accent))
                .controlSize(.large)
                .padding(.bottom, 40)
        }
    }

    private var summary: String {
        let tasks = model.tasksCompleted
        return tasks > 0 ? "cleaned · \(tasks) maintenance task\(tasks == 1 ? "" : "s") completed" : "cleaned"
    }
}
