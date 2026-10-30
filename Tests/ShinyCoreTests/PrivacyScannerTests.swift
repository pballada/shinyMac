import Foundation
import Testing
@testable import ShinyCore

@Suite struct PrivacyScannerTests {
    @Test func findsChromiumHistoryAndCookiesButNeverPasswords() throws {
        let home = try TempFolder()
        let chrome = "Library/Application Support/Google/Chrome"
        try home.file("\(chrome)/Default/History", bytes: 50_000)
        try home.file("\(chrome)/Default/Cookies", bytes: 8_000)
        try home.file("\(chrome)/Default/Login Data", bytes: 8_000)
        try home.file("\(chrome)/Default/Bookmarks", bytes: 8_000)
        try home.file("\(chrome)/Profile 1/History", bytes: 9_000)

        let groups = PrivacyScanner.scan(home: home.url, progress: ScanProgress())
        let group = try #require(groups.first { $0.id == "com.google.Chrome" })
        let names = group.items.map(\.url.lastPathComponent)

        #expect(names.filter { $0 == "History" }.count == 2)
        #expect(names.contains("Cookies"))
        #expect(!names.contains("Login Data"))
        #expect(!names.contains("Bookmarks"))
        #expect(group.items.first { $0.url.lastPathComponent == "Cookies" }?.isRecommended == false)
        #expect(group.items.first { $0.url.lastPathComponent == "History" }?.isRecommended == true)
    }

    @Test func firefoxKeepsPlacesDatabase() throws {
        let home = try TempFolder()
        let profile = "Library/Application Support/Firefox/Profiles/abc.default"
        try home.file("\(profile)/places.sqlite", bytes: 10_000)
        try home.file("\(profile)/formhistory.sqlite", bytes: 10_000)
        try home.file("\(profile)/cookies.sqlite", bytes: 10_000)

        let groups = PrivacyScanner.scan(home: home.url, progress: ScanProgress())
        let names = try #require(groups.first { $0.id == "org.mozilla.firefox" }).items.map(\.url.lastPathComponent)
        #expect(Set(names) == ["formhistory.sqlite", "cookies.sqlite"])
    }

    @Test func makesCamelCaseReadable() {
        #expect(PrivacyScanner.readable("RecentDocuments") == "Recent Documents")
        #expect(PrivacyScanner.readable("ApplicationRecentDocuments") == "Application Recent Documents")
    }
}
