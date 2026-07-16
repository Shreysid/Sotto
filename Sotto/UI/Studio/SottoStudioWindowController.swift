import AppKit
import SwiftUI

@MainActor
final class SottoStudioWindowController: NSWindowController {
    init(state: SottoAppState) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1_040, height: 690),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Sotto Studio"
        window.toolbarStyle = .unified
        window.minSize = NSSize(width: 900, height: 580)
        window.miniwindowImage = NSApplication.shared.applicationIconImage
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(
            rootView: SottoStudioView().environmentObject(state)
        )
        super.init(window: window)
    }

    required init?(coder: NSCoder) { nil }

    func showAndActivate() {
        if window?.isVisible == false {
            window?.center()
        }
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}
