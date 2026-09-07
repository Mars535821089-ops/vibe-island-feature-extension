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
    var accepted = false
    var failed = false
    for _ in 0..<18 {
        let error: CGFloat = calibrator.candidate <= 100 ? 40 : -40
        switch calibrator.observe(rightEdgeError: error) {
        case .retry:
            continue
        case .ready:
            accepted = true
        case .failed:
            failed = true
        }
        break
    }
    #expect(!accepted)
    #expect(failed)
}

@Test("calibration exhaustively checks neighboring preferred positions after a discontinuous boundary")
func calibrationChecksDiscontinuousNeighbor() {
    var calibrator = PreferredPositionCalibrator(
        initialPosition: 1903,
        step: 4,
        range: 1880...1920,
        maximumUnderfill: 0,
        maximumOverflow: 20
    )
    let edgeErrors: [Int: CGFloat] = [
        1903: -4,
        1899: -4,
        1897: -4,
        1896: 34,
        1895: 16
    ]
    var visited: [Int] = []
    var readyPosition: Int?

    for _ in 0..<18 {
        visited.append(calibrator.candidate)
        let error = edgeErrors[calibrator.candidate]
            ?? (calibrator.candidate <= 1896 ? 34 : -4)
        switch calibrator.observe(rightEdgeError: error) {
        case .retry:
            continue
        case let .ready(position):
            readyPosition = position
        case .failed:
            break
        }
        if readyPosition != nil { break }
    }

    #expect(visited.contains(1895))
    #expect(readyPosition == 1895)
}

@Test("calibration rejects a sub-host-chrome gap and searches for a representable neighbor")
func calibrationSearchesPastUnrepresentableGap() {
    var calibrator = PreferredPositionCalibrator(
        initialPosition: 1903,
        step: 2,
        range: 1880...1920,
        maximumUnderfill: 0,
        minimumPositiveOverflow: 16,
        maximumOverflow: 20
    )
    let edgeErrors: [Int: CGFloat] = [
        1903: -4,
        1899: -4,
        1898: -4,
        1897: 8,
        1896: 34,
        1895: 16
    ]
    var visited: [Int] = []
    var readyPosition: Int?

    for _ in 0..<18 {
        visited.append(calibrator.candidate)
        let error = edgeErrors[calibrator.candidate]
            ?? (calibrator.candidate <= 1897 ? 34 : -4)
        switch calibrator.observe(rightEdgeError: error) {
        case .retry:
            continue
        case let .ready(position):
            readyPosition = position
        case .failed:
            break
        }
        if readyPosition != nil { break }
    }

    #expect(visited.contains(1896))
    #expect(visited.contains(1895))
    #expect(readyPosition == 1895)
}

@Test func lifecycleTimeoutSurvivesRepeatedBegin() {
    var gate = LayoutAttemptGate()
    let first = gate.begin(now: 10)
    #expect(first)
    let second = gate.begin(now: 60)
    #expect(second)
    #expect(!gate.expired(now: 71))
    #expect(gate.expired(now: 131))
}

@Test func failedLayoutRequiresStableChange() {
    var gate = LayoutAttemptGate()
    gate.fail()
    for _ in 0..<20 { let allowed = gate.permits(signature: "old"); #expect(!allowed) }
    for _ in 0..<3 { let allowed = gate.permits(signature: "new"); #expect(!allowed) }
    let allowed = gate.permits(signature: "new"); #expect(allowed)
}
