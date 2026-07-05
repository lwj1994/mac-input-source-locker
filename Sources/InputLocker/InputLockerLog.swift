import Foundation
import OSLog

enum InputLockerLog {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "milu.inputlocker"

    static let app = Logger(subsystem: subsystem, category: "app")
    static let enforcer = Logger(subsystem: subsystem, category: "enforcer")
    static let floating = Logger(subsystem: subsystem, category: "floating-focus")
    static let inputSource = Logger(subsystem: subsystem, category: "input-source")
}
