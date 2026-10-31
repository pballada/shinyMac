import Foundation

/// Finds the big things Xcode leaves around: build data, archives, device support, simulators and runtimes.
public enum XcodeScanner {
    public static func scan(home: URL = Paths.home, progress: ScanProgress) -> [CleanupGroup] {
        let developer = home.appending(path: "Library/Developer", directoryHint: .isDirectory)
        progress.update(detail: "Simulators", fraction: 0)
        let devices = simulatorDevices()
        let steps: [(String, () -> CleanupGroup?)] = [
            ("Simulator runtimes", { runtimesGroup(devices: devices) }),
            ("Simulators", { simulatorsGroup(devices) }),
            ("Derived data", { derivedDataGroup(developer: developer) }),
            ("Device support", { deviceSupportGroup(developer: developer) }),
            ("Archives", { archivesGroup(developer: developer) }),
            ("Caches", { cachesGroup(home: home, developer: developer) }),
            ("Organizer downloads", { organizerGroup(developer: developer) }),
            ("Xcode versions", { xcodeVersionsGroup() }),
        ]
        var groups: [CleanupGroup] = []
        for (index, (title, step)) in steps.enumerated() {
            if Task.isCancelled { break }
            progress.update(detail: title, fraction: Double(index) / Double(steps.count))
            guard let group = step(), !group.items.isEmpty else { continue }
            groups.append(group)
            if group.selectedByDefault {
                progress.found(bytes: group.items.filter(\.isRecommended).reduce(0) { $0 + $1.size })
            }
        }
        progress.update(fraction: 1)
        return groups
    }

    // MARK: Derived data

    static func derivedDataGroup(developer: URL) -> CleanupGroup {
        let items = FileSizer.children(of: developer.appending(path: "Xcode/DerivedData"))
            .filter { $0.lastPathComponent != ".DS_Store" }
            .map { folder in
                let item = FileSizer.item(at: folder)
                let workspace = workspacePath(ofDerivedData: folder)
                return CleanupItem(
                    url: folder, name: projectName(ofDerivedData: folder, workspace: workspace), size: item.size,
                    modified: item.modified, note: workspace.map { Paths.abbreviated(URL(filePath: $0)) }
                )
            }
        return CleanupGroup(
            id: "derivedData", title: "Derived Data", detail: "Build products and indexes, rebuilt on the next build",
            symbol: "hammer.fill", items: sorted(items)
        )
    }

    /// "MyApp-gbdqnhhzxyz" → "MyApp", unless the folder's info.plist names the workspace.
    static func projectName(ofDerivedData folder: URL, workspace: String?) -> String {
        if let workspace {
            return URL(filePath: workspace).deletingPathExtension().lastPathComponent
        }
        let name = folder.lastPathComponent
        guard let dash = name.lastIndex(of: "-"), name.distance(from: dash, to: name.endIndex) > 10 else { return name }
        return String(name[..<dash])
    }

    static func workspacePath(ofDerivedData folder: URL) -> String? {
        plist(at: folder.appending(path: "info.plist"))?["WorkspacePath"] as? String
    }

    // MARK: Device support

    static let deviceSupportFolders = ["iOS", "watchOS", "tvOS", "visionOS", "macOS"].map { "Xcode/\($0) DeviceSupport" }

    /// Symbols copied from each device OS version you've debugged on. The newest per platform starts unchecked.
    static func deviceSupportGroup(developer: URL) -> CleanupGroup {
        let items = deviceSupportFolders.flatMap { folder -> [CleanupItem] in
            let platform = folder.dropFirst("Xcode/".count).split(separator: " ").first.map(String.init) ?? ""
            let versions = FileSizer.children(of: developer.appending(path: folder))
                .filter { $0.lastPathComponent != ".DS_Store" }
                .map { FileSizer.item(at: $0) }
                .sorted { ($0.modified ?? .distantPast) > ($1.modified ?? .distantPast) }
            return versions.enumerated().map { index, item in
                CleanupItem(
                    url: item.url, name: "\(platform) \(item.name)", size: item.size, modified: item.modified,
                    isRecommended: index > 0,
                    note: index == 0 ? "Most recent; Xcode copies it again when you connect the device" : nil
                )
            }
        }
        return CleanupGroup(
            id: "deviceSupport", title: "Device Support", detail: "Debug symbols for each device OS version, copied again when needed",
            symbol: "iphone.gen3", items: sorted(items)
        )
    }

    // MARK: Archives

    static func archivesGroup(developer: URL) -> CleanupGroup {
        let archives = FileSizer.children(of: developer.appending(path: "Xcode/Archives"))
            .flatMap { FileSizer.children(of: $0) }
            .filter { $0.pathExtension == "xcarchive" }
        let items = archives.map { archive in
            let item = FileSizer.item(at: archive)
            let info = plist(at: archive.appending(path: "Info.plist"))
            let properties = info?["ApplicationProperties"] as? [String: Any]
            let version = properties?["CFBundleShortVersionString"] as? String
            let build = properties?["CFBundleVersion"] as? String
            let date = info?["CreationDate"] as? Date ?? item.modified
            let name = [info?["Name"] as? String ?? archive.deletingPathExtension().lastPathComponent,
                        version.map { v in build.map { "\(v) (\($0))" } ?? v }]
                .compactMap { $0 }.joined(separator: " ")
            return CleanupItem(
                url: archive, name: name, size: item.size, modified: date,
                note: date.map { "Archived \($0.formatted(date: .abbreviated, time: .omitted))" }, removal: .moveToTrash
            )
        }
        return CleanupGroup(
            id: "archives", title: "Archives", detail: "Builds you distributed; keep the ones you need to symbolicate crashes",
            symbol: "archivebox.fill", items: sorted(items), selectedByDefault: false
        )
    }

    // MARK: Caches

    static func cachesGroup(home: URL, developer: URL) -> CleanupGroup {
        let candidates: [(URL, String)] = [
            (developer.appending(path: "CoreSimulator/Caches"), "Simulator caches"),
            (developer.appending(path: "Xcode/DocumentationCache"), "Documentation cache"),
            (developer.appending(path: "Xcode/UserData/Previews"), "SwiftUI preview simulators"),
            (developer.appending(path: "XCPGDevices"), "Playground simulators"),
            (developer.appending(path: "XCTestDevices"), "Test clone simulators"),
            (home.appending(path: "Library/Caches/com.apple.dt.Xcode"), "Xcode cache"),
            (home.appending(path: "Library/Logs/CoreSimulator"), "Simulator logs"),
            (developer.appending(path: "Xcode/DeviceLogs"), "Device logs"),
        ]
        let items = candidates.map { FileSizer.item(at: $0.0, name: $0.1) }.filter { $0.size > 0 }
        return CleanupGroup(
            id: "caches", title: "Caches & Logs", detail: "Regenerated by Xcode and the Simulator on demand",
            symbol: "archivebox", items: sorted(items)
        )
    }

    /// Crash reports and metrics downloaded by the Organizer, one folder per app.
    static func organizerGroup(developer: URL) -> CleanupGroup {
        let items = FileSizer.children(of: developer.appending(path: "Xcode/Products"))
            .filter { $0.lastPathComponent != ".DS_Store" }
            .map { FileSizer.item(at: $0) }
            .filter { $0.size > 0 }
        return CleanupGroup(
            id: "organizer", title: "Organizer Downloads", detail: "Crash reports and metrics; the Organizer downloads them again",
            symbol: "chart.bar.doc.horizontal.fill", items: sorted(items), selectedByDefault: false
        )
    }

    // MARK: Simulators

    public struct SimulatorDevice: Sendable, Equatable {
        let udid: String
        let name: String
        let runtime: String
        let isAvailable: Bool
        let lastUsed: Date?
        let dataPath: String?
    }

    static func simulatorDevices() -> [SimulatorDevice] {
        guard let result = try? Shell.run("/usr/bin/xcrun", ["simctl", "list", "devices", "-j"]), result.succeeded else { return [] }
        return parseDevices(Data(result.output.utf8))
    }

    static func parseDevices(_ data: Data) -> [SimulatorDevice] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let byRuntime = json["devices"] as? [String: [[String: Any]]] else { return [] }
        let dates = ISO8601DateFormatter()
        return byRuntime.flatMap { runtime, devices in
            devices.compactMap { device -> SimulatorDevice? in
                guard let udid = device["udid"] as? String, let name = device["name"] as? String else { return nil }
                return SimulatorDevice(
                    udid: udid, name: name, runtime: runtime, isAvailable: device["isAvailable"] as? Bool ?? true,
                    lastUsed: (device["lastUsedAt"] as? String).flatMap(dates.date(from:)), dataPath: device["dataPath"] as? String
                )
            }
        }
    }

    /// "com.apple.CoreSimulator.SimRuntime.iOS-18-1" → "iOS 18.1".
    static func runtimeName(_ identifier: String) -> String {
        guard let last = identifier.split(separator: ".").last else { return identifier }
        let parts = last.split(separator: "-")
        guard let platform = parts.first else { return identifier }
        let display = platform == "xrOS" ? "visionOS" : String(platform)
        return ([display] + [parts.dropFirst().joined(separator: ".")]).joined(separator: " ")
    }

    /// Devices whose runtime is gone are recommended; working ones keep their apps and data, so start unchecked.
    static func simulatorsGroup(_ devices: [SimulatorDevice]) -> CleanupGroup {
        let items = devices.compactMap { device -> CleanupItem? in
            guard let dataPath = device.dataPath else { return nil }
            let folder = URL(filePath: dataPath).deletingLastPathComponent()
            let size = FileSizer.size(of: folder)
            guard size > 0 else { return nil }
            let used = device.lastUsed.map { "used \($0.formatted(.relative(presentation: .named)))" } ?? "never used"
            let note = device.isAvailable ? "\(runtimeName(device.runtime)) · \(used)" : "\(runtimeName(device.runtime)) is no longer installed"
            return CleanupItem(
                url: folder, name: device.name, size: size, modified: device.lastUsed, isRecommended: !device.isAvailable,
                note: note, removal: .simulator(udid: device.udid)
            )
        }
        return CleanupGroup(
            id: "simulators", title: "Simulators", detail: "Simulated devices with their installed apps and data",
            symbol: "ipad.and.iphone", items: sorted(items)
        )
    }

    struct SimulatorRuntime: Equatable {
        let identifier: String
        let runtimeIdentifier: String
        let platform: String
        let version: String
        let size: Int64
        let path: String
        let isDeletable: Bool
    }

    static func runtimes() -> [SimulatorRuntime] {
        guard let result = try? Shell.run("/usr/bin/xcrun", ["simctl", "runtime", "list", "-j"]), result.succeeded else { return [] }
        return parseRuntimes(Data(result.output.utf8))
    }

    static func parseRuntimes(_ data: Data) -> [SimulatorRuntime] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: [String: Any]] else { return [] }
        return json.values.compactMap { runtime in
            guard let identifier = runtime["identifier"] as? String,
                  let runtimeIdentifier = runtime["runtimeIdentifier"] as? String else { return nil }
            return SimulatorRuntime(
                identifier: identifier, runtimeIdentifier: runtimeIdentifier,
                platform: runtimeName(runtimeIdentifier).split(separator: " ").first.map(String.init) ?? "",
                version: runtime["version"] as? String ?? "",
                size: (runtime["sizeBytes"] as? NSNumber)?.int64Value ?? 0,
                path: runtime["path"] as? String ?? "",
                isDeletable: runtime["deletable"] as? Bool ?? false
            )
        }
    }

    /// Each runtime is several GB. Older versions of a platform are recommended unless a simulator still uses them.
    static func runtimesGroup(devices: [SimulatorDevice], runtimes: [SimulatorRuntime] = runtimes()) -> CleanupGroup {
        let deviceCounts = Dictionary(grouping: devices, by: \.runtime).mapValues(\.count)
        let newest = Dictionary(grouping: runtimes, by: \.platform).compactMapValues { list in
            list.max { UpdateChecker.isNewer($1.version, than: $0.version) }?.identifier
        }
        let items = runtimes.filter(\.isDeletable).map { runtime in
            let count = deviceCounts[runtime.runtimeIdentifier] ?? 0
            let isNewest = newest[runtime.platform] == runtime.identifier
            let usage = count == 0 ? "no simulators use it" : "\(count) simulator\(count == 1 ? "" : "s")"
            return CleanupItem(
                url: URL(filePath: runtime.path), name: "\(runtime.platform) \(runtime.version) Simulator", size: runtime.size,
                isRecommended: !isNewest && count == 0,
                note: isNewest ? "Latest \(runtime.platform) · \(usage)" : usage.prefix(1).uppercased() + usage.dropFirst(),
                removal: .simulatorRuntime(identifier: runtime.identifier)
            )
        }
        return CleanupGroup(
            id: "runtimes", title: "Simulator Runtimes", detail: "Downloadable OS images; Xcode can fetch any of them again",
            symbol: "square.stack.3d.down.right.fill", items: sorted(items), selectedByDefault: false
        )
    }

    // MARK: Xcode versions

    /// Every copy of Xcode except the one `xcode-select` points to, which starts unchecked.
    static func xcodeVersionsGroup() -> CleanupGroup {
        let active = (try? Shell.run("/usr/bin/xcode-select", ["-p"]))
            .map { $0.output.trimmingCharacters(in: .whitespacesAndNewlines) } ?? ""
        let apps = FileSizer.children(of: URL(filePath: "/Applications")).filter { url in
            url.pathExtension == "app"
                && (plist(at: url.appending(path: "Contents/Info.plist"))?["CFBundleIdentifier"] as? String) == "com.apple.dt.Xcode"
        }
        guard apps.count > 1 else { return CleanupGroup(id: "xcodeVersions", title: "", detail: "", symbol: "", items: []) }
        let items = apps.map { app in
            let isActive = !active.isEmpty && active.hasPrefix(app.path(percentEncoded: false))
            let version = plist(at: app.appending(path: "Contents/Info.plist"))?["CFBundleShortVersionString"] as? String
            return CleanupItem(
                url: app, size: FileSizer.size(of: app), isRecommended: !isActive,
                note: [version.map { "Version \($0)" }, isActive ? "selected with xcode-select" : nil].compactMap { $0 }.joined(separator: " · "),
                removal: .moveToTrash
            )
        }
        return CleanupGroup(
            id: "xcodeVersions", title: "Xcode Versions", detail: "Extra copies of Xcode, moved to the Trash",
            symbol: "hammer.circle.fill", items: sorted(items), selectedByDefault: false
        )
    }

    // MARK: Helpers

    private static func sorted(_ items: [CleanupItem]) -> [CleanupItem] {
        items.sorted { $0.size > $1.size }
    }

    private static func plist(at url: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
    }
}
