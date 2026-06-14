import Foundation
import os.log

/// Centralized error logging utility with detailed context and debugging information.
/// Provides structured logging for error tracking, debugging, and analytics.
final class ErrorLogger {

    // MARK: - Singleton

    static let shared = ErrorLogger()

    // MARK: - Properties

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.opencount", category: "ErrorHandling")
    private let logQueue = DispatchQueue(label: "com.opencount.errorlogger", qos: .utility)

    // MARK: - Log Levels

    enum LogLevel {
        case debug
        case info
        case warning
        case error
        case critical

        var osLogType: OSLogType {
            switch self {
            case .debug: return .debug
            case .info: return .info
            case .warning: return .default
            case .error: return .error
            case .critical: return .fault
            }
        }
    }

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Methods

    /// Log an AppError with full context and recovery suggestions.
    func log(_ error: AppError, context: String, metadata: [String: Any]? = nil) {
        logQueue.async { [weak self] in
            guard let self = self else { return }
            let logMessage = self.formatErrorMessage(error, context: context, metadata: metadata)
            self.logger.error("\(logMessage, privacy: .public)")
            #if DEBUG
            print("🔴 ERROR: \(logMessage)")
            #endif
        }
    }

    /// Log a generic error with context.
    func log(_ error: Error, context: String, metadata: [String: Any]? = nil) {
        logQueue.async { [weak self] in
            guard let self = self else { return }
            let logMessage = """
            Context: \(context)
            Error: \(error.localizedDescription)
            Type: \(String(describing: type(of: error)))
            \(self.formatMetadata(metadata))
            """
            self.logger.error("\(logMessage, privacy: .public)")
            #if DEBUG
            print("🔴 ERROR: \(logMessage)")
            #endif
        }
    }

    /// Log a message at the specified level.
    func log(_ message: String, level: LogLevel = .info, context: String? = nil) {
        logQueue.async { [weak self] in
            guard let self = self else { return }
            let fullMessage = context.map { "\($0): \(message)" } ?? message

            switch level {
            case .debug:
                self.logger.debug("\(fullMessage, privacy: .public)")
            case .info:
                self.logger.info("\(fullMessage, privacy: .public)")
            case .warning:
                self.logger.warning("\(fullMessage, privacy: .public)")
            case .error:
                self.logger.error("\(fullMessage, privacy: .public)")
            case .critical:
                self.logger.critical("\(fullMessage, privacy: .public)")
            }

            #if DEBUG
            let emoji = self.emojiForLevel(level)
            print("\(emoji) \(fullMessage)")
            #endif
        }
    }

    /// Log a retry attempt with details.
    func logRetry(operation: String, attempt: Int, maxAttempts: Int, delay: TimeInterval, error: Error) {
        let message = """
        Retry attempt \(attempt)/\(maxAttempts) for \(operation)
        Delay: \(String(format: "%.2f", delay))s
        Error: \(error.localizedDescription)
        """
        log(message, level: .warning, context: "RetryPolicy")
    }

    // MARK: - Private Methods

    private func formatErrorMessage(_ error: AppError, context: String, metadata: [String: Any]?) -> String {
        var message = """
        Context: \(context)
        Error: \(error.errorDescription ?? "Unknown error")
        Recovery: \(error.recoverySuggestion ?? "No recovery suggestion")
        """
        if let metadata = metadata {
            message += "\n" + formatMetadata(metadata)
        }
        return message
    }

    private func formatMetadata(_ metadata: [String: Any]?) -> String {
        guard let metadata = metadata, !metadata.isEmpty else { return "" }
        let metadataString = metadata
            .map { key, value in "\(key): \(value)" }
            .joined(separator: "\n")
        return "Metadata:\n\(metadataString)"
    }

    private func emojiForLevel(_ level: LogLevel) -> String {
        switch level {
        case .debug: return "🔍"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "🔴"
        case .critical: return "💥"
        }
    }
}
