import Foundation
import Testing
@testable import ShinyCore

@Suite struct DuplicateFinderTests {
    @Test func findsIdenticalFilesAndKeepsTheOldest() throws {
        let home = try TempFolder()
        let content = Data((0..<200_000).map { UInt8($0 % 251) })
        let original = home.url.appending(path: "Documents/photo.jpg")
        let copy = home.url.appending(path: "Downloads/photo copy.jpg")
        for url in [original, copy] {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try content.write(to: url)
        }
        try FileManager.default.setAttributes([.creationDate: Date(timeIntervalSince1970: 1_000_000)], ofItemAtPath: original.path)

        // Same size and same first 64 KB, but different at the end: not a duplicate.
        var lookalike = content
        lookalike[lookalike.count - 1] ^= 0xFF
        try lookalike.write(to: home.url.appending(path: "Downloads/other.jpg"))
        // Same content inside Library is ignored.
        try home.file("Library/Caches/x.bin", bytes: 0)
        try content.write(to: home.url.appending(path: "Library/Caches/x.bin"))

        let groups = DuplicateFinder.scan(root: home.url, minimumSize: 100_000, progress: ScanProgress())
        let group = try #require(groups.first)
        #expect(groups.count == 1)
        #expect(group.items.map(\.url.lastPathComponent) == ["photo.jpg", "photo copy.jpg"])
        #expect(group.items.map(\.isRecommended) == [false, true])
    }

    @Test func hashesPrefixOrWholeFile() throws {
        let temp = try TempFolder()
        let a = temp.url.appending(path: "a")
        let b = temp.url.appending(path: "b")
        try Data(repeating: 1, count: 100_000).write(to: a)
        var other = Data(repeating: 1, count: 100_000)
        other[99_999] = 2
        try other.write(to: b)
        #expect(DuplicateFinder.hash(a, limit: 65_536) == DuplicateFinder.hash(b, limit: 65_536))
        #expect(DuplicateFinder.hash(a, limit: nil) != DuplicateFinder.hash(b, limit: nil))
    }
}
