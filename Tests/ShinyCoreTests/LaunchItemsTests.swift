import Foundation
import Testing
@testable import ShinyCore

@Suite struct LaunchItemsTests {
    @Test func parsesPlistsAndDetectsBrokenItems() throws {
        let folder = try TempFolder()
        let healthy = folder.url.appending(path: "com.example.healthy.plist")
        try PropertyListSerialization.data(fromPropertyList: [
            "Label": "com.example.healthy", "ProgramArguments": ["/bin/sh", "-c", "true"], "RunAtLoad": true,
        ], format: .xml, options: 0).write(to: healthy)
        let broken = folder.url.appending(path: "com.example.broken.plist")
        try PropertyListSerialization.data(fromPropertyList: [
            "Label": "com.example.broken", "Program": "/Applications/Gone.app/Contents/MacOS/Helper", "KeepAlive": ["SuccessfulExit": false],
        ], format: .xml, options: 0).write(to: broken)

        let ok = try #require(LaunchItems.parse(healthy, scope: .userAgent))
        #expect(ok.label == "com.example.healthy")
        #expect(ok.program == "/bin/sh")
        #expect(ok.runAtLoad)
        #expect(!ok.isBroken)
        #expect(ok.owningApp == nil)

        let gone = try #require(LaunchItems.parse(broken, scope: .userAgent))
        #expect(gone.isBroken)
        #expect(gone.keepAlive)
        #expect(gone.owningApp?.lastPathComponent == "Gone.app")
    }

    @Test func parsesDisabledServices() {
        let output = """
        \tdisabled services = {
        \t\t"com.foo.agent" => disabled
        \t\t"com.bar.agent" => enabled
        \t\t"com.legacy.agent" => true
        \t}
        """
        #expect(LaunchItems.parseDisabled(output) == ["com.foo.agent", "com.legacy.agent"])
    }
}
