import Foundation

/// Defines retry strategy with exponential backoff for transient failures.
struct RetryPolicy {

    let maxAttempts: Int
    let initialDelay: TimeInterval
    let maxDelay: TimeInterval
    let backoffMultiplier: Double
    let jitterFactor: Double
    let shouldRetry: (Error) -> Bool

    // MARK: - Predefined Strategies

    static let networkTransient = RetryPolicy(
        maxAttempts: 5,
        initialDelay: 0.5,
        maxDelay: 30,
        backoffMultiplier: 2.0,
        jitterFactor: 0.1,
        shouldRetry: { error in
            let nsError = error as NSError
            return nsError.domain == NSURLErrorDomain ||
                   (nsError.domain == "com.opencount" && nsError.code == -1)
        }
    )

    static let memoryPressure = RetryPolicy(
        maxAttempts: 3,
        initialDelay: 1.0,
        maxDelay: 15,
        backoffMultiplier: 2.0,
        jitterFactor: 0.15,
        shouldRetry: { error in
            let appError = error as? AppError
            return appError == .aiInferenceOutOfMemory
        }
    )

    static let aiInference = RetryPolicy(
        maxAttempts: 3,
        initialDelay: 1.0,
        maxDelay: 20,
        backoffMultiplier: 1.5,
        jitterFactor: 0.2,
        shouldRetry: { error in
            guard let appError = error as? AppError else { return false }
            switch appError {
            case .aiInferenceFailed, .aiInferenceOutOfMemory:
                return true
            default:
                return false
            }
        }
    )

    static let fileOperation = RetryPolicy(
        maxAttempts: 4,
        initialDelay: 0.2,
        maxDelay: 10,
        backoffMultiplier: 2.0,
        jitterFactor: 0.1,
        shouldRetry: { error in
            guard let appError = error as? AppError else { return false }
            switch appError {
            case .imageFileMissing, .exportWriteFailure, .swiftDataSaveFailure:
                return true
            default:
                return false
            }
        }
    )

    static let icloudSync = RetryPolicy(
        maxAttempts: 4,
        initialDelay: 2.0,
        maxDelay: 60,
        backoffMultiplier: 1.5,
        jitterFactor: 0.2,
        shouldRetry: { error in
            let appError = error as? AppError
            return appError == .iCloudSyncFailure
        }
    )

    static let noRetry = RetryPolicy(
        maxAttempts: 1,
        initialDelay: 0,
        maxDelay: 0,
        backoffMultiplier: 1.0,
        jitterFactor: 0,
        shouldRetry: { _ in false }
    )

    // MARK: - Methods

    func delayForAttempt(_ attempt: Int) -> TimeInterval {
        let exponentialDelay = initialDelay * pow(backoffMultiplier, Double(attempt - 1))
        let cappedDelay = min(exponentialDelay, maxDelay)
        let jitter = cappedDelay * jitterFactor * Double.random(in: 0...1)
        return cappedDelay + jitter
    }

    func shouldRetryAttempt(_ attempt: Int, error: Error) -> Bool {
        return attempt < maxAttempts && shouldRetry(error)
    }
}
