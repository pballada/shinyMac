import SwiftUI

/// Root state shared by every window.
@Observable
final class AppState {
    var selection: Module = .smartCare

    /// Short status shown next to a module in the sidebar, such as the size of junk found.
    func badge(for module: Module) -> String? {
        nil
    }
}
