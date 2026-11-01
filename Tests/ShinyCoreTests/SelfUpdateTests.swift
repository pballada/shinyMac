import Foundation
import Testing
@testable import ShinyCore

@Suite struct SelfUpdateTests {
    func json(tag: String = "v0.3.0", draft: Bool = false, prerelease: Bool = false, assets: [String]) -> Data {
        let object: [String: Any] = [
            "tag_name": tag, "draft": draft, "prerelease": prerelease, "body": "Notes",
            "html_url": "https://github.com/pballada/shinyMac/releases/tag/\(tag)",
            "assets": assets.map { ["browser_download_url": "https://github.com/pballada/shinyMac/releases/download/\(tag)/\($0)"] },
        ]
        return try! JSONSerialization.data(withJSONObject: object)
    }

    @Test func readsTheReleaseZip() throws {
        let release = try #require(SelfUpdate.parseRelease(json(assets: ["checksums.txt", "ShinyMac-0.3.0.zip"])))
        #expect(release.version == "0.3.0")
        #expect(release.download.lastPathComponent == "ShinyMac-0.3.0.zip")
        #expect(release.notes == "Notes")
    }

    @Test func skipsDraftsPrereleasesAndReleasesWithoutAZip() {
        #expect(SelfUpdate.parseRelease(json(draft: true, assets: ["ShinyMac-0.3.0.zip"])) == nil)
        #expect(SelfUpdate.parseRelease(json(prerelease: true, assets: ["ShinyMac-0.3.0.zip"])) == nil)
        #expect(SelfUpdate.parseRelease(json(assets: ["notes.txt"])) == nil)
    }

    @Test func trustsOnlyAppsSignedByOurTeam() throws {
        // Apple's own apps are validly signed, but not by us.
        #expect(!SelfUpdate.isTrusted(URL(filePath: "/System/Library/CoreServices/Finder.app")))
        #expect(SelfUpdate.isTrusted(
            URL(filePath: "/System/Library/CoreServices/Finder.app"),
            requirement: "anchor apple and identifier \"com.apple.finder\""
        ), "The same check accepts an app that meets its requirement")

        // A notarized release build, when one has been made locally with scripts/release.sh.
        let release = URL(filePath: #filePath).deletingLastPathComponent().appending(path: "../../build/ShinyMac.app").standardized
        if FileManager.default.fileExists(atPath: release.path),
           (try? Shell.run("/usr/bin/codesign", ["-dv", release.path]))?.output.contains("TeamIdentifier=\(SelfUpdate.teamIdentifier)") == true {
            #expect(SelfUpdate.isTrusted(release))
        }
    }
}

/// Downloads the real latest release and installs it over a throwaway copy. Opt in with SHINYMAC_NETWORK_TESTS=1.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["SHINYMAC_NETWORK_TESTS"] != nil))
struct SelfUpdateNetworkTests {
    @Test func installsTheLatestReleaseOverAnOldCopy() async throws {
        let release = try #require(try await SelfUpdate.check(currentVersion: "0.0.1"))
        let folder = try TempFolder()
        let old = folder.url.appending(path: "ShinyMac.app")
        try FileManager.default.createDirectory(at: old.appending(path: "Contents"), withIntermediateDirectories: true)

        try await SelfUpdate.install(release, replacing: old)

        #expect(SelfUpdate.isTrusted(old))
        let info = NSDictionary(contentsOf: old.appending(path: "Contents/Info.plist"))
        #expect(info?["CFBundleShortVersionString"] as? String == release.version)
    }
}
