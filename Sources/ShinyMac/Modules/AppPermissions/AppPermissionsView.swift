import ShinyCore
import SwiftUI

struct AppPermissionsView: View {
    @Bindable var model: AppPermissionsModel

    var body: some View {
        ZStack {
            switch model.phase {
            case .idle:
                ModuleStartView(module: .appPermissions, features: Module.appPermissions.features, actionTitle: "View") { model.load() }
            case .loading:
                ModuleBusyView(module: .appPermissions, title: "Reading privacy permissions…")
            case .needsAccess:
                NeedsAccessView(model: model)
            case .ready:
                PermissionsBrowser(model: model)
            }
        }
        .transition(.opacity)
    }
}

private struct NeedsAccessView: View {
    let model: AppPermissionsModel

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            HeroIllustration(symbol: "lock.shield.fill", theme: Module.appPermissions.theme, size: 190)
            Text("Full Disk Access needed").font(.display(24))
            Text("macOS keeps the list of app permissions in a protected database. Give ShinyMac Full Disk Access to see it.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.7))
                .frame(maxWidth: 420)
            HStack(spacing: 10) {
                OpenFullDiskAccessButton()
                Button("Try Again", systemImage: "arrow.clockwise") { model.load() }
                    .buttonStyle(.glassPill)
            }
            Spacer()
        }
        .padding(24)
    }
}

private struct PermissionsBrowser: View {
    @Bindable var model: AppPermissionsModel

    private var theme: ModuleTheme { Module.appPermissions.theme }

    var body: some View {
        VStack(spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("App Permissions").font(.display(24))
                Text("\(model.totalGrants) permissions granted")
                    .font(.system(size: 13))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
                Button("Refresh", systemImage: "arrow.clockwise") { model.load() }
                    .buttonStyle(.glassPill)
            }

            HStack(spacing: 14) {
                GlassCard(padding: 8) {
                    ScrollView {
                        VStack(spacing: 2) {
                            ForEach(AppPermissions.services) { service in
                                ServiceRow(
                                    service: service, count: model.entries(for: service).count,
                                    isSelected: model.selectedServiceID == service.id
                                ) {
                                    withAnimation(.smooth(duration: 0.25)) { model.selectedServiceID = service.id }
                                }
                            }
                        }
                    }
                }
                .frame(width: 250)

                GlassCard(padding: 0) {
                    let service = model.selectedService
                    let entries = model.entries(for: service)
                    VStack(spacing: 0) {
                        HStack(spacing: 12) {
                            Image(systemName: service.symbol)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(theme.iconGradient)
                                .frame(width: 40, height: 40)
                                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(service.title).font(.display(18))
                                Text(entries.count == 1 ? "1 app allowed" : "\(entries.count) apps allowed")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                            Spacer()
                            Button("Change in Settings", systemImage: "gearshape") { NSWorkspace.shared.open(service.settingsURL) }
                                .buttonStyle(.glassPill(prominent: true, tint: theme.accent))
                                .help("Only System Settings can revoke a permission")
                        }
                        .padding(16)
                        Divider().overlay(.white.opacity(0.1))
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(entries) { GrantRow(entry: $0) }
                            }
                            .padding(.vertical, 6)
                        }
                        .overlay {
                            if entries.isEmpty {
                                VStack(spacing: 8) {
                                    Image(systemName: "checkmark.seal.fill").font(.system(size: 30)).foregroundStyle(theme.accent)
                                    Text("No apps have this permission").foregroundStyle(.white.opacity(0.7))
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 18)
    }
}

private struct ServiceRow: View {
    let service: AppPermissions.Service
    let count: Int
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: service.symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Module.appPermissions.theme.iconGradient)
                    .frame(width: 26)
                Text(service.title).font(.system(size: 13, weight: .medium))
                Spacer()
                Text("\(count)")
                    .font(.system(size: 12, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(count == 0 ? 0.35 : 0.75))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.white.opacity(isSelected ? 0.15 : (isHovering ? 0.06 : 0)))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}

private struct GrantRow: View {
    let entry: AppPermissionsModel.Entry
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            if let url = entry.url {
                FileIconView(url: url, size: 30)
            } else {
                Image(systemName: "questionmark.app.dashed")
                    .font(.system(size: 20))
                    .frame(width: 30, height: 30)
                    .foregroundStyle(.white.opacity(0.5))
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.name).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.45))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            if entry.url == nil {
                Text("NOT INSTALLED")
                    .font(.system(size: 9.5, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .foregroundStyle(Color(hex: 0xFFD479))
                    .background(Color(hex: 0xFFD479).opacity(0.15), in: Capsule())
                    .help("This permission belongs to an app that's no longer on your Mac")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
        .background(.white.opacity(isHovering ? 0.05 : 0))
        .onHover { isHovering = $0 }
        .contextMenu {
            if let url = entry.url { Button("Reveal in Finder") { FileIcons.reveal([url]) } }
        }
    }

    private var subtitle: String {
        let since = entry.grant.lastModified.map { " · allowed \($0.formatted(.relative(presentation: .named)))" } ?? ""
        return entry.grant.client + since
    }
}
