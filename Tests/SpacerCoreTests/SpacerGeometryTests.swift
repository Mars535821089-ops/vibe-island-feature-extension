import CoreGraphics
import Testing
@testable import SpacerCore

@Test("no covered icon leaves the spacer disabled")
func noCollisionLeavesSpacerDisabled() {
    let island = CGRect(x: 1543, y: 0, width: 354, height: 30)
    let items = [
        CGRect(x: 1904, y: 0, width: 41, height: 30),
        CGRect(x: 1979, y: 0, width: 40, height: 30)
    ]

    #expect(!SpacerPolicy.shouldShowSpacer(itemFrames: items, spacerFrame: nil, islandFrame: island))
}

@Test("an icon covered by the compact island enables the spacer")
func collisionEnablesSpacer() {
    let island = CGRect(x: 1543, y: 0, width: 354, height: 30)
    let items = [
        CGRect(x: 1837, y: 0, width: 67, height: 30),
        CGRect(x: 1904, y: 0, width: 41, height: 30)
    ]

    #expect(SpacerPolicy.shouldShowSpacer(itemFrames: items, spacerFrame: nil, islandFrame: island))
}

@Test("an active spacer uses the reconstructed unreserved layout")
func activeSpacerUsesProjectedLayout() {
    let island = CGRect(x: 1543, y: 0, width: 354, height: 30)
    let spacer = CGRect(x: 1543, y: 0, width: 436, height: 30)
    let shiftedItems = [
        CGRect(x: 1401, y: 0, width: 67, height: 30),
        CGRect(x: 1468, y: 0, width: 75, height: 30),
        CGRect(x: 1979, y: 0, width: 40, height: 30)
    ]

    #expect(
        SpacerPolicy.shouldShowSpacer(
            itemFrames: shiftedItems,
            spacerFrame: spacer,
            islandFrame: island
        )
    )
}

@Test("an active spacer releases when the projected icons no longer reach the island")
func activeSpacerReleasesWhenProjectionIsClear() {
    let island = CGRect(x: 1543, y: 0, width: 354, height: 30)
    let spacer = CGRect(x: 1543, y: 0, width: 436, height: 30)
    let shiftedItems = [
        CGRect(x: 1000, y: 0, width: 50, height: 30),
        CGRect(x: 1979, y: 0, width: 40, height: 30)
    ]

    #expect(
        !SpacerPolicy.shouldShowSpacer(
            itemFrames: shiftedItems,
            spacerFrame: spacer,
            islandFrame: island
        )
    )
}

@Test("status item length aligns its left edge with the centered island")
func alignsSpacerLeftEdge() {
    let island = CGRect(x: 1543, y: 0, width: 354, height: 30)
    let spacer = CGRect(x: 1609, y: 0, width: 370, height: 30)

    #expect(
        SpacerPolicy.alignedLength(
            currentLength: 354,
            spacerFrame: spacer,
            islandFrame: island
        ) == 420
    )
}

@Test("the spacer window is excluded without relying on its protected name")
func excludesSpacerByGeometry() {
    let spacer = CGRect(x: 1609, y: 0, width: 370, height: 30)
    let icon = CGRect(x: 1533, y: 0, width: 41, height: 30)

    #expect(
        SpacerPolicy.excludingSpacer(
            from: [spacer, icon],
            spacerFrame: spacer
        ) == [icon]
    )
}

@Test("a hidden spacer becomes visible only for a real collision")
func hiddenSpacerVisibilityTransition() {
    #expect(SpacerPolicy.visibilityAction(isVisible: false, hasCollision: true) == .show)
    #expect(SpacerPolicy.visibilityAction(isVisible: false, hasCollision: false) == .none)
}

@Test("a visible spacer hides instead of being destroyed when clear")
func visibleSpacerVisibilityTransition() {
    #expect(SpacerPolicy.visibilityAction(isVisible: true, hasCollision: false) == .hide)
    #expect(SpacerPolicy.visibilityAction(isVisible: true, hasCollision: true) == .none)
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

@Test("configuration keeps the measured compact island size")
func configurationDefaultsToMeasuredWidth() {
    let configuration = SpacerConfiguration(environment: [:])

    #expect(SpacerConfiguration.compactIslandWidth == 354)
    #expect(configuration.width == 354)
    #expect(configuration.autosaveName == "VibeIslandMenuSpacer.ConditionalSlot.v7")
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
