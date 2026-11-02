import Foundation
import Synchronization

/// Finds the space developer tools take outside Xcode: Docker, package manager caches, language toolchains,
/// local AI models, editor caches and the dependency folders inside your projects.
public enum DevToolsScanner {
    public static func scan(home: URL = Paths.home, now: Date = .now, progress: ScanProgress) -> [CleanupGroup] {
        progress.update(detail: "Docker", fraction: 0)
        let docker = dockerGroup(home: home)
        let steps: [(String, () -> CleanupGroup)] = [
            ("Docker", { docker.group }),
            ("Virtual machines", { virtualMachinesGroup(home: home, dockerIsRunning: docker.isRunning) }),
            ("Package caches", { packageCachesGroup(home: home) }),
            ("Editor caches", { editorCachesGroup(home: home) }),
            ("Toolchains", { toolchainsGroup(home: home) }),
            ("AI models", { aiModelsGroup(home: home) }),
            ("Project dependencies", { projectDependenciesGroup(home: home, now: now, progress: progress) }),
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

    // MARK: Docker

    enum Docker {
        static func candidates(home: URL) -> [String] {
            [
                "/usr/local/bin/docker", "/opt/homebrew/bin/docker",
                "/Applications/Docker.app/Contents/Resources/bin/docker",
                home.appending(path: ".docker/bin/docker").path(percentEncoded: false),
                home.appending(path: ".orbstack/bin/docker").path(percentEncoded: false),
                home.appending(path: ".rd/bin/docker").path(percentEncoded: false),
            ]
        }

        static func cli(home: URL) -> String? {
            candidates(home: home).first { FileManager.default.isExecutableFile(atPath: $0) }
        }

        struct Usage: Equatable {
            let type: String
            let count: Int
            let reclaimable: Int64
        }

        /// One JSON object per line from `docker system df --format '{{json .}}'`.
        static func parseDiskUsage(_ output: String) -> [Usage] {
            output.split(whereSeparator: \.isNewline).compactMap { line in
                guard let object = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
                      let type = object["Type"] as? String else { return nil }
                let count = Int("\(object["TotalCount"] ?? "0")") ?? 0
                let reclaimable = (object["Reclaimable"] as? String).flatMap(parseSize) ?? 0
                return Usage(type: type, count: count, reclaimable: reclaimable)
            }
        }

        /// "1.2GB (35%)" → 1_200_000_000. Docker prints decimal units.
        static func parseSize(_ text: String) -> Int64? {
            let value = text.split(separator: " ").first.map(String.init) ?? text
            let units: [(String, Double)] = [("TB", 1e12), ("GB", 1e9), ("MB", 1e6), ("kB", 1e3), ("KB", 1e3), ("B", 1)]
            for (suffix, multiplier) in units where value.hasSuffix(suffix) {
                guard let number = Double(value.dropLast(suffix.count)) else { return nil }
                return Int64(number * multiplier)
            }
            return nil
        }
    }

    /// What `docker system df` says can be reclaimed, removed with Docker's own prune commands.
    /// `isRunning` is false when there's no Docker CLI or its daemon doesn't answer.
    static func dockerGroup(home: URL) -> (group: CleanupGroup, isRunning: Bool) {
        let empty = CleanupGroup(id: "docker", title: "Docker", detail: "", symbol: "shippingbox.fill", items: [])
        guard let cli = Docker.cli(home: home),
              let result = try? Shell.run(cli, ["system", "df", "--format", "{{json .}}"], timeout: 15), result.succeeded
        else { return (empty, false) }
        let usage = Dictionary(Docker.parseDiskUsage(result.output).map { ($0.type, $0) }, uniquingKeysWith: { a, _ in a })
        // Placeholder paths: these items aren't files, but each needs a stable identity.
        let base = home.appending(path: "Library/Containers/com.docker.docker/Data", directoryHint: .isDirectory)
        let kinds: [(type: String, name: String, arguments: [String], recommended: Bool, note: String)] = [
            ("Build Cache", "Build cache", ["builder", "prune", "--all", "--force"], true,
             "Layers kept to speed up rebuilds; the next build recreates them"),
            ("Containers", "Stopped containers", ["container", "prune", "--force"], false,
             "Containers that aren't running, with any changes made inside them"),
            ("Images", "Unused images", ["image", "prune", "--all", "--force"], false,
             "Images no container uses; they're pulled again when needed"),
            ("Local Volumes", "Unused volumes", ["volume", "prune", "--all", "--force"], false,
             "Data volumes no container uses. Their data is gone for good"),
        ]
        let items = kinds.compactMap { kind -> CleanupItem? in
            guard let entry = usage[kind.type], entry.reclaimable > 0 else { return nil }
            return CleanupItem(
                url: base.appending(path: "shinymac-\(kind.arguments[0])"), name: kind.name, size: entry.reclaimable,
                isRecommended: kind.recommended, note: kind.note,
                removal: .command(executable: cli, arguments: kind.arguments)
            )
        }
        let group = CleanupGroup(
            id: "docker", title: "Docker", detail: "Reclaimable space reported by Docker, cleared with its prune commands",
            symbol: "shippingbox.fill", items: sorted(items)
        )
        return (group, true)
    }

    /// Disk images of the Linux VMs that container tools run in. Listed so you can see them, never pre-selected.
    static func virtualMachinesGroup(home: URL, dockerIsRunning: Bool) -> CleanupGroup {
        var candidates: [(URL, String, String)] = [
            (home.appending(path: ".colima"), "Colima", "Quit Colima first. Removes its VMs and everything in them"),
            (home.appending(path: ".local/share/containers/podman/machine"), "Podman machines",
             "Stop Podman first. Removes its VMs and everything in them"),
            (home.appending(path: ".lima"), "Lima", "Stop Lima first. Removes its VMs and everything in them"),
            (home.appending(path: "Library/Group Containers/HUAQ24HBR6.dev.orbstack/data"), "OrbStack data",
             "Quit OrbStack first. Removes every image, container and machine"),
            (home.appending(path: ".android/avd"), "Android emulators", "Every Android Virtual Device and its data"),
        ]
        // Deleting Docker's disk while Docker runs would corrupt it; when it runs, prune it from the Docker group.
        if !dockerIsRunning {
            candidates.insert((
                home.appending(path: "Library/Containers/com.docker.docker/Data/vms"), "Docker Desktop disk",
                "Docker isn't running. Removes every image, container and volume; Docker makes a fresh disk"
            ), at: 0)
        }
        let items = candidates.compactMap { url, name, note -> CleanupItem? in
            let size = FileSizer.size(of: url)
            guard size > 0 else { return nil }
            return CleanupItem(url: url, name: name, size: size, isRecommended: false, note: note, removal: .moveToTrash)
        }
        return CleanupGroup(
            id: "vms", title: "Virtual Machines", detail: "Disks of the Linux VMs behind Docker-style tools and emulators",
            symbol: "server.rack", items: sorted(items), selectedByDefault: false
        )
    }

    // MARK: Caches

    static func packageCachesGroup(home: URL) -> CleanupGroup {
        let candidates: [(String, String)] = [
            (".npm/_cacache", "npm"), ("Library/Caches/Yarn", "Yarn"), (".yarn/berry/cache", "Yarn Berry"),
            ("Library/pnpm/store", "pnpm store"), ("Library/Caches/pnpm", "pnpm"), (".bun/install/cache", "Bun"),
            ("Library/Caches/deno", "Deno"), ("Library/Caches/pip", "pip"), ("Library/Caches/pypoetry", "Poetry"),
            (".cache/uv", "uv"), ("Library/Caches/Homebrew", "Homebrew downloads"),
            ("Library/Caches/CocoaPods", "CocoaPods"), ("Library/Caches/org.swift.swiftpm", "Swift Package Manager"),
            ("Library/Caches/go-build", "Go build cache"), (".gradle/caches", "Gradle"), (".m2/repository", "Maven"),
            (".cargo/registry/cache", "Cargo downloads"), (".cargo/git/checkouts", "Cargo git checkouts"),
            (".pub-cache", "Dart & Flutter"), ("Library/Caches/composer", "Composer"), (".nuget/packages", "NuGet"),
            (".cache/bazel", "Bazel"), (".cache/pre-commit", "pre-commit"),
        ]
        var items = candidates.map { FileSizer.item(at: home.appending(path: $0.0, directoryHint: .isDirectory), name: $0.1) }
            .filter { $0.size > 0 }
        // Go's module cache is read-only on disk, so only `go clean` can remove it.
        let goModules = home.appending(path: "go/pkg/mod", directoryHint: .isDirectory)
        if let go = ["/usr/local/go/bin/go", "/opt/homebrew/bin/go", "/usr/local/bin/go"].first(where: FileManager.default.isExecutableFile),
           case let size = FileSizer.size(of: goModules), size > 0 {
            items.append(CleanupItem(
                url: goModules, name: "Go modules", size: size, note: "Downloaded again on the next build",
                removal: .command(executable: go, arguments: ["clean", "-modcache"])
            ))
        }
        for conda in ["miniconda3", "anaconda3", "miniforge3", "opt/anaconda3", "opt/miniconda3"] {
            let pkgs = FileSizer.item(at: home.appending(path: "\(conda)/pkgs", directoryHint: .isDirectory), name: "Conda packages")
            if pkgs.size > 0 {
                items.append(CleanupItem(
                    url: pkgs.url, name: pkgs.name, size: pkgs.size, isRecommended: false,
                    note: "Package downloads Conda can fetch again; environments keep what they use"
                ))
            }
        }
        return CleanupGroup(
            id: "packageCaches", title: "Package Caches", detail: "Downloads package managers fetch again on demand",
            symbol: "shippingbox.fill", items: sorted(items)
        )
    }

    static let editors: [(folder: String, name: String)] = [
        ("Code", "VS Code"), ("Cursor", "Cursor"), ("Windsurf", "Windsurf"), ("VSCodium", "VSCodium"), ("Zed", "Zed"),
    ]

    static func editorCachesGroup(home: URL) -> CleanupGroup {
        let support = home.appending(path: "Library/Application Support", directoryHint: .isDirectory)
        var items = editors.flatMap { editor in
            ["Cache", "CachedData", "CachedExtensionVSIXs", "Code Cache", "GPUCache", "logs"].map { cache in
                FileSizer.item(at: support.appending(path: "\(editor.folder)/\(cache)"), name: "\(editor.name) · \(cache)")
            }
        }
        items.append(FileSizer.item(at: home.appending(path: "Library/Caches/JetBrains"), name: "JetBrains IDEs"))
        items.append(FileSizer.item(at: home.appending(path: "Library/Caches/Google/AndroidStudio"), name: "Android Studio"))
        return CleanupGroup(
            id: "editorCaches", title: "Editor Caches", detail: "Rebuilt when the editor next starts; quit it first",
            symbol: "chevron.left.forwardslash.chevron.right", items: sorted(items.filter { $0.size > 0 })
        )
    }

    // MARK: Toolchains and models

    /// Installed language versions. The one each manager uses by default starts unchecked.
    static func toolchainsGroup(home: URL) -> CleanupGroup {
        func versions(_ folder: String, tool: String, active: String?) -> [CleanupItem] {
            FileSizer.children(of: home.appending(path: folder, directoryHint: .isDirectory))
                .filter { !$0.lastPathComponent.hasPrefix(".") }
                .map { url in
                    let version = url.lastPathComponent
                    let isActive = active.map { version.contains($0) || $0.contains(version) } ?? false
                    let item = FileSizer.item(at: url)
                    return CleanupItem(
                        url: url, name: "\(tool) \(version)", size: item.size, modified: item.modified, isRecommended: false,
                        note: isActive ? "Default version · keep it" : "Installed with \(folder.split(separator: "/").first ?? "")"
                    )
                }
        }
        func firstLine(_ path: String) -> String? {
            (try? String(contentsOf: home.appending(path: path), encoding: .utf8))?
                .split(whereSeparator: \.isNewline).first.map { $0.trimmingCharacters(in: .whitespaces) }
        }
        var items = versions(".nvm/versions/node", tool: "Node", active: firstLine(".nvm/alias/default"))
        items += versions(".pyenv/versions", tool: "Python", active: firstLine(".pyenv/version"))
        items += versions(".rbenv/versions", tool: "Ruby", active: firstLine(".rbenv/version"))
        items += versions(".rustup/toolchains", tool: "Rust", active: rustDefaultToolchain(home: home))
        items += versions("Library/Android/sdk/system-images", tool: "Android system images", active: nil)
        items += versions(".gradle/wrapper/dists", tool: "Gradle", active: nil)
        return CleanupGroup(
            id: "toolchains", title: "Toolchains & SDKs", detail: "Language versions and SDKs; remove the ones you no longer use",
            symbol: "wrench.adjustable.fill", items: sorted(items.filter { $0.size > 0 }), selectedByDefault: false
        )
    }

    /// `default_toolchain = "stable-aarch64-apple-darwin"` in rustup's settings.
    static func rustDefaultToolchain(home: URL) -> String? {
        guard let text = try? String(contentsOf: home.appending(path: ".rustup/settings.toml"), encoding: .utf8) else { return nil }
        let line = text.split(whereSeparator: \.isNewline).first { $0.hasPrefix("default_toolchain") }
        return line?.split(separator: "\"").dropFirst().first.map(String.init)
    }

    static func aiModelsGroup(home: URL) -> CleanupGroup {
        let candidates: [(String, String)] = [
            (".ollama/models", "Ollama models"), (".cache/huggingface", "Hugging Face cache"),
            (".lmstudio/models", "LM Studio models"), (".cache/lm-studio/models", "LM Studio models"),
            (".cache/torch", "PyTorch hub cache"), (".cache/whisper", "Whisper models"),
            ("Library/Application Support/nomic.ai/GPT4All", "GPT4All models"),
            ("Library/Containers/com.apple.DiffusionCLI", "Diffusion models"),
        ]
        let items = candidates.map { FileSizer.item(at: home.appending(path: $0.0, directoryHint: .isDirectory), name: $0.1) }
            .filter { $0.size > 0 }
            .map { CleanupItem(url: $0.url, name: $0.name, size: $0.size, modified: $0.modified, isRecommended: false,
                               note: "Downloaded models; fetch them again to use them") }
        return CleanupGroup(
            id: "aiModels", title: "AI Models", detail: "Local language and image models, often several GB each",
            symbol: "brain.head.profile", items: sorted(items), selectedByDefault: false
        )
    }

    // MARK: Project dependencies

    /// A dependency or build folder and the project file that proves it's regenerable.
    static let projectMarkers: [(folder: String, marker: String, tool: String)] = [
        ("node_modules", "package.json", "npm install"),
        (".venv", "pyproject.toml", "pip / uv"), (".venv", "requirements.txt", "pip"),
        ("venv", "requirements.txt", "pip"),
        ("target", "Cargo.toml", "cargo build"),
        (".build", "Package.swift", "swift build"),
        ("Pods", "Podfile", "pod install"),
        (".gradle", "settings.gradle", "Gradle"), (".gradle", "settings.gradle.kts", "Gradle"),
        (".next", "next.config.js", "next build"), (".next", "next.config.mjs", "next build"),
        (".next", "next.config.ts", "next build"),
    ]

    /// Projects untouched this long have their dependency folders pre-selected.
    static let idleProjectAge: TimeInterval = 90 * 86_400

    /// Walks the home folder for dependency folders that sit next to the project file that recreates them.
    static func projectDependenciesGroup(home: URL, now: Date, progress: ScanProgress) -> CleanupGroup {
        let skipped: Set<String> = ["Library", "Applications", ".Trash"].map {
            home.appending(path: $0).path(percentEncoded: false).trimmingSuffix("/")
        }.reduce(into: []) { $0.insert($1) }
        let dependencyNames = Set(projectMarkers.map(\.folder))
        let markersByFile = Dictionary(grouping: projectMarkers, by: \.marker)
        let found = Mutex<[URL: CleanupItem]>([:])

        ParallelWalker.walk(root: home, progress: progress) { url, values in
            let name = url.lastPathComponent
            if values.isDirectory == true {
                // Never descend into a dependency folder (nested node_modules) or the skipped areas.
                return !dependencyNames.contains(name) && !skipped.contains(url.path(percentEncoded: false).trimmingSuffix("/"))
                    && values.isPackage != true
            }
            // A project file: look for its dependency folders next to it (hidden ones aren't walked).
            guard let markers = markersByFile[name] else { return false }
            let project = url.deletingLastPathComponent()
            for marker in markers {
                let folder = project.appending(path: marker.folder, directoryHint: .isDirectory)
                guard found.withLock({ $0[folder] == nil }),
                      (try? folder.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else { continue }
                let size = FileSizer.size(of: folder)
                guard size >= minimumDependencySize else { continue }
                let lastWorked = [values.contentModificationDate, projectActivity(project)].compactMap { $0 }.max()
                let idle = lastWorked.map { now.timeIntervalSince($0) } ?? .infinity
                let isIdle = idle >= idleProjectAge
                let when = lastWorked.map { "touched \($0.formatted(.relative(presentation: .named)))" } ?? "no recent activity"
                let item = CleanupItem(
                    url: folder, name: "\(project.lastPathComponent) · \(marker.folder)", size: size, modified: lastWorked,
                    isRecommended: isIdle, note: "\(Paths.abbreviated(project)) · \(when) · \(marker.tool) restores it"
                )
                progress.found(bytes: size)
                found.withLock { $0[folder] = item }
            }
            return false
        }
        return CleanupGroup(
            id: "projects", title: "Project Dependencies",
            detail: "node_modules, virtual envs and build folders; projects idle for 3 months are pre-selected",
            symbol: "folder.fill.badge.gearshape", items: sorted(Array(found.withLock { $0 }.values)), selectedByDefault: true
        )
    }

    /// Dependency folders smaller than this aren't worth a row.
    static let minimumDependencySize: Int64 = 20_000_000

    /// The project folder's own modification date, which changes when files are added or renamed in it.
    private static func projectActivity(_ project: URL) -> Date? {
        try? project.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }

    // MARK: Helpers

    private static func sorted(_ items: [CleanupItem]) -> [CleanupItem] {
        items.sorted { $0.size > $1.size }
    }
}
