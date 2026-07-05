import Carbon
import Foundation

public enum InputSourceSelectionError: Error, Equatable, LocalizedError {
    case notFound(String)
    case selectionFailed(id: String, status: OSStatus)

    public var errorDescription: String? {
        switch self {
        case .notFound(let id):
            "Input source not found: \(id)"
        case .selectionFailed(let id, let status):
            "Failed to select input source \(id): \(status)"
        }
    }
}

public final class InputSourceManager {
    public init() {}

    public func currentInputSource() -> InputSource? {
        let source = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        return makeInputSource(from: source)
    }

    public func selectableInputSources() -> [InputSource] {
        rawInputSources()
            .compactMap(makeInputSource(from:))
            .filter { $0.isEnabled && $0.isSelectCapable && $0.isKeyboardInputSource }
            .uniquedByID()
            .sorted {
                $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }
    }

    public func inputSource(id: String) -> InputSource? {
        rawInputSource(id: id).flatMap(makeInputSource(from:))
    }

    public func selectInputSource(id: String) throws {
        guard let source = rawInputSource(id: id) else {
            throw InputSourceSelectionError.notFound(id)
        }

        let status = TISSelectInputSource(source)
        guard status == noErr else {
            throw InputSourceSelectionError.selectionFailed(id: id, status: status)
        }
    }

    private func rawInputSource(id: String) -> TISInputSource? {
        let filter = [kTISPropertyInputSourceID as String: id] as CFDictionary
        guard let cfSources = TISCreateInputSourceList(filter, false)?.takeRetainedValue() else {
            return nil
        }

        let sources = cfSources as NSArray
        return sources.map { $0 as! TISInputSource }.first
    }

    private func rawInputSources() -> [TISInputSource] {
        guard let cfSources = TISCreateInputSourceList(nil, false)?.takeRetainedValue() else {
            return []
        }

        let sources = cfSources as NSArray
        return sources.map { $0 as! TISInputSource }
    }

    private func makeInputSource(from source: TISInputSource) -> InputSource? {
        guard let id = stringProperty(source, kTISPropertyInputSourceID) else {
            return nil
        }

        return InputSource(
            id: id,
            localizedName: stringProperty(source, kTISPropertyLocalizedName) ?? id,
            category: stringProperty(source, kTISPropertyInputSourceCategory),
            isEnabled: boolProperty(source, kTISPropertyInputSourceIsEnabled) ?? false,
            isSelectCapable: boolProperty(source, kTISPropertyInputSourceIsSelectCapable) ?? false,
            iconImageURL: urlProperty(source, kTISPropertyIconImageURL)
        )
    }

    private func stringProperty(_ source: TISInputSource, _ key: CFString) -> String? {
        guard let value = TISGetInputSourceProperty(source, key) else {
            return nil
        }
        return Unmanaged<CFString>.fromOpaque(value).takeUnretainedValue() as String
    }

    private func boolProperty(_ source: TISInputSource, _ key: CFString) -> Bool? {
        guard let value = TISGetInputSourceProperty(source, key) else {
            return nil
        }
        return CFBooleanGetValue(Unmanaged<CFBoolean>.fromOpaque(value).takeUnretainedValue())
    }

    private func urlProperty(_ source: TISInputSource, _ key: CFString) -> URL? {
        guard let value = TISGetInputSourceProperty(source, key) else {
            return nil
        }
        return Unmanaged<CFURL>.fromOpaque(value).takeUnretainedValue() as URL
    }
}

private extension Array where Element == InputSource {
    func uniquedByID() -> [InputSource] {
        var seenIDs = Set<String>()
        return filter { source in
            guard !seenIDs.contains(source.id) else { return false }
            seenIDs.insert(source.id)
            return true
        }
    }
}
