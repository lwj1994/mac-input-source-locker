import AppKit
import MacInputSourceLockerCore
import SwiftUI

final class StatusMenuController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private let manager = InputSourceManager()
    private let settingsStore = SettingsStore()
    private lazy var enforcer = InputSourceEnforcer(manager: manager, settingsStore: settingsStore)

    private var inputSources: [InputSource] = []

    override init() {
        super.init()
        configureStatusItem()
        refreshInputSources()
        enforcer.onStateChanged = { [weak self] in
            self?.updateStatusItem()
        }
        enforcer.start()
        updateStatusItem()
    }

    func stop() {
        enforcer.stop()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuildMenu()
    }

    private func configureStatusItem() {
        menu.delegate = self
        statusItem.menu = menu
        statusItem.button?.imagePosition = .imageOnly
    }

    private func refreshInputSources() {
        inputSources = manager.selectableInputSources()
    }

    private func updateStatusItem() {
        guard let button = statusItem.button else { return }
        let isEnabled = settingsStore.isLockEnabled
        button.image = statusIcon()
        button.contentTintColor = nil

        let targetName = targetInputSource()?.displayName ?? settingsStore.targetInputSourceID ?? L10n.menuNoTarget
        button.toolTip = isEnabled
            ? L10n.statusTooltipLocked(targetName)
            : L10n.statusTooltipPaused()
    }

    private func rebuildMenu() {
        refreshInputSources()
        menu.removeAllItems()

        addDashboardItem()
        menu.addItem(.separator())

        let toggleItem = NSMenuItem(
            title: settingsStore.isLockEnabled ? L10n.menuPauseLock : L10n.menuEnableLock,
            action: #selector(toggleLock(_:)),
            keyEquivalent: ""
        )
        toggleItem.target = self
        toggleItem.image = symbolMenuIcon(settingsStore.isLockEnabled ? "pause.circle" : "play.circle")
        menu.addItem(toggleItem)

        addInputSourceItems()

        menu.addItem(.separator())

        let keyboardSettingsItem = NSMenuItem(
            title: L10n.menuOpenKeyboardSettings,
            action: #selector(openKeyboardSettings(_:)),
            keyEquivalent: ""
        )
        keyboardSettingsItem.target = self
        keyboardSettingsItem.image = symbolMenuIcon("keyboard")
        menu.addItem(keyboardSettingsItem)

        let quitItem = NSMenuItem(title: L10n.menuQuit, action: #selector(quitApp(_:)), keyEquivalent: "q")
        quitItem.target = self
        quitItem.image = symbolMenuIcon("power")
        menu.addItem(quitItem)
    }

    private func addDashboardItem() {
        let targetName = targetInputSource()?.displayName ?? settingsStore.targetInputSourceID ?? L10n.dashboardTargetUnset
        let currentName = manager.currentInputSource()?.displayName ?? L10n.dashboardUnavailable

        let content = LockDashboardMenuContent(
            isLockEnabled: settingsStore.isLockEnabled,
            targetName: targetName,
            currentName: currentName,
            frontmostApplicationName: enforcer.lastFrontmostApplicationName
        )

        let hostingView = NSHostingView(rootView: content)
        let fittingHeight = max(1, ceil(hostingView.fittingSize.height))
        hostingView.frame = NSRect(
            x: 0,
            y: 0,
            width: LockDashboardMenuContent.width,
            height: fittingHeight
        )

        let item = NSMenuItem()
        item.view = hostingView
        menu.addItem(item)
    }

    private func addInputSourceItems() {
        let targetID = settingsStore.targetInputSourceID

        if inputSources.isEmpty {
            let item = NSMenuItem(title: L10n.menuNoSelectableInputSources, action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        } else {
            for source in inputSources {
                let item = NSMenuItem(
                    title: source.displayName,
                    action: #selector(selectTargetInputSource(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = source.id
                item.state = source.id == targetID ? .on : .off
                item.toolTip = source.id
                item.image = inputSourceIcon(for: source)
                menu.addItem(item)
            }
        }
    }

    private func targetInputSource() -> InputSource? {
        guard let id = settingsStore.targetInputSourceID else { return nil }
        return inputSources.first { $0.id == id } ?? manager.inputSource(id: id)
    }

    private func statusIcon() -> NSImage? {
        guard let image = Bundle.module.url(forResource: "InputLockerStatusIcon", withExtension: "png")
            .flatMap(NSImage.init(contentsOf:))
        else {
            let fallback = NSImage(systemSymbolName: "keyboard", accessibilityDescription: nil)
            fallback?.size = NSSize(width: 18, height: 18)
            fallback?.isTemplate = true
            return fallback
        }

        image.size = NSSize(width: 18, height: 18)
        image.isTemplate = false
        return image
    }

    private func symbolMenuIcon(_ systemName: String) -> NSImage? {
        guard let image = NSImage(systemSymbolName: systemName, accessibilityDescription: nil) else {
            return nil
        }
        image.size = NSSize(width: 18, height: 18)
        image.isTemplate = true
        return image
    }

    private func inputSourceIcon(for source: InputSource) -> NSImage? {
        guard let url = source.iconImageURL,
              let image = NSImage(contentsOf: url)
        else {
            return symbolMenuIcon("keyboard")
        }

        image.size = NSSize(width: 18, height: 18)
        image.isTemplate = false
        return image
    }

    @objc private func toggleLock(_ sender: NSMenuItem) {
        enforcer.setLockEnabled(!settingsStore.isLockEnabled)
        updateStatusItem()
    }

    @objc private func selectTargetInputSource(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        settingsStore.targetInputSourceID = id
        enforcer.setLockEnabled(true)
        enforcer.applyNow(reason: L10n.enforcerTargetChanged)
        updateStatusItem()
    }

    @objc private func openKeyboardSettings(_ sender: NSMenuItem) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func quitApp(_ sender: NSMenuItem) {
        NSApp.terminate(nil)
    }
}
