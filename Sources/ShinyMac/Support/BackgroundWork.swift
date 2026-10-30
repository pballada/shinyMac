import ShinyCore
import SwiftUI

/// Runs blocking engine work off the main actor while streaming progress snapshots to the UI.
/// Returns nil if the calling task was cancelled. `minimumDuration` keeps very fast jobs from flashing by.
func runInBackground<T: Sendable>(
    progress: ScanProgress = ScanProgress(),
    minimumDuration: Duration = .zero,
    onProgress: @escaping @MainActor (ScanProgress.Snapshot) -> Void = { _ in },
    _ work: @escaping @Sendable () -> T
) async -> T? {
    let start = ContinuousClock.now
    let worker = Task.detached(priority: .userInitiated) { work() }
    let poller = Task { @MainActor in
        while !Task.isCancelled {
            onProgress(progress.snapshot)
            try? await Task.sleep(for: .milliseconds(80))
        }
    }
    defer { poller.cancel() }

    let value = await withTaskCancellationHandler {
        await worker.value
    } onCancel: {
        worker.cancel()
        progress.cancel()
    }

    let remaining = minimumDuration - (ContinuousClock.now - start)
    if remaining > .zero, !Task.isCancelled {
        try? await Task.sleep(for: remaining)
    }
    onProgress(progress.snapshot)
    return Task.isCancelled ? nil : value
}
