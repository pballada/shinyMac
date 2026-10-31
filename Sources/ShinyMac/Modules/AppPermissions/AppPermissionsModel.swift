import AppKit
import ShinyCore
import SwiftUI

@Observable
final class AppPermissionsModel {
    enum Phase: Equatable { case idle, loading, ready, needsAccess }

    /// A grant resolved to something displayable.
    struct Entry: Identifiable, Hashable {
        var id: String { grant.id }
        let grant: AppPermissions.Grant
        let name: String
        let url: URL?
    }

    private(set) var phase: Phase = .idle
    private(set) var entries: [String: [Entry]] = [:]
    var selectedServiceID = AppPermissions.services[0].id

    var selectedService: AppPermissions.Service {
        AppPermissions.services.first { $0.id == selectedServiceID } ?? AppPermissions.services[0]
    }

    var totalGrants: Int { entries.values.reduce(0) { $0 + $1.count } }

    var badge: String? { phase == .ready ? "\(totalGrants)" : nil }

    func entries(for service: AppPermissions.Service) -> [Entry] { entries[service.id] ?? [] }

    func load() {
        if phase != .ready { withAnimation(.smooth) { phase = .loading } }
        Task {
            let grants = await runInBackground(minimumDuration: .seconds(0.8)) { AppPermissions.grants() } ?? nil
            guard let grants else {
                withAnimation(.smooth) { phase = .needsAccess }
                return
            }
            entries = Dictionary(grouping: grants.map(resolve), by: \.grant.service)
                .mapValues { $0.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending } }
            if entries(for: selectedService).isEmpty,
               let first = AppPermissions.services.first(where: { !self.entries(for: $0).isEmpty }) {
                selectedServiceID = first.id
            }
            withAnimation(.smooth) { phase = .ready }
        }
    }

    private func resolve(_ grant: AppPermissions.Grant) -> Entry {
        if grant.isPath {
            let url = URL(filePath: grant.client)
            return Entry(grant: grant, name: url.lastPathComponent, url: url)
        }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: grant.client) else {
            return Entry(grant: grant, name: grant.client, url: nil)
        }
        return Entry(grant: grant, name: FileManager.default.displayName(atPath: url.path(percentEncoded: false))
            .replacingOccurrences(of: ".app", with: ""), url: url)
    }
}
