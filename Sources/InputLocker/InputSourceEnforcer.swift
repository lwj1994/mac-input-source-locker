import AppKit
import Foundation
import MacInputSourceLockerCore

final class InputSourceEnforcer: NSObject {
    private let manager: InputSourceManager
    private let settingsStore: SettingsStore
    private var timer: Timer?
    private var isStarted = false

    var onStateChanged: (() -> Void)?

    private(set) var lastEventText = L10n.enforcerReady
    private(set) var lastEnforcedAt: Date?
    private(set) var lastFrontmostApplicationName: String?

    init(manager: InputSourceManager, settingsStore: SettingsStore) {
        self.manager = manager
        self.settingsStore = settingsStore
        super.init()
    }

    deinit {
        stop()
    }

    func start() {
        guard !isStarted else { return }
        isStarted = true

        seedTargetIfNeeded()
        seedFrontmostApplication()
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(applicationDidActivate(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        updateTimer()
        applyNow(reason: L10n.enforcerStarted)
    }

    func stop() {
        guard isStarted else { return }
        isStarted = false
        timer?.invalidate()
        timer = nil
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    func setLockEnabled(_ isEnabled: Bool) {
        settingsStore.isLockEnabled = isEnabled
        seedTargetIfNeeded()
        updateTimer()
        lastEventText = isEnabled ? L10n.enforcerLockEnabled : L10n.enforcerLockPaused
        if isEnabled {
            applyNow(reason: L10n.enforcerLockEnabled)
        } else {
            onStateChanged?()
        }
    }

    func applyNow(reason: String = L10n.enforcerManualApply) {
        guard settingsStore.isLockEnabled else {
            lastEventText = L10n.enforcerLockPaused
            onStateChanged?()
            return
        }

        guard let targetID = settingsStore.targetInputSourceID else {
            seedTargetIfNeeded()
            if settingsStore.targetInputSourceID == nil {
                lastEventText = L10n.enforcerNoTargetInputSource
                onStateChanged?()
            }
            return
        }

        guard let current = manager.currentInputSource() else {
            lastEventText = L10n.enforcerCurrentInputSourceUnavailable
            onStateChanged?()
            return
        }

        settingsStore.lastSelectedInputSourceID = current.id
        guard current.id != targetID else {
            lastEventText = L10n.enforcerLockedTo(current.displayName)
            onStateChanged?()
            return
        }

        do {
            try manager.selectInputSource(id: targetID)
            lastEnforcedAt = Date()
            let targetName = manager.inputSource(id: targetID)?.displayName ?? targetID
            lastEventText = L10n.enforcerChanged(reason: reason, from: current.displayName, to: targetName)
        } catch {
            lastEventText = error.localizedDescription
        }

        onStateChanged?()
    }

    private func seedTargetIfNeeded() {
        guard settingsStore.targetInputSourceID == nil else { return }
        settingsStore.targetInputSourceID = manager.currentInputSource()?.id
    }

    private func seedFrontmostApplication() {
        guard let app = NSWorkspace.shared.frontmostApplication else { return }
        lastFrontmostApplicationName = app.localizedName ?? app.bundleIdentifier
    }

    private func updateTimer() {
        timer?.invalidate()
        timer = nil

        guard isStarted, settingsStore.isLockEnabled else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.applyNow(reason: L10n.enforcerPeriodicCheck)
        }
    }

    @objc private func applicationDidActivate(_ notification: Notification) {
        if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
            lastFrontmostApplicationName = app.localizedName ?? app.bundleIdentifier
        }

        scheduleActivationEnforcement()
    }

    private func scheduleActivationEnforcement() {
        guard isStarted, settingsStore.isLockEnabled else { return }

        applyNow(reason: L10n.enforcerAppSwitched)
        for delay in [0.12, 0.35, 0.75] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self, self.isStarted, self.settingsStore.isLockEnabled else { return }
                self.applyNow(reason: L10n.enforcerFocusSettled)
            }
        }
    }
}
