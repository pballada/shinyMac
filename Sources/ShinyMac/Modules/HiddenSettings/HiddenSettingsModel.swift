import ShinyCore
import SwiftUI

@Observable
final class HiddenSettingsModel {
    var category: HiddenSettings.Category = .finder
    /// Bumped after every write so views re-read values from CFPreferences.
    private(set) var revision = 0
    private var pendingRestarts: Set<HiddenSettings.Restart> = []
    private var restartTask: Task<Void, Never>?

    var visibleTweaks: [HiddenSettings.Tweak] { HiddenSettings.tweaks.filter { $0.category == category } }

    var customizedCount: Int {
        _ = revision
        return HiddenSettings.tweaks.filter(HiddenSettings.isCustomized).count
    }

    var badge: String? { customizedCount > 0 ? "\(customizedCount)" : nil }

    func isOn(_ tweak: HiddenSettings.Tweak) -> Bool {
        _ = revision
        return HiddenSettings.isOn(tweak)
    }

    func selectedOption(_ tweak: HiddenSettings.Tweak) -> HiddenSettings.Option? {
        _ = revision
        return HiddenSettings.selectedOption(tweak)
    }

    func isCustomized(_ tweak: HiddenSettings.Tweak) -> Bool {
        _ = revision
        return HiddenSettings.isCustomized(tweak)
    }

    func set(_ tweak: HiddenSettings.Tweak, on: Bool) {
        HiddenSettings.setToggle(tweak, on: on)
        changed(tweak)
    }

    func select(_ tweak: HiddenSettings.Tweak, option: HiddenSettings.Option) {
        HiddenSettings.select(tweak, option: option)
        changed(tweak)
    }

    func restoreDefaults() {
        let customized = HiddenSettings.tweaks.filter(HiddenSettings.isCustomized)
        customized.forEach(HiddenSettings.reset)
        customized.forEach(changed)
    }

    private func changed(_ tweak: HiddenSettings.Tweak) {
        revision += 1
        guard let restart = tweak.restart else { return }
        pendingRestarts.insert(restart)
        // Wait for a pause in changes so flipping several switches restarts Finder or the Dock once.
        restartTask?.cancel()
        restartTask = Task {
            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled else { return }
            let targets = pendingRestarts
            pendingRestarts = []
            await runInBackground { targets.forEach(HiddenSettings.restart) }
        }
    }
}
