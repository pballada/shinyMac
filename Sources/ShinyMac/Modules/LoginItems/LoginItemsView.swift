import ShinyCore
import SwiftUI

struct LoginItemsView: View {
    @Bindable var model: LoginItemsModel

    var body: some View {
        ZStack {
            switch model.phase {
            case .idle:
                ModuleStartView(module: .loginItems, features: Module.loginItems.features, actionTitle: "View") { model.load() }
            case .loading:
                ModuleBusyView(module: .loginItems, title: "Reading launch agents…")
            case .ready:
                LoginItemsList(model: model)
            }
        }
        .transition(.opacity)
    }
}

private struct LoginItemsList: View {
    let model: LoginItemsModel
    @State private var pendingRemoval: [LaunchItem] = []

    private var theme: ModuleTheme { Module.loginItems.theme }

    var body: some View {
        VStack(spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Login Items").font(.display(24))
                Text("\(model.items.count) background items")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
                Button("Login Items Settings", systemImage: "gearshape") { NSWorkspace.shared.open(LoginItemsModel.loginItemsSettings) }
                    .buttonStyle(.glassPill)
                Button("Refresh", systemImage: "arrow.clockwise") { model.load() }
                    .buttonStyle(.glassPill)
            }

            if !model.brokenItems.isEmpty {
                PermissionBanner(
                    title: "\(model.brokenItems.count) broken item\(model.brokenItems.count == 1 ? "" : "s")",
                    message: "These start programs that no longer exist, usually left behind by deleted apps.",
                    symbol: "bandage.fill", tint: Color(hex: 0xFF8FA3)
                ) {
                    Button("Remove Broken") { pendingRemoval = model.brokenItems }
                        .buttonStyle(.glassPill(prominent: true, tint: theme.accent))
                }
            }

            if let message = model.message {
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            GlassCard(padding: 0) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                        ForEach(LaunchItem.Scope.allCases, id: \.self) { scope in
                            let items = model.items(in: scope)
                            if !items.isEmpty {
                                Section {
                                    ForEach(items) { item in
                                        LaunchItemRow(model: model, item: item) { pendingRemoval = [item] }
                                    }
                                } header: {
                                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                                        Text(scope.rawValue.uppercased())
                                            .font(.system(size: 10.5, weight: .bold))
                                            .tracking(0.7)
                                        Text(scope.detail).font(.system(size: 11))
                                        Spacer()
                                    }
                                    .foregroundStyle(.white.opacity(0.5))
                                    .padding(.horizontal, 18)
                                    .padding(.top, 14)
                                    .padding(.bottom, 6)
                                }
                            }
                        }
                    }
                    .padding(.bottom, 8)
                }
                .overlay {
                    if model.items.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "checkmark.seal.fill").font(.system(size: 30)).foregroundStyle(theme.accent)
                            Text("No third-party background items").foregroundStyle(.white.opacity(0.7))
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 18)
        .confirmationDialog(
            "Remove \(pendingRemoval.count) background item\(pendingRemoval.count == 1 ? "" : "s")?",
            isPresented: Binding(get: { !pendingRemoval.isEmpty }, set: { if !$0 { pendingRemoval = [] } }),
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) { model.remove(pendingRemoval) }
        } message: {
            Text("They are stopped and their launch files removed. System-wide items ask for your password.")
        }
    }
}

private struct LaunchItemRow: View {
    let model: LoginItemsModel
    let item: LaunchItem
    let onRemove: () -> Void
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            icon
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                    statusPill
                }
                Text(item.label)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(1)
                if let program = item.program {
                    Text(program)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.white.opacity(0.35))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            Spacer(minLength: 8)
            if model.busyItems.contains(item.id) {
                ProgressView().controlSize(.small)
            } else {
                Toggle("Enabled", isOn: Binding(get: { !item.isDisabled }, set: { model.setEnabled(item, $0) }))
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .tint(Module.loginItems.theme.accent)
                    .help(item.scope.isPrivileged ? "Asks for your password" : "Start or stop this item")
                Button(action: onRemove) {
                    Image(systemName: "trash").frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(isHovering ? 0.8 : 0.4))
                .help("Remove")
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .background(.white.opacity(isHovering ? 0.05 : 0))
        .onHover { isHovering = $0 }
        .contextMenu {
            Button("Reveal Launch File") { FileIcons.reveal([item.plistURL]) }
            if let app = item.owningApp, !item.isBroken { Button("Reveal App") { FileIcons.reveal([app]) } }
        }
    }

    private var title: String {
        if let app = item.owningApp { return app.deletingPathExtension().lastPathComponent }
        return FileIcons.displayName(for: URL(filePath: "/" + item.label))
    }

    @ViewBuilder private var icon: some View {
        if let app = item.owningApp, !item.isBroken {
            FileIconView(url: app, size: 32)
        } else {
            Image(systemName: item.isBroken ? "bandage.fill" : "gearshape.2.fill")
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 32, height: 32)
                .background(Module.loginItems.theme.iconGradient.opacity(item.isBroken ? 0.5 : 0.9), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    @ViewBuilder private var statusPill: some View {
        if item.isBroken {
            Pill(text: "Broken", color: Color(hex: 0xFF7A85))
        } else if item.isDisabled {
            Pill(text: "Disabled", color: .gray)
        } else if item.isLoaded {
            Pill(text: "Running", color: Color(hex: 0x4BE3A8))
        } else if item.runAtLoad || item.keepAlive {
            Pill(text: "At login", color: Module.loginItems.theme.accent)
        }
    }
}

private struct Pill: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 9.5, weight: .bold))
            .textCase(.uppercase)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .foregroundStyle(color)
            .background(color.opacity(0.18), in: Capsule())
    }
}
