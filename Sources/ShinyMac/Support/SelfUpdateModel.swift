import AppKit
import ShinyCore
import SwiftUI

/// Checks GitHub for new ShinyMac releases and installs them. Shared by the sidebar, Settings and the app menu.
@Observable
final class SelfUpdateModel {
    static let shared = SelfUpdateModel()

    enum Phase: Equatable {
        case idle, checking, upToDate
        case available(SelfUpdate.Release)
        case installing(SelfUpdate.Release)
        case readyToRelaunch(String)
        case failed(String)
    }

    private(set) var phase: Phase = .idle

    /// Updating replaces the app bundle, so it only works from an installed copy (not `swift run`).
    var isSupported: Bool {
        Bundle.main.bundleURL.pathExtension == "app" && Bundle.main.bundleIdentifier == SelfUpdate.bundleIdentifier
    }

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    /// Checks in the background at launch and every few hours, at most once a day.
    func startAutomaticChecks() {
        Task {
            while !Task.isCancelled {
                await checkIfDue()
                try? await Task.sleep(for: .seconds(6 * 3600))
            }
        }
    }

    private func checkIfDue() async {
        let defaults = UserDefaults.standard
        guard isSupported, defaults.bool(forKey: Preferences.Key.autoCheckUpdates, default: true) else { return }
        let last = defaults.object(forKey: Preferences.Key.lastUpdateCheck) as? Date ?? .distantPast
        guard Date.now.timeIntervalSince(last) > 23 * 3600 else { return }
        await check(userInitiated: false)
        if case .available = phase, defaults.bool(forKey: Preferences.Key.autoInstallUpdates, default: false) {
            await install()
        }
    }

    func check(userInitiated: Bool = true) async {
        guard isSupported else {
            if userInitiated { phase = .failed("Updates work in the installed app, not in development builds.") }
            return
        }
        switch phase {
        case .checking, .installing, .readyToRelaunch: return
        default: break
        }
        withAnimation(.smooth) { phase = .checking }
        do {
            let release = try await SelfUpdate.check(currentVersion: currentVersion)
            UserDefaults.standard.set(Date.now, forKey: Preferences.Key.lastUpdateCheck)
            withAnimation(.smooth) { phase = release.map(Phase.available) ?? .upToDate }
        } catch {
            // Background checks fail quietly (offline, rate limited); a manual check says why.
            withAnimation(.smooth) { phase = userInitiated ? .failed(error.localizedDescription) : .idle }
        }
    }

    func install() async {
        guard case .available(let release) = phase else { return }
        withAnimation(.smooth) { phase = .installing(release) }
        do {
            try await SelfUpdate.install(release, replacing: Bundle.main.bundleURL)
            withAnimation(.smooth) { phase = .readyToRelaunch(release.version) }
        } catch {
            withAnimation(.smooth) { phase = .failed(error.localizedDescription) }
        }
    }

    #if DEBUG
    /// Screenshot hook: pretend an update is waiting.
    func debugPretendAvailable(_ version: String) {
        phase = .available(.init(version: version, notes: "", page: URL(string: "https://github.com/pballada/shinyMac/releases")!,
                                 download: URL(string: "https://example.com")!))
    }
    #endif

    func relaunch() {
        guard (try? SelfUpdate.relaunch(Bundle.main.bundleURL)) != nil else { return }
        NSApp.terminate(nil)
    }

    /// One line for Settings.
    var status: String {
        switch phase {
        case .idle: "Version \(currentVersion)"
        case .checking: "Checking…"
        case .upToDate: "ShinyMac \(currentVersion) is the latest version."
        case .available(let release): "ShinyMac \(release.version) is available."
        case .installing(let release): "Installing \(release.version)…"
        case .readyToRelaunch(let version): "\(version) is installed. Relaunch to finish."
        case .failed(let message): message
        }
    }
}

/// Banner across the top of the main window while an update is available, installing or waiting for a relaunch.
struct UpdateBanner: View {
    let model: SelfUpdateModel
    /// "Later" hides an available update until the next launch; installing and relaunching always show.
    @State private var dismissedVersion: String?

    private var theme: ModuleTheme { SidebarSection.home.theme }

    var body: some View {
        Group {
            switch model.phase {
            case .available(let release) where release.version != dismissedVersion:
                banner(
                    title: "ShinyMac \(release.version) is available",
                    detail: "You have \(model.currentVersion). Installing takes a few seconds and keeps your settings.",
                    link: release.page
                ) {
                    Button("Later") { withAnimation(.smooth) { dismissedVersion = release.version } }
                        .buttonStyle(.glassPill)
                    Button("Install Update") { Task { await model.install() } }
                        .buttonStyle(.glassPill(prominent: true, tint: theme.accent))
                }
            case .installing(let release):
                banner(title: "Installing ShinyMac \(release.version)…", detail: "Checking the signature and replacing the app.") {
                    ProgressView().controlSize(.small)
                }
            case .readyToRelaunch(let version):
                banner(title: "ShinyMac \(version) is ready", detail: "Relaunch to start using it. It only takes a moment.") {
                    Button("Relaunch Now") { model.relaunch() }
                        .buttonStyle(.glassPill(prominent: true, tint: theme.accent))
                }
            default:
                EmptyView()
            }
        }
        .animation(.smooth, value: model.phase)
    }

    private func banner(title: String, detail: String, link: URL? = nil, @ViewBuilder actions: () -> some View) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 26))
                .foregroundStyle(theme.iconGradient)
                .symbolEffect(.bounce, options: .nonRepeating)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 14, weight: .semibold))
                HStack(spacing: 6) {
                    Text(detail)
                    if let link {
                        Link("What's new", destination: link).underline()
                    }
                }
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.65))
                .lineLimit(1)
            }
            .layoutPriority(1)
            Spacer(minLength: 12)
            HStack(spacing: 8) { actions() }
                .controlSize(.regular)
                .fixedSize()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(theme.accent.opacity(0.16), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shinyGlass(in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}
