import AppKit
import SpacerCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var observationTimer: Timer?
    private let configuration = SpacerConfiguration()
    private let runtimeAutosaveName = "VibeIslandMenuSpacer.ConditionalSlot.v11"
    private let runtimeCalibrationVersion = 11
    private let setupMode = CommandLine.arguments.contains("--setup")
    private var positionCalibrator: PreferredPositionCalibrator?
    private var pendingCalibrationPosition: Int?
    private var currentPreferredPosition: Int?
    private var calibratedIslandRight: CGFloat?
    private var calibratedAnchorRight: CGFloat?
    private var lengthSettler: SpacerLengthSettler?
    private var restoringSavedLayout = false
    private var calibrationFrame: CGRect?
    private var calibrationStableSamples = 0
    private var pendingCalibrationDelayTicks = 0
    private var settlementWaitTicks = 0
    private var restorationWaitTicks = 0
    private var attemptGate = LayoutAttemptGate()
    private var failureReason = "none"
    private var blockedUntil: TimeInterval = 0
    private let validatedCacheKey = "VibeIslandMenuSpacer Validated Layout v11"
    private let geometryTolerance: CGFloat = 0.5
    private let clickThroughController = MenuBarClickThroughController()
    // Control Center exposes status-item insertion boundaries rather than a
    // continuous X coordinate. Accept one standard icon-slot quantum around
    // the centered edge, then require the final hosted width to remain exactly
    // 354pt and every native item center to sit outside the island.
    private let runtimeDiscreteTolerance: CGFloat = 20

    func applicationDidFinishLaunching(_ notification: Notification) {
        let application = NSApplication.shared
        application.setActivationPolicy(.accessory)
        clickThroughController.start()

        if setupMode {
            let screen = NSScreen.main ?? NSScreen.screens.first
            let fallback = Int(
                ((screen?.frame.midX ?? 0) - SpacerConfiguration.compactIslandWidth / 2).rounded()
            )
            if let savedLayout = savedLayout() {
                createStatusItem(
                    length: savedLayout.length,
                    preferredPosition: savedLayout.position
                )
            } else {
                let position = savedPreferredPosition(fallback: fallback)
                createStatusItem(length: configuration.width, preferredPosition: position)
            }
        } else {
            refreshLayout()
        }

        observationTimer = Timer.scheduledTimer(
            timeInterval: 0.25,
            target: self,
            selector: #selector(refreshLayout),
            userInfo: nil,
            repeats: true
        )
    }

    @objc private func refreshLayout() {
        guard !setupMode else { return }
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }

        let windows = menuBarWindows()
        let menuBarFrame = windows.first(where: { window in
            window.layer == 24
                && window.frame.height >= 20
                && window.frame.height <= 50
                && abs(window.frame.minX - screen.frame.minX) <= 1
                && abs(window.frame.width - screen.frame.width) <= 1
        })?.frame
            ?? CGRect(x: screen.frame.minX, y: 0, width: screen.frame.width, height: 30)
        let islandFrame = SpacerGeometry.centeredSlot(
            inMenuBar: menuBarFrame,
            width: SpacerConfiguration.compactIslandWidth
        )
        // Read our status item's AppKit window directly. CGWindow names are
        // redacted when Screen Recording is not granted, so name-based lookup
        // sees the host but cannot identify it and calibration never advances.
        // AppKit uses a bottom-left Y axis; normalization keeps its real X/width
        // while projecting it onto the CG menu-bar coordinate space.
        let spacerFrame = (statusItem?.button?.window?.frame).flatMap {
            SpacerGeometry.normalizedStatusItemFrame($0, in: menuBarFrame)
        }
        let hostedItemWindows = windows
            .filter { window in
                window.layer == 25
                    && SpacerGeometry.isHostedWindow(window.frame, in: menuBarFrame)
            }
        let itemWindows = hostedItemWindows.filter { window in
            guard let spacerFrame else { return true }
            return abs(window.frame.minX - spacerFrame.minX) > 1
                || abs(window.frame.width - spacerFrame.width) > 1
        }
        let itemFrames = itemWindows.map(\.frame)
        clickThroughController.update(
            menuBarFrame: menuBarFrame,
            islandFrame: islandFrame,
            itemWindows: itemWindows
        )

        let now = ProcessInfo.processInfo.systemUptime
        if attemptGate.expired(now: now) { failLayout("layout-timeout") }
        let signature = NSStringFromRect(islandFrame) + itemWindows.sorted { $0.windowID < $1.windowID }
            .map { "\($0.windowID):\(NSStringFromRect($0.frame))" }.joined(separator: ";")
        if now < blockedUntil || !attemptGate.permits(signature: signature) {
            writeDiagnostics(islandFrame: islandFrame, spacerFrame: nil,
                             itemFrames: itemFrames, hasCollision: nil)
            return
        }

        if positionCalibrator != nil {
            if statusItem == nil, let position = pendingCalibrationPosition {
                if pendingCalibrationDelayTicks > 0 {
                    pendingCalibrationDelayTicks -= 1
                } else {
                    pendingCalibrationPosition = nil
                    resetCalibrationStability()
                    // A one-point status item and the final 354-point item can be
                    // assigned to different discrete Control Center slots. Probe
                    // with the final width so the measured anchor is the anchor
                    // that will actually remain installed.
                    createStatusItem(
                        length: SpacerConfiguration.compactIslandWidth,
                        preferredPosition: position
                    )
                }
            } else if let spacerFrame {
                if calibrationFrameIsStable(spacerFrame) {
                    continueCalibration(spacerFrame: spacerFrame, islandFrame: islandFrame)
                }
            }
            writeDiagnostics(
                islandFrame: islandFrame,
                spacerFrame: spacerFrame,
                itemFrames: itemFrames,
                hasCollision: nil
            )
            return
        }

        if restoringSavedLayout {
            guard let item = statusItem, let spacerFrame else {
                restorationWaitTicks += 1
                if restorationWaitTicks >= 40 {
                    beginCalibration(islandFrame: islandFrame)
                }
                writeDiagnostics(
                    islandFrame: islandFrame,
                    spacerFrame: spacerFrame,
                    itemFrames: itemFrames,
                    hasCollision: nil
                )
                return
            }

            if calibrationFrameIsStable(spacerFrame) {
                let savedAnchorMatches = calibratedAnchorRight.map {
                    abs($0 - spacerFrame.maxX) <= 0.5
                } ?? false
                let hasLargeOverflow = spacerFrame.maxX
                    > islandFrame.maxX + SpacerConfiguration.maximumAnchorOverflow

                if hasLargeOverflow || !savedAnchorMatches {
                    beginCalibration(islandFrame: islandFrame)
                } else {
                    restoringSavedLayout = false
                    restorationWaitTicks = 0
                    resetCalibrationStability()
                    beginLengthSettlement(
                        item: item,
                        spacerFrame: spacerFrame,
                        islandFrame: islandFrame
                    )
                }
            }

            writeDiagnostics(
                islandFrame: islandFrame,
                spacerFrame: spacerFrame,
                itemFrames: itemFrames,
                hasCollision: nil
            )
            return
        }

        if var settler = lengthSettler {
            guard let item = statusItem, let spacerFrame else {
                settlementWaitTicks += 1
                if settlementWaitTicks >= 40 {
                    beginCalibration(islandFrame: islandFrame)
                }
                writeDiagnostics(
                    islandFrame: islandFrame,
                    spacerFrame: spacerFrame,
                    itemFrames: itemFrames,
                    hasCollision: nil
                )
                return
            }

            switch settler.observe(
                currentLength: item.length,
                spacerFrame: spacerFrame,
                islandFrame: islandFrame
            ) {
            case .wait:
                lengthSettler = settler
                settlementWaitTicks += 1
                if settlementWaitTicks >= 40 {
                    beginCalibration(islandFrame: islandFrame)
                }
            case let .setLength(length):
                lengthSettler = settler
                settlementWaitTicks = 0
                item.length = length
            case let .ready(anchorRight):
                lengthSettler = nil
                settlementWaitTicks = 0
                calibratedIslandRight = islandFrame.maxX
                calibratedAnchorRight = anchorRight
                let rightEdgeError = spacerFrame.maxX - islandFrame.maxX
                guard abs(spacerFrame.width - islandFrame.width) <= geometryTolerance,
                      rightEdgeError >= -runtimeDiscreteTolerance,
                      rightEdgeError <= runtimeDiscreteTolerance,
                      !itemFrames.contains(where: { frame in
                          islandFrame.contains(
                              CGPoint(x: frame.midX, y: islandFrame.midY)
                          )
                      }) else {
                    failLayout("geometry-not-clickable")
                    return
                }
                saveSettledLayout(length: item.length, anchorRight: anchorRight)
                attemptGate.complete()
                failureReason = "none"
            case .recalibrate, .failed:
                lengthSettler = nil
                settlementWaitTicks = 0
                beginCalibration(islandFrame: islandFrame)
            }

            writeDiagnostics(
                islandFrame: islandFrame,
                spacerFrame: spacerFrame,
                itemFrames: itemFrames,
                hasCollision: nil
            )
            return
        }

        if let item = statusItem, let spacerFrame {
            if calibratedIslandRight.map({ abs($0 - islandFrame.maxX) > 0.5 }) == true {
                beginCalibration(islandFrame: islandFrame)
                writeDiagnostics(
                    islandFrame: islandFrame,
                    spacerFrame: spacerFrame,
                    itemFrames: itemFrames,
                    hasCollision: nil
                )
                return
            }

            let maximumOverflow = runtimeDiscreteTolerance

            switch SpacerPolicy.alignmentAction(
                currentLength: item.length,
                spacerFrame: spacerFrame,
                islandFrame: islandFrame,
                maximumUnderfill: runtimeDiscreteTolerance,
                maximumOverflow: maximumOverflow
            ) {
            case .reposition:
                beginCalibration(islandFrame: islandFrame)
                writeDiagnostics(
                    islandFrame: islandFrame,
                    spacerFrame: spacerFrame,
                    itemFrames: itemFrames,
                    hasCollision: nil
                )
                return
            case let .setLength(desiredLength):
                if abs(item.length - desiredLength) > 0.5 {
                    beginLengthSettlement(
                        item: item,
                        spacerFrame: spacerFrame,
                        islandFrame: islandFrame
                    )
                    writeDiagnostics(
                        islandFrame: islandFrame,
                        spacerFrame: spacerFrame,
                        itemFrames: itemFrames,
                        hasCollision: nil
                    )
                    return
                }
            }

            let hasCollision = SpacerPolicy.shouldShowSpacer(
                itemFrames: itemFrames,
                spacerFrame: spacerFrame,
                islandFrame: islandFrame
            )
            if SpacerPolicy.presenceAction(
                isPresent: true,
                hasCollision: hasCollision
            ) == .remove {
                removeSpacer()
            }

            writeDiagnostics(
                islandFrame: islandFrame,
                spacerFrame: spacerFrame,
                itemFrames: itemFrames,
                hasCollision: hasCollision
            )
            return
        }

        guard statusItem == nil else {
            writeDiagnostics(
                islandFrame: islandFrame,
                spacerFrame: spacerFrame,
                itemFrames: itemFrames,
                hasCollision: nil
            )
            return
        }

        let hasCollision = SpacerPolicy.shouldShowSpacer(
            itemFrames: itemFrames,
            spacerFrame: nil,
            islandFrame: islandFrame
        )
        if SpacerPolicy.presenceAction(
            isPresent: false,
            hasCollision: hasCollision
        ) == .create {
            beginSavedRestoreOrCalibration(islandFrame: islandFrame)
        }

        writeDiagnostics(
            islandFrame: islandFrame,
            spacerFrame: spacerFrame,
            itemFrames: itemFrames,
            hasCollision: hasCollision
        )
    }

    private func createStatusItem(length: CGFloat, preferredPosition: Int) {
        guard statusItem == nil else { return }

        applyPreferredPosition(preferredPosition)
        let item = NSStatusBar.system.statusItem(withLength: length)
        item.autosaveName = runtimeAutosaveName
        item.isVisible = true
        if let button = item.button {
            button.title = ""
            button.image = nil
            button.imagePosition = .noImage
            button.toolTip = "Vibe Island 条件占位"
            button.setAccessibilityLabel("Vibe Island 条件占位")
        }

        let menu = NSMenu()
        menu.addItem(withTitle: "仅在图标被遮挡时自动占位", action: nil, keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(
            withTitle: "退出并恢复菜单栏",
            action: #selector(quitAndRestore),
            keyEquivalent: "q"
        ).target = self
        item.menu = menu
        statusItem = item
        currentPreferredPosition = preferredPosition
    }

    private func beginCalibration(islandFrame: CGRect) {
        guard attemptGate.begin(now: ProcessInfo.processInfo.systemUptime) else {
            failLayout("layout-timeout")
            return
        }
        destroyStatusItem()
        restoringSavedLayout = false
        restorationWaitTicks = 0
        lengthSettler = nil
        settlementWaitTicks = 0
        calibratedIslandRight = nil
        calibratedAnchorRight = nil
        resetCalibrationStability()
        let fallback = Int(islandFrame.minX.rounded())
        let initialPosition = savedPreferredPosition(fallback: fallback)
        positionCalibrator = PreferredPositionCalibrator(
            initialPosition: initialPosition,
            step: 32,
            maximumUnderfill: runtimeDiscreteTolerance,
            maximumOverflow: runtimeDiscreteTolerance
        )
        pendingCalibrationPosition = initialPosition
        // Let Control Center fully collapse the previous wide item before
        // measuring a hosted nonzero candidate. Sampling the transient layout makes
        // preferred-position anchors drift across restarts.
        pendingCalibrationDelayTicks = 20
    }

    private func beginSavedRestoreOrCalibration(islandFrame: CGRect) {
        guard attemptGate.begin(now: ProcessInfo.processInfo.systemUptime) else {
            failLayout("layout-timeout")
            return
        }
        guard let savedLayout = savedLayout() else {
            beginCalibration(islandFrame: islandFrame)
            return
        }

        destroyStatusItem()
        positionCalibrator = nil
        pendingCalibrationPosition = nil
        pendingCalibrationDelayTicks = 0
        lengthSettler = nil
        settlementWaitTicks = 0
        calibratedIslandRight = nil
        calibratedAnchorRight = savedLayout.calibrationVersion
            == runtimeCalibrationVersion
            ? savedLayout.anchorRight
            : nil
        restoringSavedLayout = true
        restorationWaitTicks = 0
        resetCalibrationStability()
        createStatusItem(
            length: savedLayout.length,
            preferredPosition: savedLayout.position
        )
    }

    private func continueCalibration(spacerFrame: CGRect, islandFrame: CGRect) {
        guard var calibrator = positionCalibrator else { return }

        let rightEdgeError = spacerFrame.maxX - islandFrame.maxX
        // Preferred positions are discrete and can look non-monotonic while
        // neighboring Control Center items are settling. Lock a probe that is
        // already within the small visual tolerance before a later transient
        // sample can select a worse anchor.
        if rightEdgeError >= -runtimeDiscreteTolerance,
           rightEdgeError <= runtimeDiscreteTolerance {
            positionCalibrator = nil
            pendingCalibrationPosition = nil
            applyPreferredPosition(calibrator.candidate)
            guard let item = statusItem else { return }
            beginLengthSettlement(
                item: item,
                spacerFrame: spacerFrame,
                islandFrame: islandFrame
            )
            return
        }
        switch calibrator.observe(rightEdgeError: rightEdgeError) {
        case let .retry(position):
            positionCalibrator = calibrator
            destroyStatusItem()
            pendingCalibrationPosition = position
            pendingCalibrationDelayTicks = 6
            resetCalibrationStability()
        case let .ready(position):
            guard position == currentPreferredPosition else {
                positionCalibrator = PreferredPositionCalibrator(
                    initialPosition: position,
                    maximumUnderfill: runtimeDiscreteTolerance,
                    maximumOverflow: runtimeDiscreteTolerance
                )
                destroyStatusItem()
                pendingCalibrationPosition = position
                pendingCalibrationDelayTicks = 6
                resetCalibrationStability()
                return
            }
            guard rightEdgeError >= -runtimeDiscreteTolerance,
                  rightEdgeError <= runtimeDiscreteTolerance else {
                failLayout("no-clickable-slot")
                return
            }
            positionCalibrator = nil
            pendingCalibrationPosition = nil
            applyPreferredPosition(position)
            guard let item = statusItem else { return }
            beginLengthSettlement(
                item: item,
                spacerFrame: spacerFrame,
                islandFrame: islandFrame
            )
        case .failed:
            failLayout("no-exact-slot")
        }
    }

    private func beginLengthSettlement(
        item: NSStatusItem,
        spacerFrame: CGRect,
        islandFrame: CGRect
    ) {
        let settler = SpacerLengthSettler(
            initialLength: item.length,
            initialFrame: spacerFrame,
            islandFrame: islandFrame,
            maximumUnderfill: runtimeDiscreteTolerance,
            maximumOverflow: runtimeDiscreteTolerance
        )
        lengthSettler = settler
        settlementWaitTicks = 0
        item.length = settler.requestedLength
    }

    private func calibrationFrameIsStable(_ frame: CGRect) -> Bool {
        if let previous = calibrationFrame,
           abs(previous.minX - frame.minX) <= 0.5,
           abs(previous.width - frame.width) <= 0.5 {
            calibrationStableSamples += 1
        } else {
            calibrationFrame = frame
            calibrationStableSamples = 1
        }
        return calibrationStableSamples >= 4
    }

    private func resetCalibrationStability() {
        calibrationFrame = nil
        calibrationStableSamples = 0
    }

    private func savedPreferredPosition(fallback: Int) -> Int {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: validatedCacheKey) else { return fallback }
        return (defaults.object(forKey: configuration.savedPositionKey) as? NSNumber)?.intValue
            ?? fallback
    }

    private func savedLayout() -> (
        position: Int,
        length: CGFloat,
        anchorRight: CGFloat?,
        calibrationVersion: Int?
    )? {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: validatedCacheKey), let position = (
            defaults.object(forKey: configuration.savedPositionKey) as? NSNumber
        )?.intValue,
        let rawLength = (
            defaults.object(forKey: configuration.savedLengthKey) as? NSNumber
        )?.doubleValue,
        rawLength.isFinite,
        rawLength > 0 else {
            return nil
        }
        let rawAnchorRight = (defaults.object(forKey: configuration.savedAnchorRightKey) as? NSNumber)?.doubleValue
        let anchorRight = rawAnchorRight.flatMap { value in
            value.isFinite ? CGFloat(value) : nil
        }
        let calibrationVersion = (
            defaults.object(forKey: configuration.savedCalibrationVersionKey) as? NSNumber
        )?.intValue
        return (position, CGFloat(rawLength), anchorRight, calibrationVersion)
    }

    private func saveSettledLayout(length: CGFloat, anchorRight: CGFloat) {
        guard length.isFinite, length > 0, anchorRight.isFinite else { return }
        let defaults = UserDefaults.standard
        guard let currentPreferredPosition else { return }
        defaults.set(currentPreferredPosition, forKey: configuration.savedPositionKey)
        defaults.set(true, forKey: validatedCacheKey)
        defaults.set(Double(length), forKey: configuration.savedLengthKey)
        defaults.set(Double(anchorRight), forKey: configuration.savedAnchorRightKey)
        defaults.set(
            runtimeCalibrationVersion,
            forKey: configuration.savedCalibrationVersionKey
        )
        defaults.synchronize()
    }

    private func applyPreferredPosition(_ position: Int) {
        let defaults = UserDefaults.standard
        defaults.set(
            position,
            forKey: "NSStatusItem Preferred Position \(runtimeAutosaveName)"
        )
        defaults.synchronize()
        currentPreferredPosition = position
    }

    private func destroyStatusItem() {
        guard let item = statusItem else { return }
        item.menu = nil
        NSStatusBar.system.removeStatusItem(item)
        statusItem = nil
    }

    private func failLayout(_ reason: String) {
        removeSpacer()
        attemptGate.fail()
        blockedUntil = ProcessInfo.processInfo.systemUptime + 2
        failureReason = reason
        UserDefaults.standard.removeObject(forKey: validatedCacheKey)
    }

    private func removeSpacer() {
        attemptGate.complete()
        destroyStatusItem()
        positionCalibrator = nil
        pendingCalibrationPosition = nil
        pendingCalibrationDelayTicks = 0
        resetCalibrationStability()
        lengthSettler = nil
        settlementWaitTicks = 0
        restoringSavedLayout = false
        restorationWaitTicks = 0
        currentPreferredPosition = nil
        calibratedIslandRight = nil
        calibratedAnchorRight = nil
    }

    private func menuBarWindows() -> [MenuBarWindow] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        let rawWindows = CGWindowListCopyWindowInfo(options, kCGNullWindowID)
            as? [[String: Any]] ?? []

        return rawWindows.compactMap { info in
            guard let bounds = info[kCGWindowBounds as String] as? [String: Any],
                  let frame = CGRect(dictionaryRepresentation: bounds as CFDictionary) else {
                return nil
            }
            return MenuBarWindow(
                name: info[kCGWindowName as String] as? String ?? "",
                windowID: info[kCGWindowNumber as String] as? CGWindowID ?? 0,
                ownerPID: info[kCGWindowOwnerPID as String] as? pid_t ?? 0,
                layer: info[kCGWindowLayer as String] as? Int ?? -1,
                frame: frame
            )
        }
    }

    private func writeDiagnostics(
        islandFrame: CGRect,
        spacerFrame: CGRect?,
        itemFrames: [CGRect],
        hasCollision: Bool?
    ) {
        let directIntersections = itemFrames.filter { $0.intersects(islandFrame) }.count
        let unclickableCenters = itemFrames.filter { frame in
            islandFrame.contains(CGPoint(x: frame.midX, y: islandFrame.midY))
        }.count
        let relocatedFrames = spacerFrame.map {
            SpacerPolicy.rightSideFrames(
                itemFrames: itemFrames,
                spacerFrame: $0,
                count: 2
            )
        } ?? []
        let unprotectedIntersections = itemFrames.filter { frame in
            frame.intersects(islandFrame) && !relocatedFrames.contains { relocated in
                abs(relocated.minX - frame.minX) <= 1
                    && abs(relocated.width - frame.width) <= 1
            }
        }.count
        let collisionText = hasCollision.map { String($0) } ?? "pending"
        let diagnostics = """
        blocked=\(attemptGate.blocked)
        failureReason=\(failureReason)
        targetSource=compact-profile-354
        present=\(statusItem != nil)
        active=\(statusItem != nil && spacerFrame != nil && positionCalibrator == nil && lengthSettler == nil && !restoringSavedLayout)
        calibrating=\(positionCalibrator != nil)
        settling=\(lengthSettler != nil)
        restoring=\(restoringSavedLayout)
        preferred=\(currentPreferredPosition ?? -1)
        collision=\(collisionText)
        island=\(NSStringFromRect(islandFrame))
        spacer=\(NSStringFromRect(spacerFrame ?? .zero))
        items=\(itemFrames.count)
        directIntersections=\(directIntersections)
        unclickableCenters=\(unclickableCenters)
        relocatedItems=\(relocatedFrames.count)
        unprotectedIntersections=\(unprotectedIntersections)
        clickThrough=\(clickThroughController.diagnosticState)
        """
        try? diagnostics.write(
            toFile: "/tmp/VibeIslandMenuSpacer-diagnostics.txt",
            atomically: true,
            encoding: .utf8
        )
    }

    @objc private func quitAndRestore() {
        observationTimer?.invalidate()
        clickThroughController.stop()
        removeSpacer()
        NSApplication.shared.terminate(nil)
    }
}

/// Vibe Island's visible compact bar is 354pt wide, but its transparent host
/// window is much wider and can win hit-testing over menu extras that the
/// spacer has correctly moved beside the compact bar.  The helper already has
/// Accessibility access.  For a click that is demonstrably on a native menu
/// extra outside the visible compact bar, move only that transparent host out
/// of hit-testing for the duration of the click, then restore it immediately.
/// Clicks on the compact bar and clicks not backed by a real menu-extra window
/// are never altered.
private final class MenuBarClickThroughController: @unchecked Sendable {
    private struct Snapshot {
        var menuBarFrame = CGRect.zero
        var islandFrame = CGRect.zero
        var itemWindows: [MenuBarWindow] = []
    }

    private struct MovedWindow {
        let element: AXUIElement
        let originalPosition: CGPoint
    }

    private var snapshot = Snapshot()
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var movedWindows: [MovedWindow] = []
    private var restoreGeneration = 0
    private(set) var diagnosticState = "stopped"

    func start() {
        guard eventTap == nil else { return }
        let mask = (CGEventMask(1) << CGEventType.leftMouseDown.rawValue)
            | (CGEventMask(1) << CGEventType.leftMouseUp.rawValue)
        let opaqueSelf = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: menuBarClickThroughCallback,
            userInfo: opaqueSelf
        ) else {
            diagnosticState = "unavailable"
            return
        }
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        eventTap = tap
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        diagnosticState = "ready"
    }

    func stop() {
        restoreMovedWindows()
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        if let eventTap { CFMachPortInvalidate(eventTap) }
        runLoopSource = nil
        eventTap = nil
        diagnosticState = "stopped"
    }

    func update(
        menuBarFrame: CGRect,
        islandFrame: CGRect,
        itemWindows: [MenuBarWindow]
    ) {
        snapshot = Snapshot(
            menuBarFrame: menuBarFrame,
            islandFrame: islandFrame,
            itemWindows: itemWindows
        )
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: true) }
            diagnosticState = "ready"
            return Unmanaged.passUnretained(event)
        case .leftMouseDown:
            prepareClickThrough(at: event.location)
            return Unmanaged.passUnretained(event)
        case .leftMouseUp:
            scheduleRestore(after: 0.12)
            return Unmanaged.passUnretained(event)
        default:
            return Unmanaged.passUnretained(event)
        }
    }

    private func prepareClickThrough(at point: CGPoint) {
        restoreMovedWindows()
        let current = snapshot
        guard current.menuBarFrame.contains(point),
              !current.islandFrame.contains(point),
              current.itemWindows.contains(where: { $0.frame.contains(point) }) else {
            return
        }

        let hosts = vibeHostWindows(containing: point, islandFrame: current.islandFrame)
        guard !hosts.isEmpty else { return }
        for host in hosts {
            guard let moved = moveHostWindow(host) else { continue }
            movedWindows.append(moved)
        }
        guard !movedWindows.isEmpty else {
            diagnosticState = "ax-move-failed"
            return
        }
        diagnosticState = "forwarding"
        // Mouse-up can be lost if an app opens a menu or starts tracking.
        // This watchdog makes the temporary move self-healing in every case.
        scheduleRestore(after: 0.8)
    }

    private func vibeHostWindows(
        containing point: CGPoint,
        islandFrame: CGRect
    ) -> [(pid: pid_t, frame: CGRect)] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID)
            as? [[String: Any]] ?? []
        return windows.compactMap { info in
            guard let owner = info[kCGWindowOwnerName as String] as? String,
                  owner == "Vibe Island",
                  let pid = info[kCGWindowOwnerPID as String] as? pid_t,
                  let bounds = info[kCGWindowBounds as String] as? [String: Any],
                  let frame = CGRect(dictionaryRepresentation: bounds as CFDictionary),
                  frame.contains(point),
                  frame.width > islandFrame.width + 20,
                  frame.height > max(50, islandFrame.height + 20) else {
                return nil
            }
            return (pid, frame)
        }
    }

    private func moveHostWindow(_ host: (pid: pid_t, frame: CGRect)) -> MovedWindow? {
        let application = AXUIElementCreateApplication(host.pid)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            application,
            kAXWindowsAttribute as CFString,
            &value
        ) == .success,
        let windows = value as? [AXUIElement] else {
            return nil
        }

        for window in windows {
            guard let position = axPoint(window, attribute: kAXPositionAttribute),
                  let size = axSize(window),
                  abs(position.x - host.frame.minX) <= 2,
                  abs(position.y - host.frame.minY) <= 2,
                  abs(size.width - host.frame.width) <= 2,
                  abs(size.height - host.frame.height) <= 2 else {
                continue
            }
            var offscreen = CGPoint(x: -host.frame.width - 200, y: position.y)
            guard let positionValue = AXValueCreate(.cgPoint, &offscreen),
                  AXUIElementSetAttributeValue(
                      window,
                      kAXPositionAttribute as CFString,
                      positionValue
                  ) == .success else {
                return nil
            }
            return MovedWindow(element: window, originalPosition: position)
        }
        return nil
    }

    private func axPoint(_ element: AXUIElement, attribute: String) -> CGPoint? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            attribute as CFString,
            &value
        ) == .success,
        let raw = value,
        CFGetTypeID(raw) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero
        guard AXValueGetValue(raw as! AXValue, .cgPoint, &point) else { return nil }
        return point
    }

    private func axSize(_ element: AXUIElement) -> CGSize? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            kAXSizeAttribute as CFString,
            &value
        ) == .success,
        let raw = value,
        CFGetTypeID(raw) == AXValueGetTypeID() else { return nil }
        var size = CGSize.zero
        guard AXValueGetValue(raw as! AXValue, .cgSize, &size) else { return nil }
        return size
    }

    private func scheduleRestore(after delay: TimeInterval) {
        restoreGeneration += 1
        let generation = restoreGeneration
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, self.restoreGeneration == generation else { return }
            self.restoreMovedWindows()
        }
    }

    private func restoreMovedWindows() {
        guard !movedWindows.isEmpty else { return }
        let pending = movedWindows
        movedWindows.removeAll()
        for moved in pending {
            var position = moved.originalPosition
            if let value = AXValueCreate(.cgPoint, &position) {
                AXUIElementSetAttributeValue(
                    moved.element,
                    kAXPositionAttribute as CFString,
                    value
                )
            }
        }
        diagnosticState = eventTap == nil ? "stopped" : "ready"
    }
}

private func menuBarClickThroughCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let controller = Unmanaged<MenuBarClickThroughController>
        .fromOpaque(userInfo)
        .takeUnretainedValue()
    return controller.handle(type: type, event: event)
}

private struct MenuBarWindow {
    let name: String
    let windowID: CGWindowID
    let ownerPID: pid_t
    let layer: Int
    let frame: CGRect
}

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.run()
