import Foundation

/// Coordinates error recovery with automatic retry, logging, and user-friendly messaging.
final class ErrorRecoveryManager {

    static let shared = ErrorRecoveryManager()

    private let logger = ErrorLogger.shared
    private let recoveryQueue = DispatchQueue(label: "com.opencount.errorrecovery", qos: .userInitiated)

    private init() {}

    // MARK: - Public Methods

    /// Execute an operation with automatic retry on transient failures.
    func execute<T>(
        _ operation: @escaping () async throws -> T,
        policy: RetryPolicy = .noRetry,
        context: String,
        metadata: [String: Any]? = nil
    ) async throws -> T {
        var attempt = 1
        var lastError: Error?

        while attempt <= policy.maxAttempts {
            do {
                if attempt > 1 {
                    logger.log("Retry attempt \(attempt)/\(policy.maxAttempts)", level: .info, context: context)
                }

                let result = try await operation()

                if attempt > 1 {
                    logger.log("Operation succeeded on attempt \(attempt)", level: .info, context: context)
                }

                return result

            } catch {
                lastError = error

                if let appError = error as? AppError {
                    logger.log(appError, context: context, metadata: metadata)
                } else {
                    logger.log(error, context: context, metadata: metadata)
                }

                if policy.shouldRetryAttempt(attempt, error: error) {
                    let delay = policy.delayForAttempt(attempt)
                    logger.logRetry(
                        operation: context,
                        attempt: attempt,
                        maxAttempts: policy.maxAttempts,
                        delay: delay,
                        error: error
                    )

                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    attempt += 1
                } else {
                    logger.log("Operation failed permanently after \(attempt) attempt(s)", level: .error, context: context)
                    throw error
                }
            }
        }

        let finalError = lastError ?? AppError.aiInferenceFailed(reason: "Unknown error")
        logger.log("All retry attempts exhausted", level: .error, context: context)
        throw finalError
    }

    /// Execute an operation with automatic retry and return a Result type.
    func executeWithResult<T>(
        _ operation: @escaping () async throws -> T,
        policy: RetryPolicy = .noRetry,
        context: String,
        metadata: [String: Any]? = nil
    ) async -> Result<T, Error> {
        do {
            let result = try await execute(operation, policy: policy, context: context, metadata: metadata)
            return .success(result)
        } catch {
            return .failure(error)
        }
    }

    /// Get a user-friendly error message for presentation in UI.
    func userFriendlyMessage(for error: Error) -> (title: String, message: String, recovery: String?) {
        if let appError = error as? AppError {
            return (
                title: "Error",
                message: appError.errorDescription ?? "An error occurred",
                recovery: appError.recoverySuggestion
            )
        } else {
            return (
                title: "Error",
                message: error.localizedDescription,
                recovery: "Please try again. If the problem persists, contact support."
            )
        }
    }

    /// Determine the appropriate retry policy for an AppError.
    func recommendedPolicy(for error: AppError) -> RetryPolicy {
        switch error {
        case .aiInferenceOutOfMemory:
            return .memoryPressure
        case .aiInferenceFailed:
            return .aiInference
        case .coreMLModelLoadFailure:
            return .aiInference
        case .iCloudSyncFailure:
            return .icloudSync
        case .imageFileMissing, .exportWriteFailure, .swiftDataSaveFailure:
            return .fileOperation
        case .videoFrameExtractionFailure:
            return RetryPolicy(
                maxAttempts: 2,
                initialDelay: 0.5,
                maxDelay: 5,
                backoffMultiplier: 1.5,
                jitterFactor: 0.1,
                shouldRetry: { _ in true }
            )
        case .photoPermissionDenied, .cameraPermissionDenied:
            return .noRetry
        }
    }
}

// MARK: - Convenience Extensions

extension ErrorRecoveryManager {

    func executeAIOperation<T>(
        _ operation: @escaping () async throws -> T,
        context: String = "AI Operation",
        metadata: [String: Any]? = nil
    ) async throws -> T {
        try await execute(operation, policy: .aiInference, context: context, metadata: metadata)
    }

    func executeFileOperation<T>(
        _ operation: @escaping () async throws -> T,
        context: String = "File Operation",
        metadata: [String: Any]? = nil
    ) async throws -> T {
        try await execute(operation, policy: .fileOperation, context: context, metadata: metadata)
    }

    func executeSyncOperation<T>(
        _ operation: @escaping () async throws -> T,
        context: String = "iCloud Sync",
        metadata: [String: Any]? = nil
    ) async throws -> T {
        try await execute(operation, policy: .icloudSync, context: context, metadata: metadata)
    }
}
