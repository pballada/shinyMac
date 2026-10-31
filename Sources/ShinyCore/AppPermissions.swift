import Foundation
import SQLite3

/// Which apps hold sensitive privacy permissions, read from the TCC databases (needs Full Disk Access).
/// Read-only: macOS only lets System Settings change these.
public enum AppPermissions {
    public struct Service: Identifiable, Hashable, Sendable {
        public let id: String
        public let title: String
        public let symbol: String
        /// Anchor of the matching pane in System Settings › Privacy & Security.
        public let settingsAnchor: String

        public var settingsURL: URL {
            URL(string: "x-apple.systempreferences:com.apple.preference.security?\(settingsAnchor)")!
        }
    }

    public struct Grant: Identifiable, Hashable, Sendable {
        public var id: String { "\(service)|\(client)" }
        public let service: String
        /// A bundle identifier, or an absolute path for command line tools.
        public let client: String
        public let isPath: Bool
        public let lastModified: Date?
    }

    /// Services worth reviewing, most sensitive first.
    public static let services: [Service] = [
        Service(id: "kTCCServiceSystemPolicyAllFiles", title: "Full Disk Access", symbol: "internaldrive.fill", settingsAnchor: "Privacy_AllFiles"),
        Service(id: "kTCCServiceAccessibility", title: "Accessibility", symbol: "accessibility", settingsAnchor: "Privacy_Accessibility"),
        Service(id: "kTCCServiceScreenCapture", title: "Screen Recording", symbol: "rectangle.dashed.badge.record", settingsAnchor: "Privacy_ScreenCapture"),
        Service(id: "kTCCServiceListenEvent", title: "Input Monitoring", symbol: "keyboard.fill", settingsAnchor: "Privacy_ListenEvent"),
        Service(id: "kTCCServiceCamera", title: "Camera", symbol: "camera.fill", settingsAnchor: "Privacy_Camera"),
        Service(id: "kTCCServiceMicrophone", title: "Microphone", symbol: "mic.fill", settingsAnchor: "Privacy_Microphone"),
        Service(id: "kTCCServiceAppleEvents", title: "Automation", symbol: "gearshape.2.fill", settingsAnchor: "Privacy_Automation"),
        Service(id: "kTCCServiceAddressBook", title: "Contacts", symbol: "person.crop.circle.fill", settingsAnchor: "Privacy_Contacts"),
        Service(id: "kTCCServiceCalendar", title: "Calendars", symbol: "calendar", settingsAnchor: "Privacy_Calendars"),
        Service(id: "kTCCServicePhotos", title: "Photos", symbol: "photo.fill", settingsAnchor: "Privacy_Photos"),
    ]

    public static func databases(home: URL = Paths.home) -> [URL] {
        [URL(filePath: "/Library/Application Support/com.apple.TCC/TCC.db"),
         home.appending(path: "Library/Application Support/com.apple.TCC/TCC.db")]
    }

    /// Allowed grants for the services above, without duplicates, or nil if no database could be read.
    public static func grants(databases: [URL] = databases()) -> [Grant]? {
        let wanted = Set(services.map(\.id))
        var readAny = false
        var seen = Set<String>()
        var result: [Grant] = []
        for database in databases {
            guard let rows = read(database) else { continue }
            readAny = true
            for grant in rows where wanted.contains(grant.service) && seen.insert(grant.id).inserted {
                result.append(grant)
            }
        }
        return readAny ? result : nil
    }

    /// auth_value 2 is "allowed" and 3 is "limited"; anything else was denied or never asked.
    static func read(_ database: URL) -> [Grant]? {
        var handle: OpaquePointer?
        let uri = "file:\(database.path(percentEncoded: true))?mode=ro"
        guard sqlite3_open_v2(uri, &handle, SQLITE_OPEN_READONLY | SQLITE_OPEN_URI, nil) == SQLITE_OK else {
            sqlite3_close(handle)
            return nil
        }
        defer { sqlite3_close(handle) }
        var statement: OpaquePointer?
        let query = "SELECT service, client, client_type, last_modified FROM access WHERE auth_value IN (2, 3)"
        guard sqlite3_prepare_v2(handle, query, -1, &statement, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(statement) }

        var grants: [Grant] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let service = sqlite3_column_text(statement, 0), let client = sqlite3_column_text(statement, 1) else { continue }
            let modified = sqlite3_column_int64(statement, 3)
            grants.append(Grant(
                service: String(cString: service), client: String(cString: client),
                isPath: sqlite3_column_int(statement, 2) == 1,
                lastModified: modified > 0 ? Date(timeIntervalSince1970: TimeInterval(modified)) : nil
            ))
        }
        return grants
    }
}
