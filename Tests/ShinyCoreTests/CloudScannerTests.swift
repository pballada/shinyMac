import Foundation
import Testing
@testable import ShinyCore

@Suite struct CloudScannerTests {
    @Test func namesProvidersFromTheirFolders() {
        #expect(CloudScanner.splitProviderFolder("GoogleDrive-me@example.com") == ("Google Drive", "me@example.com"))
        #expect(CloudScanner.splitProviderFolder("OneDrive-Personal") == ("OneDrive", "Personal"))
        #expect(CloudScanner.splitProviderFolder("Dropbox") == ("Dropbox", nil))
    }

    @Test func reportsDownloadedItemsPerProvider() throws {
        let home = try TempFolder()
        try home.file("Library/Mobile Documents/com~apple~CloudDocs/Projects/video.mov", bytes: 2_000_000)
        try home.file("Library/Mobile Documents/com~apple~CloudDocs/note.txt", bytes: 100)
        try home.file("Library/CloudStorage/Dropbox/Photos/a.jpg", bytes: 1_500_000)
        try home.file("Library/CloudStorage/.hidden/x", bytes: 2_000_000)

        let groups = CloudScanner.scan(home: home.url, progress: ScanProgress())
        #expect(groups.map(\.title) == ["iCloud Drive", "Dropbox"])
        #expect(groups[0].items.map(\.name) == ["Projects"], "Items under 1 MB are skipped")
        #expect(groups.flatMap(\.items).allSatisfy { $0.removal == .evictDownload })
    }

    @Test func evictingIsNeverAFileDeletion() {
        #expect(Cleaner.toolCommand(for: .evictDownload) == nil)
    }
}
