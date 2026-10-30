import Foundation

/// A running program's resource use, with helper processes folded into their app.
public struct ProcessUsage: Identifiable, Hashable, Sendable {
    public var id: String { name }
    public let name: String
    /// Percent of one core; can exceed 100 on multi-core work.
    public let cpu: Double
    public let memory: Int64
    /// Processes folded into this entry (e.g. browser renderers).
    public let processCount: Int
    public let pids: [Int32]
}

public enum ProcessList {
    public enum Metric: String, Sendable, CaseIterable {
        case cpu = "CPU"
        case memory = "Memory"
    }

    /// The heaviest programs right now, by CPU or memory.
    public static func top(by metric: Metric, limit: Int = 5) -> [ProcessUsage] {
        guard let output = try? Shell.run("/bin/ps", ["-Aceo", "pid=,pcpu=,rss=,comm="]).output else { return [] }
        let usage = aggregate(parse(output))
        let sorted = usage.sorted { metric == .cpu ? $0.cpu > $1.cpu : $0.memory > $1.memory }
        return Array(sorted.prefix(limit))
    }

    struct Sample {
        let pid: Int32
        let cpu: Double
        let memory: Int64
        let name: String
    }

    /// Parses `ps -Aceo pid=,pcpu=,rss=,comm=` (RSS in KiB).
    static func parse(_ output: String) -> [Sample] {
        output.split(whereSeparator: \.isNewline).compactMap { line in
            let fields = line.split(separator: " ", maxSplits: 3, omittingEmptySubsequences: true)
            guard fields.count == 4, let pid = Int32(fields[0]), let cpu = Double(fields[1].replacingOccurrences(of: ",", with: ".")),
                  let rss = Int64(fields[2])
            else { return nil }
            return Sample(pid: pid, cpu: cpu, memory: rss * 1024, name: String(fields[3]))
        }
    }

    /// "Google Chrome Helper (Renderer)" → "Google Chrome".
    static func appName(for processName: String) -> String {
        for marker in [" Helper", " Web Content", " Networking", " Graphics and Media"] {
            if let range = processName.range(of: marker), range.lowerBound > processName.startIndex {
                return String(processName[..<range.lowerBound])
            }
        }
        return processName
    }

    static func aggregate(_ samples: [Sample]) -> [ProcessUsage] {
        Dictionary(grouping: samples) { appName(for: $0.name) }.map { name, group in
            ProcessUsage(
                name: name, cpu: group.reduce(0) { $0 + $1.cpu }, memory: group.reduce(0) { $0 + $1.memory },
                processCount: group.count, pids: group.map(\.pid)
            )
        }
    }
}
