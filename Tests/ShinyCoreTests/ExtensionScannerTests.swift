import Foundation
import Testing
@testable import ShinyCore

@Suite struct ExtensionScannerTests {
    @Test func listsExtensionsWithFriendlyNamesUnchecked() throws {
        let home = try TempFolder()
        let plugin = home.url.appending(path: "Library/QuickLook/Markdown.qlgenerator")
        try FileManager.default.createDirectory(at: plugin.appending(path: "Contents"), withIntermediateDirectories: true)
        try PropertyListSerialization.data(fromPropertyList: ["CFBundleName": "QLMarkdown", "CFBundleShortVersionString": "1.0.5"],
                                           format: .xml, options: 0).write(to: plugin.appending(path: "Contents/Info.plist"))
        try home.file("Library/Screen Savers/Aerial.saver/Contents/MacOS/Aerial", bytes: 20_000)
        try home.file("Library/Screen Savers/notes.txt", bytes: 100)

        let groups = ExtensionScanner.scan(home: home.url, progress: ScanProgress())
        let inHome = { (item: CleanupItem) in item.url.path.hasPrefix(home.url.path) }

        let quickLook = try #require(groups.first { $0.id == "quickLook" })
        #expect(quickLook.items.filter(inHome).map(\.name) == ["QLMarkdown 1.0.5"])
        #expect(!quickLook.selectedByDefault)
        let savers = try #require(groups.first { $0.id == "screenSavers" })
        #expect(savers.items.filter(inHome).map(\.name) == ["Aerial"])
    }
}
