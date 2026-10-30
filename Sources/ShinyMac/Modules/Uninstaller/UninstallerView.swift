import ShinyCore
import SwiftUI

struct UninstallerView: View {
    @Bindable var model: UninstallerModel

    var body: some View {
        ZStack {
            switch model.phase {
            case .idle:
                ModuleStartView(module: .uninstaller, features: Module.uninstaller.features, actionTitle: "View") { model.load() }
            case .loading:
                ModuleBusyView(module: .uninstaller, title: "Looking for apps…")
            case .ready:
                UninstallerBrowser(model: model)
            }
        }
        .transition(.opacity)
    }
}

private struct UninstallerBrowser: View {
    @Bindable var model: UninstallerModel

    var body: some View {
        VStack(spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Uninstaller").font(.display(24))
                Text("\(model.apps.count) apps · \(ByteFormat.string(model.totalAppsSize))")
                    .font(.system(size: 13))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
                Button("Refresh", systemImage: "arrow.clockwise") { model.load() }
                    .buttonStyle(.glassPill)
            }

            HStack(spacing: 14) {
                AppListPane(model: model).frame(width: 330)
                AppDetailPane(model: model)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 18)
    }
}

// MARK: - App list

private struct AppListPane: View {
    @Bindable var model: UninstallerModel

    var body: some View {
        GlassCard(padding: 0) {
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.white.opacity(0.5))
                    TextField("Search apps", text: $model.search)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                    Menu {
                        Picker("Sort by", selection: $model.sort) {
                            ForEach(UninstallerModel.Sort.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.inline)
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                ScrollView(.horizontal) {
                    HStack(spacing: 6) {
                        ForEach(UninstallerModel.Filter.allCases) { filter in
                            FilterChip(
                                title: filter.rawValue, count: model.count(for: filter), isOn: model.filter == filter,
                                tint: Module.uninstaller.theme.accent
                            ) {
                                withAnimation(.smooth(duration: 0.25)) { model.filter = filter }
                            }
                        }
                    }
                }
                .scrollIndicators(.never)
            }
            .padding(12)

            Divider().overlay(.white.opacity(0.1))

            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(model.visibleApps) { app in
                        AppRow(app: app, size: model.sizes[app.url], isSelected: model.selectedApp?.id == app.id) {
                            model.select(app)
                        }
                    }
                }
                .padding(8)
            }
            .overlay {
                if model.visibleApps.isEmpty {
                    Text("No apps match").foregroundStyle(.white.opacity(0.5))
                }
            }
        }
    }
}

struct FilterChip: View {
    let title: String
    var count: Int?
    let isOn: Bool
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Text(title)
                if let count {
                    Text("\(count)").monospacedDigit().foregroundStyle(.white.opacity(isOn ? 0.85 : 0.5))
                }
            }
            .font(.system(size: 12, weight: .semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(isOn ? AnyShapeStyle(tint.opacity(0.55)) : AnyShapeStyle(.white.opacity(0.08))))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct AppRow: View {
    let app: InstalledApp
    let size: Int64?
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                FileIconView(url: app.url, size: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                Group {
                    if let size {
                        Text(ByteFormat.string(size))
                    } else {
                        ProgressView().controlSize(.mini)
                    }
                }
                .font(.system(size: 12, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.white.opacity(isSelected ? 0.15 : (isHovering ? 0.06 : 0)))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }

    private var subtitle: String {
        let version = app.version.map { "v\($0)" } ?? ""
        guard let lastUsed = app.lastUsed else { return version }
        return "\(version) · \(lastUsed.formatted(.relative(presentation: .named)))"
    }
}

// MARK: - Detail

private struct AppDetailPane: View {
    @Bindable var model: UninstallerModel
    @State private var confirmUninstall = false
    @State private var confirmReset = false

    private var theme: ModuleTheme { Module.uninstaller.theme }

    var body: some View {
        GlassCard(padding: 0) {
            if let outcome = model.outcome {
                OutcomeView(model: model, outcome: outcome)
            } else if let app = model.selectedApp {
                VStack(spacing: 0) {
                    header(for: app).padding(18)
                    Divider().overlay(.white.opacity(0.1))
                    fileList
                    Divider().overlay(.white.opacity(0.1))
                    footer(for: app).padding(14)
                }
            } else {
                Text("Select an app").foregroundStyle(.white.opacity(0.5))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func header(for app: InstalledApp) -> some View {
        HStack(spacing: 16) {
            FileIconView(url: app.url, size: 64)
            VStack(alignment: .leading, spacing: 4) {
                Text(app.name).font(.display(22))
                Text(app.bundleID)
                    .font(.system(size: 11.5, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
                    .textSelection(.enabled)
                HStack(spacing: 6) {
                    StatPill(symbol: "internaldrive", text: ByteFormat.string(model.filesSize))
                    if let version = app.version { StatPill(symbol: "tag", text: version) }
                    if let lastUsed = app.lastUsed {
                        StatPill(symbol: "clock", text: "Opened \(lastUsed.formatted(.relative(presentation: .named)))")
                    }
                    if app.isAppStore { StatPill(symbol: "bag", text: "App Store") }
                }
                .padding(.top, 2)
            }
            Spacer()
        }
    }

    private var fileList: some View {
        ScrollView {
            if model.isFindingFiles {
                ProgressView("Finding related files…")
                    .controlSize(.small)
                    .padding(40)
                    .frame(maxWidth: .infinity)
            } else {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    ForEach(model.groupedFiles, id: \.kind) { group in
                        Section {
                            ForEach(group.files) { file in
                                FileRow(model: model, file: file)
                            }
                        } header: {
                            HStack(spacing: 6) {
                                Image(systemName: group.kind.symbol)
                                Text(group.kind.rawValue.uppercased()).tracking(0.6)
                                Spacer()
                                Text(ByteFormat.string(group.files.reduce(0) { $0 + $1.size })).monospacedDigit()
                            }
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundStyle(.white.opacity(0.5))
                            .padding(.horizontal, 18)
                            .padding(.top, 12)
                            .padding(.bottom, 4)
                        }
                    }
                }
                .padding(.bottom, 8)
            }
        }
    }

    private func footer(for app: InstalledApp) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text("\(model.selectedFiles.count) of \(model.files.count) items selected")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.6))
                Text(ByteFormat.string(model.selectedFilesSize))
                    .font(.display(18, weight: .semibold))
                    .monospacedDigit()
            }
            Spacer()
            Button("Reset App", systemImage: "arrow.counterclockwise") { confirmReset = true }
                .buttonStyle(.glassPill)
                .disabled(model.isRemoving || !model.selectedFiles.contains { $0.kind != .application })
                .help("Remove the app's data and settings but keep the app")
            Button {
                confirmUninstall = true
            } label: {
                Label(model.isRemoving ? "Removing…" : "Uninstall", systemImage: "trash")
            }
            .buttonStyle(.glassPill(prominent: true, tint: theme.accent))
            .disabled(model.isRemoving || model.selectedFiles.isEmpty)
        }
        .confirmationDialog("Uninstall \(app.name)?", isPresented: $confirmUninstall, titleVisibility: .visible) {
            Button("Move \(model.selectedFiles.count) Items to Trash", role: .destructive) { model.remove(reset: false) }
        } message: {
            Text("\(ByteFormat.string(model.selectedFilesSize)) will be moved to the Trash. If the app is running it will be quit first.")
        }
        .confirmationDialog("Reset \(app.name)?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Reset", role: .destructive) { model.remove(reset: true) }
        } message: {
            Text("Settings, caches and data are moved to the Trash. The app stays installed and starts fresh.")
        }
    }
}

private struct FileRow: View {
    let model: UninstallerModel
    let file: Leftover
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 10) {
            CheckCircle(state: model.fileSelection.contains(file.url) ? .on : .off, tint: Module.uninstaller.theme.accent, size: 16)
            FileIconView(url: file.url, size: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(file.url.lastPathComponent).font(.system(size: 12.5, weight: .medium)).lineLimit(1)
                Text(Paths.abbreviated(file.url.deletingLastPathComponent()))
                    .font(.system(size: 10.5))
                    .foregroundStyle(.white.opacity(0.45))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            if file.isSystemWide && file.kind != .application {
                Image(systemName: "lock.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.4))
                    .help("System-wide file; may ask for your password")
            }
            Spacer(minLength: 6)
            Text(ByteFormat.string(file.size))
                .font(.system(size: 12, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 6)
        .background(.white.opacity(isHovering ? 0.05 : 0))
        .contentShape(Rectangle())
        .onTapGesture { model.toggle(file) }
        .onHover { isHovering = $0 }
        .contextMenu { Button("Reveal in Finder") { FileIcons.reveal([file.url]) } }
    }
}

private struct OutcomeView: View {
    let model: UninstallerModel
    let outcome: UninstallerModel.Outcome

    var body: some View {
        VStack(spacing: 14) {
            Spacer()
            HeroIllustration(symbol: "checkmark", theme: Module.uninstaller.theme, size: 190)
            Text(outcome.wasReset ? "\(outcome.appName) was reset" : "\(outcome.appName) was uninstalled")
                .font(.display(22))
            Text("\(ByteFormat.string(outcome.report.removedBytes)) moved to the Trash")
                .foregroundStyle(.white.opacity(0.7))
            if !outcome.report.failures.isEmpty {
                VStack(spacing: 8) {
                    Label("\(outcome.report.failures.count) items need your attention", systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(Color(hex: 0xFFD479))
                    if outcome.report.failures.contains(where: \.needsAdmin) {
                        Button("Remove with Administrator Password…", systemImage: "lock.fill") { model.retryAsAdmin() }
                            .buttonStyle(.glassPill)
                            .disabled(model.isRemoving)
                    }
                }
                .padding(.top, 6)
            }
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }
}

struct StatPill: View {
    let symbol: String
    let text: String

    var body: some View {
        Label(text, systemImage: symbol)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.white.opacity(0.75))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(.white.opacity(0.08), in: Capsule())
    }
}
