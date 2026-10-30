import SwiftUI

/// Root state shared by every window.
@Observable
final class AppState {
    var selection: Module = .smartCare
}
