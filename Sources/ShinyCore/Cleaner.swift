import Foundation

/// Removes cleanup items from disk, never touching anything `SafetyGuard` protects.
public enum Cleaner {
    public struct Failure: Identifiable, Hashable, Sendable {
        public var id: URL { url }
        public let url: URL
        public let reason: String
        /// True when retrying with administrator privileges would likely succeed.
        public let needsAdmin: Bool
    }

    public struct Report: Sendable {
        public var removedBytes: Int64 = 0
        public var removed: [URL] = []
        public var failures: [Failure] = []

        public init() {}

        public mutating func merge(_ other: Report) {
            removedBytes += other.removedBytes
            removed += other.removed
            failures += other.failures
        }
    }

    public static func remove(_ items: [CleanupItem], mode: RemovalMode, progress: ScanProgress? = nil) -> Report {
        var report = Report()
        let fileManager = FileManager.default

        for (index, item) in items.enumerated() {
            if Task.isCancelled { break }
            progress?.update(detail: Paths.abbreviated(item.url), fraction: Double(index) / Double(max(items.count, 1)))

            if let tool = toolCommand(for: item.removal) {
                runTool(tool, for: item, into: &report)
                continue
            }

            guard SafetyGuard.canRemove(item.url) else {
                report.failures.append(Failure(url: item.url, reason: "Protected location", needsAdmin: false))
                continue
            }

            do {
                switch item.removal == .moveToTrash ? .trash : mode {
                case .trash: try fileManager.trashItem(at: item.url, resultingItemURL: nil)
                case .delete: try fileManager.removeItem(at: item.url)
                }
                report.removedBytes += item.size
                report.removed.append(item.url)
            } catch {
                if !exists(item.url) {
                    // Already gone (e.g. removed together with its parent).
                    report.removedBytes += item.size
                    report.removed.append(item.url)
                    continue
                }
                // A folder delete can fail halfway; count what did get freed.
                if mode == .delete {
                    report.removedBytes += max(0, item.size - FileSizer.size(of: item.url))
                }
                report.failures.append(Failure(
                    url: item.url,
                    reason: (error as NSError).localizedDescription,
                    needsAdmin: isPermissionError(error)
                ))
            }
        }
        progress?.update(fraction: 1)
        return report
    }

    /// Permanently deletes paths as root, after macOS asks for an administrator password.
    /// Only paths that pass `SafetyGuard` are touched.
    public static func removeWithPrivileges(_ urls: [URL]) throws -> Report {
        let safe = urls.filter { SafetyGuard.canRemove($0) }
        guard !safe.isEmpty else { return Report() }
        let sizes = Dictionary(uniqueKeysWithValues: safe.map { ($0, FileSizer.size(of: $0)) })
        let command = "/bin/rm -rf -- " + safe.map { Shell.shellQuoted($0.path(percentEncoded: false)) }.joined(separator: " ")
        let result = try Shell.runAsAdmin(command, prompt: "ShinyMac needs your permission to remove protected files.")
        if result.wasCancelled { throw CancellationError() }

        var report = Report()
        for url in safe {
            if exists(url) {
                report.failures.append(Failure(url: url, reason: "Could not be removed, even as administrator", needsAdmin: false))
            } else {
                report.removedBytes += sizes[url] ?? 0
                report.removed.append(url)
            }
        }
        return report
    }

    /// Items that a developer tool removes rather than the file system.
    static func toolCommand(for removal: Removal) -> [String]? {
        switch removal {
        case .file, .moveToTrash: nil
        case .simulator(let udid): ["simctl", "delete", udid]
        case .simulatorRuntime(let identifier): ["simctl", "runtime", "delete", identifier]
        }
    }

    private static func runTool(_ arguments: [String], for item: CleanupItem, into report: inout Report) {
        do {
            let result = try Shell.run("/usr/bin/xcrun", arguments)
            if result.succeeded {
                report.removedBytes += item.size
                report.removed.append(item.url)
            } else {
                let reason = result.output.split(whereSeparator: \.isNewline).last.map(String.init) ?? "xcrun failed"
                report.failures.append(Failure(url: item.url, reason: reason, needsAdmin: false))
            }
        } catch {
            report.failures.append(Failure(url: item.url, reason: error.localizedDescription, needsAdmin: false))
        }
    }

    static func exists(_ url: URL) -> Bool {
        // lstat semantics: a dangling symlink still "exists".
        (try? url.checkResourceIsReachable()) == true
            || (try? FileManager.default.attributesOfItem(atPath: url.path(percentEncoded: false))) != nil
    }

    static func isPermissionError(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain,
           [NSFileWriteNoPermissionError, NSFileReadNoPermissionError].contains(nsError.code) {
            return true
        }
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError,
           underlying.domain == NSPOSIXErrorDomain,
           [Int(EACCES), Int(EPERM)].contains(underlying.code) {
            return true
        }
        return nsError.domain == NSPOSIXErrorDomain && [Int(EACCES), Int(EPERM)].contains(nsError.code)
    }
}
