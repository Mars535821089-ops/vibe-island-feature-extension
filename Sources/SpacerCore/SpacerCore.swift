import CoreGraphics
import Foundation

public struct SpacerConfiguration: Sendable, Equatable {
    public static let defaultWidth: CGFloat = 354
    public static let environmentKey = "VIBE_ISLAND_SPACER_WIDTH"
    public static let defaultAutosaveName = "VibeIslandMenuSpacer.ReservedSlot"

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
    public static func preferredPositionFromRight(
        screenWidth: CGFloat,
        buttonWidth: CGFloat,
        statusItemChromeWidth: CGFloat
    ) -> CGFloat {
        max(
            0,
            screenWidth / 2 - buttonWidth / 2 - statusItemChromeWidth
        )
    }

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
