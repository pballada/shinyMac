import AppKit
import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var state
    @AppStorage(Preferences.Key.hasOnboarded) private var hasOnboarded = false

    var body: some View {
        ZStack {
            AuroraBackground(section: hasOnboarded ? state.selection.section : .home)

            if hasOnboarded {
                HStack(spacing: 0) {
                    SidebarView()

                    ZStack {
                        DetailView(module: state.selection)
                            .id(state.selection)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.985)),
                                removal: .opacity
                            ))
                    }
                    .padding(.top, 28)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .transition(.opacity)
            } else {
                OnboardingView { withAnimation(.smooth) { hasOnboarded = true } }
                    .transition(.opacity)
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            openApps(urls)
        }
        .onReceive(NotificationCenter.default.publisher(for: .shinyMacOpenApps)) { note in
            openApps(note.object as? [URL] ?? [])
        }
        .ignoresSafeArea()
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
        .animation(.smooth(duration: 0.4), value: state.selection)
    }
}

extension RootView {
    /// Apps dropped on the window or the Dock icon open in the Uninstaller.
    @discardableResult
    func openApps(_ urls: [URL]) -> Bool {
        guard let app = urls.first(where: { $0.pathExtension == "app" }), hasOnboarded else { return false }
        guard state.uninstaller.reveal(appAt: app) else { return false }
        state.selection = .uninstaller
        NSApp.activate()
        return true
    }
}

extension Notification.Name {
    /// Posted by the app delegate with `[URL]` when apps are dropped on the Dock icon.
    static let shinyMacOpenApps = Notification.Name("ShinyMacOpenApps")
}

/// Routes the selected module to its screen.
struct DetailView: View {
    let module: Module
    @Environment(AppState.self) private var state

    var body: some View {
        switch module {
        case .smartCare:
            SmartCareView(model: state.smartCare)
        case .systemJunk:
            CleanupModuleView(model: state.junk)
        case .trash:
            TrashModuleView(model: state.trash)
        case .privacy:
            PrivacyModuleView(model: state.privacy)
        case .uninstaller:
            UninstallerView(model: state.uninstaller)
        case .leftovers:
            CleanupModuleView(model: state.leftovers)
        case .updater:
            UpdaterView(model: state.updater)
        case .largeFiles:
            LargeFilesView(model: state.largeFiles)
        case .spaceLens:
            SpaceLensView(model: state.spaceLens)
        case .shredder:
            ShredderView(model: state.shredder)
        case .maintenance:
            MaintenanceView(model: state.maintenance)
        case .loginItems:
            LoginItemsView(model: state.loginItems)
        }
    }
}
