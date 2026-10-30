import Foundation
import Synchronization

/// Thread-safe progress shared between a background scan and the UI, which polls `snapshot`.
public final class ScanProgress: Sendable {
    public struct Snapshot: Sendable, Equatable {
        public var detail = ""
        public var fraction: Double?
        public var bytesFound: Int64 = 0

        public init(detail: String = "", fraction: Double? = nil, bytesFound: Int64 = 0) {
            self.detail = detail
            self.fraction = fraction
            self.bytesFound = bytesFound
        }
    }

    private let state = Mutex(Snapshot())
    private let cancelled = Atomic<Bool>(false)

    public init() {}

    public var snapshot: Snapshot { state.withLock { $0 } }

    public func update(detail: String) {
        state.withLock { $0.detail = detail }
    }

    public func update(detail: String, fraction: Double) {
        state.withLock {
            $0.detail = detail
            $0.fraction = min(max(fraction, 0), 1)
        }
    }

    public func update(fraction: Double) {
        state.withLock { $0.fraction = min(max(fraction, 0), 1) }
    }

    /// Set when the user stops a scan. Unlike `Task.isCancelled`, worker threads spawned by the scan can see it.
    public var isCancelled: Bool { cancelled.load(ordering: .relaxed) || Task.isCancelled }

    public func cancel() {
        cancelled.store(true, ordering: .relaxed)
    }

    public func found(bytes: Int64) {
        state.withLock { $0.bytesFound += bytes }
    }
}
