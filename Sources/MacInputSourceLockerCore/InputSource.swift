import Carbon
import Foundation

public struct InputSource: Equatable, Identifiable {
    public let id: String
    public let localizedName: String
    public let category: String?
    public let isEnabled: Bool
    public let isSelectCapable: Bool
    public let iconImageURL: URL?

    public init(
        id: String,
        localizedName: String,
        category: String?,
        isEnabled: Bool,
        isSelectCapable: Bool,
        iconImageURL: URL? = nil
    ) {
        self.id = id
        self.localizedName = localizedName
        self.category = category
        self.isEnabled = isEnabled
        self.isSelectCapable = isSelectCapable
        self.iconImageURL = iconImageURL
    }

    public var displayName: String {
        let trimmedName = localizedName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? id : trimmedName
    }

    public var isKeyboardInputSource: Bool {
        category == kTISCategoryKeyboardInputSource as String
    }
}
