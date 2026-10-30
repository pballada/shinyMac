import Darwin
import Foundation
import IOKit.ps

/// A point-in-time reading of the Mac's vital signs.
public struct SystemSnapshot: Sendable, Equatable {
    public struct Battery: Sendable, Equatable {
        public let level: Double
        public let isCharging: Bool
        public let isPluggedIn: Bool
    }

    /// 0...1 across all cores since the previous sample.
    public var cpuUsage: Double = 0
    public var memoryUsed: Int64 = 0
    public var memoryTotal: Int64 = Int64(ProcessInfo.processInfo.physicalMemory)
    public var volume: VolumeInfo?
    public var battery: Battery?
    /// Bytes per second since the previous sample.
    public var networkIn: Double = 0
    public var networkOut: Double = 0
    public var uptime: TimeInterval = ProcessInfo.processInfo.systemUptime

    public var memoryFraction: Double { memoryTotal > 0 ? Double(memoryUsed) / Double(memoryTotal) : 0 }

    public init() {}
}

/// Samples CPU, memory, disk, battery and network. Rates are computed between successive calls to `sample()`.
public final class SystemMonitor {
    private let host = mach_host_self()
    private var previousTicks: (busy: UInt64, total: UInt64)?
    private var previousNetwork: (inBytes: UInt64, outBytes: UInt64, time: TimeInterval)?

    public init() {}

    public func sample() -> SystemSnapshot {
        var snapshot = SystemSnapshot()
        snapshot.cpuUsage = cpuUsage()
        snapshot.memoryUsed = memoryUsed()
        snapshot.volume = VolumeInfo.current()
        snapshot.battery = Self.battery()
        (snapshot.networkIn, snapshot.networkOut) = networkRates()
        return snapshot
    }

    private func cpuUsage() -> Double {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(host, HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }

        let user = UInt64(info.cpu_ticks.0), system = UInt64(info.cpu_ticks.1)
        let idle = UInt64(info.cpu_ticks.2), nice = UInt64(info.cpu_ticks.3)
        let busy = user + system + nice
        let total = busy + idle
        defer { previousTicks = (busy, total) }
        guard let previous = previousTicks, total > previous.total else { return 0 }
        return Double(busy - previous.busy) / Double(total - previous.total)
    }

    /// Matches Activity Monitor's "Memory Used": app memory + wired + compressed.
    private func memoryUsed() -> Int64 {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(host, HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        let pageSize = Int64(sysconf(_SC_PAGESIZE))
        let appPages = Int64(stats.internal_page_count) - Int64(stats.purgeable_count)
        return (appPages + Int64(stats.wire_count) + Int64(stats.compressor_page_count)) * pageSize
    }

    private static func battery() -> SystemSnapshot.Battery? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef]
        else { return nil }
        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                  description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
                  let current = description[kIOPSCurrentCapacityKey] as? Int,
                  let maximum = description[kIOPSMaxCapacityKey] as? Int, maximum > 0
            else { continue }
            return SystemSnapshot.Battery(
                level: Double(current) / Double(maximum),
                isCharging: description[kIOPSIsChargingKey] as? Bool ?? false,
                isPluggedIn: description[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue
            )
        }
        return nil
    }

    private func networkRates() -> (Double, Double) {
        let (inBytes, outBytes) = Self.networkCounters()
        let now = ProcessInfo.processInfo.systemUptime
        defer { previousNetwork = (inBytes, outBytes, now) }
        guard let previous = previousNetwork, now > previous.time,
              inBytes >= previous.inBytes, outBytes >= previous.outBytes // counters can wrap
        else { return (0, 0) }
        let elapsed = now - previous.time
        return (Double(inBytes - previous.inBytes) / elapsed, Double(outBytes - previous.outBytes) / elapsed)
    }

    /// Total bytes received and sent on physical interfaces.
    static func networkCounters() -> (UInt64, UInt64) {
        var addresses: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addresses) == 0, let first = addresses else { return (0, 0) }
        defer { freeifaddrs(addresses) }

        var received: UInt64 = 0
        var sent: UInt64 = 0
        for pointer in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let interface = pointer.pointee
            guard let address = interface.ifa_addr, address.pointee.sa_family == UInt8(AF_LINK),
                  let data = interface.ifa_data?.assumingMemoryBound(to: if_data.self)
            else { continue }
            let name = String(cString: interface.ifa_name)
            guard name.hasPrefix("en") || name.hasPrefix("pdp_ip") else { continue }
            received += UInt64(data.pointee.ifi_ibytes)
            sent += UInt64(data.pointee.ifi_obytes)
        }
        return (received, sent)
    }
}
