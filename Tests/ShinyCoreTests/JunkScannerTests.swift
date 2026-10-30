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

    @Test func findsIOSFirmwareAndNamesDeviceBackups() throws {
        let home = try TempFolder()
        try home.file("Library/iTunes/iPhone Software Updates/iPhone_18.0_Restore.ipsw", bytes: 60_000)
        try home.file("Library/iTunes/iPhone Software Updates/notes.txt", bytes: 100)
        let backup = home.url.appending(path: "Library/Application Support/MobileSync/Backup/00008110-ABC")
        try FileManager.default.createDirectory(at: backup, withIntermediateDirectories: true)
        try PropertyListSerialization.data(fromPropertyList: [
            "Device Name": "Test iPhone", "Last Backup Date": Date(timeIntervalSince1970: 1_700_000_000),
        ], format: .xml, options: 0).write(to: backup.appending(path: "Info.plist"))
        try home.file("Library/Application Support/MobileSync/Backup/00008110-ABC/Manifest.db", bytes: 40_000)

        let groups = Dictionary(uniqueKeysWithValues: JunkScanner.scan(home: home.url, progress: ScanProgress()).map { ($0.id, $0) })
        #expect(groups["iosUpdates"]?.items.map(\.name) == ["iPhone_18.0_Restore.ipsw"])
        let backups = try #require(groups["iosBackups"])
        #expect(!backups.selectedByDefault)
        #expect(backups.items.first?.name.hasPrefix("Test iPhone · ") == true)
    }
}
