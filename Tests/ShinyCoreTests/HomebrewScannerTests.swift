import Foundation
import Testing
@testable import ShinyCore

@Suite struct HomebrewScannerTests {
    @Test func parsesAutoremoveDryRun() {
        let output = """
        ==> Would autoremove 3 unneeded formulae:
        libyaml
        python@3.11
        sqlite
        Warning: something unrelated
        """
        #expect(HomebrewScanner.parseAutoremove(output) == ["libyaml", "python@3.11", "sqlite"])
        #expect(HomebrewScanner.parseAutoremove("") == [])
    }

    @Test func findsOldVersionsButKeepsTheLinkedAndPinnedOnes() throws {
        let prefix = try TempFolder()
        try prefix.file("Cellar/wget/1.21/bin/wget", bytes: 50_000)
        try prefix.file("Cellar/wget/1.24/bin/wget", bytes: 50_000)
        try prefix.file("Cellar/jq/1.7/bin/jq", bytes: 50_000)
        try prefix.file("Cellar/node/20/bin/node", bytes: 50_000)
        try prefix.file("Cellar/node/22/bin/node", bytes: 50_000)
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: prefix.url.appending(path: "opt"), withIntermediateDirectories: true)
        try fileManager.createSymbolicLink(atPath: prefix.url.appending(path: "opt/wget").path, withDestinationPath: "../Cellar/wget/1.24")
        try fileManager.createSymbolicLink(atPath: prefix.url.appending(path: "opt/jq").path, withDestinationPath: "../Cellar/jq/1.7")
        try fileManager.createSymbolicLink(atPath: prefix.url.appending(path: "opt/node").path, withDestinationPath: "../Cellar/node/22")
        try fileManager.createDirectory(at: prefix.url.appending(path: "var/homebrew/pinned"), withIntermediateDirectories: true)
        try fileManager.createSymbolicLink(atPath: prefix.url.appending(path: "var/homebrew/pinned/node").path, withDestinationPath: "../../../Cellar/node/22")

        let group = HomebrewScanner.oldVersionsGroup(prefix: prefix.url, brew: "/opt/homebrew/bin/brew")
        #expect(group.items.map(\.name) == ["wget"], "jq has one version and node is pinned")
        #expect(group.items.first?.url.lastPathComponent == "1.21")
        #expect(group.items.first?.note == "Old 1.21 · keeps 1.24")
        guard case .command(_, let arguments)? = group.items.first?.removal else {
            Issue.record("Old versions are removed by brew cleanup")
            return
        }
        #expect(arguments.suffix(2) == ["cleanup", "wget"])
        #expect(arguments.contains("HOMEBREW_NO_AUTO_UPDATE=1"))
    }

    @Test func noPrefixMeansNothingToScan() {
        #expect(HomebrewScanner.prefix(candidates: ["/nonexistent-shinymac"]) == nil)
        #expect(HomebrewScanner.scan(prefix: nil, progress: ScanProgress()).isEmpty)
    }
}
