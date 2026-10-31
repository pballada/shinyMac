import AppKit
import ShinyCore
import SwiftUI

struct SettingsView: View {
    @AppStorage(Preferences.Key.alwaysUseTrash) private var alwaysUseTrash = false
    @AppStorage(Preferences.Key.showMenuBarMonitor) private var showMenuBarMonitor = true
    @AppStorage(Preferences.Key.spaceAlerts) private var spaceAlerts = true
    @AppStorage(Preferences.Key.careSchedule) private var careSchedule = CareSchedule.weekly.rawValue
    @State private var hasFullDiskAccess = Permissions.hasFullDiskAccess

    var body: some View {
        Form {
            Section("Cleaning") {
                Toggle(isOn: $alwaysUseTrash) {
                    Text("Move everything to the Trash")
                    Text("Caches and junk are normally deleted right away because apps rebuild them. Turn this on to keep a way back, at the cost of space until you empty the Trash.")
                }
            }

            Section("Menu Bar") {
                Toggle(isOn: $showMenuBarMonitor) {
                    Text("Show system monitor in the menu bar")
                    Text("CPU, memory, disk, battery and network at a glance. ShinyMac keeps running there after you close its window.")
                }
            }

            Section("Notifications") {
                Toggle(isOn: $spaceAlerts) {
                    Text("Warn me when space runs low")
                    Text("At most once a day, when free space drops below 10% or the Trash passes 5 GB.")
                }
                Picker(selection: $careSchedule) {
                    ForEach(CareSchedule.allCases) { Text($0.title).tag($0.rawValue) }
                } label: {
                    Text("Remind me to run Smart Care")
                    Text("Counted from your last Smart Care scan. The reminder says how much junk is waiting.")
                }
            }

            Section("Permissions") {
                LabeledContent {
                    if hasFullDiskAccess {
                        Label("Granted", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                    } else {
                        Button("Open System Settings") { NSWorkspace.shared.open(Permissions.fullDiskAccessSettings) }
                    }
                } label: {
                    Text("Full Disk Access")
                    Text("Lets ShinyMac see Safari data, Mail downloads, the Trash and protected caches.")
                }
            }

            Section {
                LabeledContent("Version", value: Self.version)
                Link("Source code on GitHub", destination: URL(string: "https://github.com/pballada/shinyMac")!)
            }
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            hasFullDiskAccess = Permissions.hasFullDiskAccess
        }
    }

    static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "dev"
        let build = info?["CFBundleVersion"] as? String
        return build.map { "\(short) (\($0))" } ?? short
    }
}
