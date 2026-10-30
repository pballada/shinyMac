import Foundation

/// Human friendly byte sizes, e.g. "3.2 GB".
public enum ByteFormat {
    public static func string(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowsNonnumericFormatting = false
        return formatter.string(fromByteCount: max(0, bytes))
    }

    /// Splits a size into its number and unit so hero labels can style them separately.
    public static func parts(_ bytes: Int64) -> (value: String, unit: String) {
        let components = string(bytes).split(maxSplits: 1, whereSeparator: \.isWhitespace)
        guard components.count == 2 else { return (string(bytes), "") }
        return (String(components[0]), String(components[1]))
    }
}
