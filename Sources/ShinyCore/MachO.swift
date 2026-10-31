import Foundation

/// Reads which CPU architectures an executable contains, straight from its Mach-O header.
public enum MachO {
    public enum Architecture: String, Sendable {
        case arm64, x86_64, i386, other
    }

    static let fatMagic: UInt32 = 0xCAFE_BABE
    static let fatMagic64: UInt32 = 0xCAFE_BABF
    static let magic64: UInt32 = 0xFEED_FACF
    static let magic32: UInt32 = 0xFEED_FACE
    static let cpuArchABI64: UInt32 = 0x0100_0000
    static let cpuX86: UInt32 = 7
    static let cpuARM: UInt32 = 12

    /// Architectures in the file, or an empty set if it isn't a Mach-O executable.
    public static func architectures(of url: URL) -> Set<Architecture> {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return [] }
        defer { try? handle.close() }
        guard let header = try? handle.read(upToCount: 4096) else { return [] }
        return architectures(header: header)
    }

    static func architectures(header data: Data) -> Set<Architecture> {
        guard data.count >= 8 else { return [] }
        let bigEndianMagic = data.uint32(at: 0, bigEndian: true)
        if bigEndianMagic == fatMagic || bigEndianMagic == fatMagic64 {
            // Fat headers are big-endian: magic, count, then one entry per slice starting with its CPU type.
            let count = Int(data.uint32(at: 4, bigEndian: true))
            let entrySize = bigEndianMagic == fatMagic64 ? 32 : 20
            var result = Set<Architecture>()
            for index in 0..<min(count, 32) {
                let offset = 8 + index * entrySize
                guard offset + 4 <= data.count else { break }
                result.insert(architecture(cpuType: data.uint32(at: offset, bigEndian: true)))
            }
            return result
        }
        let littleEndianMagic = data.uint32(at: 0, bigEndian: false)
        guard littleEndianMagic == magic64 || littleEndianMagic == magic32 else { return [] }
        return [architecture(cpuType: data.uint32(at: 4, bigEndian: false))]
    }

    static func architecture(cpuType: UInt32) -> Architecture {
        switch cpuType {
        case cpuARM | cpuArchABI64: .arm64
        case cpuX86 | cpuArchABI64: .x86_64
        case cpuX86: .i386
        default: .other
        }
    }

    /// The app's main executable, from `CFBundleExecutable`.
    public static func executable(ofApp app: URL, info: [String: Any]) -> URL? {
        guard let name = info["CFBundleExecutable"] as? String else { return nil }
        return app.appending(path: "Contents/MacOS/\(name)")
    }

    /// True for apps that only run on Apple silicon through Rosetta.
    public static func isIntelOnly(_ architectures: Set<Architecture>) -> Bool {
        !architectures.isEmpty && !architectures.contains(.arm64)
    }
}

extension Data {
    func uint32(at offset: Int, bigEndian: Bool) -> UInt32 {
        let bytes = self[index(startIndex, offsetBy: offset)..<index(startIndex, offsetBy: offset + 4)]
        let value = bytes.reduce(UInt32(0)) { $0 << 8 | UInt32($1) }
        return bigEndian ? value : value.byteSwapped
    }
}
