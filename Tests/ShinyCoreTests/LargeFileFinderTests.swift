import Foundation
import Testing
@testable import ShinyCore

@Suite struct LargeFileFinderTests {
    @Test func classifiesFileKinds() {
        #expect(FileKind.of(URL(filePath: "/a/movie.mov")) == .video)
        #expect(FileKind.of(URL(filePath: "/a/song.mp3")) == .audio)
        #expect(FileKind.of(URL(filePath: "/a/photo.HEIC")) == .picture)
        #expect(FileKind.of(URL(filePath: "/a/backup.zip")) == .archive)
        #expect(FileKind.of(URL(filePath: "/a/installer.dmg")) == .diskImage)
        #expect(FileKind.of(URL(filePath: "/a/report.pdf")) == .document)
        #expect(FileKind.of(URL(filePath: "/a/Thing.app"), isPackage: true) == .application)
        #expect(FileKind.of(URL(filePath: "/a/blob.xyz123")) == .other)
    }

    @Test func findsLargeFilesAndSkipsLibraryAndHiddenFolders() throws {
        let home = try TempFolder()
        try home.file("Movies/big.mov", bytes: 300_000)
        try home.file("Documents/small.txt", bytes: 1_000)
        try home.file("Library/Caches/huge.bin", bytes: 500_000)
        try home.file(".hidden/huge.bin", bytes: 500_000)
        try home.file("Downloads/archive.zip", bytes: 200_000)

        let files = LargeFileFinder.scan(root: home.url, minimumSize: 100_000, progress: ScanProgress())
        #expect(files.map(\.url.lastPathComponent) == ["big.mov", "archive.zip"])
        #expect(files.first?.kind == .video)
    }
}
