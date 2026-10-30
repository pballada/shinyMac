import ShinyCore
import SwiftUI

/// Root state shared by every window. Each module keeps its own model so results survive navigation.
@Observable
final class AppState {
    var selection: Module = .smartCare

    let junk = CleanupModel(module: .systemJunk, removalMode: .delete) { progress in
        JunkScanner.scan(progress: progress)
    }

    /// Short status shown next to a module in the sidebar, such as the size of junk found.
    func badge(for module: Module) -> String? {
        switch module {
        case .systemJunk: junk.badge
        default: nil
        }
    }

    #if DEBUG
    /// Read-only actions for the screenshot hook.
    func performDebugAction(_ action: String) {
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
        default: nil
        }
    }
}
