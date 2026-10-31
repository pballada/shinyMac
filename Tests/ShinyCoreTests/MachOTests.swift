import Foundation
import Testing
@testable import ShinyCore

@Suite struct MachOTests {
    private func bytes(_ words: [UInt32], bigEndian: Bool) -> Data {
        Data(words.flatMap { word -> [UInt8] in
            let value = bigEndian ? word.bigEndian : word.littleEndian
            return withUnsafeBytes(of: value) { Array($0) }
        })
    }

    @Test func thinIntelBinaryIsIntelOnly() {
        let header = bytes([MachO.magic64, MachO.cpuX86 | MachO.cpuArchABI64], bigEndian: false)
        #expect(MachO.architectures(header: header) == [.x86_64])
        #expect(MachO.isIntelOnly([.x86_64]))
    }

    @Test func universalBinaryIsNotIntelOnly() {
        // Fat header with two 20-byte entries: cputype, subtype, offset, size, align.
        let header = bytes([
            MachO.fatMagic, 2,
            MachO.cpuX86 | MachO.cpuArchABI64, 3, 0x4000, 100, 14,
            MachO.cpuARM | MachO.cpuArchABI64, 0, 0x8000, 100, 14,
        ], bigEndian: true)
        let architectures = MachO.architectures(header: header)
        #expect(architectures == [.x86_64, .arm64])
        #expect(!MachO.isIntelOnly(architectures))
    }

    @Test func nonMachOFilesHaveNoArchitectures() {
        #expect(MachO.architectures(header: Data("#!/bin/sh\necho hi\n".utf8)).isEmpty)
        #expect(!MachO.isIntelOnly([]))
    }

    @Test func readsARealExecutable() {
        let architectures = MachO.architectures(of: URL(filePath: "/bin/ls"))
        #expect(architectures.contains(.arm64) || architectures.contains(.x86_64))
    }
}
