import ShinyCore
import SwiftUI

/// Root state shared by every window. Each module keeps its own model so results survive navigation.
@Observable
final class AppState {
    var selection: Module = .smartCare

    let junk = CleanupModel(module: .systemJunk, removalMode: .delete) { progress in
        JunkScanner.scan(progress: progress)
    }

    let trash = CleanupModel(
        module: .trash, removalMode: .delete, verb: .empty, honorsTrashPreference: false,
        confirmation: "Everything selected will be deleted permanently. This can't be undone."
    ) { progress in
        TrashScanner.scan(progress: progress)
    }

    let privacy = CleanupModel(
        module: .privacy, removalMode: .delete, honorsTrashPreference: false,
        confirmation: "Open browsers will be quit first. Cleared history and cookies can't be restored.",
        beforeClean: { await PrivacyModuleView.quitApps($0) }
    ) { progress in
        PrivacyScanner.scan(progress: progress)
    }

    let uninstaller = UninstallerModel()

    let leftovers = CleanupModel(module: .leftovers, removalMode: .trash, verb: .remove) { progress in
        OrphanFinder.scan(installed: AppScanner.installedApps(), progress: progress)
    }

    let updater = UpdaterModel()
    let largeFiles = LargeFilesModel()
    let spaceLens = SpaceLensModel()
    let maintenance = MaintenanceModel()
    let loginItems = LoginItemsModel()

    /// Short status shown next to a module in the sidebar, such as the size of junk found.
    func badge(for module: Module) -> String? {
        switch module {
        case .systemJunk: junk.badge
        case .trash: trash.badge
        case .privacy: privacy.badge
        case .leftovers: leftovers.badge
        case .largeFiles: largeFiles.badge
        case .spaceLens: spaceLens.badge
        case .maintenance: maintenance.badge
        case .loginItems: loginItems.badge
        case .updater: updater.badge
        case .uninstaller: uninstaller.phase == .ready ? "\(uninstaller.apps.count)" : nil
        default: nil
        }
    }

    #if DEBUG
    /// Read-only actions for the screenshot hook.
    func performDebugAction(_ action: String) {
        if selection == .uninstaller { uninstaller.load(); return }
        if selection == .largeFiles { largeFiles.scan(); return }
        if selection == .spaceLens { spaceLens.scan(); return }
        if selection == .maintenance { maintenance.showTasks(); return }
        if selection == .loginItems { loginItems.load(); return }
        if selection == .updater { updater.check(); return }
        guard let model = cleanupModel(for: selection) else { return }
        model.scan()
        if action == "review" {
            Task {
                while model.phase != .results { try? await Task.sleep(for: .milliseconds(100)) }
                model.isReviewing = true
            }
        }
    }
    #endif

    func cleanupModel(for module: Module) -> CleanupModel? {
        switch module {
        case .systemJunk: junk
        case .trash: trash
        case .privacy: privacy
        case .leftovers: leftovers
        default: nil
        }
    }
}
