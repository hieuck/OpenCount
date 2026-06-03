import Foundation

/// Typed error cases for OpenCount, surfaced through ViewModel's @Published var error: AppError?
/// Each case includes user-friendly messages and recovery suggestions for comprehensive error handling.
enum AppError: LocalizedError {
    case aiInferenceOutOfMemory
    case aiInferenceFailed(reason: String)
    case coreMLModelLoadFailure
    case photoPermissionDenied
    case cameraPermissionDenied
    case iCloudSyncFailure
    case imageFileMissing
    case swiftDataSaveFailure
    case exportWriteFailure(reason: String)
    case videoFrameExtractionFailure

    // MARK: - User-Facing Messages

    var errorDescription: String? {
        switch self {
        case .aiInferenceOutOfMemory:
            return "AI inference failed due to insufficient memory. Please try again or switch to manual counting."
        case .aiInferenceFailed(let reason):
            return "AI inference failed: \(reason)"
        case .coreMLModelLoadFailure:
            return "Failed to load the AI model. AI features are temporarily unavailable."
        case .photoPermissionDenied:
            return "Photo Library access is required to import images. Please grant permission in Settings."
        case .cameraPermissionDenied:
            return "Camera access is required for this feature. Please grant permission in Settings."
        case .iCloudSyncFailure:
            return "iCloud sync encountered an error. Your data is safe locally and will sync when connectivity is restored."
        case .imageFileMissing:
            return "The image file could not be found. It may have been moved or deleted."
        case .swiftDataSaveFailure:
            return "Failed to save your session. Please try again."
        case .exportWriteFailure(let reason):
            return "Export failed: \(reason)"
        case .videoFrameExtractionFailure:
            return "Failed to extract a video frame. The frame will be skipped."
        }
    }

    // MARK: - Recovery Suggestions

    var recoverySuggestion: String? {
        switch self {
        case .aiInferenceOutOfMemory:
            return "Close other apps to free memory, then retry. You can also use manual tap-to-count."
        case .aiInferenceFailed:
            return "Check that the image is valid and try again."
        case .coreMLModelLoadFailure:
            return "Restart the app. If the problem persists, reinstall OpenCount."
        case .photoPermissionDenied, .cameraPermissionDenied:
            return "Open iOS Settings > Privacy & Security to grant permission."
        case .iCloudSyncFailure:
            return "Check your internet connection and iCloud account status."
        case .imageFileMissing:
            return "Re-import the image from your Photos Library or Files app."
        case .swiftDataSaveFailure:
            return "Ensure the device has sufficient storage and try again."
        case .exportWriteFailure:
            return "Ensure the device has sufficient storage and try again."
        case .videoFrameExtractionFailure:
            return "Try a different video format or re-import the video."
        }
    }

    // MARK: - Categorization for Error Handling

    /// Determines if this error is retryable (transient).
    var isRetryable: Bool {
        switch self {
        case .aiInferenceOutOfMemory, .aiInferenceFailed, .iCloudSyncFailure,
             .swiftDataSaveFailure, .exportWriteFailure, .videoFrameExtractionFailure:
            return true
        case .coreMLModelLoadFailure, .photoPermissionDenied, .cameraPermissionDenied,
             .imageFileMissing:
            return false
        }
    }

    /// Determines if user action is required to recover (e.g., permission grants).
    var requiresUserAction: Bool {
        switch self {
        case .photoPermissionDenied, .cameraPermissionDenied, .imageFileMissing:
            return true
        default:
            return false
        }
    }

    /// Severity level for analytics and reporting.
    enum Severity {
        case low
        case medium
        case high
        case critical
    }

    var severity: Severity {
        switch self {
        case .videoFrameExtractionFailure:
            return .low
        case .aiInferenceFailed, .exportWriteFailure, .swiftDataSaveFailure:
            return .medium
        case .aiInferenceOutOfMemory, .iCloudSyncFailure, .imageFileMissing:
            return .high
        case .coreMLModelLoadFailure, .photoPermissionDenied, .cameraPermissionDenied:
            return .critical
        }
    }

    /// Whether this error should trigger a user-visible alert.
    var shouldShowAlert: Bool {
        switch self {
        case .videoFrameExtractionFailure:
            return false  // Handled silently
        default:
            return true
        }
    }
}
