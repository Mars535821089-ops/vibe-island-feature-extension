import CoreGraphics
import Testing
@testable import SpacerCore

@Test("calibration normalizes AppKit width overhead before judging the anchor")
func calibrationNormalizesHostedWidthBeforeAnchor() {
    let island = CGRect(x: 1543, y: 0, width: 354, height: 30)
    let initialProbe = CGRect(x: 1622, y: 0, width: 370, height: 30)
    var settler = SpacerLengthSettler(
        initialLength: 354,
        initialFrame: initialProbe,
        islandFrame: island
    )

    #expect(settler.requestedLength == 338)
    #expect(
        settler.observe(
            currentLength: 354,
            spacerFrame: initialProbe,
            islandFrame: island
        ) == .setLength(338)
    )
}
