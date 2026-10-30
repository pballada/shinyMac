import Foundation
import Testing
@testable import ShinyCore

@Suite struct ByteFormatTests {
    @Test func zeroIsNumeric() {
        #expect(ByteFormat.string(0).contains("0"))
    }

    @Test func negativeSizesClampToZero() {
        #expect(ByteFormat.string(-42) == ByteFormat.string(0))
    }

    @Test func partsSplitValueAndUnit() {
        let parts = ByteFormat.parts(3_200_000_000)
        #expect(!parts.value.isEmpty)
        #expect(parts.unit == "GB")
    }

    @Test func abbreviatesHomeFolder() {
        let url = Paths.home("Library/Caches")
        #expect(Paths.abbreviated(url) == "~/Library/Caches")
        #expect(Paths.abbreviated(Paths.home) == "~")
        #expect(Paths.abbreviated(URL(filePath: "/Applications")) == "/Applications")
    }
}
