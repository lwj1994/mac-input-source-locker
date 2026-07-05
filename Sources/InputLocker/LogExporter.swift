import Foundation
import OSLog

enum LogExporter {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "milu.inputlocker"
    private static let exportWindow = "2h"

    static func defaultFileName(now: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        return "InputLocker-Logs-\(formatter.string(from: now)).txt"
    }

    static func makeLogText() throws -> String {
        var sections = [diagnosticsHeader()]

        do {
            let commandLog = try makeCommandLogText()
            sections.append(commandLog.isEmpty ? "No InputLocker unified logs found." : commandLog)
        } catch {
            sections.append("log show failed: \(error.localizedDescription)")
            let fallbackLog = try makeCurrentProcessLogText()
            sections.append(fallbackLog.isEmpty ? "No current process OSLog entries found." : fallbackLog)
        }

        return sections.joined(separator: "\n\n")
    }

    private static func diagnosticsHeader() -> String {
        let processInfo = ProcessInfo.processInfo
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"

        return """
        InputLocker Log Export
        Generated At: \(Date().ISO8601Format())
        Bundle ID: \(subsystem)
        App Version: \(appVersion) (\(buildNumber))
        Process ID: \(processInfo.processIdentifier)
        macOS: \(processInfo.operatingSystemVersionString)
        Log Window: last \(exportWindow)
        Predicate: subsystem == "\(subsystem)"
        """
    }

    private static func makeCommandLogText() throws -> String {
        try runLogCommand(arguments: [
            "show",
            "--last", exportWindow,
            "--predicate", "subsystem == \"\(subsystem)\"",
            "--style", "compact",
            "--info",
            "--debug",
        ])
    }

    private static func runLogCommand(arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/log")
        process.arguments = arguments

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8) ?? ""
        let errorOutput = String(data: errorData, encoding: .utf8) ?? ""

        guard process.terminationStatus == 0 else {
            throw LogExportError.commandFailed(status: process.terminationStatus, stderr: errorOutput)
        }

        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func makeCurrentProcessLogText() throws -> String {
        let store = try OSLogStore(scope: .currentProcessIdentifier)
        let startDate = Date().addingTimeInterval(-2 * 60 * 60)
        let position = store.position(date: startDate)
        let entries = try store.getEntries(at: position)

        return entries.compactMap { entry -> String? in
            guard let logEntry = entry as? OSLogEntryLog,
                  logEntry.subsystem == subsystem
            else {
                return nil
            }

            return "\(logEntry.date.ISO8601Format()) \(logEntry.level.description) [\(logEntry.category)] \(logEntry.composedMessage)"
        }
        .joined(separator: "\n")
    }
}

private enum LogExportError: LocalizedError {
    case commandFailed(status: Int32, stderr: String)

    var errorDescription: String? {
        switch self {
        case let .commandFailed(status, stderr):
            let detail = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            if detail.isEmpty {
                return "/usr/bin/log exited with status \(status)"
            }
            return "/usr/bin/log exited with status \(status): \(detail)"
        }
    }
}

private extension OSLogEntryLog.Level {
    var description: String {
        switch self {
        case .debug:
            return "debug"
        case .info:
            return "info"
        case .notice:
            return "notice"
        case .error:
            return "error"
        case .fault:
            return "fault"
        case .undefined:
            return "undefined"
        @unknown default:
            return "unknown"
        }
    }
}
