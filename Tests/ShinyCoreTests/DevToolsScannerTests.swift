import Foundation
import Testing
@testable import ShinyCore

@Suite struct DevToolsScannerTests {
    @Test func parsesDockerDiskUsage() {
        let output = """
        {"Active":"2","Reclaimable":"1.25GB (42%)","Size":"3GB","TotalCount":"7","Type":"Images"}
        {"Active":"1","Reclaimable":"0B (0%)","Size":"12kB","TotalCount":"3","Type":"Containers"}
        {"Active":"0","Reclaimable":"850.5MB","Size":"850.5MB","TotalCount":"40","Type":"Build Cache"}
        not json
        """
        let usage = DevToolsScanner.Docker.parseDiskUsage(output)
        #expect(usage.map(\.type) == ["Images", "Containers", "Build Cache"])
        #expect(usage[0] == .init(type: "Images", count: 7, reclaimable: 1_250_000_000))
        #expect(usage[1].reclaimable == 0)
        #expect(usage[2].reclaimable == 850_500_000)
        #expect(DevToolsScanner.Docker.parseSize("12kB") == 12_000)
        #expect(DevToolsScanner.Docker.parseSize("nonsense") == nil)
    }

    @Test func findsDependencyFoldersOnlyNextToTheirProjectFile() throws {
        let home = try TempFolder()
        let big = 21_000_000
        try home.file("Code/web/package.json", bytes: 10)
        try home.file("Code/web/node_modules/react/index.js", bytes: big)
        try home.file("Code/web/node_modules/nested/node_modules/x.js", bytes: 10)
        try home.file("Code/tool/Cargo.toml", bytes: 10)
        try home.file("Code/tool/target/debug/tool", bytes: big)
        try home.file("Code/notes/target/report.pdf", bytes: big)
        try home.file("Code/app/Package.swift", bytes: 10)
        try home.file("Code/app/.build/debug/app", bytes: big)
        try home.file("Code/tiny/package.json", bytes: 10)
        try home.file("Code/tiny/node_modules/a.js", bytes: 1_000)
        try home.file("Library/Caches/proj/package.json", bytes: 10)
        try home.file("Library/Caches/proj/node_modules/a.js", bytes: big)

        let group = DevToolsScanner.projectDependenciesGroup(home: home.url, now: .now, progress: ScanProgress())
        #expect(Set(group.items.map(\.name)) == ["web · node_modules", "tool · target", "app · .build"],
                "A folder named target without Cargo.toml, tiny folders and ~/Library are left alone")
        let noneRecommended = !group.items.contains(where: \.isRecommended)
        #expect(noneRecommended, "Projects touched today aren't pre-selected")

        let later = DevToolsScanner.projectDependenciesGroup(
            home: home.url, now: .now.addingTimeInterval(DevToolsScanner.idleProjectAge + 86_400), progress: ScanProgress()
        )
        let allRecommended = !later.items.contains { !$0.isRecommended }
        #expect(allRecommended, "Idle projects are pre-selected")
    }

    @Test func listsPackageCachesAndModelsWithoutPreselectingModels() throws {
        let home = try TempFolder()
        try home.file(".npm/_cacache/index", bytes: 5_000)
        try home.file(".gradle/caches/jars/a.jar", bytes: 5_000)
        try home.file(".ollama/models/blobs/sha", bytes: 5_000)
        try home.file(".nvm/versions/node/v22.1.0/bin/node", bytes: 5_000)
        try home.file(".nvm/versions/node/v18.20.0/bin/node", bytes: 5_000)
        try home.file(".nvm/alias/default", bytes: 0)
        try "v22.1.0\n".write(to: home.url.appending(path: ".nvm/alias/default"), atomically: true, encoding: .utf8)

        let caches = DevToolsScanner.packageCachesGroup(home: home.url)
        #expect(Set(caches.items.map(\.name)) == ["npm", "Gradle"])
        let cachesRecommended = !caches.items.contains { !$0.isRecommended }
        #expect(caches.selectedByDefault && cachesRecommended)

        let models = DevToolsScanner.aiModelsGroup(home: home.url)
        #expect(models.items.map(\.name) == ["Ollama models"])
        #expect(!models.selectedByDefault && !models.items[0].isRecommended)

        let toolchains = DevToolsScanner.toolchainsGroup(home: home.url)
        #expect(Set(toolchains.items.map(\.name)) == ["Node v22.1.0", "Node v18.20.0"])
        #expect(toolchains.items.first { $0.name == "Node v22.1.0" }?.note == "Default version · keep it")
    }

    @Test func commandRemovalsRunTheirOwnTool() {
        let item = CleanupItem(url: URL(filePath: "/nonexistent/docker-builder"), size: 1,
                               removal: .command(executable: "/usr/bin/true", arguments: []))
        let report = Cleaner.remove([item], mode: .delete)
        #expect(report.removed == [item.url] && report.removedBytes == 1)
        let failing = CleanupItem(url: URL(filePath: "/nonexistent/x"), size: 1, removal: .command(executable: "/usr/bin/false", arguments: []))
        #expect(Cleaner.remove([failing], mode: .delete).failures.count == 1)
    }
}
