import AppleViewModel
import Foundation
import MacInputSourceLockerCore

struct InputLockerState: Equatable {
    var inputSources: [InputSource] = []
    var isLockEnabled = true
    var globalTargetInputSourceID: String?
    var effectiveTargetInputSourceID: String?
    var currentInputSourceName = L10n.dashboardUnavailable
    var currentApplicationContext: FrontmostApplicationContext?
    var currentAppRule: AppInputSourceRule?
    var appRules: [AppInputSourceRule] = []
    var lastEventText = L10n.enforcerReady
}

@MainActor
final class InputLockerViewModel: StateViewModel<InputLockerState> {
    private let manager: InputSourceManager
    private let settingsStore: SettingsStore
    private let enforcer: InputSourceEnforcer
    private var hasStarted = false

    init(
        manager: InputSourceManager = InputSourceManager(),
        settingsStore: SettingsStore = SettingsStore()
    ) {
        self.manager = manager
        self.settingsStore = settingsStore
        self.enforcer = InputSourceEnforcer(manager: manager, settingsStore: settingsStore)
        super.init(state: InputLockerState(), equals: ==)
        enforcer.onStateChanged = { [weak self] in
            self?.refresh()
        }
    }

    override func onCreate(_ arg: InstanceArg) {
        super.onCreate(arg)
        start()
    }

    override func dispose() {
        stop()
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        enforcer.start()
        refresh()
    }

    func stop() {
        guard hasStarted else { return }
        hasStarted = false
        enforcer.stop()
        refresh()
    }

    func refresh() {
        let inputSources = manager.selectableInputSources()
        let currentAppContext = enforcer.currentApplicationContext()
        let currentAppRule = enforcer.currentAppRule()
        let currentInputSourceName = manager.currentInputSource()?.displayName ?? L10n.dashboardUnavailable

        setState(InputLockerState(
            inputSources: inputSources,
            isLockEnabled: settingsStore.isLockEnabled,
            globalTargetInputSourceID: settingsStore.targetInputSourceID,
            effectiveTargetInputSourceID: enforcer.effectiveTargetInputSourceID(),
            currentInputSourceName: currentInputSourceName,
            currentApplicationContext: currentAppContext,
            currentAppRule: currentAppRule,
            appRules: settingsStore.appInputSourceRules,
            lastEventText: enforcer.lastEventText
        ))
    }

    func setLockEnabled(_ isEnabled: Bool) {
        enforcer.setLockEnabled(isEnabled)
        refresh()
    }

    func selectGlobalInputSource(id: String?) {
        settingsStore.targetInputSourceID = id
        if id != nil {
            enforcer.setLockEnabled(true)
        }
        enforcer.applyNow(reason: L10n.enforcerTargetChanged)
        refresh()
    }

    func selectCurrentAppInputSource(id: String?) {
        guard let context = enforcer.currentApplicationContext() else { return }

        if let id, !id.isEmpty {
            settingsStore.setAppInputSourceRule(
                bundleIdentifier: context.bundleIdentifier,
                appName: context.name,
                inputSourceID: id
            )
            enforcer.setLockEnabled(true)
        } else {
            settingsStore.removeAppInputSourceRule(for: context.bundleIdentifier)
        }

        enforcer.applyNow(reason: L10n.enforcerAppRuleChanged)
        refresh()
    }

    func removeAppInputSourceRule(for bundleIdentifier: String) {
        settingsStore.removeAppInputSourceRule(for: bundleIdentifier)
        enforcer.applyNow(reason: L10n.enforcerAppRuleChanged)
        refresh()
    }

    func displayName(for inputSourceID: String?) -> String? {
        guard let inputSourceID else { return nil }
        return state.inputSources.first { $0.id == inputSourceID }?.displayName
            ?? manager.inputSource(id: inputSourceID)?.displayName
    }

    func inputSourceName(for inputSourceID: String) -> String {
        displayName(for: inputSourceID) ?? inputSourceID
    }
}

@MainActor
let inputLockerViewModelSpec = ViewModelSpec<InputLockerViewModel>(
    key: "input-locker",
    aliveForever: true
) {
    InputLockerViewModel()
}
