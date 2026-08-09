import CoreGraphics
import Testing
@testable import SpacerCore

@Test("adaptive width centers from the real anchored right edge")
func adaptiveWidthCentersFromRightEdge() {
    #expect(
        SpacerGeometry.adaptiveWidth(
            anchoredRightEdge: 1906,
            targetCenter: 1720,
            minimumWidth: 354,
            maximumWidth: 418
        ) == 372
    )
}

@Test("adaptive width stays inside compact safety bounds")
func adaptiveWidthUsesSafetyBounds() {
    #expect(
        SpacerGeometry.adaptiveWidth(
            anchoredRightEdge: 1880,
            targetCenter: 1720,
            minimumWidth: 354,
            maximumWidth: 418
        ) == 354
    )
    #expect(
        SpacerGeometry.adaptiveWidth(
            anchoredRightEdge: 2000,
            targetCenter: 1720,
            minimumWidth: 354,
            maximumWidth: 418
        ) == 418
    )
}

@Test("354-point compact island is centered on a 3440-point display")
func centersKnownCompactIsland() {
    let rect = SpacerGeometry.centeredSlot(
        in: CGRect(x: 0, y: 0, width: 3440, height: 1415),
        width: 354,
        menuBarHeight: 30
    )

    #expect(rect == CGRect(x: 1543, y: 1385, width: 354, height: 30))
    #expect(rect.midX == 1720)
}

@Test("centering respects a secondary display origin")
func centersOnSecondaryDisplay() {
    let rect = SpacerGeometry.centeredSlot(
        in: CGRect(x: 3440, y: 0, width: 1920, height: 1080),
        width: 354,
        menuBarHeight: 24
    )

    #expect(rect.origin.x == 4223)
    #expect(rect.midX == 4400)
}

@Test("slot width is bounded to the display")
func boundsOversizedSlot() {
    let rect = SpacerGeometry.centeredSlot(
        in: CGRect(x: 0, y: 0, width: 300, height: 200),
        width: 354,
        menuBarHeight: 30
    )

    #expect(rect == CGRect(x: 0, y: 170, width: 300, height: 30))
}

@Test("configuration keeps the compact island size and reserves drift coverage")
func configurationDefaultsToMeasuredWidth() {
    let configuration = SpacerConfiguration(environment: [:])

    #expect(SpacerConfiguration.compactIslandWidth == 354)
    #expect(configuration.width == 354)
    #expect(configuration.autosaveName == "VibeIslandMenuSpacer.CenteredSlot.v5")
}

@Test("configuration accepts a positive width override")
func configurationAcceptsPositiveOverride() {
    let configuration = SpacerConfiguration(
        environment: ["VIBE_ISLAND_SPACER_WIDTH": "360"]
    )

    #expect(configuration.width == 360)
}

@Test("configuration rejects invalid width overrides")
func configurationRejectsInvalidOverride() {
    #expect(SpacerConfiguration(environment: ["VIBE_ISLAND_SPACER_WIDTH": "0"]).width == 354)
    #expect(SpacerConfiguration(environment: ["VIBE_ISLAND_SPACER_WIDTH": "abc"]).width == 354)
}
