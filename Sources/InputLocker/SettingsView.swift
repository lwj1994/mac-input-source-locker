import AppKit
import AppleViewModel
import MacInputSourceLockerCore
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @WatchViewModel(inputLockerViewModelSpec) private var viewModel: InputLockerViewModel
    @State private var isExportingLogs = false
    @State private var logExportStatusText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    settingsSection(L10n.settingsGeneralSection) {
                        Toggle(L10n.settingsLockEnabled, isOn: lockEnabledBinding)

                        Picker(L10n.settingsDefaultInputSource, selection: globalTargetBinding) {
                            Text(L10n.dashboardTargetUnset).tag("")
                            ForEach(viewModel.state.inputSources) { source in
                                Text(source.displayName).tag(source.id)
                            }
                        }
                        .labelsHidden()
                    }

                    settingsSection(L10n.settingsCurrentAppSection) {
                        currentAppRuleControls
                    }

                    settingsSection(L10n.settingsRulesSection) {
                        appRulesList
                    }

                    settingsSection(L10n.settingsDiagnosticsSection) {
                        logExportControls
                    }
                }
                .padding(20)
            }
        }
        .frame(minWidth: 560, minHeight: 560)
        .onAppear {
            viewModel.refresh()
        }
    }

    private var logExportControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                exportLogs()
            } label: {
                Label(
                    isExportingLogs ? L10n.settingsExportingLogs : L10n.settingsExportLogs,
                    systemImage: "square.and.arrow.up"
                )
            }
            .disabled(isExportingLogs)

            if let logExportStatusText {
                Text(logExportStatusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "keyboard")
                .font(.system(size: 21, weight: .semibold))
                .foregroundColor(.accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.settingsTitle)
                    .font(.system(size: 17, weight: .semibold))
                Text(L10n.settingsCurrentAppSection)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    @ViewBuilder
    private var currentAppRuleControls: some View {
        if let currentAppContext = viewModel.state.currentApplicationContext {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(currentAppContext.name)
                            .font(.system(size: 13, weight: .medium))
                        Text(currentAppContext.bundleIdentifier)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }

                Picker(L10n.settingsAppInputSource, selection: currentAppRuleBinding) {
                    Text(L10n.settingsUseGlobalTarget).tag("")
                    ForEach(viewModel.state.inputSources) { source in
                        Text(source.displayName).tag(source.id)
                    }
                }
                .labelsHidden()
            }
        } else {
            Text(L10n.settingsNoCurrentApp)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var appRulesList: some View {
        if viewModel.state.appRules.isEmpty {
            Text(L10n.settingsNoAppRules)
                .foregroundStyle(.secondary)
        } else {
            VStack(spacing: 0) {
                ForEach(viewModel.state.appRules) { rule in
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(rule.appName)
                                .font(.system(size: 13, weight: .medium))
                                .lineLimit(1)
                            Text(rule.bundleIdentifier)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 12)

                        Text(viewModel.inputSourceName(for: rule.inputSourceID))
                            .font(.caption.weight(.medium))
                            .lineLimit(1)

                        Button {
                            viewModel.removeAppInputSourceRule(for: rule.bundleIdentifier)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.vertical, 8)

                    if rule.id != viewModel.state.appRules.last?.id {
                        Divider()
                    }
                }
            }
        }
    }

    private var lockEnabledBinding: Binding<Bool> {
        Binding(
            get: { viewModel.state.isLockEnabled },
            set: { newValue in
                viewModel.setLockEnabled(newValue)
            }
        )
    }

    private var globalTargetBinding: Binding<String> {
        Binding(
            get: { viewModel.state.globalTargetInputSourceID ?? "" },
            set: { newValue in
                viewModel.selectGlobalInputSource(id: newValue.isEmpty ? nil : newValue)
            }
        )
    }

    private var currentAppRuleBinding: Binding<String> {
        Binding(
            get: { viewModel.state.currentAppRule?.inputSourceID ?? "" },
            set: { newValue in
                viewModel.selectCurrentAppInputSource(id: newValue.isEmpty ? nil : newValue)
            }
        )
    }

    private func settingsSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func exportLogs() {
        let panel = NSSavePanel()
        panel.title = L10n.settingsExportLogs
        panel.nameFieldStringValue = LogExporter.defaultFileName()
        panel.allowedContentTypes = [.plainText]
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        isExportingLogs = true
        logExportStatusText = L10n.settingsExportingLogs

        Task {
            do {
                let text = try await Task.detached(priority: .userInitiated) {
                    try LogExporter.makeLogText()
                }.value

                try await Task.detached(priority: .userInitiated) {
                    let didAccess = url.startAccessingSecurityScopedResource()
                    defer {
                        if didAccess {
                            url.stopAccessingSecurityScopedResource()
                        }
                    }
                    try text.write(to: url, atomically: true, encoding: .utf8)
                }.value

                await MainActor.run {
                    isExportingLogs = false
                    logExportStatusText = L10n.settingsExportLogsDone(url.lastPathComponent)
                }
            } catch {
                await MainActor.run {
                    isExportingLogs = false
                    logExportStatusText = L10n.settingsExportLogsFailed(error.localizedDescription)
                }
            }
        }
    }
}
