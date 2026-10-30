import Foundation
import Testing
@testable import ShinyCore

@Suite struct OrphanFinderTests {
    @Test func extractsIdentifiers() {
        #expect(OrphanFinder.identifier(from: "com.foo.app.plist") == "com.foo.app")
        #expect(OrphanFinder.identifier(from: "ABCDE12345.com.foo.app") == "com.foo.app")
        #expect(OrphanFinder.identifier(from: "group.com.foo.app") == "com.foo.app")
        #expect(OrphanFinder.identifier(from: "W5364U7YZB.group.io.tailscale.ipn") == "io.tailscale.ipn")
        #expect(OrphanFinder.identifier(from: "groups.com.apple.podcasts") == "com.apple.podcasts")
        #expect(OrphanFinder.identifier(from: "com.foo.app.savedState") == "com.foo.app")
        #expect(OrphanFinder.identifier(from: "Spotify") == nil)
        #expect(OrphanFinder.identifier(from: "com.foo") == nil)
        #expect(OrphanFinder.identifier(from: "My App 2.0.1") == nil)
    }

    @Test func respectsInstalledAppsVendorsAndApple() {
        let ids: Set = ["com.spotify.client"]
        let vendors: Set = ["com.spotify", "com.google"]
        #expect(!OrphanFinder.isOrphan("com.spotify.client.helper", installedIDs: ids, installedVendors: vendors))
        #expect(!OrphanFinder.isOrphan("com.google.Keystone", installedIDs: ids, installedVendors: vendors))
        #expect(!OrphanFinder.isOrphan("com.apple.Safari", installedIDs: ids, installedVendors: vendors))
        #expect(OrphanFinder.isOrphan("com.gone.OldApp", installedIDs: ids, installedVendors: vendors))
        #expect(!OrphanFinder.isOrphan("is.workflow.my.app", installedIDs: ids, installedVendors: vendors))
        #expect(!OrphanFinder.isOrphan("com.dropbox.dropboxmacupdate.agent", installedIDs: ids, installedVendors: vendors, installedNames: ["dropbox"]))
    }

    @Test func findsOrphansInAFakeHome() throws {
        let home = try TempFolder()
        try home.file("Library/Caches/com.gone.OldApp/cache.db", bytes: 20_000)
        try home.file("Library/Application Support/com.gone.OldApp/data.json", bytes: 9_000)
        try home.file("Library/Caches/com.still.Here/cache.db", bytes: 20_000)
        try home.file("Library/Caches/com.apple.Music/cache.db", bytes: 20_000)
        try home.file("Library/Application Support/SomeFolder/data", bytes: 20_000)

        let installed = [InstalledApp(
            url: URL(filePath: "/Applications/Here.app"), name: "Here", bundleID: "com.still.Here",
            version: nil, bundleName: nil, isAppStore: false, lastUsed: nil
        )]
        let groups = OrphanFinder.scan(installed: installed, home: home.url, checkLaunchServices: false, progress: ScanProgress())
        let byID = Dictionary(uniqueKeysWithValues: groups.map { ($0.id, $0) })

        #expect(byID["Caches"]?.items.map(\.name) == ["com.gone.OldApp"])
        #expect(byID["Caches"]?.selectedByDefault == true)
        #expect(byID["Application Support"]?.items.map(\.name) == ["com.gone.OldApp"])
        #expect(byID["Application Support"]?.selectedByDefault == false)
    }
}
