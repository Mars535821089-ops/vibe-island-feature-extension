import AppKit
import SpacerCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var observationTimer: Timer?
    private let configuration = SpacerConfiguration()
    private let setupMode = CommandLine.arguments.contains("--setup")

    func applicationDidFinishLaunching(_ notification: Notification) {
        let application = NSApplication.shared
        application.setActivationPolicy(.accessory)
        if setupMode {
            createStatusItem()
        } else {
            refreshLayout()
        }
        observationTimer = Timer.scheduledTimer(
            timeInterval: 0.5,
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
                && window.frame.minY <= 1
                && window.frame.height >= 20
                && window.frame.height <= 50
                && window.frame.width >= screen.frame.width
        })?.frame
            ?? CGRect(x: screen.frame.minX, y: 0, width: screen.frame.width, height: 30)
        let islandFrame = CGRect(
            x: screen.frame.midX - SpacerConfiguration.compactIslandWidth / 2,
            y: menuBarFrame.minY,
            width: SpacerConfiguration.compactIslandWidth,
            height: menuBarFrame.height
        )
        let spacerFrame = statusItem?.button?.window.map { window in
            CGRect(
                x: window.frame.minX,
                y: menuBarFrame.minY,
                width: window.frame.width,
                height: menuBarFrame.height
            )
        }
        let hostedItemFrames = windows
            .filter { window in
                window.layer == 25
                    && abs(window.frame.minY - menuBarFrame.minY) <= 1
                    && abs(window.frame.height - menuBarFrame.height) <= 1
                    && window.frame.maxX > screen.frame.minX
                    && window.frame.minX < screen.frame.maxX
            }
            .map(\.frame)
        let itemFrames = SpacerPolicy.excludingSpacer(
            from: hostedItemFrames,
            spacerFrame: spacerFrame
        )

        if let item = statusItem, item.isVisible {
            guard let spacerFrame else { return }

            let desiredLength = SpacerPolicy.alignedLength(
                currentLength: item.length,
                spacerFrame: spacerFrame,
                islandFrame: islandFrame
            )
            if abs(item.length - desiredLength) > 0.5 {
                item.length = desiredLength
            }

            let hasCollision = SpacerPolicy.shouldShowSpacer(
                itemFrames: itemFrames,
                spacerFrame: spacerFrame,
                islandFrame: islandFrame
            )
            if SpacerPolicy.visibilityAction(
                isVisible: true,
                hasCollision: hasCollision
            ) == .hide {
                item.isVisible = false
            }
        } else {
            let hasCollision = SpacerPolicy.shouldShowSpacer(
                itemFrames: itemFrames,
                spacerFrame: nil,
                islandFrame: islandFrame
            )
            if SpacerPolicy.visibilityAction(
                isVisible: false,
                hasCollision: hasCollision
            ) == .show {
                if let item = statusItem {
                    item.isVisible = true
                } else {
                    createStatusItem()
                }
            }
        }

        writeDiagnostics(
            islandFrame: islandFrame,
            spacerFrame: spacerFrame,
            itemFrames: itemFrames
        )
    }

    private func createStatusItem() {
        guard statusItem == nil else { return }

        let item = NSStatusBar.system.statusItem(withLength: configuration.width)
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
                layer: info[kCGWindowLayer as String] as? Int ?? -1,
                frame: frame
            )
        }
    }

    private func writeDiagnostics(
        islandFrame: CGRect,
        spacerFrame: CGRect?,
        itemFrames: [CGRect]
    ) {
        let diagnostics = """
        active=\(statusItem?.isVisible == true)
        island=\(NSStringFromRect(islandFrame))
        spacer=\(NSStringFromRect(spacerFrame ?? .zero))
        items=\(itemFrames.count)
        """
        try? diagnostics.write(
            toFile: "/tmp/VibeIslandMenuSpacer-diagnostics.txt",
            atomically: true,
            encoding: .utf8
        )
    }

    @objc private func quitAndRestore() {
        observationTimer?.invalidate()
        NSApplication.shared.terminate(nil)
    }
}

private struct MenuBarWindow {
    let layer: Int
    let frame: CGRect
}

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.run()
