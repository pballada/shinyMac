import Foundation
import Testing
@testable import ShinyCore

@Suite struct UpdateCheckerTests {
    let appcast = """
    <?xml version="1.0" encoding="utf-8"?>
    <rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
      <channel>
        <item>
          <title>Version 2.1</title>
          <sparkle:releaseNotesLink>https://example.com/notes/2.1</sparkle:releaseNotesLink>
          <enclosure url="https://example.com/App-2.1.zip" sparkle:version="210" sparkle:shortVersionString="2.1"/>
        </item>
        <item>
          <title>Version 2.10</title>
          <sparkle:version>2100</sparkle:version>
          <sparkle:shortVersionString>2.10</sparkle:shortVersionString>
          <enclosure url="https://example.com/App-2.10.zip"/>
        </item>
        <item>
          <title>Beta</title>
          <sparkle:channel>beta</sparkle:channel>
          <enclosure url="https://example.com/App-3.0b1.zip" sparkle:version="3000" sparkle:shortVersionString="3.0b1"/>
        </item>
      </channel>
    </rss>
    """

    @Test func parsesEnclosureAttributesAndElements() {
        let items = UpdateChecker.parseAppcast(Data(appcast.utf8))
        #expect(items.count == 3)
        #expect(items[0] == AppcastItem(
            shortVersion: "2.1", build: "210", channel: nil,
            releaseNotes: URL(string: "https://example.com/notes/2.1"), download: URL(string: "https://example.com/App-2.1.zip")
        ))
        #expect(items[1].shortVersion == "2.10")
        #expect(items[1].build == "2100")
        #expect(items[2].channel == "beta")
    }

    @Test func comparesVersionsNumerically() {
        #expect(UpdateChecker.isNewer("1.10", than: "1.9"))
        #expect(UpdateChecker.isNewer("2.0", than: "1.99.1"))
        #expect(!UpdateChecker.isNewer("1.2", than: "1.2"))
        #expect(!UpdateChecker.isNewer("1.2 (45)", than: "1.2"))
        #expect(UpdateChecker.isNewer("2024.10", than: "2024.9"))
    }

    @Test func picksNewestStableItem() throws {
        let items = UpdateChecker.parseAppcast(Data(appcast.utf8))
        let stable = items.filter { $0.channel == nil }
        let latest = try #require(stable.max { UpdateChecker.isNewer($1, than: $0) })
        #expect(latest.shortVersion == "2.10")
    }
}

@Suite struct AppStoreUpdateTests {
    private func app(_ bundleID: String, version: String) -> InstalledApp {
        InstalledApp(
            url: URL(filePath: "/Applications/\(bundleID).app"), name: bundleID, bundleID: bundleID, version: version,
            bundleName: nil, isAppStore: true, lastUsed: nil
        )
    }

    @Test func batchesBundleIDsIntoOneLookup() throws {
        let url = try #require(UpdateChecker.appStoreLookupURL(for: [app("a.one", version: "1"), app("b.two", version: "1")], country: "ES"))
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        #expect(items.first { $0.name == "bundleId" }?.value == "a.one,b.two")
        #expect(items.first { $0.name == "country" }?.value == "es")
        #expect(Array(1...120).chunked(into: 50).map(\.count) == [50, 50, 20])
    }

    @Test func reportsNewerCompatibleVersions() {
        let lookup = Data("""
        {"resultCount": 3, "results": [
          {"bundleId": "a.one", "version": "2.1", "trackId": 123, "minimumOsVersion": "14.0"},
          {"bundleId": "b.two", "version": "1.0"},
          {"bundleId": "c.three", "version": "9.0", "minimumOsVersion": "99.0"}
        ]}
        """.utf8)
        let apps = [app("a.one", version: "2.0.5"), app("b.two", version: "1.0"), app("c.three", version: "1.0")]
        let updates = UpdateChecker.appStoreUpdates(for: apps, lookup: lookup, systemVersion: "Version 26.1 (Build 25B78)")
        #expect(updates.map(\.app.bundleID) == ["a.one"], "Same version and too-new macOS requirements are skipped")
        #expect(updates.first?.appStorePage?.absoluteString == "macappstore://apps.apple.com/app/id123")
    }
}
