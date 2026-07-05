import AppKit
import Foundation
import MacInputSourceLockerCore

struct FrontmostApplicationContext: Equatable {
    let bundleIdentifier: String
    let name: String
}

final class InputSourceEnforcer: NSObject {
    private static let maxReconcileRetries = 3

    private let manager: InputSourceManager
    private let settingsStore: SettingsStore
    private let inputSourceObserver = InputSourceChangeObserver()
    private let floatingFocusMonitor = FloatingInputFocusMonitor()
    private var isStarted = false
    private var pendingReconcile = false
    private var reconcileRetries = 0
    private var lastResolvedTargetInputSourceID: String?
    private var frontmostApplicationContext: FrontmostApplicationContext?
    private var floatingApplicationContext: FrontmostApplicationContext?

    var onStateChanged: (() -> Void)?

    private(set) var lastEventText = L10n.enforcerReady
    private(set) var lastEnforcedAt: Date?
    private(set) var lastFrontmostApplicationName: String?
    private(set) var lastFrontmostApplicationBundleIdentifier: String?

    init(
        manager: InputSourceManager,
        settingsStore: SettingsStore
    ) {
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

        InputLockerLog.enforcer.info("enforcer start")
        removeFloatingApplicationRules()
        seedTargetIfNeeded()
        seedFrontmostApplication()
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(applicationDidActivate(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        inputSourceObserver.start { [weak self] in
            self?.inputSourceDidChange()
        }
        floatingFocusMonitor.start { [weak self] context in
            self?.floatingApplicationDidChange(context)
        }
        applyNow(reason: L10n.enforcerStarted)
    }

    func stop() {
        guard isStarted else { return }
        isStarted = false
        InputLockerLog.enforcer.info("enforcer stop")
        inputSourceObserver.stop()
        floatingFocusMonitor.stop()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    func setLockEnabled(_ isEnabled: Bool) {
        settingsStore.isLockEnabled = isEnabled
        seedTargetIfNeeded()
        resetReconcileState()
        lastEventText = isEnabled ? L10n.enforcerLockEnabled : L10n.enforcerLockPaused
        InputLockerLog.enforcer.info("lock enabled=\(isEnabled, privacy: .public)")
        if isEnabled {
            applyNow(reason: L10n.enforcerLockEnabled)
        } else {
            onStateChanged?()
        }
    }

    func applyNow(reason: String = L10n.enforcerManualApply) {
        guard settingsStore.isLockEnabled else {
            lastEventText = L10n.enforcerLockPaused
            InputLockerLog.enforcer.debug("skip apply reason=\(reason, privacy: .public) lock disabled")
            onStateChanged?()
            return
        }

        refreshFloatingApplicationContext()

        guard let target = effectiveTargetInputSource() else {
            seedTargetIfNeeded()
            if effectiveTargetInputSource() == nil {
                lastEventText = L10n.enforcerNoTargetInputSource
                InputLockerLog.enforcer.warning("skip apply reason=\(reason, privacy: .public) no target input source")
                onStateChanged?()
            }
            return
        }

        guard let current = manager.currentInputSource() else {
            lastEventText = L10n.enforcerCurrentInputSourceUnavailable
            InputLockerLog.enforcer.warning("skip apply reason=\(reason, privacy: .public) current input source unavailable")
            onStateChanged?()
            return
        }

        InputLockerLog.enforcer.info(
            "resolve reason=\(reason, privacy: .public) app=\(self.lastFrontmostApplicationBundleIdentifier ?? "nil", privacy: .public) source=\(target.source, privacy: .public) current=\(current.id, privacy: .public) target=\(target.inputSourceID, privacy: .public)"
        )
        updateReconcileState(for: target.inputSourceID)
        settingsStore.lastSelectedInputSourceID = current.id
        guard current.id != target.inputSourceID else {
            resetReconcileState()
            lastEventText = target.appName.map {
                L10n.enforcerLockedToForApp(current.displayName, appName: $0)
            } ?? L10n.enforcerLockedTo(current.displayName)
            InputLockerLog.enforcer.debug("already locked inputSource=\(current.id, privacy: .public)")
            onStateChanged?()
            return
        }

        do {
            try manager.selectInputSource(id: target.inputSourceID)
            lastEnforcedAt = Date()
            let targetName = manager.inputSource(id: target.inputSourceID)?.displayName ?? target.inputSourceID
            InputLockerLog.enforcer.info(
                "select input source reason=\(reason, privacy: .public) from=\(current.id, privacy: .public) to=\(target.inputSourceID, privacy: .public) source=\(target.source, privacy: .public)"
            )
            lastEventText = target.appName.map {
                L10n.enforcerChangedForApp(reason: reason, appName: $0, from: current.displayName, to: targetName)
            } ?? L10n.enforcerChanged(reason: reason, from: current.displayName, to: targetName)
            scheduleReconcile(reason: L10n.enforcerFocusSettled)
        } catch {
            lastEventText = error.localizedDescription
            InputLockerLog.enforcer.error("select input source failed target=\(target.inputSourceID, privacy: .public) error=\(error.localizedDescription, privacy: .public)")
        }

        onStateChanged?()
    }

    func currentApplicationContext() -> FrontmostApplicationContext? {
        frontmostApplicationContext
    }

    func currentAppRule() -> AppInputSourceRule? {
        settingsStore.appInputSourceRule(for: frontmostApplicationContext?.bundleIdentifier)
    }

    func effectiveTargetInputSourceID() -> String? {
        effectiveTargetInputSource()?.inputSourceID
    }

    private func seedTargetIfNeeded() {
        guard settingsStore.targetInputSourceID == nil else { return }
        settingsStore.targetInputSourceID = manager.currentInputSource()?.id
    }

    private func seedFrontmostApplication() {
        guard let app = NSWorkspace.shared.frontmostApplication else { return }
        updateFrontmostApplication(app)
    }

    @objc private func applicationDidActivate(_ notification: Notification) {
        if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
            updateFrontmostApplication(app)
        }

        scheduleActivationEnforcement()
    }

    private func updateFrontmostApplication(_ app: NSRunningApplication) {
        guard let bundleIdentifier = app.bundleIdentifier,
              bundleIdentifier != Bundle.main.bundleIdentifier,
              !FloatingInputFocusMonitor.isLauncherBundleIdentifier(bundleIdentifier)
        else {
            return
        }

        frontmostApplicationContext = FrontmostApplicationContext(
            bundleIdentifier: bundleIdentifier,
            name: app.localizedName ?? bundleIdentifier
        )
        InputLockerLog.enforcer.info("frontmost app bundle=\(bundleIdentifier, privacy: .public) name=\(self.frontmostApplicationContext?.name ?? bundleIdentifier, privacy: .public)")
        publishEffectiveApplicationContext()
    }

    private func floatingApplicationDidChange(_ context: FrontmostApplicationContext?) {
        floatingApplicationContext = context
        InputLockerLog.enforcer.info("floating app changed bundle=\(context?.bundleIdentifier ?? "nil", privacy: .public) name=\(context?.name ?? "nil", privacy: .public)")
        publishEffectiveApplicationContext()
        scheduleActivationEnforcement(reason: context == nil ? L10n.enforcerFocusSettled : L10n.enforcerAppSwitched)
    }

    private func refreshFloatingApplicationContext() {
        let context = floatingFocusMonitor.currentContext()
        guard context != floatingApplicationContext else { return }
        floatingApplicationContext = context
        InputLockerLog.enforcer.info("floating app refreshed bundle=\(context?.bundleIdentifier ?? "nil", privacy: .public) name=\(context?.name ?? "nil", privacy: .public)")
        publishEffectiveApplicationContext()
    }

    private func publishEffectiveApplicationContext() {
        let context = floatingApplicationContext ?? frontmostApplicationContext
        lastFrontmostApplicationBundleIdentifier = context?.bundleIdentifier
        lastFrontmostApplicationName = context?.name
        InputLockerLog.enforcer.debug("effective app bundle=\(context?.bundleIdentifier ?? "nil", privacy: .public) name=\(context?.name ?? "nil", privacy: .public)")
    }

    private func effectiveTargetInputSource() -> EffectiveTargetInputSource? {
        if floatingApplicationContext != nil {
            return settingsStore.targetInputSourceID.map {
                EffectiveTargetInputSource(inputSourceID: $0, appName: nil, source: "global")
            }
        }

        if let rule = settingsStore.appInputSourceRule(for: lastFrontmostApplicationBundleIdentifier) {
            return EffectiveTargetInputSource(
                inputSourceID: rule.inputSourceID,
                appName: rule.appName,
                source: "app-rule"
            )
        }

        return settingsStore.targetInputSourceID.map {
            EffectiveTargetInputSource(inputSourceID: $0, appName: nil, source: "global")
        }
    }

    private func removeFloatingApplicationRules() {
        let rules = settingsStore.appInputSourceRules
        let keptRules = rules.filter {
            !FloatingInputFocusMonitor.isLauncherBundleIdentifier($0.bundleIdentifier)
        }
        guard keptRules.count != rules.count else { return }

        settingsStore.appInputSourceRules = keptRules
        InputLockerLog.enforcer.info("removed floating app rules count=\(rules.count - keptRules.count, privacy: .public)")
    }

    private func inputSourceDidChange() {
        guard isStarted, settingsStore.isLockEnabled else { return }
        InputLockerLog.enforcer.debug("input source change event")
        applyNow(reason: L10n.enforcerInputSourceChanged)
    }

    private func scheduleActivationEnforcement(reason: String = L10n.enforcerAppSwitched) {
        guard isStarted, settingsStore.isLockEnabled else { return }

        applyNow(reason: reason)
        for delay in [0.12, 0.35, 0.75] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self, self.isStarted, self.settingsStore.isLockEnabled else { return }
                self.applyNow(reason: L10n.enforcerFocusSettled)
            }
        }
    }

    private func updateReconcileState(for targetInputSourceID: String) {
        guard lastResolvedTargetInputSourceID != targetInputSourceID else { return }
        lastResolvedTargetInputSourceID = targetInputSourceID
        reconcileRetries = 0
        pendingReconcile = false
    }

    private func resetReconcileState() {
        reconcileRetries = 0
        pendingReconcile = false
    }

    private func scheduleReconcile(reason: String) {
        guard !pendingReconcile, reconcileRetries < Self.maxReconcileRetries else { return }
        pendingReconcile = true
        reconcileRetries += 1
        InputLockerLog.enforcer.debug("schedule reconcile retry=\(self.reconcileRetries, privacy: .public) reason=\(reason, privacy: .public)")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self else { return }
            self.pendingReconcile = false
            guard self.isStarted, self.settingsStore.isLockEnabled else { return }
            self.applyNow(reason: reason)
        }
    }
}

private struct EffectiveTargetInputSource {
    let inputSourceID: String
    let appName: String?
    let source: String
}
