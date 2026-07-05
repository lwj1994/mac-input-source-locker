import AppKit
import ApplicationServices
import Foundation

final class FloatingInputFocusMonitor: NSObject {
    private static let launcherBundleIdentifiers: Set<String> = [
        "com.apple.Spotlight",
        "com.raycast.macos",
        "com.runningwithcrayons.Alfred",
        "at.obdev.LaunchBar",
    ]

    private static let watchedNotifications: [CFString] = [
        kAXWindowCreatedNotification as CFString,
        kAXFocusedUIElementChangedNotification as CFString,
        kAXMainWindowChangedNotification as CFString,
        kAXUIElementDestroyedNotification as CFString,
    ]

    private let systemWideElement = AXUIElementCreateSystemWide()
    private var observers: [pid_t: AXObserver] = [:]
    private var onChange: ((FrontmostApplicationContext?) -> Void)?
    private var currentBundleIdentifier: String?
    private var pendingSettledEvaluation = false
    private var isStarted = false

    override init() {
        super.init()
        AXUIElementSetMessagingTimeout(systemWideElement, 0.25)
    }

    deinit {
        stop()
    }

    func start(onChange: @escaping (FrontmostApplicationContext?) -> Void) {
        guard !isStarted else { return }
        isStarted = true
        self.onChange = onChange
        InputLockerLog.floating.info("floating monitor start axTrusted=\(AXIsProcessTrusted(), privacy: .public)")

        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(
            self,
            selector: #selector(runningApplicationsChanged(_:)),
            name: NSWorkspace.didLaunchApplicationNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(runningApplicationsChanged(_:)),
            name: NSWorkspace.didTerminateApplicationNotification,
            object: nil
        )

        attachRunningLaunchers()
        evaluate()
    }

    func stop() {
        guard isStarted else { return }
        isStarted = false
        InputLockerLog.floating.info("floating monitor stop observers=\(self.observers.count, privacy: .public)")
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        for pid in Array(observers.keys) {
            detach(pid: pid)
        }
        observers.removeAll()
        onChange = nil
        currentBundleIdentifier = nil
        pendingSettledEvaluation = false
    }

    func currentContext() -> FrontmostApplicationContext? {
        return detectedLauncher().bundleIdentifier.flatMap(makeContext)
    }

    @objc private func runningApplicationsChanged(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              Self.isLauncher(app.bundleIdentifier)
        else {
            return
        }

        if notification.name == NSWorkspace.didLaunchApplicationNotification {
            InputLockerLog.floating.info("launcher launched bundle=\(app.bundleIdentifier ?? "nil", privacy: .public) pid=\(app.processIdentifier, privacy: .public)")
            attach(app: app)
        } else {
            InputLockerLog.floating.info("launcher terminated bundle=\(app.bundleIdentifier ?? "nil", privacy: .public) pid=\(app.processIdentifier, privacy: .public)")
            detach(pid: app.processIdentifier)
            evaluate()
        }
    }

    private func attachRunningLaunchers() {
        guard AXIsProcessTrusted() else {
            InputLockerLog.floating.warning("skip launcher observers because accessibility is not trusted")
            return
        }

        var attachedCount = 0
        for app in NSWorkspace.shared.runningApplications where Self.isLauncher(app.bundleIdentifier) {
            attach(app: app)
            attachedCount += 1
        }
        InputLockerLog.floating.info("attached running launchers count=\(attachedCount, privacy: .public)")
    }

    private func attach(app: NSRunningApplication) {
        guard AXIsProcessTrusted() else {
            InputLockerLog.floating.warning("skip attach bundle=\(app.bundleIdentifier ?? "nil", privacy: .public) accessibility not trusted")
            return
        }

        guard observers[app.processIdentifier] == nil else {
            InputLockerLog.floating.debug("skip attach bundle=\(app.bundleIdentifier ?? "nil", privacy: .public) pid=\(app.processIdentifier, privacy: .public) already observed")
            return
        }

        var observer: AXObserver?
        let observerError = AXObserverCreate(app.processIdentifier, floatingInputFocusCallback, &observer)
        guard observerError == .success,
              let observer
        else {
            InputLockerLog.floating.warning("create AX observer failed bundle=\(app.bundleIdentifier ?? "nil", privacy: .public) pid=\(app.processIdentifier, privacy: .public) error=\(observerError.rawValue, privacy: .public)")
            return
        }

        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        let context = Unmanaged.passUnretained(self).toOpaque()
        var didAttachNotification = false
        for notification in Self.watchedNotifications {
            if AXObserverAddNotification(observer, appElement, notification, context) == .success {
                didAttachNotification = true
                InputLockerLog.floating.debug("watch AX notification bundle=\(app.bundleIdentifier ?? "nil", privacy: .public) notification=\(notification as String, privacy: .public)")
            }
        }

        guard didAttachNotification else {
            InputLockerLog.floating.warning("attach AX observer failed bundle=\(app.bundleIdentifier ?? "nil", privacy: .public) no notifications accepted")
            return
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
        observers[app.processIdentifier] = observer
        InputLockerLog.floating.info("attached launcher observer bundle=\(app.bundleIdentifier ?? "nil", privacy: .public) pid=\(app.processIdentifier, privacy: .public)")
    }

    private func detach(pid: pid_t) {
        guard let observer = observers.removeValue(forKey: pid) else { return }
        CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
        InputLockerLog.floating.info("detached launcher observer pid=\(pid, privacy: .public)")
    }

    fileprivate func evaluate() {
        let detection = detectedLauncher()
        InputLockerLog.floating.debug("evaluate floating bundle=\(detection.bundleIdentifier ?? "nil", privacy: .public) method=\(detection.method, privacy: .public)")
        report(bundleIdentifier: detection.bundleIdentifier)
    }

    fileprivate func evaluateWindowTransition() {
        evaluate()
        guard !pendingSettledEvaluation else { return }
        pendingSettledEvaluation = true

        let delays = [0.08, 0.22, 0.45]
        for delay in delays {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self, self.isStarted else { return }
                self.evaluate()
                if delay == delays.last {
                    self.pendingSettledEvaluation = false
                }
            }
        }
    }

    private func detectedLauncher() -> FloatingLauncherDetection {
        if let bundleIdentifier = focusedLauncherBundleIdentifier() {
            return FloatingLauncherDetection(bundleIdentifier: bundleIdentifier, method: "focused-ax")
        }

        if let bundleIdentifier = visibleLauncherBundleIdentifier() {
            return FloatingLauncherDetection(bundleIdentifier: bundleIdentifier, method: "visible-window")
        }

        return FloatingLauncherDetection(bundleIdentifier: nil, method: "none")
    }

    private func focusedLauncherBundleIdentifier() -> String? {
        guard AXIsProcessTrusted(),
              let bundleIdentifier = focusedBundleIdentifier(),
              Self.isLauncher(bundleIdentifier)
        else {
            return nil
        }

        return bundleIdentifier
    }

    private func visibleLauncherBundleIdentifier() -> String? {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        for window in windows {
            guard Self.isVisibleFloatingWindow(window),
                  let pid = window[kCGWindowOwnerPID as String] as? pid_t,
                  let bundleIdentifier = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier,
                  Self.isLauncher(bundleIdentifier)
            else {
                continue
            }

            let layer = window[kCGWindowLayer as String] as? Int ?? 0
            InputLockerLog.floating.debug("visible floating window bundle=\(bundleIdentifier, privacy: .public) pid=\(pid, privacy: .public) layer=\(layer, privacy: .public)")
            return bundleIdentifier
        }

        return nil
    }

    private func report(bundleIdentifier: String?) {
        guard bundleIdentifier != currentBundleIdentifier else { return }
        currentBundleIdentifier = bundleIdentifier
        onChange?(bundleIdentifier.flatMap(makeContext))
    }

    private func focusedBundleIdentifier() -> String? {
        var focusedValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            systemWideElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedValue
        ) == .success,
            let focusedValue,
            CFGetTypeID(focusedValue) == AXUIElementGetTypeID()
        else {
            return nil
        }

        var pid: pid_t = 0
        guard AXUIElementGetPid(focusedValue as! AXUIElement, &pid) == .success else {
            return nil
        }
        return NSRunningApplication(processIdentifier: pid)?.bundleIdentifier
    }

    private func makeContext(bundleIdentifier: String) -> FrontmostApplicationContext {
        let runningApp = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first
        let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
        let displayName = runningApp?.localizedName
            ?? appURL?.deletingPathExtension().lastPathComponent
            ?? bundleIdentifier

        return FrontmostApplicationContext(bundleIdentifier: bundleIdentifier, name: displayName)
    }

    private static func isLauncher(_ bundleIdentifier: String?) -> Bool {
        isLauncherBundleIdentifier(bundleIdentifier)
    }

    static func isLauncherBundleIdentifier(_ bundleIdentifier: String?) -> Bool {
        guard let bundleIdentifier else { return false }
        return launcherBundleIdentifiers.contains(bundleIdentifier)
    }

    private static func isVisibleFloatingWindow(_ window: [String: Any]) -> Bool {
        let layer = window[kCGWindowLayer as String] as? Int ?? 0
        let alpha = window[kCGWindowAlpha as String] as? Double ?? 1
        guard layer > 0, alpha > 0 else { return false }

        guard let bounds = window[kCGWindowBounds as String] as? [String: Any],
              let width = bounds["Width"] as? Double,
              let height = bounds["Height"] as? Double
        else {
            return true
        }

        return width > 20 && height > 20
    }
}

private func floatingInputFocusCallback(
    _ observer: AXObserver,
    _ element: AXUIElement,
    _ notification: CFString,
    _ refcon: UnsafeMutableRawPointer?
) {
    guard let refcon else { return }
    let monitor = Unmanaged<FloatingInputFocusMonitor>.fromOpaque(refcon).takeUnretainedValue()
    DispatchQueue.main.async {
        monitor.evaluateWindowTransition()
    }
}

private struct FloatingLauncherDetection {
    let bundleIdentifier: String?
    let method: String
}
