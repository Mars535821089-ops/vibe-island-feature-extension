import AppKit
import SpacerCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var recenterTimer: Timer?
    private let configuration = SpacerConfiguration()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let application = NSApplication.shared
        application.setActivationPolicy(.accessory)
        let setupMode = CommandLine.arguments.contains("--setup")
            || ProcessInfo.processInfo.environment["VIBE_ISLAND_SPACER_SETUP"] == "1"

        let item = NSStatusBar.system.statusItem(withLength: configuration.width)
        item.autosaveName = configuration.autosaveName
        item.isVisible = true

        // Keep the slot visually quiet: Vibe Island's own window sits above it.
        // A tooltip and menu make the otherwise blank item discoverable and reversible.
        if let button = item.button {
            if setupMode {
                button.attributedTitle = NSAttributedString(
                    string: "  ⟵ VIBE ISLAND SLOT ⟶  ",
                    attributes: [
                        .foregroundColor: NSColor.systemYellow,
                        .font: NSFont.boldSystemFont(ofSize: 12)
                    ]
                )
            } else {
                button.title = ""
            }
            button.image = nil
            button.imagePosition = .noImage
            button.toolTip = "Vibe Island 占位（按住 ⌘ 拖动到黑色小窗口正下方）"
            button.setAccessibilityLabel("Vibe Island 菜单栏占位")
            button.setAccessibilityHelp("按住 Command 将此占位拖到黑色小窗口正下方；退出后菜单栏立即恢复")

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                let windowFrame = button.window?.frame ?? .zero
                let diagnostics = """
                width=\(item.length)
                window=\(NSStringFromRect(windowFrame))
                button=\(NSStringFromRect(button.frame))
                title=\(button.attributedTitle.string)
                """
                try? diagnostics.write(
                    toFile: "/tmp/VibeIslandMenuSpacer-diagnostics.txt",
                    atomically: true,
                    encoding: .utf8
                )
                NSLog(
                    "VibeIslandMenuSpacer width=%.1f window=%@ button=%@",
                    item.length,
                    NSStringFromRect(windowFrame),
                    NSStringFromRect(button.frame)
                )
            }
        }

        let menu = NSMenu()
        menu.addItem(withTitle: "Vibe Island 占位", action: nil, keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(
            withTitle: "退出并恢复菜单栏",
            action: #selector(quitAndRestore),
            keyEquivalent: "q"
        ).target = self
        item.menu = menu
        statusItem = item

        recenterStatusItem()
        recenterTimer = Timer.scheduledTimer(
            timeInterval: 0.5,
            target: self,
            selector: #selector(recenterStatusItem),
            userInfo: nil,
            repeats: true
        )
    }

    @objc private func recenterStatusItem() {
        guard let item = statusItem,
              let button = item.button,
              let window = button.window,
              let screen = window.screen ?? NSScreen.screens.first else { return }

        let buttonRightEdge = window.frame.minX + button.frame.maxX
        let desiredWidth = SpacerGeometry.adaptiveWidth(
            anchoredRightEdge: buttonRightEdge,
            targetCenter: screen.frame.midX,
            minimumWidth: SpacerConfiguration.compactIslandWidth,
            maximumWidth: SpacerConfiguration.compactIslandWidth + 64
        )

        if abs(item.length - desiredWidth) > 0.5 {
            item.length = desiredWidth
        }
    }

    @objc private func quitAndRestore() {
        recenterTimer?.invalidate()
        NSApplication.shared.terminate(nil)
    }
}

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.run()
