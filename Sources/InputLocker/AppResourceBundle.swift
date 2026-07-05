import Foundation

enum AppResourceBundle {
    #if SWIFT_PACKAGE
    static let current = Bundle.module
    #else
    static let current = Bundle.main
    #endif
}
