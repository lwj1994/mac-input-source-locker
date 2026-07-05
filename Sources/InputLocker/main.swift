import AppKit
import AppleViewModel
import MacInputSourceLockerCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: StatusMenuController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        InputLockerLog.app.info("application did finish launching")
        ViewModel.initialize(config: ViewModelConfig(onError: { error, type in
            InputLockerLog.app.error("view model error type=\(String(describing: type), privacy: .public) error=\(String(describing: error), privacy: .public)")
        }))
        NSApp.setActivationPolicy(.accessory)
        controller = StatusMenuController()
    }

    func applicationWillTerminate(_ notification: Notification) {
        InputLockerLog.app.info("application will terminate")
        controller?.stop()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
