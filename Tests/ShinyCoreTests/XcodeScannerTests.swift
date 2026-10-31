import Foundation
import Testing
@testable import ShinyCore

@Suite struct XcodeScannerTests {
    @Test func namesDerivedDataAfterTheProject() {
        let folder = URL(filePath: "/tmp/DerivedData/ShinyMac-gbdqnhhzxyzabcdefghijklmnop")
        #expect(XcodeScanner.projectName(ofDerivedData: folder, workspace: nil) == "ShinyMac")
        #expect(XcodeScanner.projectName(ofDerivedData: folder, workspace: "/Users/me/Code/Shiny.xcworkspace") == "Shiny")
        #expect(XcodeScanner.projectName(ofDerivedData: URL(filePath: "/tmp/ModuleCache.noindex"), workspace: nil) == "ModuleCache.noindex")
    }

    @Test func readableRuntimeNames() {
        #expect(XcodeScanner.runtimeName("com.apple.CoreSimulator.SimRuntime.iOS-18-1") == "iOS 18.1")
        #expect(XcodeScanner.runtimeName("com.apple.CoreSimulator.SimRuntime.xrOS-2-5") == "visionOS 2.5")
    }

    @Test func recommendsOnlyOrphanedSimulatorsAndUnusedOldRuntimes() {
        let devices = XcodeScanner.parseDevices(Data("""
        {"devices": {
          "com.apple.CoreSimulator.SimRuntime.iOS-18-1": [
            {"udid": "A", "name": "iPhone 16", "isAvailable": true, "dataPath": "/nonexistent/A/data"}],
          "com.apple.CoreSimulator.SimRuntime.iOS-17-0": [
            {"udid": "B", "name": "iPhone 15", "isAvailable": false, "dataPath": "/nonexistent/B/data"}]
        }}
        """.utf8))
        #expect(devices.count == 2)
        #expect(devices.first { $0.udid == "B" }?.isAvailable == false)

        let runtimes = XcodeScanner.parseRuntimes(Data("""
        {
          "1": {"identifier": "1", "runtimeIdentifier": "com.apple.CoreSimulator.SimRuntime.iOS-18-1", "version": "18.1",
                "sizeBytes": 8000000000, "path": "/r/1.dmg", "deletable": true},
          "2": {"identifier": "2", "runtimeIdentifier": "com.apple.CoreSimulator.SimRuntime.iOS-17-5", "version": "17.5",
                "sizeBytes": 7000000000, "path": "/r/2.dmg", "deletable": true},
          "3": {"identifier": "3", "runtimeIdentifier": "com.apple.CoreSimulator.SimRuntime.iOS-26-4", "version": "26.4",
                "sizeBytes": 9000000000, "path": "/r/3.dmg", "deletable": true}
        }
        """.utf8))
        let group = XcodeScanner.runtimesGroup(devices: devices, runtimes: runtimes)
        let recommended = Dictionary(uniqueKeysWithValues: group.items.map { ($0.name, $0.isRecommended) })
        #expect(recommended["iOS 26.4 Simulator"] == false) // newest
        #expect(recommended["iOS 18.1 Simulator"] == false) // still used by a simulator
        #expect(recommended["iOS 17.5 Simulator"] == true)
        #expect(group.items.first { $0.name == "iOS 17.5 Simulator" }?.removal == .simulatorRuntime(identifier: "2"))
        #expect(!group.selectedByDefault)
    }

    @Test func toolRemovalsUseSimctl() {
        #expect(Cleaner.toolCommand(for: .simulator(udid: "X")) == ["simctl", "delete", "X"])
        #expect(Cleaner.toolCommand(for: .file) == nil)
    }

    @Test func moveToTrashOverridesDelete() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "shiny-xcode-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appending(path: "Old.xcarchive")
        try Data("x".utf8).write(to: file)
        let report = Cleaner.remove([CleanupItem(url: file, size: 1, removal: .moveToTrash)], mode: .delete)
        #expect(report.removed == [file])
        // Clean up the trashed copy so test runs don't fill the Trash.
        if let trashed = try? FileManager.default.contentsOfDirectory(at: Paths.trash, includingPropertiesForKeys: nil)
            .first(where: { $0.lastPathComponent.hasPrefix("Old") && $0.pathExtension == "xcarchive" }) {
            try? FileManager.default.removeItem(at: trashed)
        }
        try? FileManager.default.removeItem(at: folder)
    }

    @Test func scansThisMacReadOnly() {
        let groups = XcodeScanner.scan(progress: ScanProgress())
        #expect(groups.allSatisfy { !$0.items.isEmpty })
    }
}
