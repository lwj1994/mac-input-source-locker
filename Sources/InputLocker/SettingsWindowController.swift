import AppKit
import SwiftUI

final class SettingsWindowController {
    private var window: NSWindow?

    init() {}

    func show() {
        if window == nil {
            let view = SettingsView()
            let hostingController = NSHostingController(rootView: view)
            let window = NSWindow(contentViewController: hostingController)
            window.title = L10n.settingsTitle
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.setContentSize(NSSize(width: 560, height: 560))
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }

        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
