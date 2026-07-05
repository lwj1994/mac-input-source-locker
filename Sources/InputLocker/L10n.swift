import Foundation

enum L10n {
    static var dashboardNotEnabled: String { tr("dashboard.notEnabled") }
    static var dashboardStatusLocked: String { tr("dashboard.status.locked") }
    static var dashboardStatusPaused: String { tr("dashboard.status.paused") }
    static var dashboardGlobalLock: String { tr("dashboard.row.globalLock") }
    static var dashboardCurrentApp: String { tr("dashboard.row.currentApp") }
    static var dashboardTargetUnset: String { tr("dashboard.targetUnset") }
    static var dashboardUnavailable: String { tr("dashboard.unavailable") }

    static var menuNoTarget: String { tr("menu.noTarget") }
    static var menuPauseLock: String { tr("menu.pauseLock") }
    static var menuEnableLock: String { tr("menu.enableLock") }
    static var menuOpenKeyboardSettings: String { tr("menu.openKeyboardSettings") }
    static var menuQuit: String { tr("menu.quit") }
    static var menuNoSelectableInputSources: String { tr("menu.noSelectableInputSources") }

    static var enforcerReady: String { tr("enforcer.ready") }
    static var enforcerStarted: String { tr("enforcer.started") }
    static var enforcerLockEnabled: String { tr("enforcer.lockEnabled") }
    static var enforcerLockPaused: String { tr("enforcer.lockPaused") }
    static var enforcerManualApply: String { tr("enforcer.manualApply") }
    static var enforcerNoTargetInputSource: String { tr("enforcer.noTargetInputSource") }
    static var enforcerCurrentInputSourceUnavailable: String { tr("enforcer.currentInputSourceUnavailable") }
    static var enforcerPeriodicCheck: String { tr("enforcer.periodicCheck") }
    static var enforcerAppSwitched: String { tr("enforcer.appSwitched") }
    static var enforcerFocusSettled: String { tr("enforcer.focusSettled") }
    static var enforcerTargetChanged: String { tr("enforcer.targetChanged") }

    static func statusTooltipLocked(_ targetName: String) -> String {
        tr("status.tooltip.locked", targetName)
    }

    static func statusTooltipPaused() -> String {
        tr("status.tooltip.paused")
    }

    static func enforcerLockedTo(_ inputSourceName: String) -> String {
        tr("enforcer.lockedTo", inputSourceName)
    }

    static func enforcerChanged(reason: String, from currentName: String, to targetName: String) -> String {
        tr("enforcer.changed", reason, currentName, targetName)
    }

    private static func tr(_ key: String, _ arguments: CVarArg...) -> String {
        let format = Bundle.module.localizedString(forKey: key, value: key, table: nil)
        return String(format: format, locale: Locale.current, arguments: arguments)
    }
}
