import Foundation

enum AppResourceBundle {
    private static let resourceBundleName = "MacInputSourceLocker_InputLocker.bundle"

    static let current: Bundle = {
        findResourceBundle() ?? Bundle.main
    }()

    private static func findResourceBundle() -> Bundle? {
        var candidates: [URL] = []

        if let resourceURL = Bundle.main.resourceURL {
            candidates.append(resourceURL.appendingPathComponent(resourceBundleName))
        }

        candidates.append(
            Bundle.main.bundleURL
                .appendingPathComponent("Contents")
                .appendingPathComponent("Resources")
                .appendingPathComponent(resourceBundleName)
        )
        candidates.append(Bundle.main.bundleURL.appendingPathComponent(resourceBundleName))

        if let executableURL = Bundle.main.executableURL {
            let executableDirectory = executableURL.deletingLastPathComponent()
            candidates.append(executableDirectory.appendingPathComponent(resourceBundleName))
            candidates.append(
                executableDirectory
                    .deletingLastPathComponent()
                    .appendingPathComponent("Resources")
                    .appendingPathComponent(resourceBundleName)
            )
        }

        for candidate in candidates {
            if let bundle = Bundle(url: candidate.standardizedFileURL) {
                return bundle
            }
        }

        return nil
    }
}
