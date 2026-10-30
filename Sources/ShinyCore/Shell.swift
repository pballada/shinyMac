import Foundation

/// Runs command line tools, optionally as administrator via the standard macOS password prompt.
public enum Shell {
    public struct Result: Sendable {
        public let status: Int32
        public let output: String

        public var succeeded: Bool { status == 0 }
        /// The user dismissed the administrator password prompt.
        public var wasCancelled: Bool { output.contains("(-128)") }
    }

    @discardableResult
    public static func run(_ executable: String, _ arguments: [String] = []) throws -> Result {
        let process = Process()
        process.executableURL = URL(filePath: executable)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return Result(status: process.terminationStatus, output: String(decoding: data, as: UTF8.self))
    }

    /// Runs `command` with `/bin/sh` as root. macOS shows its own password dialog.
    @discardableResult
    public static func runAsAdmin(_ command: String, prompt: String? = nil) throws -> Result {
        var script = "do shell script \(appleScriptQuoted(command))"
        if let prompt { script += " with prompt \(appleScriptQuoted(prompt))" }
        script += " with administrator privileges"
        return try run("/usr/bin/osascript", ["-e", script])
    }

    /// Single-quotes a string for `/bin/sh`.
    public static func shellQuoted(_ string: String) -> String {
        "'" + string.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    /// Double-quotes a string as an AppleScript literal.
    public static func appleScriptQuoted(_ string: String) -> String {
        let escaped = string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"" + escaped + "\""
    }
}
