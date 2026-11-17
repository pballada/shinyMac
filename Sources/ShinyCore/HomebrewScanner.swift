import Foundation

/// Finds the space Homebrew keeps around: old versions of upgraded formulae, its download cache and logs, and
/// dependencies nothing needs any more. Removal goes through `brew` itself wherever it keeps its own bookkeeping.
public enum HomebrewScanner {
    /// Where `brew` lives on Apple silicon and on Intel Macs.
    public static let candidatePrefixes = ["/opt/homebrew", "/usr/local"]

    /// Homebrew's install prefix, or nil when it isn't installed.
    public static func prefix(candidates: [String] = candidatePrefixes) -> URL? {
        candidates.map { URL(filePath: $0, directoryHint: .isDirectory) }
            .first { FileManager.default.isExecutableFile(atPath: $0.appending(path: "bin/brew").path(percentEncoded: false)) }
    }

    public static var isInstalled: Bool { prefix() != nil }

    public static func scan(home: URL = Paths.home, prefix: URL? = prefix(), progress: ScanProgress) -> [CleanupGroup] {
        guard let prefix else { return [] }
        let brew = prefix.appending(path: "bin/brew").path(percentEncoded: false)
        let steps: [(String, () -> CleanupGroup)] = [
            ("Old versions", { oldVersionsGroup(prefix: prefix, brew: brew) }),
            ("Downloads", { downloadsGroup(home: home) }),
            ("Unused dependencies", { unusedDependenciesGroup(prefix: prefix, brew: brew) }),
            ("Logs", { logsGroup(home: home) }),
        ]
        var groups: [CleanupGroup] = []
        for (index, (title, step)) in steps.enumerated() {
            if progress.isCancelled || Task.isCancelled { break }
            progress.update(detail: title, fraction: Double(index) / Double(steps.count))
            let group = step()
            guard !group.items.isEmpty else { continue }
            groups.append(group)
            if group.selectedByDefault {
                progress.found(bytes: group.items.filter(\.isRecommended).reduce(0) { $0 + $1.size })
            }
        }
        progress.update(fraction: 1)
        return groups
    }

    /// Runs brew without triggering its auto-update, which can take minutes.
    static func command(_ brew: String, _ arguments: [String]) -> Removal {
        .command(executable: "/usr/bin/env", arguments: ["HOMEBREW_NO_AUTO_UPDATE=1", "HOMEBREW_NO_ENV_HINTS=1", brew] + arguments)
    }

    // MARK: Old versions

    /// Versions in the Cellar other than the one `opt/<name>` points to. Pinned formulae are left alone, as
    /// `brew cleanup` does.
    static func oldVersionsGroup(prefix: URL, brew: String) -> CleanupGroup {
        let cellar = prefix.appending(path: "Cellar", directoryHint: .isDirectory)
        let pinned = Set(FileSizer.children(of: prefix.appending(path: "var/homebrew/pinned")).map(\.lastPathComponent))
        var items: [CleanupItem] = []
        for formula in FileSizer.children(of: cellar) {
            let name = formula.lastPathComponent
            guard !pinned.contains(name), let current = currentVersion(of: name, prefix: prefix) else { continue }
            let old = FileSizer.children(of: formula).filter { $0.lastPathComponent != current && !$0.lastPathComponent.hasPrefix(".") }
            guard let first = old.first else { continue }
            let size = old.reduce(0) { $0 + FileSizer.size(of: $1) }
            guard size > 0 else { continue }
            let versions = old.map(\.lastPathComponent).sorted().joined(separator: ", ")
            items.append(CleanupItem(
                url: first, name: name, size: size, note: "Old \(versions) · keeps \(current)",
                removal: command(brew, ["cleanup", name])
            ))
        }
        return CleanupGroup(
            id: "brew-old", title: "Old Versions", detail: "Formulae kept from before an upgrade; removed with brew cleanup",
            symbol: "clock.arrow.circlepath", items: sorted(items)
        )
    }

    /// The version `opt/<name>` links to, e.g. "1.24.0".
    static func currentVersion(of formula: String, prefix: URL) -> String? {
        let link = prefix.appending(path: "opt/\(formula)").path(percentEncoded: false)
        guard let destination = try? FileManager.default.destinationOfSymbolicLink(atPath: link) else { return nil }
        return URL(filePath: destination).lastPathComponent
    }

    // MARK: Caches and logs

    static func downloadsGroup(home: URL) -> CleanupGroup {
        let cache = home.appending(path: "Library/Caches/Homebrew", directoryHint: .isDirectory)
        let items = FileSizer.children(of: cache)
            .map { FileSizer.item(at: $0, name: $0.lastPathComponent == "downloads" ? "Downloaded bottles" : nil) }
            .filter { $0.size > 0 }
        return CleanupGroup(
            id: "brew-downloads", title: "Downloads", detail: "Bottles and source archives Homebrew downloads again if needed",
            symbol: "arrow.down.circle.fill", items: sorted(items)
        )
    }

    static func logsGroup(home: URL) -> CleanupGroup {
        let item = FileSizer.item(at: home.appending(path: "Library/Logs/Homebrew", directoryHint: .isDirectory), name: "Install logs")
        return CleanupGroup(
            id: "brew-logs", title: "Logs", detail: "Build and install logs", symbol: "doc.text.fill",
            items: item.size > 0 ? [item] : []
        )
    }

    // MARK: Unused dependencies

    /// What `brew autoremove` would uninstall: formulae installed only as dependencies that nothing needs now.
    /// Never pre-selected.
    static func unusedDependenciesGroup(prefix: URL, brew: String) -> CleanupGroup {
        var items: [CleanupItem] = []
        if case .command(let executable, let arguments) = command(brew, ["autoremove", "--dry-run"]),
           let result = try? Shell.run(executable, arguments, timeout: 60), result.succeeded {
            for name in parseAutoremove(result.output) {
                let keg = prefix.appending(path: "Cellar/\(name)", directoryHint: .isDirectory)
                let size = FileSizer.size(of: keg)
                guard size > 0 else { continue }
                items.append(CleanupItem(
                    url: keg, name: name, size: size, isRecommended: false,
                    note: "Installed as a dependency; nothing uses it now", removal: command(brew, ["uninstall", name])
                ))
            }
        }
        return CleanupGroup(
            id: "brew-unused", title: "Unused Dependencies",
            detail: "Formulae brew autoremove would uninstall", symbol: "shippingbox.fill",
            items: sorted(items), selectedByDefault: false
        )
    }

    /// Formula names from `brew autoremove --dry-run`: every line after the "==> Would autoremove" header.
    static func parseAutoremove(_ output: String) -> [String] {
        var names: [String] = []
        var inList = false
        for line in output.split(whereSeparator: \.isNewline).map({ $0.trimmingCharacters(in: .whitespaces) }) {
            if line.hasPrefix("==>") {
                inList = line.localizedCaseInsensitiveContains("would autoremove")
                continue
            }
            if inList, !line.isEmpty, !line.contains(" ") { names.append(line) }
        }
        return names
    }

    private static func sorted(_ items: [CleanupItem]) -> [CleanupItem] {
        items.sorted { $0.size > $1.size }
    }
}

/// Which developer tools are on this Mac, so the sidebar only offers the screens that apply.
public enum DeveloperTools {
    public static func hasXcode(home: URL = Paths.home) -> Bool {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: home.appending(path: "Library/Developer").path(percentEncoded: false)) { return true }
        return FileSizer.children(of: URL(filePath: "/Applications")).contains {
            $0.lastPathComponent.hasPrefix("Xcode") && $0.pathExtension == "app"
        }
    }

    /// Any sign of the tools Dev Tools looks at: Docker, package managers, language toolchains, VMs or local models.
    public static func hasDevTools(home: URL = Paths.home) -> Bool {
        if DevToolsScanner.Docker.cli(home: home) != nil || HomebrewScanner.isInstalled { return true }
        let markers = [
            ".npm", ".yarn", ".bun", ".cargo", ".rustup", ".gradle", ".m2", ".pyenv", ".nvm", ".rbenv", ".cache/uv",
            ".colima", ".lima", ".android", ".ollama", ".pub-cache", "go/pkg", "Library/pnpm", "Library/Caches/pip",
            "Library/Caches/CocoaPods", "Library/Caches/Yarn",
        ]
        return markers.contains { FileManager.default.fileExists(atPath: home.appending(path: $0).path(percentEncoded: false)) }
    }
}
