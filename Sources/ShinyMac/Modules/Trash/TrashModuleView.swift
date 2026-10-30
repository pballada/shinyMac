import ShinyCore
import SwiftUI

/// Trash Bins: the shared cleanup flow, plus a Finder fallback when the Trash is hidden from us.
struct TrashModuleView: View {
    @Bindable var model: CleanupModel
    @State private var isReadable = TrashScanner.isUserTrashReadable()
    @State private var isEmptyingWithFinder = false
    @State private var finderError: String?

    var body: some View {
        CleanupModuleView(model: model)
            .overlay(alignment: .top) {
                if !isReadable, model.phase == .idle || model.phase == .results {
                    PermissionBanner(
                        title: "Your Trash is private",
                        message: finderError ?? "Grant Full Disk Access to see what's inside, or let Finder empty it for you."
                    ) {
                        HStack(spacing: 8) {
                            OpenFullDiskAccessButton()
                            Button(isEmptyingWithFinder ? "Emptying…" : "Empty with Finder") { emptyWithFinder() }
                                .buttonStyle(.glassPill(prominent: true, tint: model.module.theme.accent))
                                .disabled(isEmptyingWithFinder)
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 52)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                // The user may have just granted Full Disk Access in System Settings.
                isReadable = TrashScanner.isUserTrashReadable()
            }
    }

    private func emptyWithFinder() {
        isEmptyingWithFinder = true
        finderError = nil
        Task {
            let result = await runInBackground { () -> Result<Shell.Result, Error> in
                Result { try TrashScanner.emptyWithFinder() }
            }
            isEmptyingWithFinder = false
            switch result {
            case .success(let output)? where output.succeeded:
                model.scan()
            case .success(let output)?:
                finderError = output.output.trimmingCharacters(in: .whitespacesAndNewlines)
            case .failure(let error)?:
                finderError = error.localizedDescription
            case nil:
                break
            }
        }
    }
}
