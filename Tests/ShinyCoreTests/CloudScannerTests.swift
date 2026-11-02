import Foundation
import Testing
@testable import ShinyCore

@Suite struct CloudScannerTests {
    @Test func namesProvidersFromTheirFolders() {
        #expect(CloudScanner.splitProviderFolder("GoogleDrive-me@example.com") == ("Google Drive", "me@example.com"))
        #expect(CloudScanner.splitProviderFolder("OneDrive-Personal") == ("OneDrive", "Personal"))
        #expect(CloudScanner.splitProviderFolder("Dropbox") == ("Dropbox", nil))
        #expect(CloudScanner.splitProviderFolder("ProtonDrive-me@proton.me") == ("Proton Drive", "me@proton.me"))
    }

    @Test func namesICloudAppContainers() {
        #expect(CloudScanner.containerName("com~apple~Pages") == "Pages")
        #expect(CloudScanner.containerName("iCloud~md~obsidian") == "obsidian")
    }

    @Test func listsBigAndStaleDownloadsButOnlyPreselectsStaleOnes() throws {
        let home = try TempFolder()
        let now = Date.now
        let drive = "Library/Mobile Documents/com~apple~CloudDocs"
        try home.file("\(drive)/Projects/video.mov", bytes: 3_000_000)
        try age(home.file("\(drive)/old.pdf", bytes: 1_500_000), days: 400, from: now)
        try home.file("\(drive)/recent.pdf", bytes: 1_500_000)
        try home.file("\(drive)/note.txt", bytes: 100)
        try home.file("Library/Mobile Documents/com~apple~Keynote/Documents/talk.key", bytes: 3_000_000)
        try home.file("Library/CloudStorage/Dropbox/Photos/a.jpg", bytes: 3_200_000)
        try home.file("Library/CloudStorage/.hidden/x", bytes: 3_000_000)

        var thresholds = CloudScanner.Thresholds()
        thresholds.big = 2_500_000
        thresholds.stale = 1_000_000
        let groups = CloudScanner.scan(home: home.url, thresholds: thresholds, now: now, progress: ScanProgress())
        let byTitle = Dictionary(uniqueKeysWithValues: groups.map { ($0.title, $0) })
        #expect(Set(byTitle.keys) == ["iCloud Drive", "iCloud App Documents", "Dropbox"])

        let drivegroup = try #require(byTitle["iCloud Drive"])
        #expect(Set(drivegroup.items.map(\.name)) == ["video.mov", "old.pdf"], "Small recent files aren't worth a row")
        #expect(drivegroup.items.first { $0.name == "old.pdf" }?.isRecommended == true)
        #expect(drivegroup.items.first { $0.name == "video.mov" }?.isRecommended == false, "Big but recently used stays unchecked")
        #expect(drivegroup.items.first { $0.name == "video.mov" }?.note?.hasPrefix("Projects · used") == true)

        let apps = try #require(byTitle["iCloud App Documents"])
        #expect(apps.items.map(\.name) == ["talk.key"], "iCloud Drive isn't listed again as an app container")
        #expect(apps.items.first?.note?.hasPrefix("Keynote/Documents") == true)
        #expect(groups.flatMap(\.items).allSatisfy { $0.removal == .evictDownload })
    }

    private func age(_ url: URL, days: Double, from now: Date) throws {
        var url = url
        var values = URLResourceValues()
        let date = now.addingTimeInterval(-days * 86_400)
        values.contentAccessDate = date
        values.contentModificationDate = date
        try url.setResourceValues(values)
    }

    @Test func evictingIsNeverAFileDeletion() {
        #expect(Cleaner.toolCommand(for: .evictDownload) == nil)
    }
}
