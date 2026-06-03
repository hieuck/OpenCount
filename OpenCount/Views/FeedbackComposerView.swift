import SwiftUI
import UIKit

// MARK: - FeedbackComposerView

/// In-app feedback composer.
/// Allows the user to submit bug reports, feature requests, or general feedback
/// directly from the app, with optional screenshot attachment.
///
/// Requirements: 32.1, 32.2, 32.3
struct FeedbackComposerView: View {

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var networkMonitor: NetworkMonitor

    // MARK: - Init

    init(preselectedType: FeedbackType = .bug) {
        _selectedType = State(initialValue: preselectedType)
    }

    // MARK: - Form state

    @State private var selectedType: FeedbackType
    @State private var description: String = ""
    @State private var screenshotImage: UIImage?
    @State private var isSubmitting: Bool = false
    @State private var isSubmitted: Bool = false
    @State private var submitError: String?

    /// Drives the OfflineFeatureAlert when the user taps Submit while offline.
    @State private var isShowingOfflineAlert: Bool = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                typePicker
                descriptionSection
                screenshotSection
                diagnosticsSection
                submitSection
            }
            .navigationTitle("Send Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityLabel("Cancel feedback")
                        .accessibilityHint("Dismiss the feedback form without submitting.")
                }
            }
            // Offline gate — Requirement 33.4
            .offlineFeatureAlert(isPresented: $isShowingOfflineAlert, featureName: "Send Feedback")
        }
    }

    // MARK: - Sections

    /// Type picker: Bug, Feature Request, Other — Requirement 32.1
    private var typePicker: some View {
        Section("Feedback Type") {
            ForEach(FeedbackType.allCases) { type in
                Button {
                    selectedType = type
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: type.systemImage)
                            .foregroundStyle(iconColor(for: type))
                            .frame(width: 24)
                            .accessibilityHidden(true)
                        Text(type.rawValue)
                            .foregroundStyle(.primary)
                        Spacer()
                        if selectedType == type {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.accent)
                                .accessibilityHidden(true)
                        }
                    }
                }
                .accessibilityLabel(type.rawValue)
                .accessibilityHint("Select \(type.rawValue) as the feedback type.")
                .accessibilityAddTraits(selectedType == type ? .isSelected : [])
            }
        }
    }

    /// Multiline description editor — Requirement 32.1
    private var descriptionSection: some View {
        Section("Description") {
            TextEditor(text: $description)
                .frame(minHeight: 80)
                .accessibilityLabel("Feedback description")
                .accessibilityHint("Describe the bug, feature request, or other feedback in detail.")
        }
    }

    /// Screenshot attachment with thumbnail and remove button — Requirement 32.3
    private var screenshotSection: some View {
        Section("Attachment") {
            if let screenshot = screenshotImage {
                // Thumbnail with remove button
                HStack(alignment: .top, spacing: 12) {
                    Image(uiImage: screenshot)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 120)
                        .cornerRadius(8)
                        .accessibilityLabel("Attached screenshot preview")

                    Spacer()

                    Button(role: .destructive) {
                        screenshotImage = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("Remove screenshot")
                    .accessibilityHint("Removes the attached screenshot from your feedback.")
                }
                .padding(.vertical, 4)
            } else {
                Button {
                    screenshotImage = captureScreenshot()
                } label: {
                    Label("Attach Screenshot", systemImage: "camera.viewfinder")
                }
                .accessibilityLabel("Attach screenshot")
                .accessibilityHint("Captures the current screen and attaches it to your feedback.")
            }
        }
    }

    /// Auto-attached diagnostics info — Requirement 32.2
    private var diagnosticsSection: some View {
        let diag = AppDiagnostics.current
        return Section("Diagnostics (auto-attached)") {
            LabeledContent("iOS Version", value: diag.iOSVersion)
            LabeledContent("Device", value: diag.deviceModel)
            LabeledContent("App Version", value: "\(diag.appVersion) (\(diag.buildNumber))")
        }
        .accessibilityLabel("Diagnostic information that will be attached to your feedback")
    }

    /// Submit button with loading and success/error states — Requirement 32.2
    private var submitSection: some View {
        Section {
            if isSubmitted {
                Label("Feedback submitted — thank you!", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .accessibilityLabel("Feedback submitted successfully")
            } else {
                Button {
                    guard networkMonitor.isConnected else {
                        isShowingOfflineAlert = true
                        return
                    }
                    submitFeedback()
                } label: {
                    HStack {
                        Spacer()
                        if isSubmitting {
                            ProgressView()
                                .padding(.trailing, 8)
                                .accessibilityLabel("Submitting feedback…")
                        }
                        Text(isSubmitting ? "Submitting…" : "Submit Feedback")
                            .font(.headline)
                        Spacer()
                    }
                }
                .disabled(isSubmitting || description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityLabel("Submit feedback")
                .accessibilityHint("Sends your feedback to the OpenCount development team.")
            }

            if let error = submitError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .accessibilityLabel("Submission error: \(error)")
            }
        }
    }

    // MARK: - Actions

    private func submitFeedback() {
        isSubmitting = true
        submitError = nil

        let feedback = UserFeedback(
            type: selectedType,
            description: description,
            screenshotData: screenshotImage?.jpegData(compressionQuality: 0.7),
            diagnostics: .current
        )

        Task {
            do {
                try await FeedbackService.shared.submitFeedback(feedback)
                await MainActor.run {
                    isSubmitting = false
                    isSubmitted = true
                }
                // Auto-dismiss after 2 seconds
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                await MainActor.run { dismiss() }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    submitError = "Submission failed. Please check your internet connection and try again."
                }
            }
        }
    }

    /// Captures the current window hierarchy as a UIImage.
    /// Uses `UIApplication.shared.connectedScenes` — Requirement 32.3
    private func captureScreenshot() -> UIImage? {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first,
              let window = windowScene.windows.first else { return nil }

        let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
        return renderer.image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: false)
        }
    }

    // MARK: - Helpers

    private func iconColor(for type: FeedbackType) -> Color {
        switch type {
        case .bug: return .red
        case .featureRequest: return .yellow
        case .other: return .blue
        }
    }
}

// MARK: - Preview

#Preview {
    FeedbackComposerView()
        .environmentObject(NetworkMonitor())
}
