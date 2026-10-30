import ShinyCore
import SwiftUI

struct UpdaterView: View {
    @Bindable var model: UpdaterModel

    var body: some View {
        ZStack {
            switch model.phase {
            case .idle:
                ModuleStartView(module: .updater, features: Module.updater.features, actionTitle: "Check") { model.check() }
            case .checking:
                ModuleBusyView(
                    module: .updater, title: "Checking for updates…",
                    detail: model.feedCount > 0 ? "\(model.checkedCount) of \(model.feedCount) update feeds" : "",
                    progress: model.feedCount > 0 ? Double(model.checkedCount) / Double(model.feedCount) : nil
                )
            case .ready:
                UpdateList(model: model)
            }
        }
        .transition(.opacity)
    }
}

private struct UpdateList: View {
    let model: UpdaterModel

    private var theme: ModuleTheme { Module.updater.theme }

    var body: some View {
        VStack(spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Updater").font(.display(24))
                if let lastChecked = model.lastChecked {
                    Text("Checked \(model.feedCount) apps \(lastChecked.formatted(.relative(presentation: .named)))")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
                Button("App Store Updates", systemImage: "bag") { NSWorkspace.shared.open(UpdaterModel.appStoreUpdates) }
                    .buttonStyle(.glassPill)
                Button("Check Again", systemImage: "arrow.clockwise") { model.check() }
                    .buttonStyle(.glassPill)
            }

            if model.updates.isEmpty {
                Spacer()
                HeroIllustration(symbol: "checkmark", theme: theme, size: 220)
                Text("Everything is up to date").font(.display(26))
                Text("No newer versions were found in your apps' update feeds.")
                    .foregroundStyle(.white.opacity(0.65))
                Spacer()
            } else {
                GlassCard(padding: 0) {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(model.updates) { update in
                                UpdateRow(model: model, update: update)
                                if update.id != model.updates.last?.id {
                                    Divider().overlay(.white.opacity(0.06)).padding(.leading, 74)
                                }
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
                Text("Apps from the App Store are updated from the App Store itself.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 18)
    }
}

private struct UpdateRow: View {
    let model: UpdaterModel
    let update: AppUpdate

    var body: some View {
        HStack(spacing: 14) {
            FileIconView(url: update.app.url, size: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(update.app.name).font(.system(size: 14, weight: .semibold))
                HStack(spacing: 6) {
                    Text(update.installedVersion).foregroundStyle(.white.opacity(0.55))
                    Image(systemName: "arrow.right").font(.system(size: 9, weight: .bold)).foregroundStyle(.white.opacity(0.4))
                    Text(update.latestVersion)
                        .fontWeight(.semibold)
                        .foregroundStyle(Module.updater.theme.iconGradient)
                }
                .font(.system(size: 12, design: .rounded))
            }
            Spacer()
            if let notes = update.releaseNotes {
                Button("What's New") { NSWorkspace.shared.open(notes) }
                    .buttonStyle(.glassPill)
            }
            Button("Update") { model.open(update) }
                .buttonStyle(.glassPill(prominent: true, tint: Module.updater.theme.accent))
                .help("Opens \(update.app.name) so its built-in updater can install the new version")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .contextMenu {
            if let download = update.download { Button("Download Directly") { NSWorkspace.shared.open(download) } }
            Button("Reveal App") { FileIcons.reveal([update.app.url]) }
        }
    }
}
