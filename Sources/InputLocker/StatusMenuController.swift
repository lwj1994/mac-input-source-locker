import AppKit
import AppleViewModel
import MacInputSourceLockerCore
import SwiftUI

final class StatusMenuController: NSObject, NSMenuDelegate, ViewModelBindingRefreshable {
    private static let menuIconSize = NSSize(width: 18, height: 18)

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private lazy var viewModel = viewModelBinding.watch(inputLockerViewModelSpec)
    private lazy var settingsWindowController = SettingsWindowController()

    override init() {
        super.init()
        configureStatusItem()
        _ = viewModel
        updateStatusItem()
    }

    func stop() {
        viewModel.stop()
    }

    func viewModelBindingDidUpdate() {
        updateStatusItem()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        viewModel.refresh()
        rebuildMenu()
    }

    private func configureStatusItem() {
        statusItem.autosaveName = "milu.inputlocker.statusItem"
        menu.delegate = self
        statusItem.menu = menu
        statusItem.button?.imagePosition = .imageOnly
    }

    private func updateStatusItem() {
        guard let button = statusItem.button else { return }
        let state = viewModel.state
        button.image = statusIcon()
        button.contentTintColor = nil

        let targetID = state.effectiveTargetInputSourceID ?? state.globalTargetInputSourceID
        let targetName = viewModel.displayName(for: targetID) ?? targetID ?? L10n.menuNoTarget
        button.toolTip = state.isLockEnabled
            ? L10n.statusTooltipLocked(targetName)
            : L10n.statusTooltipPaused()
    }

    private func rebuildMenu() {
        menu.removeAllItems()

        addDashboardItem()
        menu.addItem(.separator())

        let settingsItem = NSMenuItem(
            title: L10n.menuSettings,
            action: #selector(openSettings(_:)),
            keyEquivalent: ","
        )
        settingsItem.target = self
        settingsItem.image = symbolMenuIcon("gearshape")
        menu.addItem(settingsItem)

        let toggleItem = NSMenuItem(
            title: viewModel.state.isLockEnabled ? L10n.menuPauseLock : L10n.menuEnableLock,
            action: #selector(toggleLock(_:)),
            keyEquivalent: ""
        )
        toggleItem.target = self
        toggleItem.image = symbolMenuIcon(viewModel.state.isLockEnabled ? "pause.circle" : "play.circle")
        menu.addItem(toggleItem)

        addCurrentAppLockItem()

        menu.addItem(.separator())

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
        let state = viewModel.state
        let targetName = viewModel.displayName(for: state.globalTargetInputSourceID)
            ?? state.globalTargetInputSourceID
            ?? L10n.dashboardTargetUnset

        let content = LockDashboardMenuContent(
            isLockEnabled: state.isLockEnabled,
            targetName: targetName,
            appLockName: currentAppLockName(),
            frontmostApplicationName: state.currentApplicationContext?.name
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
        let state = viewModel.state
        let targetID = state.globalTargetInputSourceID
        let headerItem = NSMenuItem(title: L10n.menuGlobalTarget, action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        menu.addItem(headerItem)

        if state.inputSources.isEmpty {
            let item = NSMenuItem(title: L10n.menuNoSelectableInputSources, action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        } else {
            for source in state.inputSources {
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

    private func addCurrentAppLockItem() {
        guard let context = viewModel.state.currentApplicationContext else {
            let item = NSMenuItem(title: L10n.menuCurrentAppUnavailable, action: nil, keyEquivalent: "")
            item.isEnabled = false
            item.image = symbolMenuIcon("app")
            menu.addItem(item)
            return
        }

        let item = NSMenuItem(title: L10n.menuCurrentAppLock(context.name), action: nil, keyEquivalent: "")
        item.image = symbolMenuIcon("app")

        let submenu = NSMenu()
        addCurrentAppInputSourceItems(to: submenu, context: context)
        item.submenu = submenu
        menu.addItem(item)
    }

    private func addCurrentAppInputSourceItems(to submenu: NSMenu, context: FrontmostApplicationContext) {
        let rule = viewModel.state.currentAppRule

        if viewModel.state.inputSources.isEmpty {
            let item = NSMenuItem(title: L10n.menuNoSelectableInputSources, action: nil, keyEquivalent: "")
            item.isEnabled = false
            submenu.addItem(item)
            return
        }

        for source in viewModel.state.inputSources {
            let item = NSMenuItem(
                title: source.displayName,
                action: #selector(selectCurrentAppInputSource(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = source.id
            item.state = source.id == rule?.inputSourceID ? .on : .off
            item.toolTip = source.id
            item.image = inputSourceIcon(for: source)
            submenu.addItem(item)
        }

        if rule != nil {
            submenu.addItem(.separator())
            let clearItem = NSMenuItem(
                title: L10n.menuClearCurrentAppRule,
                action: #selector(clearCurrentAppInputSource(_:)),
                keyEquivalent: ""
            )
            clearItem.target = self
            clearItem.image = symbolMenuIcon("trash")
            submenu.addItem(clearItem)
        }
    }

    private func currentAppLockName() -> String {
        guard let rule = viewModel.state.currentAppRule else {
            return L10n.dashboardAppLockUnset
        }

        return viewModel.displayName(for: rule.inputSourceID) ?? rule.inputSourceID
    }

    private func statusIcon() -> NSImage? {
        guard let image = AppResourceBundle.current.url(forResource: "InputLockerStatusIcon", withExtension: "png")
            .flatMap(NSImage.init(contentsOf:))
        else {
            let fallback = NSImage(systemSymbolName: "keyboard", accessibilityDescription: nil)
            fallback?.size = Self.menuIconSize
            fallback?.isTemplate = true
            return fallback
        }

        image.size = Self.menuIconSize
        image.isTemplate = true
        return image
    }

    private func symbolMenuIcon(_ systemName: String) -> NSImage? {
        guard let image = NSImage(systemSymbolName: systemName, accessibilityDescription: nil) else {
            return nil
        }
        image.size = Self.menuIconSize
        image.isTemplate = true
        return image
    }

    private func inputSourceIcon(for source: InputSource) -> NSImage? {
        let image = source.iconImageURL
            .flatMap(NSImage.init(contentsOf:))
            ?? NSImage(systemSymbolName: "keyboard", accessibilityDescription: nil)

        return image?.withAdaptiveTemplateTint(size: Self.menuIconSize)
    }

    @objc private func toggleLock(_ sender: NSMenuItem) {
        viewModel.setLockEnabled(!viewModel.state.isLockEnabled)
    }

    @objc private func selectTargetInputSource(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        viewModel.selectGlobalInputSource(id: id)
    }

    @objc private func selectCurrentAppInputSource(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String,
              viewModel.state.currentApplicationContext != nil
        else {
            settingsWindowController.show()
            return
        }

        viewModel.selectCurrentAppInputSource(id: id)
    }

    @objc private func clearCurrentAppInputSource(_ sender: NSMenuItem) {
        viewModel.selectCurrentAppInputSource(id: nil)
    }

    @objc private func openSettings(_ sender: NSMenuItem) {
        settingsWindowController.show()
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

private extension NSImage {
    func withAdaptiveTemplateTint(size: NSSize) -> NSImage {
        let sourceRect = NSRect(origin: .zero, size: self.size)
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor.black.setFill()
            rect.fill()
            self.draw(in: rect, from: sourceRect, operation: .destinationIn, fraction: 1)
            return true
        }
        image.isTemplate = true
        return image
    }
}
