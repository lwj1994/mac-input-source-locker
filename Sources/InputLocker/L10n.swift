import Foundation

enum L10n {
    static var dashboardNotEnabled: String { tr("dashboard.notEnabled") }
    static var dashboardStatusLocked: String { tr("dashboard.status.locked") }
    static var dashboardStatusPaused: String { tr("dashboard.status.paused") }
    static var dashboardGlobalLock: String { tr("dashboard.row.globalLock") }
    static var dashboardAppLock: String { tr("dashboard.row.appLock") }
    static var dashboardCurrentApp: String { tr("dashboard.row.currentApp") }
    static var dashboardTargetUnset: String { tr("dashboard.targetUnset") }
    static var dashboardUnavailable: String { tr("dashboard.unavailable") }
    static var dashboardAppLockUnset: String { tr("dashboard.appLockUnset") }

    static var menuNoTarget: String { tr("menu.noTarget") }
    static var menuSettings: String { tr("menu.settings") }
    static var menuPauseLock: String { tr("menu.pauseLock") }
    static var menuEnableLock: String { tr("menu.enableLock") }
    static var menuGlobalTarget: String { tr("menu.globalTarget") }
    static var menuCurrentAppUnavailable: String { tr("menu.currentAppUnavailable") }
    static var menuClearCurrentAppRule: String { tr("menu.clearCurrentAppRule") }
    static var menuOpenKeyboardSettings: String { tr("menu.openKeyboardSettings") }
    static var menuQuit: String { tr("menu.quit") }
    static var menuNoSelectableInputSources: String { tr("menu.noSelectableInputSources") }

    static var settingsTitle: String { tr("settings.title") }
    static var settingsGeneralSection: String { tr("settings.section.general") }
    static var settingsCurrentAppSection: String { tr("settings.section.currentApp") }
    static var settingsRulesSection: String { tr("settings.section.rules") }
    static var settingsDiagnosticsSection: String { tr("settings.section.diagnostics") }
    static var settingsLockEnabled: String { tr("settings.lockEnabled") }
    static var settingsDefaultInputSource: String { tr("settings.defaultInputSource") }
    static var settingsAppInputSource: String { tr("settings.appInputSource") }
    static var settingsUseGlobalTarget: String { tr("settings.useGlobalTarget") }
    static var settingsNoCurrentApp: String { tr("settings.noCurrentApp") }
    static var settingsNoAppRules: String { tr("settings.noAppRules") }
    static var settingsExportLogs: String { tr("settings.exportLogs") }
    static var settingsExportingLogs: String { tr("settings.exportingLogs") }

    static var enforcerReady: String { tr("enforcer.ready") }
    static var enforcerStarted: String { tr("enforcer.started") }
    static var enforcerLockEnabled: String { tr("enforcer.lockEnabled") }
    static var enforcerLockPaused: String { tr("enforcer.lockPaused") }
    static var enforcerManualApply: String { tr("enforcer.manualApply") }
    static var enforcerNoTargetInputSource: String { tr("enforcer.noTargetInputSource") }
    static var enforcerCurrentInputSourceUnavailable: String { tr("enforcer.currentInputSourceUnavailable") }
    static var enforcerInputSourceChanged: String { tr("enforcer.inputSourceChanged") }
    static var enforcerAppSwitched: String { tr("enforcer.appSwitched") }
    static var enforcerFocusSettled: String { tr("enforcer.focusSettled") }
    static var enforcerTargetChanged: String { tr("enforcer.targetChanged") }
    static var enforcerAppRuleChanged: String { tr("enforcer.appRuleChanged") }

    static func statusTooltipLocked(_ targetName: String) -> String {
        tr("status.tooltip.locked", targetName)
    }

    static func statusTooltipPaused() -> String {
        tr("status.tooltip.paused")
    }

    static func enforcerLockedTo(_ inputSourceName: String) -> String {
        tr("enforcer.lockedTo", inputSourceName)
    }

    static func enforcerLockedToForApp(_ inputSourceName: String, appName: String) -> String {
        tr("enforcer.lockedToForApp", inputSourceName, appName)
    }

    static func enforcerChanged(reason: String, from currentName: String, to targetName: String) -> String {
        tr("enforcer.changed", reason, currentName, targetName)
    }

    static func enforcerChangedForApp(reason: String, appName: String, from currentName: String, to targetName: String) -> String {
        tr("enforcer.changedForApp", reason, appName, currentName, targetName)
    }

    static func menuCurrentAppLock(_ appName: String) -> String {
        tr("menu.currentAppLock", appName)
    }

    static func settingsExportLogsDone(_ fileName: String) -> String {
        tr("settings.exportLogsDone", fileName)
    }

    static func settingsExportLogsFailed(_ errorMessage: String) -> String {
        tr("settings.exportLogsFailed", errorMessage)
    }

    private static func tr(_ key: String, _ arguments: CVarArg...) -> String {
        let format = AppResourceBundle.current.localizedString(forKey: key, value: key, table: nil)
        return String(format: format, locale: Locale.current, arguments: arguments)
    }
}
