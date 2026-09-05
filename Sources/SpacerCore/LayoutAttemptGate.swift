import Foundation

/// One budget across probe, restore and settlement; failed layouts wait for change.
public struct LayoutAttemptGate: Sendable {
    private var started: TimeInterval?
    public private(set) var blocked = false
    private var baseline: String?
    private var candidate: String?
    private var samples = 0
    public init() {}
    public mutating func begin(now: TimeInterval) -> Bool {
        guard !blocked else { return false }
        if started == nil { started = now }
        return !expired(now: now)
    }
    public func expired(now: TimeInterval) -> Bool {
        started.map { now - $0 >= 60 } ?? false
    }
    public mutating func complete() { started = nil }
    public mutating func fail() {
        started = nil
        blocked = true
        baseline = nil
        candidate = nil
        samples = 0
    }
    public mutating func permits(signature: String) -> Bool {
        guard blocked else { return true }
        if candidate == signature { samples += 1 }
        else { candidate = signature; samples = 1 }
        guard samples >= 4 else { return false }
        guard let baseline else { self.baseline = signature; return false }
        guard baseline != signature else { return false }
        blocked = false
        return true
    }
}
