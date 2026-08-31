import AppKit
import SpacerCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var observationTimer: Timer?
    private let configuration = SpacerConfiguration()
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
    private var latestItemWindows: [MenuBarWindow] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        let application = NSApplication.shared
        application.setActivationPolicy(.accessory)

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
        let spacerFrame = statusItem?.button?.window.flatMap { window in
            SpacerGeometry.normalizedStatusItemFrame(
                window.frame,
                in: menuBarFrame
            )
        }
        let hostedItemWindows = windows
            .filter { window in
                window.layer == 25
                    && SpacerGeometry.isHostedWindow(window.frame, in: menuBarFrame)
            }
        let itemWindows = hostedItemWindows.filter { window in
            guard let spacerFrame else { return true }
            return abs(window.frame.minX - spacerFrame.minX) > 1
                || abs(window.frame.minY - spacerFrame.minY) > 1
                || abs(window.frame.width - spacerFrame.width) > 1
                || abs(window.frame.height - spacerFrame.height) > 1
        }
        latestItemWindows = itemWindows
        let itemFrames = itemWindows.map(\.frame)

        if positionCalibrator != nil {
            if statusItem == nil, let position = pendingCalibrationPosition {
                if pendingCalibrationDelayTicks > 0 {
                    pendingCalibrationDelayTicks -= 1
                } else {
                    pendingCalibrationPosition = nil
                    resetCalibrationStability()
                    createStatusItem(length: 0, preferredPosition: position)
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

                if hasLargeOverflow && !savedAnchorMatches {
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
                saveSettledLayout(length: item.length, anchorRight: anchorRight)
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

            let anchorMoved = calibratedAnchorRight.map {
                abs($0 - spacerFrame.maxX) > 0.5
            } ?? true
            let maximumOverflow = anchorMoved
                ? SpacerConfiguration.maximumAnchorOverflow
                : CGFloat.greatestFiniteMagnitude

            switch SpacerPolicy.alignmentAction(
                currentLength: item.length,
                spacerFrame: spacerFrame,
                islandFrame: islandFrame,
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

        applyPreferredPosition(preferredPosition, saveAsCalibrated: false)
        let item = NSStatusBar.system.statusItem(withLength: length)
        item.autosaveName = configuration.autosaveName
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
            maximumUnderfill: SpacerConfiguration.maximumAnchorUnderfill
        )
        pendingCalibrationPosition = initialPosition
        // Let Control Center fully collapse the previous wide item before
        // measuring a zero-width candidate. Sampling the transient layout makes
        // preferred-position anchors drift across restarts.
        pendingCalibrationDelayTicks = 20
    }

    private func beginSavedRestoreOrCalibration(islandFrame: CGRect) {
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
            == SpacerConfiguration.calibrationVersion
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
        if rightEdgeError >= -SpacerConfiguration.maximumAnchorUnderfill,
           rightEdgeError <= SpacerConfiguration.maximumAnchorOverflow {
            positionCalibrator = nil
            pendingCalibrationPosition = nil
            applyPreferredPosition(calibrator.candidate, saveAsCalibrated: true)
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
            positionCalibrator = nil
            pendingCalibrationPosition = nil
            applyPreferredPosition(position, saveAsCalibrated: true)
            guard let item = statusItem else { return }
            beginLengthSettlement(
                item: item,
                spacerFrame: spacerFrame,
                islandFrame: islandFrame
            )
        case .failed:
            positionCalibrator = nil
            pendingCalibrationPosition = nil
            removeSpacer()
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
            islandFrame: islandFrame
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
        guard let position = (
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
        defaults.set(Double(length), forKey: configuration.savedLengthKey)
        defaults.set(Double(anchorRight), forKey: configuration.savedAnchorRightKey)
        defaults.set(
            SpacerConfiguration.calibrationVersion,
            forKey: configuration.savedCalibrationVersionKey
        )
        defaults.synchronize()
    }

    private func applyPreferredPosition(_ position: Int, saveAsCalibrated: Bool) {
        let defaults = UserDefaults.standard
        defaults.set(position, forKey: configuration.preferredPositionKey)
        if saveAsCalibrated {
            defaults.set(position, forKey: configuration.savedPositionKey)
        }
        defaults.synchronize()
        currentPreferredPosition = position
    }

    private func destroyStatusItem() {
        guard let item = statusItem else { return }
        item.menu = nil
        NSStatusBar.system.removeStatusItem(item)
        statusItem = nil
    }

    private func removeSpacer() {
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
        present=\(statusItem != nil)
        active=\((statusItem?.length ?? 0) > 0.5)
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
        """
        try? diagnostics.write(
            toFile: "/tmp/VibeIslandMenuSpacer-diagnostics.txt",
            atomically: true,
            encoding: .utf8
        )
    }

    @objc private func quitAndRestore() {
        observationTimer?.invalidate()
        removeSpacer()
        NSApplication.shared.terminate(nil)
    }
}

private struct MenuBarWindow {
    let windowID: CGWindowID
    let ownerPID: pid_t
    let layer: Int
    let frame: CGRect
}

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.run()
