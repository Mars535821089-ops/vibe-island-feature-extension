import CoreGraphics
import Foundation

public struct SpacerConfiguration: Sendable, Equatable {
    public static let compactIslandWidth: CGFloat = 354
    public static let maximumAnchorUnderfill: CGFloat = 4
    public static let maximumAnchorOverflow: CGFloat = 8
    public static let calibrationVersion = 6
    public static let defaultWidth: CGFloat = compactIslandWidth
    public static let environmentKey = "VIBE_ISLAND_SPACER_WIDTH"
    public static let defaultAutosaveName = "VibeIslandMenuSpacer.ConditionalSlot.v8"

    public let width: CGFloat
    public let autosaveName: String
    public let preferredPositionKey: String
    public let savedPositionKey: String
    public let savedLengthKey: String
    public let savedAnchorRightKey: String
    public let savedCalibrationVersionKey: String

    public init(environment: [String: String] = ProcessInfo.processInfo.environment) {
        if let raw = environment[Self.environmentKey],
           let value = Double(raw.trimmingCharacters(in: .whitespacesAndNewlines)),
           value.isFinite,
           value > 0 {
            width = CGFloat(value)
        } else {
            width = Self.defaultWidth
        }
        autosaveName = Self.defaultAutosaveName
        preferredPositionKey = "NSStatusItem Preferred Position \(autosaveName)"
        savedPositionKey = "VibeIslandMenuSpacer Saved Preferred Position"
        savedLengthKey = "VibeIslandMenuSpacer Saved Length"
        savedAnchorRightKey = "VibeIslandMenuSpacer Saved Anchor Right"
        savedCalibrationVersionKey = "VibeIslandMenuSpacer Saved Calibration Version"
    }
}

public enum SpacerGeometry {
    public static func centeredSlot(
        in screenFrame: CGRect,
        width requestedWidth: CGFloat,
        menuBarHeight: CGFloat
    ) -> CGRect {
        let width = min(max(0, requestedWidth), screenFrame.width)
        let height = min(max(0, menuBarHeight), screenFrame.height)
        return CGRect(
            x: screenFrame.midX - width / 2,
            y: screenFrame.maxY - height,
            width: width,
            height: height
        )
    }

    public static func centeredSlot(
        inMenuBar menuBarFrame: CGRect,
        width requestedWidth: CGFloat
    ) -> CGRect {
        let width = min(max(0, requestedWidth), menuBarFrame.width)
        return CGRect(
            x: menuBarFrame.midX - width / 2,
            y: menuBarFrame.minY,
            width: width,
            height: menuBarFrame.height
        )
    }

    public static func isHostedWindow(
        _ windowFrame: CGRect,
        in menuBarFrame: CGRect,
        tolerance: CGFloat = 1
    ) -> Bool {
        abs(windowFrame.minY - menuBarFrame.minY) <= tolerance
            && abs(windowFrame.height - menuBarFrame.height) <= tolerance
            && windowFrame.maxX > menuBarFrame.minX
            && windowFrame.minX < menuBarFrame.maxX
    }

    public static func normalizedStatusItemFrame(
        _ appKitWindowFrame: CGRect,
        in menuBarFrame: CGRect,
        tolerance: CGFloat = 1
    ) -> CGRect? {
        guard appKitWindowFrame.width > 0,
              appKitWindowFrame.height > 0,
              abs(appKitWindowFrame.height - menuBarFrame.height) <= tolerance else {
            return nil
        }

        let normalizedFrame = CGRect(
            x: appKitWindowFrame.minX,
            y: menuBarFrame.minY,
            width: appKitWindowFrame.width,
            height: menuBarFrame.height
        )
        return isHostedWindow(normalizedFrame, in: menuBarFrame, tolerance: tolerance)
            ? normalizedFrame
            : nil
    }
}

public enum SpacerPolicy {
    public static func rightSideFrames(
        itemFrames: [CGRect],
        spacerFrame: CGRect,
        count: Int,
        adjacencyTolerance: CGFloat = 2
    ) -> [CGRect] {
        guard count > 0 else { return [] }
        let sorted = itemFrames
            .filter { $0.maxX <= spacerFrame.minX + adjacencyTolerance }
            .sorted { $0.minX < $1.minX }
        guard let last = sorted.last,
              abs(last.maxX - spacerFrame.minX) <= adjacencyTolerance else {
            return []
        }

        var selected = [last]
        var expectedRightEdge = last.minX
        for frame in sorted.dropLast().reversed() where selected.count < count {
            guard abs(frame.maxX - expectedRightEdge) <= adjacencyTolerance else {
                return []
            }
            selected.append(frame)
            expectedRightEdge = frame.minX
        }
        guard selected.count == count else { return [] }
        return selected.reversed()
    }

    public static func presenceAction(
        isPresent: Bool,
        hasCollision: Bool
    ) -> SpacerPresenceAction {
        if isPresent && !hasCollision { return .remove }
        if !isPresent && hasCollision { return .create }
        return .none
    }

    public static func excludingSpacer(
        from itemFrames: [CGRect],
        spacerFrame: CGRect?
    ) -> [CGRect] {
        guard let spacerFrame else { return itemFrames }

        return itemFrames.filter { frame in
            abs(frame.minX - spacerFrame.minX) > 1
                || abs(frame.minY - spacerFrame.minY) > 1
                || abs(frame.width - spacerFrame.width) > 1
                || abs(frame.height - spacerFrame.height) > 1
        }
    }

    public static func shouldShowSpacer(
        itemFrames: [CGRect],
        spacerFrame: CGRect?,
        islandFrame: CGRect
    ) -> Bool {
        let framesWithoutSpacer: [CGRect]
        if let spacerFrame {
            framesWithoutSpacer = itemFrames.map { frame in
                guard frame.maxX <= spacerFrame.minX + 1 else { return frame }
                return frame.offsetBy(dx: spacerFrame.width, dy: 0)
            }
        } else {
            framesWithoutSpacer = itemFrames
        }

        return framesWithoutSpacer.contains { $0.intersects(islandFrame) }
    }

    public static func alignmentAction(
        currentLength: CGFloat,
        spacerFrame: CGRect,
        islandFrame: CGRect,
        leadingReservedWidth: CGFloat = 0,
        tolerance: CGFloat = 0.5,
        maximumUnderfill: CGFloat = SpacerConfiguration.maximumAnchorUnderfill,
        maximumOverflow: CGFloat = SpacerConfiguration.maximumAnchorOverflow
    ) -> SpacerAlignmentAction {
        guard spacerFrame.maxX <= islandFrame.maxX + max(0, maximumOverflow) else {
            return .reposition
        }

        guard spacerFrame.maxX >= islandFrame.maxX - max(0, maximumUnderfill) else {
            return .reposition
        }

        let effectiveLeftEdge = spacerFrame.minX - max(0, leadingReservedWidth)
        return .setLength(max(0, currentLength + effectiveLeftEdge - islandFrame.minX))
    }
}

public enum SpacerPresenceAction: Sendable, Equatable {
    case create
    case remove
    case none
}

public enum SpacerAlignmentAction: Sendable, Equatable {
    case reposition
    case setLength(CGFloat)
}

public enum SpacerLengthSettlementAction: Sendable, Equatable {
    case wait
    case setLength(CGFloat)
    case ready(anchorRight: CGFloat)
    case recalibrate
    case failed
}

public struct SpacerLengthSettler: Sendable, Equatable {
    public private(set) var requestedLength: CGFloat

    private let windowWidthOverhead: CGFloat
    private let tolerance: CGFloat
    private let maximumUnderfill: CGFloat
    private let maximumCorrections: Int
    private let leadingReservedWidth: CGFloat
    private var correctionCount = 0

    public init(
        initialLength: CGFloat,
        initialFrame: CGRect,
        islandFrame: CGRect,
        leadingReservedWidth: CGFloat = 0,
        tolerance: CGFloat = 0.5,
        maximumUnderfill: CGFloat = SpacerConfiguration.maximumAnchorUnderfill,
        maximumCorrections: Int = 3
    ) {
        windowWidthOverhead = max(0, initialFrame.width - initialLength)
        self.tolerance = tolerance
        self.maximumUnderfill = max(0, maximumUnderfill)
        self.maximumCorrections = max(0, maximumCorrections)
        self.leadingReservedWidth = max(0, leadingReservedWidth)
        requestedLength = max(
            0,
            initialLength + initialFrame.minX - self.leadingReservedWidth - islandFrame.minX
        )
    }

    public mutating func observe(
        currentLength: CGFloat,
        spacerFrame: CGRect,
        islandFrame: CGRect
    ) -> SpacerLengthSettlementAction {
        let expectedWindowWidth = requestedLength + windowWidthOverhead
        guard abs(currentLength - requestedLength) <= tolerance,
              abs(spacerFrame.width - expectedWindowWidth) <= tolerance else {
            return .wait
        }

        guard spacerFrame.maxX >= islandFrame.maxX - maximumUnderfill else {
            return .recalibrate
        }

        let leftEdgeError = spacerFrame.minX - leadingReservedWidth - islandFrame.minX
        if abs(leftEdgeError) <= tolerance {
            return .ready(anchorRight: spacerFrame.maxX)
        }

        guard correctionCount < maximumCorrections else {
            return .failed
        }

        let correctedLength = max(0, currentLength + leftEdgeError)
        guard abs(correctedLength - currentLength) > tolerance else {
            return .failed
        }

        correctionCount += 1
        requestedLength = correctedLength
        return .setLength(correctedLength)
    }
}

public enum PreferredPositionCalibrationAction: Sendable, Equatable {
    case retry(position: Int)
    case ready(position: Int)
    case failed
}

public struct PreferredPositionCalibrator: Sendable, Equatable {
    public private(set) var candidate: Int

    private let minimumPosition: Int
    private let maximumPosition: Int
    private var searchStep: Int
    private let maximumUnderfill: CGFloat
    private var coveringPosition: Int?
    private var coveringError: CGFloat?
    private var underfillingPosition: Int?
    private var underfillingError: CGFloat?
    private var observationCount = 0

    public init(
        initialPosition: Int,
        step: Int = 32,
        range: ClosedRange<Int> = 0...10_000,
        maximumUnderfill: CGFloat = 0
    ) {
        minimumPosition = range.lowerBound
        maximumPosition = range.upperBound
        candidate = min(max(initialPosition, range.lowerBound), range.upperBound)
        searchStep = max(1, step)
        self.maximumUnderfill = max(0, maximumUnderfill)
    }

    public mutating func observe(coversTarget: Bool) -> PreferredPositionCalibrationAction {
        observe(coversTarget: coversTarget, rightEdgeError: nil)
    }

    public mutating func observe(
        rightEdgeError: CGFloat
    ) -> PreferredPositionCalibrationAction {
        observe(
            coversTarget: rightEdgeError >= 0,
            rightEdgeError: rightEdgeError
        )
    }

    private mutating func observe(
        coversTarget: Bool,
        rightEdgeError: CGFloat?
    ) -> PreferredPositionCalibrationAction {
        observationCount += 1
        // Window Server can temporarily report a non-monotonic slot map while
        // neighboring menu items are reflowing. Never leave the app calibrating
        // forever; the current candidate is the safest bounded fallback.
        if observationCount >= 18 {
            return .ready(position: candidate)
        }
        if coversTarget {
            if candidate >= (coveringPosition ?? minimumPosition) {
                coveringPosition = candidate
                coveringError = rightEdgeError
            }
        } else {
            if candidate <= (underfillingPosition ?? maximumPosition) {
                underfillingPosition = candidate
                underfillingError = rightEdgeError
            }
        }

        if let coveringPosition, let underfillingPosition {
            guard coveringPosition < underfillingPosition else {
                return .failed
            }
            if underfillingPosition - coveringPosition <= 1 {
                if let underfillingError,
                   underfillingError >= -maximumUnderfill,
                   abs(underfillingError) < abs(coveringError ?? .greatestFiniteMagnitude) {
                    return .ready(position: underfillingPosition)
                }
                if coversTarget && candidate == coveringPosition {
                    return .ready(position: coveringPosition)
                }
                candidate = coveringPosition
                return .retry(position: candidate)
            }

            candidate = coveringPosition + (underfillingPosition - coveringPosition) / 2
            return .retry(position: candidate)
        }

        if coversTarget {
            let next = min(maximumPosition, candidate + searchStep)
            guard next != candidate else {
                return .ready(position: candidate)
            }
            candidate = next
        } else {
            let next = max(minimumPosition, candidate - searchStep)
            guard next != candidate else {
                return .failed
            }
            candidate = next
        }
        searchStep = min(maximumPosition - minimumPosition, searchStep * 2)
        return .retry(position: candidate)
    }
}
