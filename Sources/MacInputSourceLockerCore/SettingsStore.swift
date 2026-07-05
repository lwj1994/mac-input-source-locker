import Foundation

public struct AppInputSourceRule: Codable, Equatable, Identifiable {
    public let bundleIdentifier: String
    public let appName: String
    public let inputSourceID: String
    public let updatedAt: Date

    public var id: String { bundleIdentifier }

    public init?(
        bundleIdentifier: String,
        appName: String,
        inputSourceID: String,
        updatedAt: Date = Date()
    ) {
        let normalizedBundleIdentifier = Self.normalized(bundleIdentifier)
        let normalizedInputSourceID = Self.normalized(inputSourceID)
        guard let normalizedBundleIdentifier, let normalizedInputSourceID else {
            return nil
        }

        self.bundleIdentifier = normalizedBundleIdentifier
        self.appName = Self.normalized(appName) ?? normalizedBundleIdentifier
        self.inputSourceID = normalizedInputSourceID
        self.updatedAt = updatedAt
    }

    private static func normalized(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

public final class SettingsStore {
    private let defaults: UserDefaults
    private let isLockEnabledKey = "isLockEnabled"
    private let targetInputSourceIDKey = "targetInputSourceID"
    private let lastSelectedInputSourceIDKey = "lastSelectedInputSourceID"
    private let appInputSourceRulesKey = "appInputSourceRules"

    public convenience init() {
        self.init(defaults: .standard)
    }

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    public var isLockEnabled: Bool {
        get {
            guard defaults.object(forKey: isLockEnabledKey) != nil else {
                return true
            }
            return defaults.bool(forKey: isLockEnabledKey)
        }
        set {
            defaults.set(newValue, forKey: isLockEnabledKey)
        }
    }

    public var targetInputSourceID: String? {
        get { normalizedString(forKey: targetInputSourceIDKey) }
        set { setNormalizedString(newValue, forKey: targetInputSourceIDKey) }
    }

    public var lastSelectedInputSourceID: String? {
        get { normalizedString(forKey: lastSelectedInputSourceIDKey) }
        set { setNormalizedString(newValue, forKey: lastSelectedInputSourceIDKey) }
    }

    public var appInputSourceRules: [AppInputSourceRule] {
        get {
            guard let data = defaults.data(forKey: appInputSourceRulesKey),
                  let rules = try? JSONDecoder().decode([AppInputSourceRule].self, from: data)
            else {
                return []
            }

            return rules.sorted()
        }
        set {
            let rules = newValue.deduplicatedAndSorted()
            guard !rules.isEmpty else {
                defaults.removeObject(forKey: appInputSourceRulesKey)
                return
            }

            if let data = try? JSONEncoder().encode(rules) {
                defaults.set(data, forKey: appInputSourceRulesKey)
            }
        }
    }

    public func appInputSourceRule(for bundleIdentifier: String?) -> AppInputSourceRule? {
        guard let bundleIdentifier = normalized(bundleIdentifier) else { return nil }
        return appInputSourceRules.first { $0.bundleIdentifier == bundleIdentifier }
    }

    public func setAppInputSourceRule(
        bundleIdentifier: String,
        appName: String,
        inputSourceID: String
    ) {
        guard let rule = AppInputSourceRule(
            bundleIdentifier: bundleIdentifier,
            appName: appName,
            inputSourceID: inputSourceID
        ) else {
            return
        }

        var rules = appInputSourceRules.filter { $0.bundleIdentifier != rule.bundleIdentifier }
        rules.append(rule)
        appInputSourceRules = rules
    }

    public func removeAppInputSourceRule(for bundleIdentifier: String) {
        guard let bundleIdentifier = normalized(bundleIdentifier) else { return }
        appInputSourceRules = appInputSourceRules.filter { $0.bundleIdentifier != bundleIdentifier }
    }

    private func normalizedString(forKey key: String) -> String? {
        guard let value = defaults.string(forKey: key) else {
            return nil
        }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func setNormalizedString(_ value: String?, forKey key: String) {
        guard let value else {
            defaults.removeObject(forKey: key)
            return
        }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            defaults.removeObject(forKey: key)
        } else {
            defaults.set(trimmed, forKey: key)
        }
    }

    private func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private extension Array where Element == AppInputSourceRule {
    func deduplicatedAndSorted() -> [AppInputSourceRule] {
        var rulesByBundleIdentifier: [String: AppInputSourceRule] = [:]
        for rule in self {
            rulesByBundleIdentifier[rule.bundleIdentifier] = rule
        }

        return Array(rulesByBundleIdentifier.values).sorted()
    }

    func sorted() -> [AppInputSourceRule] {
        sorted {
            let nameComparison = $0.appName.localizedCaseInsensitiveCompare($1.appName)
            if nameComparison == .orderedSame {
                return $0.bundleIdentifier.localizedCaseInsensitiveCompare($1.bundleIdentifier) == .orderedAscending
            }
            return nameComparison == .orderedAscending
        }
    }
}
