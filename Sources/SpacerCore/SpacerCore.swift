import CoreGraphics
import Foundation

public struct SpacerConfiguration: Sendable, Equatable {
    public static let compactIslandWidth: CGFloat = 354
    public static let defaultWidth: CGFloat = compactIslandWidth
    public static let environmentKey = "VIBE_ISLAND_SPACER_WIDTH"
    public static let defaultAutosaveName = "VibeIslandMenuSpacer.CenteredSlot.v5"

    public let width: CGFloat
    public let autosaveName: String

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
}

public enum SpacerPolicy {
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

    public static func alignedLength(
        currentLength: CGFloat,
        spacerFrame: CGRect,
        islandFrame: CGRect
    ) -> CGFloat {
        max(0, currentLength + spacerFrame.minX - islandFrame.minX)
    }
}
