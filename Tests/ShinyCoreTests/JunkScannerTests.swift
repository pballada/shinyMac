import Foundation
import Testing
@testable import ShinyCore

@Suite struct JunkScannerTests {
    @Test func findsCachesLogsAndDeveloperJunkInAFakeHome() throws {
        let home = try TempFolder()
        try home.file("Library/Caches/com.example.app/data.bin", bytes: 40_000)
        try home.file("Library/Caches/CloudKit/keep.bin", bytes: 40_000)
        try home.file("Library/Caches/Homebrew/downloads/x.tar.gz", bytes: 20_000)
        try home.file("Library/Logs/Example/app.log", bytes: 8_000)
        try home.file("Library/Developer/Xcode/DerivedData/Proj-abc/Build.bin", bytes: 64_000)
        try home.file(".npm/_cacache/index", bytes: 4_000)
        try home.file("Downloads/Installer.dmg", bytes: 12_000)

        let groups = JunkScanner.scan(home: home.url, progress: ScanProgress())
        let byID = Dictionary(uniqueKeysWithValues: groups.map { ($0.id, $0) })

        let caches = try #require(byID["userCaches"])
        #expect(caches.items.map(\.name) == ["com.example.app"], "CloudKit and Homebrew must not be reported as user caches")

        let dev = try #require(byID["devCaches"])
        #expect(Set(dev.items.map(\.name)) == ["Homebrew downloads", "npm cache"])

        #expect(byID["logs"]?.items.count == 1)
        #expect(byID["xcode"]?.items.first?.name == "Proj-abc")

        let installers = try #require(byID["installers"])
        #expect(!installers.selectedByDefault)
        #expect(byID["mail"] == nil, "Empty categories are dropped")
    }

    @Test func detectsBrokenPropertyLists() throws {
        let temp = try TempFolder()
        let good = temp.url.appending(path: "good.plist")
        try PropertyListSerialization.data(fromPropertyList: ["a": 1], format: .xml, options: 0).write(to: good)
        let broken = try temp.file("broken.plist", bytes: 0)
        try Data("<plist><dict><key>oops".utf8).write(to: broken)

        #expect(!JunkScanner.isBrokenPropertyList(good))
        #expect(JunkScanner.isBrokenPropertyList(broken))
    }
}
