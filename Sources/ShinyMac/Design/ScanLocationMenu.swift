import AppKit
import ShinyCore
import SwiftUI

/// Where a file scan looks: the Home folder, a mounted disk, or any folder.
enum ScanLocation {
    /// Writable disks other than the startup disk: external drives, SD cards, network shares.
    static func externalVolumes() -> [URL] {
        let keys: [URLResourceKey] = [.volumeIsBrowsableKey, .volumeIsReadOnlyKey, .volumeLocalizedNameKey]
        let volumes = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: [.skipHiddenVolumes]) ?? []
        return volumes.filter { url in
            let path = url.standardizedFileURL.path(percentEncoded: false)
            guard path != "/", !path.hasPrefix("/System/Volumes"),
                  let values = try? url.resourceValues(forKeys: Set(keys)) else { return false }
            // Read-only disks (Time Machine snapshots, some NTFS drives) can't have anything removed.
            return values.volumeIsBrowsable == true && values.volumeIsReadOnly != true
        }
    }

    static func isHome(_ url: URL) -> Bool { url.standardizedFileURL == Paths.home.standardizedFileURL }

    static func isVolume(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isVolumeKey]))?.isVolume == true
    }

    static func name(of url: URL) -> String {
        if isHome(url) { return "Home Folder" }
        if isVolume(url), let name = (try? url.resourceValues(forKeys: [.volumeLocalizedNameKey]))?.volumeLocalizedName {
            return name
        }
        return FileManager.default.displayName(atPath: url.path(percentEncoded: false))
    }

    static func symbol(of url: URL) -> String {
        if isHome(url) { return "house.fill" }
        return isVolume(url) ? "externaldrive.fill" : "folder.fill"
    }

    /// "in My Drive" for busy titles; empty for the Home folder, which every scan assumes.
    static func suffix(for url: URL) -> String {
        isHome(url) ? "" : " in \(name(of: url))"
    }

    @MainActor
    static func chooseFolder(startingAt url: URL) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = url
        panel.prompt = "Scan"
        return panel.runModal() == .OK ? panel.url : nil
    }
}

/// Pill that shows where a scan looks and lets the user pick the Home folder, a mounted disk or any folder.
/// Picking one starts a scan there.
struct ScanLocationMenu: View {
    let location: URL
    let onChoose: (URL) -> Void
    @State private var volumes = ScanLocation.externalVolumes()

    var body: some View {
        Menu {
            Button("Home Folder", systemImage: "house") { onChoose(Paths.home) }
            if !volumes.isEmpty {
                Section("Disks") {
                    ForEach(volumes, id: \.self) { volume in
                        Button(ScanLocation.name(of: volume), systemImage: "externaldrive") { onChoose(volume) }
                    }
                }
            }
            Divider()
            Button("Choose Folder…", systemImage: "folder") {
                if let url = ScanLocation.chooseFolder(startingAt: location) { onChoose(url) }
            }
        } label: {
            Label(ScanLocation.name(of: location), systemImage: ScanLocation.symbol(of: location))
        }
        .menuStyle(.button)
        .buttonStyle(.glassPill)
        .fixedSize()
        .help("Choose what to scan: your Home folder, an external disk or any folder")
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didMountNotification)) { _ in
            volumes = ScanLocation.externalVolumes()
        }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didUnmountNotification)) { _ in
            volumes = ScanLocation.externalVolumes()
        }
    }
}
