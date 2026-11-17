import AppKit
import ShinyCore
import SwiftUI

@Observable
final class UninstallerModel {
    enum Phase: Equatable { case idle, loading, ready }

    enum Filter: String, CaseIterable, Identifiable {
        case all = "All"
        case unused = "Unused"
        case large = "Large"
        case intel = "Intel"
        case appStore = "App Store"
        var id: Self { self }

        /// Every Intel Mac app is "Intel only", so that filter only makes sense on Apple silicon.
        static var available: [Filter] {
            #if arch(arm64)
            allCases
            #else
            allCases.filter { $0 != .intel }
            #endif
        }
    }

    enum Sort: String, CaseIterable, Identifiable {
        case name = "Name"
        case size = "Size"
        case lastUsed = "Last Opened"
        var id: Self { self }
    }

    /// Outcome of the most recent uninstall or reset, shown in the detail pane.
    struct Outcome {
        let apps: [InstalledApp]
        let wasReset: Bool
        var report: Cleaner.Report

        var title: String {
            if apps.count == 1, let app = apps.first { return "\(app.name) was \(wasReset ? "reset" : "uninstalled")" }
            return "\(apps.count) apps were uninstalled"
        }
    }

    private(set) var phase: Phase = .idle
    private(set) var apps: [InstalledApp] = []
    private(set) var sizes: [URL: Int64] = [:]
    var search = ""
    var filter: Filter = .all
    var sort: Sort = .name

    private(set) var selectedApp: InstalledApp?
    private(set) var files: [Leftover] = []
    var fileSelection: Set<URL> = []
    private(set) var isFindingFiles = false
    private(set) var isRemoving = false
    private(set) var outcome: Outcome?

    /// Apps checked in the list for uninstalling together, in the order they were checked.
    private(set) var checked: [InstalledApp] = []
    /// Related files of each checked app, keyed by the app's URL.
    private(set) var checkedFiles: [URL: [Leftover]] = [:]
    var checkedSelection: Set<URL> = []
    private var checkedTasks: [URL: Task<Void, Never>] = [:]

    private var loadTask: Task<Void, Never>?
    private var filesTask: Task<Void, Never>?

    static let unusedInterval: TimeInterval = 90 * 24 * 3600
    static let largeThreshold: Int64 = 500_000_000

    // MARK: Derived

    var visibleApps: [InstalledApp] {
        let query = search.trimmingCharacters(in: .whitespaces)
        var result = apps.filter { app in
            guard query.isEmpty || app.name.localizedStandardContains(query) || app.bundleID.localizedStandardContains(query) else {
                return false
            }
            switch filter {
            case .all: return true
            case .unused: return isUnused(app)
            case .large: return (sizes[app.url] ?? 0) >= Self.largeThreshold
            case .intel: return app.isIntelOnly
            case .appStore: return app.isAppStore
            }
        }
        switch sort {
        case .name: break
        case .size: result.sort { (sizes[$0.url] ?? 0) > (sizes[$1.url] ?? 0) }
        case .lastUsed: result.sort { ($0.lastUsed ?? .distantPast) < ($1.lastUsed ?? .distantPast) }
        }
        return result
    }

    func count(for filter: Filter) -> Int {
        switch filter {
        case .all: apps.count
        case .unused: apps.count(where: isUnused)
        case .large: apps.count { (sizes[$0.url] ?? 0) >= Self.largeThreshold }
        case .intel: apps.count(where: \.isIntelOnly)
        case .appStore: apps.count(where: \.isAppStore)
        }
    }

    func isUnused(_ app: InstalledApp) -> Bool {
        guard let lastUsed = app.lastUsed else { return false }
        return Date.now.timeIntervalSince(lastUsed) > Self.unusedInterval
    }

    var selectedFiles: [Leftover] { files.filter { fileSelection.contains($0.url) } }
    var selectedFilesSize: Int64 { selectedFiles.reduce(0) { $0 + $1.size } }
    var filesSize: Int64 { files.reduce(0) { $0 + $1.size } }
    var totalAppsSize: Int64 { sizes.values.reduce(0, +) }

    /// Files grouped by where they live, in a stable order.
    var groupedFiles: [(kind: LeftoverKind, files: [Leftover])] {
        let grouped = Dictionary(grouping: files, by: \.kind)
        return LeftoverKind.allCases.compactMap { kind in grouped[kind].map { (kind, $0) } }
    }

    // MARK: Several apps

    /// Apps are checked: the detail pane lists all of them instead of the focused app, and clicking a row checks it.
    var isSelectingSeveral: Bool { !checked.isEmpty }

    func isChecked(_ app: InstalledApp) -> Bool { checked.contains { $0.id == app.id } }

    var isFindingCheckedFiles: Bool { checked.contains { checkedFiles[$0.url] == nil } }

    /// Every checked file, once: apps from the same vendor can share a folder.
    var selectedCheckedFiles: [Leftover] {
        var seen: Set<URL> = []
        return checked.flatMap { checkedFiles[$0.url] ?? [] }.filter { checkedSelection.contains($0.url) && seen.insert($0.url).inserted }
    }

    var selectedCheckedSize: Int64 { selectedCheckedFiles.reduce(0) { $0 + $1.size } }
    var checkedFileCount: Int { Set(checked.flatMap { checkedFiles[$0.url] ?? [] }.map(\.url)).count }

    func checkedSize(of app: InstalledApp) -> Int64 {
        (checkedFiles[app.url] ?? []).filter { checkedSelection.contains($0.url) }.reduce(0) { $0 + $1.size }
    }

    func checkState(of app: InstalledApp) -> CheckState {
        let files = checkedFiles[app.url] ?? []
        return CheckState(selected: files.count { checkedSelection.contains($0.url) }, total: max(files.count, 1))
    }

    func toggleCheck(_ app: InstalledApp) {
        guard !isRemoving else { return }
        outcome = nil
        if let index = checked.firstIndex(where: { $0.id == app.id }) {
            checked.remove(at: index)
            checkedTasks.removeValue(forKey: app.url)?.cancel()
            let files = checkedFiles.removeValue(forKey: app.url) ?? []
            let stillListed = Set(checked.flatMap { checkedFiles[$0.url] ?? [] }.map(\.url))
            checkedSelection.subtract(files.map(\.url).filter { !stillListed.contains($0) })
            return
        }
        checked.append(app)
        // Reuse what the detail pane already found for the focused app.
        if selectedApp?.id == app.id, !isFindingFiles {
            adoptCheckedFiles(files, for: app)
            return
        }
        let identity = app.identity
        let bundle = app.url
        checkedTasks[app.url] = Task {
            guard let found = await runInBackground({ () -> [Leftover] in
                [Leftover(url: bundle, kind: .application, size: FileSizer.size(of: bundle))] + LeftoverFinder.find(for: identity)
            }) else { return }
            guard isChecked(app) else { return }
            adoptCheckedFiles(found, for: app)
        }
    }

    /// Checks or unchecks every file of one checked app.
    func toggleFiles(of app: InstalledApp) {
        let urls = (checkedFiles[app.url] ?? []).map(\.url)
        if checkState(of: app) == .on { checkedSelection.subtract(urls) } else { checkedSelection.formUnion(urls) }
    }

    func toggleChecked(_ file: Leftover) {
        if checkedSelection.contains(file.url) { checkedSelection.remove(file.url) } else { checkedSelection.insert(file.url) }
    }

    func clearChecked() {
        checkedTasks.values.forEach { $0.cancel() }
        checkedTasks = [:]
        checked = []
        checkedFiles = [:]
        checkedSelection = []
    }

    private func adoptCheckedFiles(_ found: [Leftover], for app: InstalledApp) {
        checkedFiles[app.url] = found
        checkedSelection.formUnion(found.map(\.url))
        checkedTasks[app.url] = nil
    }

    /// Uninstalls every checked app with its selected files, in one go.
    func removeChecked() {
        let apps = checked
        let targets = selectedCheckedFiles.map { CleanupItem(url: $0.url, size: $0.size) }
        guard !apps.isEmpty, !targets.isEmpty else { return }
        isRemoving = true
        Task {
            for app in apps { await quitIfRunning(app) }
            let report = await runInBackground(minimumDuration: .seconds(0.8), {
                Cleaner.remove(targets, mode: .trash)
            }) ?? Cleaner.Report()
            clearChecked()
            finishRemoval(of: apps, reset: false, report: report)
        }
    }

    // MARK: Loading

    func load() {
        loadTask?.cancel()
        clearChecked()
        withAnimation(.smooth) { phase = .loading }
        loadTask = Task {
            guard let found = await runInBackground(minimumDuration: .seconds(1), { AppScanner.installedApps() }) else { return }
            apps = found
            sizes = [:]
            withAnimation(.smooth) { phase = .ready }
            if let pending = pendingApp {
                pendingApp = nil
                show(pending)
            } else if selectedApp == nil, let first = found.first {
                select(first)
            }

            // Sizes trickle in so the list is usable immediately.
            let stream = AsyncStream<(URL, Int64)> { continuation in
                let worker = Task.detached(priority: .utility) {
                    AppScanner.measure(found) { continuation.yield(($0, $1)) }
                    continuation.finish()
                }
                continuation.onTermination = { _ in worker.cancel() }
            }
            for await (url, size) in stream {
                sizes[url] = size
            }
        }
    }

    /// An app dropped on the window or Dock icon, waiting for the app list to load.
    private var pendingApp: InstalledApp?

    /// Opens a dropped app in the uninstaller. Returns false if the URL isn't a removable app.
    @discardableResult
    func reveal(appAt url: URL) -> Bool {
        guard let app = AppScanner.app(at: url) else { return false }
        if phase == .ready {
            show(app)
        } else {
            pendingApp = app
            if phase == .idle { load() }
        }
        return true
    }

    private func show(_ dropped: InstalledApp) {
        let path = dropped.url.standardizedFileURL
        let app = apps.first { $0.url.standardizedFileURL == path } ?? dropped
        if !apps.contains(app) { apps.insert(app, at: 0) }
        search = ""
        filter = .all
        select(app)
    }

    func select(_ app: InstalledApp) {
        guard selectedApp?.id != app.id || outcome != nil else { return }
        selectedApp = app
        outcome = nil
        files = []
        fileSelection = []
        isFindingFiles = true
        filesTask?.cancel()
        filesTask = Task {
            let identity = app.identity
            let bundle = app.url
            guard let leftovers = await runInBackground({ () -> [Leftover] in
                [Leftover(url: bundle, kind: .application, size: FileSizer.size(of: bundle))]
                    + LeftoverFinder.find(for: identity)
            }) else { return }
            guard selectedApp?.id == app.id else { return }
            files = leftovers
            fileSelection = Set(leftovers.map(\.url))
            isFindingFiles = false
        }
    }

    func toggle(_ file: Leftover) {
        if fileSelection.contains(file.url) { fileSelection.remove(file.url) } else { fileSelection.insert(file.url) }
    }

    // MARK: Removal

    /// Removes the selected files. A reset keeps the app itself and only clears its data.
    func remove(reset: Bool) {
        guard let app = selectedApp else { return }
        let targets = (reset ? selectedFiles.filter { $0.kind != .application } : selectedFiles)
            .map { CleanupItem(url: $0.url, size: $0.size) }
        guard !targets.isEmpty else { return }

        isRemoving = true
        Task {
            await quitIfRunning(app)
            let report = await runInBackground(minimumDuration: .seconds(0.8), {
                Cleaner.remove(targets, mode: .trash)
            }) ?? Cleaner.Report()
            finishRemoval(of: [app], reset: reset, report: report)
        }
    }

    /// Root-owned files (App Store apps, system launch daemons) need the administrator password.
    func retryAsAdmin() {
        guard var outcome else { return }
        let urls = outcome.report.failures.filter(\.needsAdmin).map(\.url)
        isRemoving = true
        Task {
            let result = await runInBackground { () -> Result<Cleaner.Report, Error> in
                Result { try Cleaner.removeWithPrivileges(urls) }
            }
            if case .success(let adminReport)? = result {
                outcome.report.failures.removeAll { urls.contains($0.url) }
                outcome.report.merge(adminReport)
            }
            finishRemoval(of: outcome.apps, reset: outcome.wasReset, report: outcome.report)
        }
    }

    private func finishRemoval(of removedApps: [InstalledApp], reset: Bool, report: Cleaner.Report) {
        isRemoving = false
        let removed = Set(report.removed)
        files.removeAll { removed.contains($0.url) }
        fileSelection.subtract(removed)
        for app in removedApps where removed.contains(app.url) {
            apps.removeAll { $0.id == app.id }
            sizes[app.url] = nil
        }
        withAnimation(.smooth) { outcome = Outcome(apps: removedApps, wasReset: reset, report: report) }
    }

    private func quitIfRunning(_ app: InstalledApp) async {
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: app.bundleID)
        guard !running.isEmpty else { return }
        running.forEach { $0.terminate() }
        for _ in 0..<30 where running.contains(where: { !$0.isTerminated }) {
            try? await Task.sleep(for: .milliseconds(100))
        }
    }
}
