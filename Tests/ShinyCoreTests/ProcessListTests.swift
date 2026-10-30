import Foundation
import Testing
@testable import ShinyCore

@Suite struct ProcessListTests {
    @Test func parsesAndFoldsHelpers() {
        let output = """
        39562  16.8 236560 Google Chrome Helper (Renderer)
        39967  16,4 127040 Google Chrome Helper (Renderer)
          400   2.0  50000 Google Chrome
          391  13.2  96944 WindowServer
        garbage line
        """
        let samples = ProcessList.parse(output)
        #expect(samples.count == 4)
        #expect(samples[1].cpu == 16.4)

        let usage = ProcessList.aggregate(samples).sorted { $0.cpu > $1.cpu }
        let chrome = usage[0]
        #expect(chrome.name == "Google Chrome")
        #expect(chrome.processCount == 3)
        #expect(abs(chrome.cpu - 35.2) < 0.001)
        #expect(chrome.memory == (236_560 + 127_040 + 50_000) * 1024)
        #expect(usage[1].name == "WindowServer")
    }

    @Test func listsLiveProcesses() {
        let top = ProcessList.top(by: .memory, limit: 3)
        #expect(top.count == 3)
        #expect(top[0].memory >= top[1].memory)
    }
}
