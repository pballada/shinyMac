import Foundation

/// A tune-up script ShinyMac can run.
public struct MaintenanceTask: Identifiable, Sendable, Hashable {
    public let id: String
    public let title: String
    public let detail: String
    public let symbol: String
    public let needsAdmin: Bool
    public let recommended: Bool
    /// `/bin/sh` command line. Must be idempotent and safe to run at any time.
    public let command: String
}

public enum MaintenanceOutcome: Sendable, Equatable {
    case success
    case failed(String)
    case cancelled
}

public enum Maintenance {
    static let lsregister = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

    public static let tasks: [MaintenanceTask] = [
        MaintenanceTask(
            id: "freeRAM", title: "Free Up RAM",
            detail: "Purges inactive memory so apps that need it get it right away.",
            symbol: "memorychip.fill", needsAdmin: true, recommended: true, command: "/usr/sbin/purge"
        ),
        MaintenanceTask(
            id: "flushDNS", title: "Flush DNS Cache",
            detail: "Clears stale name lookups. Fixes sites that won't load after network changes.",
            symbol: "network", needsAdmin: true, recommended: true,
            command: "/usr/bin/dscacheutil -flushcache; /usr/bin/killall -HUP mDNSResponder"
        ),
        MaintenanceTask(
            id: "quickLook", title: "Reset Quick Look",
            detail: "Clears thumbnail and preview caches, fixing blank or outdated previews.",
            symbol: "eye.fill", needsAdmin: false, recommended: true, command: "/usr/bin/qlmanage -r cache && /usr/bin/qlmanage -r"
        ),
        MaintenanceTask(
            id: "launchServices", title: "Rebuild Launch Services",
            detail: "Repairs the database behind \"Open With\" menus, duplicate entries and default apps.",
            symbol: "arrow.triangle.2.circlepath", needsAdmin: false, recommended: false,
            command: "\(lsregister) -gc && \(lsregister) -f -r -all local,system,user"
        ),
        MaintenanceTask(
            id: "spotlight", title: "Reindex Spotlight",
            detail: "Rebuilds the search index when results are missing or wrong. Takes a while in the background.",
            symbol: "magnifyingglass", needsAdmin: true, recommended: false, command: "/usr/bin/mdutil -E /"
        ),
        MaintenanceTask(
            id: "fontCache", title: "Clear Font Caches",
            detail: "Fixes garbled or missing fonts. Takes effect after you log out.",
            symbol: "textformat", needsAdmin: false, recommended: false, command: "/usr/bin/atsutil databases -removeUser"
        ),
        MaintenanceTask(
            id: "timeMachine", title: "Thin Time Machine Snapshots",
            detail: "Removes local snapshots that hold on to purgeable space.",
            symbol: "clock.arrow.circlepath", needsAdmin: true, recommended: false,
            command: "/usr/bin/tmutil thinlocalsnapshots / 999999999999 4"
        ),
        MaintenanceTask(
            id: "mail", title: "Speed Up Mail",
            detail: "Compacts Mail's message index. Mail must be closed; needs Full Disk Access.",
            symbol: "envelope.fill", needsAdmin: false, recommended: false,
            command: #"if /usr/bin/pgrep -xq Mail; then echo "Quit Mail first" >&2; exit 1; fi; for f in "$HOME"/Library/Mail/V*/MailData/"Envelope Index"; do [ -f "$f" ] && /usr/bin/sqlite3 "$f" "VACUUM;"; done; true"#
        ),
    ]

    /// Runs one task as the current user.
    public static func run(_ task: MaintenanceTask) -> MaintenanceOutcome {
        precondition(!task.needsAdmin, "Use runAsAdmin(_:) for privileged tasks")
        do {
            let result = try Shell.run("/bin/sh", ["-c", task.command])
            return result.succeeded ? .success : .failed(lastLine(of: result.output) ?? "Exited with status \(result.status)")
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    /// Runs privileged tasks in one batch so macOS only asks for the password once.
    public static func runAsAdmin(_ tasks: [MaintenanceTask]) -> [String: MaintenanceOutcome] {
        guard !tasks.isEmpty else { return [:] }
        do {
            let result = try Shell.runAsAdmin(batchScript(for: tasks), prompt: "ShinyMac wants to run maintenance tasks.")
            if result.wasCancelled {
                return Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, .cancelled) })
            }
            return parseBatchOutput(result.output, tasks: tasks)
        } catch {
            return Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, .failed(error.localizedDescription)) })
        }
    }

    /// Each task reports its own status marker so one failure doesn't hide the others.
    static func batchScript(for tasks: [MaintenanceTask]) -> String {
        tasks.map { "( \($0.command) ) >/dev/null 2>&1 && echo '#ok:\($0.id)' || echo '#fail:\($0.id)'" }
            .joined(separator: "; ")
    }

    static func parseBatchOutput(_ output: String, tasks: [MaintenanceTask]) -> [String: MaintenanceOutcome] {
        var outcomes: [String: MaintenanceOutcome] = [:]
        for task in tasks {
            if output.contains("#ok:\(task.id)") {
                outcomes[task.id] = .success
            } else if output.contains("#fail:\(task.id)") {
                outcomes[task.id] = .failed("The command reported an error")
            } else {
                outcomes[task.id] = .failed("Didn't run")
            }
        }
        return outcomes
    }

    private static func lastLine(of output: String) -> String? {
        output.split(whereSeparator: \.isNewline).last.map(String.init)
    }
}
