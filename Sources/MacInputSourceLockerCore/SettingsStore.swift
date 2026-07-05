import Foundation

public final class SettingsStore {
    private let defaults: UserDefaults
    private let isLockEnabledKey = "isLockEnabled"
    private let targetInputSourceIDKey = "targetInputSourceID"
    private let lastSelectedInputSourceIDKey = "lastSelectedInputSourceID"

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
}
