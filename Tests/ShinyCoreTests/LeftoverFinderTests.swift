import Foundation
import Testing
@testable import ShinyCore

@Suite struct AppIdentityTests {
    let vscode = AppIdentity(bundleID: "com.microsoft.VSCode", names: ["Visual Studio Code", "Code"])

    @Test(arguments: [
        "com.microsoft.VSCode", "com.microsoft.VSCode.plist", "com.microsoft.VSCode.ShipIt",
        "com.microsoft.VSCode.savedState", "UBF8T346G9.com.microsoft.VSCode", "Code", "visual-studio-code",
        "Visual Studio Code",
    ])
    func matchesFilesThatBelongToTheApp(_ name: String) {
        #expect(vscode.matches(fileName: name))
    }

    @Test(arguments: [
        "com.microsoft.VSCodeInsiders", "com.microsoft.Word", "Microsoft", "CodeRunner", "com.microsoft",
        "Xcode", "co",
    ])
    func ignoresLookalikes(_ name: String) {
        #expect(!vscode.matches(fileName: name))
    }

    @Test func genericAndShortNamesNeverMatchOnTheirOwn() {
        let app = AppIdentity(bundleID: "com.example.helper", names: ["Helper", "Go"])
        #expect(!app.matches(fileName: "Helper"))
        #expect(!app.matches(fileName: "Go"))
        #expect(app.matches(fileName: "com.example.helper.plist"))
    }

    @Test func findsVendorSubfolders() {
        let chrome = AppIdentity(bundleID: "com.google.Chrome", names: ["Google Chrome"])
        #expect(chrome.vendorRemainder(forFolder: "Google") == "chrome")
        #expect(chrome.vendorRemainder(forFolder: "Microsoft") == nil)
    }
}

@Suite struct LeftoverFinderTests {
    @Test func collectsLeftoversAcrossTheLibrary() throws {
        let home = try TempFolder()
        try home.file("Library/Application Support/Code/User/settings.json", bytes: 30_000)
        try home.file("Library/Caches/com.microsoft.VSCode/Cache.db", bytes: 12_000)
        try home.file("Library/Preferences/com.microsoft.VSCode.plist", bytes: 500)
        try home.file("Library/Saved Application State/com.microsoft.VSCode.savedState/data", bytes: 500)
        try home.file("Library/Application Support/Google/Chrome/Default/History", bytes: 9_000)
        try home.file("Library/Application Support/Slack/data", bytes: 500)

        // Only look at the fake home; the real /Library may contain anything.
        let inHome = { (leftover: Leftover) in leftover.url.path.hasPrefix(home.url.path) }
        let vscode = AppIdentity(bundleID: "com.microsoft.VSCode", names: ["Visual Studio Code", "Code"])
        let found = LeftoverFinder.find(for: vscode, home: home.url).filter(inHome)
        #expect(Set(found.map(\.url.lastPathComponent)) == [
            "Code", "com.microsoft.VSCode", "com.microsoft.VSCode.plist", "com.microsoft.VSCode.savedState",
        ])
        #expect(found.first?.url.lastPathComponent == "Code", "Largest first")
        #expect(found.first?.kind == .support)

        let chrome = AppIdentity(bundleID: "com.google.Chrome", names: ["Google Chrome"])
        let chromeFiles = LeftoverFinder.find(for: chrome, home: home.url).filter(inHome)
        #expect(chromeFiles.map(\.url.lastPathComponent) == ["Chrome"])
    }
}
