import Foundation

/// A launchd job that starts with the Mac or the user session.
public struct LaunchItem: Identifiable, Hashable, Sendable {
    public enum Scope: String, Sendable, CaseIterable {
        case userAgent = "Your Agents"
        case globalAgent = "Agents for All Users"
        case daemon = "System Daemons"

        public var detail: String {
            switch self {
            case .userAgent: "Start when you log in"
            case .globalAgent: "Start when anyone logs in"
            case .daemon: "Run in the background as root"
            }
        }

        /// Changing these needs an administrator password.
        public var isPrivileged: Bool { self == .daemon }
    }

    public var id: URL { plistURL }
    public let plistURL: URL
    public let label: String
    public let scope: Scope
    /// Executable path from `Program` or the first `ProgramArguments` entry.
    public let program: String?
    public let runAtLoad: Bool
    public let keepAlive: Bool
    public var isLoaded = false
    public var isDisabled = false

    /// Points at an executable that no longer exists, typically left over from a deleted app.
    public var isBroken: Bool {
        guard let program, program.hasPrefix("/") else { return false }
        return !FileManager.default.fileExists(atPath: program)
    }

    /// The app bundle the executable lives in, if any.
    public var owningApp: URL? {
        guard let program, let range = program.range(of: ".app/") else { return nil }
        return URL(filePath: String(program[..<range.lowerBound]) + ".app")
    }
}

public enum LaunchItems {
    public static func folders(home: URL = Paths.home) -> [(URL, LaunchItem.Scope)] {
        [
            (home.appending(path: "Library/LaunchAgents", directoryHint: .isDirectory), .userAgent),
            (URL(filePath: "/Library/LaunchAgents", directoryHint: .isDirectory), .globalAgent),
            (URL(filePath: "/Library/LaunchDaemons", directoryHint: .isDirectory), .daemon),
        ]
    }

    /// Every third-party launch job, with live loaded and disabled state.
    public static func scan(home: URL = Paths.home) -> [LaunchItem] {
        let loaded = loadedLabels()
        let userDisabled = disabledLabels(domain: "gui/\(getuid())")
        let systemDisabled = disabledLabels(domain: "system")

        return folders(home: home).flatMap { folder, scope in
            FileSizer.children(of: folder)
                .filter { $0.pathExtension == "plist" }
                .compactMap { parse($0, scope: scope) }
                .map { item in
                    var item = item
                    item.isLoaded = loaded.contains(item.label)
                    item.isDisabled = (scope == .daemon ? systemDisabled : userDisabled).contains(item.label)
                    return item
                }
        }
        .sorted { $0.label.localizedStandardCompare($1.label) == .orderedAscending }
    }

    static func parse(_ url: URL, scope: LaunchItem.Scope) -> LaunchItem? {
        guard let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return nil }
        let label = plist["Label"] as? String ?? url.deletingPathExtension().lastPathComponent
        let program = plist["Program"] as? String ?? (plist["ProgramArguments"] as? [String])?.first
        let keepAlive = (plist["KeepAlive"] as? Bool) ?? (plist["KeepAlive"] is [String: Any])
        return LaunchItem(
            plistURL: url, label: label, scope: scope, program: program,
            runAtLoad: plist["RunAtLoad"] as? Bool ?? false, keepAlive: keepAlive
        )
    }

    /// Labels loaded in the user's session (`launchctl list`).
    static func loadedLabels() -> Set<String> {
        guard let output = try? Shell.run("/bin/launchctl", ["list"]).output else { return [] }
        return Set(output.split(whereSeparator: \.isNewline).dropFirst().compactMap { line in
            line.split(separator: "\t").last.map(String.init)
        })
    }

    static func disabledLabels(domain: String) -> Set<String> {
        guard let output = try? Shell.run("/bin/launchctl", ["print-disabled", domain]).output else { return [] }
        return parseDisabled(output)
    }

    /// Parses `launchctl print-disabled` lines like `"com.foo.agent" => disabled`.
    static func parseDisabled(_ output: String) -> Set<String> {
        var labels = Set<String>()
        for line in output.split(whereSeparator: \.isNewline) {
            let parts = line.components(separatedBy: "=>")
            guard parts.count == 2 else { continue }
            let state = parts[1].trimmingCharacters(in: .whitespaces)
            guard state == "disabled" || state == "true" else { continue }
            labels.insert(parts[0].trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "\"")))
        }
        return labels
    }

    /// Enables or disables a job persistently and starts or stops it right away.
    /// Agents are toggled in the user's session; daemons need an administrator password.
    public static func setEnabled(_ item: LaunchItem, _ enabled: Bool) throws {
        let plist = item.plistURL.path(percentEncoded: false)
        if item.scope.isPrivileged {
            let target = "system/\(item.label)"
            let command = enabled
                ? "/bin/launchctl enable \(Shell.shellQuoted(target)); /bin/launchctl bootstrap system \(Shell.shellQuoted(plist)) 2>/dev/null; true"
                : "/bin/launchctl disable \(Shell.shellQuoted(target)); /bin/launchctl bootout \(Shell.shellQuoted(target)) 2>/dev/null; true"
            let result = try Shell.runAsAdmin(command, prompt: "ShinyMac wants to change a background service.")
            if result.wasCancelled { throw CancellationError() }
        } else {
            let domain = "gui/\(getuid())"
            if enabled {
                try Shell.run("/bin/launchctl", ["enable", "\(domain)/\(item.label)"])
                try Shell.run("/bin/launchctl", ["bootstrap", domain, plist])
            } else {
                try Shell.run("/bin/launchctl", ["disable", "\(domain)/\(item.label)"])
                try Shell.run("/bin/launchctl", ["bootout", "\(domain)/\(item.label)"])
            }
        }
    }

    /// Stops the job and moves its plist to the Trash (or deletes it as administrator for system-wide items).
    public static func remove(_ item: LaunchItem) throws -> Cleaner.Report {
        if item.scope == .userAgent {
            _ = try? Shell.run("/bin/launchctl", ["bootout", "gui/\(getuid())/\(item.label)"])
            return Cleaner.remove([CleanupItem(url: item.plistURL, size: FileSizer.size(of: item.plistURL))], mode: .trash)
        }
        guard SafetyGuard.canRemove(item.plistURL) else { return Cleaner.Report() }
        let domain = item.scope == .daemon ? "system" : "gui/\(getuid())"
        let plist = item.plistURL.path(percentEncoded: false)
        // One prompt: stop the job and delete its plist together.
        let command = "/bin/launchctl bootout \(Shell.shellQuoted("\(domain)/\(item.label)")) 2>/dev/null; /bin/rm -f -- \(Shell.shellQuoted(plist))"
        let size = FileSizer.size(of: item.plistURL)
        let result = try Shell.runAsAdmin(command, prompt: "ShinyMac wants to remove a background service.")
        if result.wasCancelled { throw CancellationError() }

        var report = Cleaner.Report()
        if Cleaner.exists(item.plistURL) {
            report.failures.append(Cleaner.Failure(url: item.plistURL, reason: "Could not be removed", needsAdmin: false))
        } else {
            report.removed.append(item.plistURL)
            report.removedBytes = size
        }
        return report
    }
}
