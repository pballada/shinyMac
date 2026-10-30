import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state
        NavigationSplitView {
            List(selection: $state.selection) {
                ForEach(SidebarSection.allCases) { section in
                    Section(section.title ?? "") {
                        ForEach(section.modules) { module in
                            Label(module.title, systemImage: module.symbol).tag(module)
                        }
                    }
                }
            }
            .navigationSplitViewColumnWidth(220)
        } detail: {
            ContentUnavailableView(
                state.selection.title,
                systemImage: state.selection.symbol,
                description: Text(state.selection.tagline)
            )
        }
    }
}
