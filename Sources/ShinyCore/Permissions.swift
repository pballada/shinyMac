import Foundation

/// Privacy permissions ShinyMac depends on.
public enum Permissions {
    /// Whether the app has Full Disk Access. The TCC database is only readable with that permission.
    public static var hasFullDiskAccess: Bool {
        let descriptor = open("/Library/Application Support/com.apple.TCC/TCC.db", O_RDONLY)
        guard descriptor >= 0 else { return false }
        close(descriptor)
        return true
    }

    /// Deep link to System Settings › Privacy & Security › Full Disk Access.
    public static let fullDiskAccessSettings = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
}
