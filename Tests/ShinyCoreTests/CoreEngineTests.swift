import Foundation
import Testing
@testable import ShinyCore

/// A throwaway folder that deletes itself.
final class TempFolder {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory.appending(path: "ShinyCoreTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    deinit { try? FileManager.default.removeItem(at: url) }

    @discardableResult
    func file(_ name: String, bytes: Int) throws -> URL {
        let fileURL = url.appending(path: name)
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(repeating: 7, count: bytes).write(to: fileURL)
        return fileURL
    }
}

@Suite struct SafetyGuardTests {
    let home = URL(filePath: "/Users/tester", directoryHint: .isDirectory)

    @Test(arguments: [
        "/", "/System", "/System/Library/CoreServices", "/Applications", "/Library", "/Library/Caches",
        "/usr/local/bin", "/Users", "/Users/tester", "/Users/someone", "/Users/tester/Library",
        "/Users/tester/Library/Caches", "/Users/tester/Documents", "/Users/tester/Library/Application Support/",
        "/private", "/private/etc/hosts",
    ])
    func protectsCriticalLocations(_ path: String) {
        #expect(!SafetyGuard.canRemove(URL(filePath: path), home: home))
    }

    @Test(arguments: [
        "/Applications/Some App.app", "/Users/tester/Library/Caches/com.example.app",
        "/Users/tester/Library/Logs/Example", "/Users/tester/Downloads/movie.mov",
        "/Library/Caches/com.example.agent", "/Users/tester/Library/Developer/Xcode/DerivedData/Proj-abc",
    ])
    func allowsOrdinaryItems(_ path: String) {
        #expect(SafetyGuard.canRemove(URL(filePath: path), home: home))
    }

    @Test func rejectsPathTraversal() {
        #expect(!SafetyGuard.canRemove(URL(filePath: "/Users/tester/Library/Caches/../.."), home: home))
    }

    @Test func rejectsNonFileURLs() throws {
        #expect(!SafetyGuard.canRemove(try #require(URL(string: "https://example.com/a/b")), home: home))
    }
}

@Suite struct ShellTests {
    @Test func shellQuotingEscapesSingleQuotes() {
        #expect(Shell.shellQuoted("/tmp/it's here") == "'/tmp/it'\\''s here'")
    }

    @Test func appleScriptQuotingEscapesQuotesAndBackslashes() {
        #expect(Shell.appleScriptQuoted(#"say "hi" \ bye"#) == #""say \"hi\" \\ bye""#)
    }

    @Test func runsProcesses() throws {
        let result = try Shell.run("/bin/echo", ["hello"])
        #expect(result.succeeded)
        #expect(result.output.trimmingCharacters(in: .whitespacesAndNewlines) == "hello")
    }
}

@Suite struct FileSizerTests {
    @Test func sizesFilesAndFolders() throws {
        let temp = try TempFolder()
        try temp.file("a.bin", bytes: 10_000)
        try temp.file("nested/b.bin", bytes: 50_000)

        #expect(FileSizer.size(of: temp.url.appending(path: "a.bin")) >= 10_000)
        #expect(FileSizer.size(of: temp.url) >= 60_000)
        #expect(FileSizer.size(of: temp.url.appending(path: "missing")) == 0)
    }

    @Test func doesNotFollowSymlinks() throws {
        let temp = try TempFolder()
        let target = try temp.file("big.bin", bytes: 200_000)
        let link = temp.url.appending(path: "link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
        #expect(FileSizer.size(of: link) == 0)
    }
}

@Suite struct CleanerTests {
    @Test func deletesItemsAndReportsFreedBytes() throws {
        let temp = try TempFolder()
        let file = try temp.file("junk/cache.bin", bytes: 30_000)
        let item = FileSizer.item(at: file)

        let report = Cleaner.remove([item], mode: .delete)

        #expect(report.failures.isEmpty)
        #expect(report.removed == [file])
        #expect(report.removedBytes == item.size)
        #expect(!FileManager.default.fileExists(atPath: file.path(percentEncoded: false)))
    }

    @Test func refusesProtectedLocations() {
        let item = CleanupItem(url: Paths.library, size: 1)
        let report = Cleaner.remove([item], mode: .delete)
        #expect(report.removed.isEmpty)
        #expect(report.failures.first?.reason == "Protected location")
    }

    @Test func missingItemsCountAsRemoved() throws {
        let temp = try TempFolder()
        let ghost = CleanupItem(url: temp.url.appending(path: "already-gone"), size: 5)
        let report = Cleaner.remove([ghost], mode: .delete)
        #expect(report.failures.isEmpty)
        #expect(report.removedBytes == 5)
    }
}

@Suite struct ScanProgressTests {
    @Test func clampsFractionAndAccumulatesBytes() {
        let progress = ScanProgress()
        progress.update(detail: "x", fraction: 1.7)
        progress.found(bytes: 10)
        progress.found(bytes: 5)
        #expect(progress.snapshot == ScanProgress.Snapshot(detail: "x", fraction: 1, bytesFound: 15))
    }
}
