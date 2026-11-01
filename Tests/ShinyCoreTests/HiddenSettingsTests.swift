import Foundation
import Testing
@testable import ShinyCore

@Suite(.serialized) struct HiddenSettingsTests {
    /// A throwaway preferences domain so tests never touch real Finder or Dock settings.
    let domain = "com.pballada.shinymac.tests.\(UUID().uuidString)"

    func tweak(_ kind: HiddenSettings.Kind) -> HiddenSettings.Tweak {
        HiddenSettings.Tweak(id: "test", category: .system, title: "Test", detail: "", domain: domain, key: "value", kind: kind, restart: nil)
    }

    func cleanUp() {
        CFPreferencesSetAppValue("value" as CFString, nil, domain as CFString)
        CFPreferencesAppSynchronize(domain as CFString)
        try? FileManager.default.removeItem(at: Paths.home.appending(path: "Library/Preferences/\(domain).plist"))
    }

    @Test func togglesWriteOnlyWhenDifferentFromTheDefault() {
        defer { cleanUp() }
        let setting = tweak(.toggle(systemDefault: false))
        #expect(!HiddenSettings.isOn(setting))
        HiddenSettings.setToggle(setting, on: true)
        #expect(HiddenSettings.isOn(setting))
        #expect(HiddenSettings.stored(setting) == .bool(true))
        #expect(HiddenSettings.isCustomized(setting))
        HiddenSettings.setToggle(setting, on: false)
        #expect(HiddenSettings.stored(setting) == nil, "Back to the default removes the key")
    }

    @Test func invertedTogglesStoreTheOpposite() {
        defer { cleanUp() }
        // e.g. "Window shadow" stored as disable-shadow.
        let setting = tweak(.toggle(systemDefault: false, inverted: true))
        #expect(HiddenSettings.isOn(setting))
        HiddenSettings.setToggle(setting, on: false)
        #expect(HiddenSettings.stored(setting) == .bool(true))
        #expect(!HiddenSettings.isOn(setting))
        HiddenSettings.setToggle(setting, on: true)
        #expect(HiddenSettings.stored(setting) == nil)
    }

    @Test func choicesMatchStoredValues() {
        defer { cleanUp() }
        let options = [HiddenSettings.Option(title: "PNG", value: nil), HiddenSettings.Option(title: "JPEG", value: .string("jpg"))]
        let setting = tweak(.choice(options))
        #expect(HiddenSettings.selectedOption(setting)?.title == "PNG")
        HiddenSettings.select(setting, option: options[1])
        #expect(HiddenSettings.selectedOption(setting)?.title == "JPEG")
        #expect(HiddenSettings.isCustomized(setting))
        HiddenSettings.reset(setting)
        #expect(HiddenSettings.selectedOption(setting)?.title == "PNG")
    }

    @Test func catalogIsWellFormed() {
        let ids = HiddenSettings.tweaks.map(\.id)
        #expect(Set(ids).count == ids.count)
        for category in HiddenSettings.Category.allCases {
            #expect(HiddenSettings.tweaks.contains { $0.category == category })
        }
        for tweak in HiddenSettings.tweaks {
            if case .choice(let options) = tweak.kind { #expect(options.first?.value == nil, "\(tweak.id): first option is the default") }
        }
    }
}
