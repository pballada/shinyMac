import Foundation
import Testing
@testable import ShinyCore

@Suite struct TrashScannerTests {
    @Test func listsTrashContentsLargestFirst() throws {
        let home = try TempFolder()
        try home.file(".Trash/small.txt", bytes: 2_000)
        try home.file(".Trash/Old Project/big.bin", bytes: 80_000)
        try home.file(".Trash/.DS_Store", bytes: 100)

        let groups = TrashScanner.scan(home: home.url, progress: ScanProgress())
        let trash = try #require(groups.first { $0.title == "Your Trash" })
        #expect(trash.items.map(\.name) == ["Old Project", "small.txt"])
        #expect(TrashScanner.isUserTrashReadable(home: home.url))
    }

    @Test func emptyTrashProducesNoGroup() throws {
        let home = try TempFolder()
        try FileManager.default.createDirectory(at: home.url.appending(path: ".Trash"), withIntermediateDirectories: true)
        #expect(TrashScanner.scan(home: home.url, progress: ScanProgress()).allSatisfy { $0.title != "Your Trash" })
    }
}
