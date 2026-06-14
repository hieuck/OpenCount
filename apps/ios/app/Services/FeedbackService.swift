import Foundation
import MetricKit
import UIKit

// MARK: - FeedbackType

enum FeedbackType: String, Codable, CaseIterable, Identifiable {
    case bug = "Bug"
    case featureRequest = "Feature Request"
    case other = "Other"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .bug: return "ant.fill"
        case .featureRequest: return "lightbulb.fill"
        case .other: return "ellipsis.bubble.fill"
        }
    }
}

// MARK: - AppDiagnostics

struct AppDiagnostics: Codable {
    let iOSVersion: String
    let deviceModel: String
    let appVersion: String
    let buildNumber: String

    static var current: AppDiagnostics {
        AppDiagnostics(
            iOSVersion: UIDevice.current.systemVersion,
            deviceModel: UIDevice.current.model,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
            buildNumber: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        )
    }
}

// MARK: - UserFeedback

struct UserFeedback: Codable {
    let type: FeedbackType
    let description: String
    let screenshotData: Data?
    let diagnostics: AppDiagnostics
}

// MARK: - FeedbackServiceProtocol

protocol FeedbackServiceProtocol {
    func submitFeedback(_ feedback: UserFeedback) async throws
}

// MARK: - FeedbackService

/// Handles in-app feedback submission and MetricKit crash reporting.
///
/// Feedback is submitted to the project's GitHub Issues API via a background
/// URLSession task. Crash reports are collected via MXMetricManager.
///
/// Requirements: 32.1–32.7
final class FeedbackService: NSObject, FeedbackServiceProtocol, MXMetricManagerSubscriber {

    // MARK: - Singleton

    static let shared = FeedbackService()

    // MARK: - UserDefaults keys

    private static let optInKey = "diagnosticsOptIn"
    private static let pendingCrashKey = "pendingCrashReport"

    // MARK: - Published crash report

    /// Set to true on launch if a pending crash report is available.
    @Published var hasPendingCrashReport: Bool = false
    private var pendingCrashDescription: String?

    // MARK: - Init

    override init() {
        super.init()
        MXMetricManager.shared.add(self)
        checkForPendingCrash()
    }

    // MARK: - Opt-in preference

    /// Whether the user has opted in to diagnostic data collection.
    /// Requirement 32.6
    var isDiagnosticsOptIn: Bool {
        get { UserDefaults.standard.bool(forKey: Self.optInKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.optInKey) }
    }

    // MARK: - Feedback submission

    /// Submits user feedback to GitHub Issues API.
    /// Requirement 32.2: send feedback via background URLSession.
    func submitFeedback(_ feedback: UserFeedback) async throws {
        // Build the issue body
        let body = buildIssueBody(feedback)

        // GitHub Issues API endpoint (public repo)
        // In production, replace with actual repo URL or webhook
        let urlString = "https://api.github.com/repos/opencount-app/opencount/issues"
        guard let url = URL(string: urlString) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30 // Requirement 33.5: 30-second timeout

        let payload: [String: Any] = [
            "title": "[\(feedback.type.rawValue)] \(String(feedback.description.prefix(80)))",
            "body": body,
            "labels": [feedback.type.rawValue.lowercased().replacingOccurrences(of: " ", with: "-")]
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        // Use background URLSession for non-blocking submission
        let config = URLSessionConfiguration.background(withIdentifier: "com.opencount.feedback")
        config.timeoutIntervalForRequest = 30
        let session = URLSession(configuration: config)

        // Fire-and-forget: we don't require a response for feedback
        _ = try? await session.data(for: request)
    }

    // MARK: - Crash report submission

    /// Submits a crash report with user consent.
    /// Requirement 32.4, 32.5
    func submitCrashReport(_ description: String, userConsented: Bool) async throws {
        guard userConsented, isDiagnosticsOptIn else { return }
        let feedback = UserFeedback(
            type: .bug,
            description: "Crash Report:\n\(description)",
            screenshotData: nil,
            diagnostics: .current
        )
        try await submitFeedback(feedback)
        clearPendingCrash()
    }

    // MARK: - MXMetricManagerSubscriber

    /// Called by MetricKit when crash diagnostics are available.
    /// Requirement 32.4: collect crash logs via MetricKit.
    func didReceive(_ payloads: [MXMetricPayload]) {
        // Metric payloads (performance data) — not crash reports
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        guard isDiagnosticsOptIn else { return }
        for payload in payloads {
            if let crashPayloads = payload.crashDiagnostics, !crashPayloads.isEmpty {
                let description = crashPayloads.map { crash in
                    let signal = crash.signal.map { Int(truncating: $0) } ?? -1
                    let exception = crash.exceptionType?.stringValue ?? "unknown"
                    return "Signal: \(signal)\nException: \(exception)\n"
                }.joined(separator: "\n---\n")

                savePendingCrash(description)
                DispatchQueue.main.async {
                    self.hasPendingCrashReport = true
                    self.pendingCrashDescription = description
                }
            }
        }
    }

    // MARK: - Pending crash helpers

    func getPendingCrashDescription() -> String? {
        pendingCrashDescription ?? UserDefaults.standard.string(forKey: Self.pendingCrashKey)
    }

    private func checkForPendingCrash() {
        if let saved = UserDefaults.standard.string(forKey: Self.pendingCrashKey) {
            pendingCrashDescription = saved
            hasPendingCrashReport = true
        }
    }

    private func savePendingCrash(_ description: String) {
        UserDefaults.standard.set(description, forKey: Self.pendingCrashKey)
    }

    private func clearPendingCrash() {
        UserDefaults.standard.removeObject(forKey: Self.pendingCrashKey)
        hasPendingCrashReport = false
        pendingCrashDescription = nil
    }

    // MARK: - Private helpers

    private func buildIssueBody(_ feedback: UserFeedback) -> String {
        """
        ## Feedback

        **Type:** \(feedback.type.rawValue)

        **Description:**
        \(feedback.description)

        ## Diagnostics

        | Field | Value |
        |-------|-------|
        | iOS Version | \(feedback.diagnostics.iOSVersion) |
        | Device | \(feedback.diagnostics.deviceModel) |
        | App Version | \(feedback.diagnostics.appVersion) |
        | Build | \(feedback.diagnostics.buildNumber) |

        *Submitted via OpenCount in-app feedback*
        """
    }
}
