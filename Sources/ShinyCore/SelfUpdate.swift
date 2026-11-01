import Foundation
import Security

/// Keeps ShinyMac itself up to date from its GitHub releases.
/// A download is installed only if it is signed by the same Developer ID team as the running app.
public enum SelfUpdate {
    public struct Release: Equatable, Sendable {
        public let version: String
        public let notes: String
        public let page: URL
        public let download: URL
    }

    public enum Failure: LocalizedError, Equatable {
        case badSignature
        case noAppInArchive
        case notWritable(String)
        case tool(String)

        public var errorDescription: String? {
            switch self {
            case .badSignature: "The download isn't signed by the ShinyMac developer, so it wasn't installed."
            case .noAppInArchive: "The download didn't contain the app."
            case .notWritable(let folder): "ShinyMac can't replace itself in \(folder). Download the update from GitHub instead."
            case .tool(let output): output
            }
        }
    }

    public static let repository = "pballada/shinyMac"
    public static let bundleIdentifier = "com.pballada.shinymac"
    public static let teamIdentifier = "5UXXXESGMK"

    static var latestReleaseURL: URL { URL(string: "https://api.github.com/repos/\(repository)/releases/latest")! }

    // MARK: Checking

    /// The newest published release, if it's newer than `currentVersion`.
    public static func check(currentVersion: String, session: URLSession = .shared) async throws -> Release? {
        var request = URLRequest(url: latestReleaseURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let (data, _) = try await session.data(for: request)
        guard let release = parseRelease(data), UpdateChecker.isNewer(release.version, than: currentVersion) else { return nil }
        return release
    }

    /// Reads GitHub's release JSON. Drafts, pre-releases and releases without a zip are ignored.
    static func parseRelease(_ data: Data) -> Release? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              json["draft"] as? Bool != true, json["prerelease"] as? Bool != true,
              let tag = json["tag_name"] as? String,
              let page = (json["html_url"] as? String).flatMap(URL.init(string:)),
              let assets = json["assets"] as? [[String: Any]],
              let zip = assets.lazy.compactMap({ $0["browser_download_url"] as? String })
                .first(where: { $0.hasSuffix(".zip") && $0.contains("ShinyMac") }),
              let download = URL(string: zip)
        else { return nil }
        let version = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        return Release(version: version, notes: json["body"] as? String ?? "", page: page, download: download)
    }

    // MARK: Installing

    /// Downloads `release`, checks its signature and swaps it in place of `app`. The running copy keeps working
    /// until it quits; relaunching opens the new version.
    public static func install(_ release: Release, replacing app: URL, session: URLSession = .shared) async throws {
        let folder = app.deletingLastPathComponent()
        guard FileManager.default.isWritableFile(atPath: folder.path) else { throw Failure.notWritable(folder.path) }

        let work = FileManager.default.temporaryDirectory.appending(path: "ShinyMacUpdate-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: work) }

        let (downloaded, _) = try await session.download(from: release.download)
        let archive = work.appending(path: "update.zip")
        try FileManager.default.moveItem(at: downloaded, to: archive)

        let unzip = try Shell.run("/usr/bin/ditto", ["-x", "-k", archive.path, work.path])
        guard unzip.succeeded else { throw Failure.tool(unzip.output) }
        guard let newApp = FileSizer.children(of: work).first(where: { $0.pathExtension == "app" }) else {
            throw Failure.noAppInArchive
        }
        guard isTrusted(newApp) else { throw Failure.badSignature }

        // Zips from the web are quarantined; the signature was just verified, so open it without a Gatekeeper prompt.
        _ = try? Shell.run("/usr/bin/xattr", ["-dr", "com.apple.quarantine", newApp.path])
        _ = try FileManager.default.replaceItemAt(app, withItemAt: newApp)
    }

    /// The code signing rule a download has to meet: Apple-issued Developer ID, our bundle ID and our team.
    static var requirementText: String {
        "anchor apple generic and identifier \"\(bundleIdentifier)\" and certificate leaf[subject.OU] = \"\(teamIdentifier)\""
    }

    static func isTrusted(_ app: URL, requirement text: String = requirementText) -> Bool {
        var code: SecStaticCode?
        var requirement: SecRequirement?
        guard SecStaticCodeCreateWithPath(app as CFURL, [], &code) == errSecSuccess, let code,
              SecRequirementCreateWithString(text as CFString, [], &requirement) == errSecSuccess, let requirement
        else { return false }
        let flags = SecCSFlags(rawValue: kSecCSCheckAllArchitectures | kSecCSStrictValidate | kSecCSCheckNestedCode)
        return SecStaticCodeCheckValidity(code, flags, requirement) == errSecSuccess
    }

    /// Opens `app` once this process has exited, for "Relaunch" after an update.
    public static func relaunch(_ app: URL, after pid: Int32 = ProcessInfo.processInfo.processIdentifier) throws {
        let script = "while kill -0 \(pid) 2>/dev/null; do sleep 0.2; done; /usr/bin/open \(Shell.shellQuoted(app.path))"
        let process = Process()
        process.executableURL = URL(filePath: "/bin/sh")
        process.arguments = ["-c", script]
        try process.run()
    }
}
