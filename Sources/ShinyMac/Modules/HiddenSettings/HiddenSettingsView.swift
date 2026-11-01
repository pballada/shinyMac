import ShinyCore
import SwiftUI

struct HiddenSettingsView: View {
    @Bindable var model: HiddenSettingsModel
    @State private var confirmRestore = false

    private var theme: ModuleTheme { Module.hiddenSettings.theme }

    var body: some View {
        VStack(spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Hidden Settings").font(.display(24))
                Text(model.customizedCount == 0 ? "All at macOS defaults" : "\(model.customizedCount) changed")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.6))
                    .contentTransition(.numericText())
                Spacer()
                Button("Restore Defaults", systemImage: "arrow.uturn.backward") { confirmRestore = true }
                    .buttonStyle(.glassPill)
                    .disabled(model.customizedCount == 0)
            }

            HStack(spacing: 6) {
                ForEach(HiddenSettings.Category.allCases) { category in
                    FilterChip(
                        title: category.rawValue,
                        count: HiddenSettings.tweaks.filter { $0.category == category && model.isCustomized($0) }.count,
                        isOn: model.category == category, tint: theme.accent
                    ) {
                        withAnimation(.smooth(duration: 0.25)) { model.category = category }
                    }
                }
                Spacer()
            }

            GlassCard(padding: 6) {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(model.visibleTweaks) { tweak in
                            TweakRow(model: model, tweak: tweak)
                        }
                    }
                }
                .scrollIndicators(.never)
            }

            Label(footnote, systemImage: "info.circle")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.55))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: 820)
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 18)
        .confirmationDialog("Restore every hidden setting to the macOS default?", isPresented: $confirmRestore, titleVisibility: .visible) {
            Button("Restore \(model.customizedCount) Settings") { model.restoreDefaults() }
        } message: {
            Text("Finder, the Dock and screenshots restart to pick up the change.")
        }
    }

    private var footnote: String {
        switch model.category {
        case .finder: "Finder restarts to apply changes. Open windows come back."
        case .dock: "The Dock restarts to apply changes."
        case .screenshots: "Applies to the next screenshot you take."
        case .system: "Applies to apps you open after the change."
        }
    }
}

private struct TweakRow: View {
    let model: HiddenSettingsModel
    let tweak: HiddenSettings.Tweak
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: Self.symbols[tweak.id] ?? tweak.category.symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Module.hiddenSettings.theme.iconGradient)
                .frame(width: 32, height: 32)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(tweak.title).font(.system(size: 13.5, weight: .semibold))
                    if model.isCustomized(tweak) {
                        Circle()
                            .fill(Module.hiddenSettings.theme.accent)
                            .frame(width: 6, height: 6)
                            .help("Changed from the macOS default")
                    }
                }
                Text(tweak.detail)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            control
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(.white.opacity(isHovering ? 0.05 : 0), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onHover { isHovering = $0 }
    }

    static let symbols: [String: String] = [
        "finderHiddenFiles": "eye.fill", "finderExtensions": "doc.text.fill", "finderPathBar": "point.topleft.down.to.point.bottomright.curvepath.fill",
        "finderStatusBar": "info.circle.fill", "finderPosixTitle": "text.cursor", "finderFoldersFirst": "folder.fill",
        "finderExtensionWarning": "exclamationmark.triangle.fill", "finderQuit": "xmark.circle.fill",
        "dsStoreNetwork": "network", "dsStoreUSB": "externaldrive.fill",
        "dockAutohideDelay": "timer", "dockAutohideSpeed": "hare.fill", "dockHiddenApps": "eye.slash.fill",
        "dockStaticOnly": "app.badge.fill", "dockScrollToOpen": "scroll.fill", "spacesReorder": "rectangle.3.group.fill",
        "screenshotFormat": "photo.fill", "screenshotShadow": "shadow", "screenshotDate": "calendar",
        "screenshotThumbnail": "rectangle.inset.bottomright.filled",
        "expandSavePanel": "square.and.arrow.down.fill", "expandPrintPanel": "printer.fill", "saveToICloud": "icloud.fill",
        "pressAndHold": "keyboard.fill", "windowAnimations": "macwindow.on.rectangle", "textEditPlain": "doc.plaintext.fill",
    ]

    @ViewBuilder private var control: some View {
        switch tweak.kind {
        case .toggle:
            Toggle("", isOn: Binding(get: { model.isOn(tweak) }, set: { model.set(tweak, on: $0) }))
                .toggleStyle(.switch)
                .tint(Module.hiddenSettings.theme.accent)
                .labelsHidden()
        case .choice(let options):
            Picker("", selection: Binding(
                get: { model.selectedOption(tweak) ?? options[0] },
                set: { model.select(tweak, option: $0) }
            )) {
                ForEach(options) { Text($0.title).tag($0) }
            }
            .labelsHidden()
            .fixedSize()
        }
    }
}
