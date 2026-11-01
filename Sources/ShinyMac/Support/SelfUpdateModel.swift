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

/// Sidebar card shown while an update is available, installing or waiting for a relaunch.
struct UpdateBanner: View {
    let model: SelfUpdateModel

    var body: some View {
        switch model.phase {
        case .available(let release):
            card(title: "ShinyMac \(release.version) is available", detail: "See what's new on GitHub", link: release.page) {
                Button("Install") { Task { await model.install() } }
            }
        case .installing(let release):
            card(title: "Installing \(release.version)…", detail: "Checking the signature and replacing the app") {
                ProgressView().controlSize(.small)
            }
        case .readyToRelaunch(let version):
            card(title: "\(version) is ready", detail: "Relaunch to start using it") {
                Button("Relaunch") { model.relaunch() }
            }
        default:
            EmptyView()
        }
    }

    private func card(title: String, detail: String, link: URL? = nil, @ViewBuilder action: () -> some View) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(SidebarSection.home.theme.iconGradient)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 12, weight: .semibold)).lineLimit(2)
                if let link {
                    Link(detail, destination: link).font(.system(size: 11)).foregroundStyle(.white.opacity(0.6))
                } else {
                    Text(detail).font(.system(size: 11)).foregroundStyle(.white.opacity(0.6))
                }
            }
            Spacer(minLength: 4)
            action()
                .buttonStyle(.glassPill(prominent: true, tint: SidebarSection.home.theme.accent))
                .controlSize(.small)
        }
        .padding(12)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
