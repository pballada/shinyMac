import AppKit
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
            case .ready:
                SmartCareReady(model: model)
            case .running:
                SmartCareRunning(model: model)
            case .done:
                SmartCareDone(model: model)
            }
        }
        .transition(.opacity)
    }
}

private var theme: ModuleTheme { Module.smartCare.theme }

// MARK: Scanning

private struct SmartCareScanning: View {
    let model: SmartCareModel

    var body: some View {
        VStack(spacing: 26) {
            Spacer()
            HeroIllustration(symbol: Module.smartCare.symbol, theme: theme, size: 290, isBusy: true,
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

// MARK: Ready

private struct SmartCareReady: View {
    let model: SmartCareModel
    @State private var isConfirming = false

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                Spacer()
                Button("Scan Again", systemImage: "arrow.clockwise") { model.scan() }
                    .buttonStyle(.glassPill)
            }
            .padding(.top, 6)

            VStack(spacing: 4) {
                Text("Ready to free up space and speed things up")
                    .font(.system(size: 12.5, weight: .bold))
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(theme.iconGradient)
                BigSize(bytes: model.freeableBytes, size: 58)
                Text(subtitle)
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.7))
            }

            VStack(spacing: 0) {
                SectionLabel(text: "Essentials · run one after the other")
                ForEach(SmartCareModel.Essential.allCases) { essential in
                    EssentialRow(model: model, essential: essential)
                }
            }
            .padding(.bottom, 6)
            .frame(maxWidth: 680)
            .shinyGlass(in: RoundedRectangle(cornerRadius: 20, style: .continuous))

            WorthALook(model: model)
                .frame(maxWidth: 680)

            Spacer(minLength: 0)
            OrbButton(title: "Run", theme: theme, isEnabled: !model.plannedEssentials.isEmpty) {
                if model.plannedEssentials.contains(.trash) { isConfirming = true } else { model.run() }
            }
            .padding(.bottom, 24)
        }
        .padding(.horizontal, 28)
        .confirmationDialog("Run Smart Care?", isPresented: $isConfirming, titleVisibility: .visible) {
            Button("Run") { model.run() }
        } message: {
            Text("Emptying the Trash deletes \(ByteFormat.string(model.trash.selectedSize)) permanently. This can't be undone.")
        }
    }

    private var subtitle: String {
        let tasks = model.enabled.contains(.speed) ? model.maintenance.selectedTasks.count : 0
        let space = "can be freed"
        return tasks > 0 ? "\(space) · \(tasks) speed-up task\(tasks == 1 ? "" : "s")" : space
    }
}

private struct EssentialRow: View {
    let model: SmartCareModel
    let essential: SmartCareModel.Essential
    @Environment(AppState.self) private var state
    @State private var isHovering = false

    var body: some View {
        let isOn = model.enabled.contains(essential)
        let hasWork = model.hasWork(essential)
        HStack(spacing: 14) {
            CheckCircle(state: isOn && hasWork ? .on : .off, tint: theme.accent, size: 18)
            EssentialIcon(essential: essential, size: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(essential.title).font(.system(size: 14, weight: .semibold))
                Text(model.detail(for: essential))
                    .font(.system(size: 11.5))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(model.headline(for: essential))
                .font(.display(17))
                .monospacedDigit()
                .opacity(isOn ? 1 : 0.45)
            Button { state.selection = essential.module } label: {
                Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.5))
            .help("Review in \(essential.module.title)")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(.white.opacity(isHovering ? 0.05 : 0))
        .contentShape(Rectangle())
        .onTapGesture { model.toggle(essential) }
        .onHover { isHovering = $0 }
        .opacity(hasWork ? 1 : 0.55)
        .animation(.easeOut(duration: 0.12), value: isHovering)
    }
}

/// Things that need a person's judgement: shown, never run automatically.
private struct WorthALook: View {
    let model: SmartCareModel
    @Environment(AppState.self) private var state

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("WORTH A LOOK")
                .font(.system(size: 10, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(.white.opacity(0.45))
                .padding(.leading, 4)
            HStack(spacing: 12) {
                tile(.updater, value: model.updater.updates.isEmpty ? "Up to date" : "\(model.updater.updates.count) updates",
                     detail: "Newer versions out")
                tile(.leftovers, value: model.leftovers.totalSize > 0 ? ByteFormat.string(model.leftovers.totalSize) : "None",
                     detail: "Left by deleted apps")
                tile(.largeFiles, value: "\(model.largeFiles.files.count) files",
                     detail: "\(ByteFormat.string(model.largeFileBytes)) of large files")
            }
        }
    }

    private func tile(_ module: Module, value: String, detail: String) -> some View {
        Button { state.selection = module } label: {
            HStack(spacing: 10) {
                ModuleIcon(module: module, size: 30)
                VStack(alignment: .leading, spacing: 1) {
                    Text(value).font(.system(size: 13.5, weight: .semibold)).monospacedDigit()
                    Text(detail).font(.system(size: 11)).foregroundStyle(.white.opacity(0.55)).lineLimit(1)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold)).foregroundStyle(.white.opacity(0.4))
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .shinyGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .help("Open \(module.title)")
    }
}

// MARK: Running

private struct SmartCareRunning: View {
    let model: SmartCareModel

    var body: some View {
        HStack(spacing: 48) {
            HeroIllustration(symbol: currentSymbol, theme: theme, size: 280, isBusy: true)
            VStack(alignment: .leading, spacing: 18) {
                Text("Looking after your Mac…").font(.display(26, weight: .semibold))
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(SmartCareModel.Essential.allCases) { essential in
                        StatusRow(essential: essential, status: model.statuses[essential] ?? .skipped,
                                  detail: model.statuses[essential] == .working ? model.runDetail : nil)
                    }
                }
            }
            .frame(width: 360, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var currentSymbol: String {
        SmartCareModel.Essential.allCases.first { model.statuses[$0] == .working }?.symbol ?? Module.smartCare.symbol
    }
}

private struct StatusRow: View {
    let essential: SmartCareModel.Essential
    let status: SmartCareModel.Status
    var detail: String?

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                switch status {
                case .working:
                    ProgressView().controlSize(.small)
                case .done:
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 20)).foregroundStyle(theme.iconGradient)
                case .failed:
                    Image(systemName: "exclamationmark.circle.fill").font(.system(size: 20)).foregroundStyle(.orange)
                case .waiting:
                    Circle().strokeBorder(.white.opacity(0.3), lineWidth: 1.5).frame(width: 18, height: 18)
                case .skipped:
                    Image(systemName: "minus.circle").font(.system(size: 19)).foregroundStyle(.white.opacity(0.3))
                }
            }
            .frame(width: 24, height: 24)
            EssentialIcon(essential: essential, size: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text(essential.title).font(.system(size: 14, weight: .semibold))
                Text(caption)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
                    .contentTransition(.opacity)
            }
        }
        .opacity(status == .skipped || status == .waiting ? 0.55 : 1)
    }

    private var caption: String {
        switch status {
        case .waiting: "Up next"
        case .working: detail ?? "Working…"
        case .done(let text), .failed(let text): text
        case .skipped: "Skipped"
        }
    }
}

// MARK: Done

private struct SmartCareDone: View {
    let model: SmartCareModel

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            HeroIllustration(symbol: "checkmark", theme: theme, size: 200)
            BigSize(bytes: model.freedBytes, size: 54)
            Text(model.tasksCompleted > 0 ? "freed · \(model.tasksCompleted) speed-up task\(model.tasksCompleted == 1 ? "" : "s") done" : "freed")
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.7))

            VStack(alignment: .leading, spacing: 12) {
                ForEach(SmartCareModel.Essential.allCases) { essential in
                    StatusRow(essential: essential, status: model.statuses[essential] ?? .skipped)
                }
            }
            .padding(18)
            .frame(maxWidth: 680, alignment: .leading)
            .shinyGlass(in: RoundedRectangle(cornerRadius: 20, style: .continuous))

            WorthALook(model: model)
                .frame(maxWidth: 680)
            Spacer()
            Button("Done") { model.finish() }
                .buttonStyle(.glassPill(prominent: true, tint: theme.accent))
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .padding(.bottom, 30)
        }
        .padding(.horizontal, 28)
    }
}

// MARK: Shared

private struct EssentialIcon: View {
    let essential: SmartCareModel.Essential
    let size: CGFloat

    var body: some View {
        Image(systemName: essential.symbol)
            .font(.system(size: size * 0.42, weight: .semibold))
            .frame(width: size, height: size)
            .background(essential.module.theme.iconGradient, in: RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
            .shadow(color: essential.module.theme.accent.opacity(0.4), radius: 6, y: 2)
    }
}

private struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .bold))
            .tracking(0.8)
            .foregroundStyle(.white.opacity(0.45))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 4)
    }
}
