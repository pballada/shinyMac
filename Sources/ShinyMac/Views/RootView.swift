import AppKit
import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var state
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        ZStack {
            AuroraBackground(section: state.selection.section)

            HStack(spacing: 0) {
                SidebarView()

                VStack(spacing: 0) {
                    VStack(spacing: 8) {
                        UpdateBanner(model: SelfUpdateModel.shared)
                        FullDiskAccessBanner()
                        if let origin = state.returnTo, origin != state.selection {
                            HStack {
                                Button(origin.title, systemImage: "chevron.left") { state.goBack() }
                                    .buttonStyle(.glassPill)
                                    .help("Back to \(origin.title)")
                                Spacer()
                            }
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 4)
                    ZStack {
                        DetailView(module: state.selection)
                            .id(state.selection)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.985)),
                                removal: .opacity
                            ))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(.top, 28)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            openApps(urls)
        }
        .onReceive(NotificationCenter.default.publisher(for: .shinyMacOpenApps)) { note in
            openApps(note.object as? [URL] ?? [])
        }
        .background(TrafficLightInset())
        .ignoresSafeArea()
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
        .animation(.smooth(duration: 0.25), value: state.selection)
        #if DEBUG
        .onAppear {
            if let id = ProcessInfo.processInfo.environment["SHINYMAC_WINDOW"] { openWindow(id: id) }
        }
        #endif
    }
}

extension RootView {
    /// Apps dropped on the window or the Dock icon open in the Uninstaller.
    @discardableResult
    func openApps(_ urls: [URL]) -> Bool {
        guard let app = urls.first(where: { $0.pathExtension == "app" }) else { return false }
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
        case .cloud:
            CleanupModuleView(model: state.cloud)
        case .trash:
            TrashModuleView(model: state.trash)
        case .privacy:
            PrivacyModuleView(model: state.privacy)
        case .appPermissions:
            AppPermissionsView(model: state.appPermissions)
        case .uninstaller:
            UninstallerView(model: state.uninstaller)
        case .leftovers:
            CleanupModuleView(model: state.leftovers)
        case .updater:
            UpdaterView(model: state.updater)
        case .extensions:
            CleanupModuleView(model: state.extensions)
        case .largeFiles:
            LargeFilesView(model: state.largeFiles)
        case .spaceLens:
            SpaceLensView(model: state.spaceLens)
        case .duplicates:
            CleanupModuleView(model: state.duplicates)
        case .xcode:
            CleanupModuleView(model: state.xcode)
        case .homebrew:
            CleanupModuleView(model: state.homebrew)
        case .devTools:
            CleanupModuleView(model: state.devTools)
        case .maintenance:
            MaintenanceView(model: state.maintenance)
        case .loginItems:
            LoginItemsView(model: state.loginItems)
        case .hiddenSettings:
            HiddenSettingsView(model: state.hiddenSettings)
        }
    }
}
