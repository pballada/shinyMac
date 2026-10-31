import Foundation
import SQLite3
import Testing
@testable import ShinyCore

@Suite struct AppPermissionsTests {
    /// Builds a database with the columns ShinyMac reads from TCC's `access` table.
    private func makeDatabase(_ rows: [(String, String, Int32, Int32)]) throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appending(path: "shiny tcc \(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appending(path: "TCC.db")
        var db: OpaquePointer?
        #expect(sqlite3_open(url.path(percentEncoded: false), &db) == SQLITE_OK)
        defer { sqlite3_close(db) }
        var sql = "CREATE TABLE access (service TEXT, client TEXT, client_type INTEGER, auth_value INTEGER, last_modified INTEGER);"
        for (service, client, type, auth) in rows {
            sql += "INSERT INTO access VALUES ('\(service)', '\(client)', \(type), \(auth), 1700000000);"
        }
        #expect(sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK)
        return url
    }

    @Test func readsAllowedGrantsOnly() throws {
        let db = try makeDatabase([
            ("kTCCServiceCamera", "us.zoom.xos", 0, 2),
            ("kTCCServiceMicrophone", "us.zoom.xos", 0, 0),
            ("kTCCServiceAccessibility", "/usr/local/bin/tool", 1, 2),
            ("kTCCServicePhotos", "com.example.photos", 0, 3),
            ("kTCCServiceUbiquity", "com.example.other", 0, 2),
        ])
        let grants = try #require(AppPermissions.grants(databases: [db]))
        #expect(Set(grants.map(\.id)) == [
            "kTCCServiceCamera|us.zoom.xos", "kTCCServiceAccessibility|/usr/local/bin/tool", "kTCCServicePhotos|com.example.photos",
        ])
        #expect(grants.first { $0.service == "kTCCServiceAccessibility" }?.isPath == true)
        #expect(grants.first?.lastModified == Date(timeIntervalSince1970: 1_700_000_000))
    }

    @Test func mergesDatabasesWithoutDuplicates() throws {
        let system = try makeDatabase([("kTCCServiceScreenCapture", "com.example.rec", 0, 2)])
        let user = try makeDatabase([("kTCCServiceScreenCapture", "com.example.rec", 0, 2), ("kTCCServiceCamera", "a", 0, 2)])
        #expect(AppPermissions.grants(databases: [system, user])?.count == 2)
    }

    @Test func unreadableDatabasesReturnNil() {
        #expect(AppPermissions.grants(databases: [URL(filePath: "/nonexistent/TCC.db")]) == nil)
    }

    @Test func settingsLinksPointToPrivacyPanes() {
        let camera = AppPermissions.services.first { $0.id == "kTCCServiceCamera" }
        #expect(camera?.settingsURL.absoluteString == "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera")
    }
}
