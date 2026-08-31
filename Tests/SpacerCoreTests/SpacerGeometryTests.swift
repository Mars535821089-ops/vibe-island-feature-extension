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

@Test("an under-covered island requests a position recalibration")
func underCoveredSpacerRequestsRecalibration() {
    let island = CGRect(x: 1543, y: 0, width: 354, height: 30)
    let spacer = CGRect(x: 1518, y: 0, width: 354, height: 30)

    #expect(
        SpacerPolicy.alignmentAction(
            currentLength: 338,
            spacerFrame: spacer,
            islandFrame: island
        ) == .reposition
    )
}

@Test("the nearest covering anchor preserves the exact compact width")
func preservesExactWidthAtCoveringAnchor() {
    let island = CGRect(x: 1543, y: 0, width: 354, height: 30)
    let spacer = CGRect(x: 1558, y: 0, width: 344, height: 30)

    #expect(
        SpacerPolicy.alignmentAction(
            currentLength: 338,
            spacerFrame: spacer,
            islandFrame: island
        ) == .setLength(348)
    )
}

@Test("a large right overshoot requests a fresh anchor")
func largeRightOvershootRequestsRecalibration() {
    let island = CGRect(x: 1543, y: 0, width: 354, height: 30)
    let spacer = CGRect(x: 1543, y: 0, width: 400, height: 30)

    #expect(
        SpacerPolicy.alignmentAction(
            currentLength: 384,
            spacerFrame: spacer,
            islandFrame: island
        ) == .reposition
    )
}

@Test("a fifteen-point right gap requests a closer anchor")
func moderateRightGapRequestsRecalibration() {
    let island = CGRect(x: 1543, y: 0, width: 354, height: 30)
    let spacer = CGRect(x: 1543, y: 0, width: 369, height: 30)

    #expect(
        SpacerPolicy.alignmentAction(
            currentLength: 353,
            spacerFrame: spacer,
            islandFrame: island
        ) == .reposition
    )
}

@Test("an accepted anchor always requests the exact compact island width")
func acceptedAnchorRequestsExactIslandWidth() {
    let island = CGRect(x: 1543, y: 0, width: 354, height: 30)
    let spacer = CGRect(x: 1543, y: 0, width: 353, height: 30)

    #expect(
        SpacerPolicy.alignmentAction(
            currentLength: 337,
            spacerFrame: spacer,
            islandFrame: island
        ) == .setLength(338)
    )
}

@Test("length settlement waits until AppKit publishes the requested width")
func lengthSettlementWaitsForPublishedWidth() {
    let island = CGRect(x: 1543, y: 0, width: 354, height: 30)
    let probe = CGRect(x: 1895, y: 0, width: 16, height: 30)
    var settler = SpacerLengthSettler(
        initialLength: 0,
        initialFrame: probe,
        islandFrame: island
    )

    #expect(settler.requestedLength == 338)
    #expect(
        settler.observe(
            currentLength: 338,
            spacerFrame: probe,
            islandFrame: island
        ) == .wait
    )
}

@Test("length settlement completes only after the spacer is actually centered")
func lengthSettlementCompletesAfterPublishedFrame() {
    let island = CGRect(x: 1543, y: 0, width: 354, height: 30)
    let probe = CGRect(x: 1895, y: 0, width: 16, height: 30)
    var settler = SpacerLengthSettler(
        initialLength: 0,
        initialFrame: probe,
        islandFrame: island
    )

    #expect(
        settler.observe(
            currentLength: 338,
            spacerFrame: CGRect(x: 1543, y: 0, width: 354, height: 30),
            islandFrame: island
        ) == .ready(anchorRight: 1897)
    )
}

@Test("length settlement accepts a one-point anchor underfill")
func lengthSettlementAcceptsMinimalUnderfill() {
    let island = CGRect(x: 1543, y: 0, width: 354, height: 30)
    let probe = CGRect(x: 1879, y: 0, width: 17, height: 30)
    var settler = SpacerLengthSettler(
        initialLength: 1,
        initialFrame: probe,
        islandFrame: island
    )

    #expect(settler.requestedLength == 338)
    #expect(
        settler.observe(
            currentLength: 338,
            spacerFrame: CGRect(x: 1542, y: 0, width: 354, height: 30),
            islandFrame: island
        ) == .ready(anchorRight: 1896)
    )
}

@Test("length settlement keeps the spacer exactly as wide as the compact island")
func lengthSettlementKeepsExactIslandWidth() {
    let island = CGRect(x: 1543, y: 0, width: 354, height: 30)
    let probe = CGRect(x: 1875, y: 0, width: 16, height: 30)
    var settler = SpacerLengthSettler(
        initialLength: 0,
        initialFrame: probe,
        islandFrame: island,
        maximumUnderfill: 6
    )

    #expect(settler.requestedLength == 338)
    #expect(
        settler.observe(
            currentLength: 338,
            spacerFrame: CGRect(x: 1537, y: 0, width: 354, height: 30),
            islandFrame: island
        ) == .ready(anchorRight: 1891)
    )
}

@Test("length settlement recalibrates if the expanded anchor no longer covers the island")
func lengthSettlementRecalibratesForUndercoverage() {
    let island = CGRect(x: 1543, y: 0, width: 354, height: 30)
    let probe = CGRect(x: 1895, y: 0, width: 16, height: 30)
    var settler = SpacerLengthSettler(
        initialLength: 0,
        initialFrame: probe,
        islandFrame: island
    )

    #expect(
        settler.observe(
            currentLength: 338,
            spacerFrame: CGRect(x: 1514, y: 0, width: 354, height: 30),
            islandFrame: island
        ) == .recalibrate
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

@Test("exactly two contiguous icons beside the spacer are retained for the island right side")
func selectsTwoIconsForRightSide() {
    let spacer = CGRect(x: 1543, y: 0, width: 421, height: 30)
    let items = [
        CGRect(x: 1429, y: 0, width: 35, height: 30),
        CGRect(x: 1464, y: 0, width: 34, height: 30),
        CGRect(x: 1498, y: 0, width: 45, height: 30),
        CGRect(x: 1964, y: 0, width: 48, height: 30)
    ]

    #expect(
        SpacerPolicy.rightSideFrames(
            itemFrames: items,
            spacerFrame: spacer,
            count: 2
        ) == Array(items[1...2])
    )
}

@Test("a gap beside the spacer prevents proxying unrelated icons")
func rejectsNoncontiguousRightSideIcons() {
    let spacer = CGRect(x: 1543, y: 0, width: 421, height: 30)
    let items = [
        CGRect(x: 1400, y: 0, width: 34, height: 30),
        CGRect(x: 1498, y: 0, width: 45, height: 30)
    ]

    #expect(
        SpacerPolicy.rightSideFrames(
            itemFrames: items,
            spacerFrame: spacer,
            count: 2
        ).isEmpty
    )
}

@Test("reserved widths are removed from the exact compact target")
func reservedWidthsAreRemovedFromExactTarget() {
    let island = CGRect(x: 1543, y: 0, width: 354, height: 30)
    let spacer = CGRect(x: 1543, y: 0, width: 421, height: 30)

    #expect(
        SpacerPolicy.alignmentAction(
            currentLength: 405,
            spacerFrame: spacer,
            islandFrame: island,
            leadingReservedWidth: 79,
            maximumOverflow: .greatestFiniteMagnitude
        ) == .setLength(259)
    )
}

@Test("a top-origin CoreGraphics status item is recognized inside the menu bar")
func recognizesCoreGraphicsMenuBarWindow() {
    let menuBar = CGRect(x: 0, y: 0, width: 3440, height: 30)
    let statusItem = CGRect(x: 1543, y: 0, width: 16, height: 30)

    #expect(
        SpacerGeometry.isHostedWindow(
            statusItem,
            in: menuBar
        )
    )
}

@Test("a similarly sized non-menu-bar window is rejected")
func rejectsNonMenuBarWindow() {
    let menuBar = CGRect(x: 0, y: 0, width: 3440, height: 30)
    let unrelatedWindow = CGRect(x: 1543, y: 1205, width: 16, height: 30)

    #expect(
        !SpacerGeometry.isHostedWindow(
            unrelatedWindow,
            in: menuBar
        )
    )
}

@Test("an AppKit status window is normalized into CoreGraphics menu-bar coordinates")
func normalizesAppKitStatusWindow() {
    let appKitWindow = CGRect(x: 1895, y: 1410, width: 16, height: 30)
    let menuBar = CGRect(x: 0, y: 0, width: 3440, height: 30)

    #expect(
        SpacerGeometry.normalizedStatusItemFrame(
            appKitWindow,
            in: menuBar
        ) == CGRect(x: 1895, y: 0, width: 16, height: 30)
    )
}

@Test("an unrealized zero-height AppKit status window is ignored")
func ignoresUnrealizedAppKitStatusWindow() {
    let appKitWindow = CGRect(x: 0, y: 0, width: 16, height: 0)
    let menuBar = CGRect(x: 0, y: 0, width: 3440, height: 30)

    #expect(
        SpacerGeometry.normalizedStatusItemFrame(
            appKitWindow,
            in: menuBar
        ) == nil
    )
}

@Test("a clear spacer is removed so it leaves no hidden gap")
func clearSpacerIsRemoved() {
    #expect(SpacerPolicy.presenceAction(isPresent: true, hasCollision: false) == .remove)
    #expect(SpacerPolicy.presenceAction(isPresent: false, hasCollision: false) == .none)
}

@Test("a spacer is created only for a real collision")
func collidedSpacerIsCreated() {
    #expect(SpacerPolicy.presenceAction(isPresent: false, hasCollision: true) == .create)
    #expect(SpacerPolicy.presenceAction(isPresent: true, hasCollision: true) == .none)
}

@Test("position calibration converges from an under-filling anchor")
func positionCalibrationConvergesFromUnderfill() {
    var calibrator = PreferredPositionCalibrator(initialPosition: 1543, step: 32)
    var readyPosition: Int?

    for _ in 0..<24 {
        let coversTarget = calibrator.candidate <= 1372
        switch calibrator.observe(coversTarget: coversTarget) {
        case .retry:
            continue
        case let .ready(position):
            readyPosition = position
        case .failed:
            break
        }
        if readyPosition != nil { break }
    }

    #expect(readyPosition == 1372)
}

@Test("position calibration converges from a covering anchor")
func positionCalibrationConvergesFromCover() {
    var calibrator = PreferredPositionCalibrator(initialPosition: 1300, step: 32)
    var readyPosition: Int?

    for _ in 0..<24 {
        let coversTarget = calibrator.candidate <= 1372
        switch calibrator.observe(coversTarget: coversTarget) {
        case .retry:
            continue
        case let .ready(position):
            readyPosition = position
        case .failed:
            break
        }
        if readyPosition != nil { break }
    }

    #expect(readyPosition == 1372)
}

@Test("position calibration prefers a one-point underfill over a large right gap")
func positionCalibrationPrefersNearestEdge() {
    var calibrator = PreferredPositionCalibrator(
        initialPosition: 1384,
        step: 32,
        maximumUnderfill: 4
    )
    let edgeErrors: [Int: CGFloat] = [
        1384: -3,
        1352: -3,
        1336: 47,
        1344: -1
    ]
    var readyPosition: Int?

    for _ in 0..<24 {
        let error = edgeErrors[calibrator.candidate] ?? 47
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

    #expect(readyPosition == 1344)
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

@Test("the compact island stays centered in CoreGraphics menu-bar coordinates")
func centersInsideMenuBarFrame() {
    let rect = SpacerGeometry.centeredSlot(
        inMenuBar: CGRect(x: 0, y: 0, width: 3440, height: 30),
        width: 354
    )

    #expect(rect == CGRect(x: 1543, y: 0, width: 354, height: 30))
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
    #expect(configuration.autosaveName == "VibeIslandMenuSpacer.ConditionalSlot.v8")
    #expect(
        configuration.preferredPositionKey
        == "NSStatusItem Preferred Position VibeIslandMenuSpacer.ConditionalSlot.v8"
    )
    #expect(configuration.savedPositionKey == "VibeIslandMenuSpacer Saved Preferred Position")
    #expect(configuration.savedLengthKey == "VibeIslandMenuSpacer Saved Length")
    #expect(configuration.savedAnchorRightKey == "VibeIslandMenuSpacer Saved Anchor Right")
    #expect(
        configuration.savedCalibrationVersionKey
            == "VibeIslandMenuSpacer Saved Calibration Version"
    )
    #expect(SpacerConfiguration.calibrationVersion == 8)
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
