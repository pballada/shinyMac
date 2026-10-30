import AppKit
import ShinyCore
import SwiftUI

@Observable
final class LoginItemsModel {
    enum Phase: Equatable { case idle, loading, ready }

    private(set) var phase: Phase = .idle
    private(set) var items: [LaunchItem] = []
    private(set) var busyItems: Set<URL> = []
    private(set) var message: String?

    static let loginItemsSettings = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension")!

    var brokenItems: [LaunchItem] { items.filter(\.isBroken) }

    var badge: String? {
        guard phase == .ready else { return nil }
        return brokenItems.isEmpty ? "\(items.count)" : "\(brokenItems.count) broken"
    }

    func items(in scope: LaunchItem.Scope) -> [LaunchItem] { items.filter { $0.scope == scope } }

    func load() {
        if phase == .idle { withAnimation(.smooth) { phase = .loading } }
        Task {
            guard let found = await runInBackground(minimumDuration: phase == .loading ? .seconds(1) : .zero, { LaunchItems.scan() }) else {
                return
            }
            items = found
            withAnimation(.smooth) { phase = .ready }
        }
    }

    func setEnabled(_ item: LaunchItem, _ enabled: Bool) {
        perform(on: [item]) {
            try LaunchItems.setEnabled(item, enabled)
            return nil
        }
    }

    func remove(_ targets: [LaunchItem]) {
        perform(on: targets) {
            var report = Cleaner.Report()
            for item in targets { report.merge(try LaunchItems.remove(item)) }
            return report.failures.isEmpty
                ? "Removed \(report.removed.count) item\(report.removed.count == 1 ? "" : "s")"
                : "\(report.failures.count) items couldn't be removed"
        }
    }

    private func perform(on targets: [LaunchItem], _ work: @escaping @Sendable () throws -> String?) {
        let urls = targets.map(\.id)
        busyItems.formUnion(urls)
        Task {
            let result = await runInBackground { () -> Result<String?, Error> in Result { try work() } }
            busyItems.subtract(urls)
            switch result {
            case .success(let text)?: message = text
            case .failure(let error)?: message = error is CancellationError ? nil : error.localizedDescription
            case nil: break
            }
            load()
        }
    }
}
