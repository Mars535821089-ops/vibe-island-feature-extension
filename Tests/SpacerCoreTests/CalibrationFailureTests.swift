import Testing
import CoreGraphics
@testable import SpacerCore

@Test func maximumPositionDoesNotAcceptOverflow() {
    var calibrator = PreferredPositionCalibrator(initialPosition: 10000)
    #expect(calibrator.observe(rightEdgeError: 100) == .failed)
}

@Test func exhaustedSearchDoesNotAcceptOverflow() {
    var calibrator = PreferredPositionCalibrator(initialPosition: 0, step: 1, range: 0...1_000_000)
    var action: PreferredPositionCalibrationAction = .retry(position: 0)
    for _ in 0..<18 { action = calibrator.observe(rightEdgeError: 100) }
    #expect(action == .failed)
}

@Test func adjacentCandidatesDoNotAcceptUncoveredLayout() {
    var calibrator = PreferredPositionCalibrator(initialPosition: 100, step: 1)
    #expect(calibrator.observe(rightEdgeError: 40) == .retry(position: 101))
    _ = calibrator.observe(rightEdgeError: -40)
    #expect(calibrator.observe(rightEdgeError: 40) == .failed)
}

@Test func lifecycleTimeoutSurvivesRepeatedBegin() {
    var gate = LayoutAttemptGate()
    let first = gate.begin(now: 10)
    #expect(first)
    let second = gate.begin(now: 60)
    #expect(second)
    #expect(gate.expired(now: 71))
}

@Test func failedLayoutRequiresStableChange() {
    var gate = LayoutAttemptGate()
    gate.fail()
    for _ in 0..<20 { let allowed = gate.permits(signature: "old"); #expect(!allowed) }
    for _ in 0..<3 { let allowed = gate.permits(signature: "new"); #expect(!allowed) }
    let allowed = gate.permits(signature: "new"); #expect(allowed)
}
