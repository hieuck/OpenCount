import SwiftUI

// MARK: - FeedbackView

/// Entry point for in-app feedback and support.
///
/// Presents three options:
///  1. **Send Feedback** — opens `FeedbackComposerView` (bug/feature/other)
///  2. **Report a Bug** — opens `FeedbackComposerView` pre-selected on Bug type
///  3. **Crash Report** — shown only when a pending crash report exists
///
/// This view is presented modally (e.g. from SettingsView or a toolbar button).
///
/// Requirements: 32.1–32.7
struct FeedbackView: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var networkMonitor: NetworkMonitor

    // MARK: - State

    @State private var isShowingComposer: Bool = false
    @State private var composerPreselectedType: FeedbackType = .other

    @State private var isShowingCrashConsent: Bool = false
    @State private var pendingCrashDescription: String = ""

    private var hasPendingCrash: Bool {
        FeedbackService.shared.hasPendingCrashReport
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                // MARK: Feedback options section
                Section {
                    feedbackOptionButton(
                        icon: "ant.fill",
                        iconColor: .red,
                        title: "Report a Bug",
                        subtitle: "Something not working? Let us know.",
                        type: .bug
                    )

                    feedbackOptionButton(
                        icon: "lightbulb.fill",
                        iconColor: .yellow,
                        title: "Request a Feature",
                        subtitle: "Have an idea to improve OpenCount?",
                        type: .featureRequest
                    )

                    feedbackOptionButton(
                        icon: "ellipsis.bubble.fill",
                        iconColor: .blue,
                        title: "General Feedback",
                        subtitle: "Share thoughts or comments.",
                        type: .other
                    )
                }

                // MARK: Crash report section (shown only when pending)
                if hasPendingCrash {
                    Section {
                        Button {
                            pendingCrashDescription = FeedbackService.shared.getPendingCrashDescription() ?? ""
                            isShowingCrashConsent = true
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.orange)
                                    .frame(width: 34, height: 34)
                                    .accessibilityHidden(true)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Send Crash Report")
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(.primary)
                                    Text("OpenCount crashed in a previous session.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .accessibilityHidden(true)
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Send crash report")
                        .accessibilityHint("Review and optionally send the crash report from the previous session.")
                    } header: {
                        Text("Crash Report")
                    } footer: {
                        Text("No personal data, photos, or session content is included.")
                    }
                }

                // MARK: Info section
                Section {
                    LabeledContent("App Version") {
                        Text(AppDiagnostics.current.appVersion)
                            .foregroundStyle(.secondary)
                    }
                    LabeledContent("Build") {
                        Text(AppDiagnostics.current.buildNumber)
                            .foregroundStyle(.secondary)
                    }
                    LabeledContent("iOS") {
                        Text(AppDiagnostics.current.iOSVersion)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Diagnostics")
                } footer: {
                    Text("Diagnostic information is automatically attached to feedback submissions to help the team reproduce issues.")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Feedback & Support")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityLabel("Close feedback panel")
                }
            }
            // Feedback composer sheet
            .sheet(isPresented: $isShowingComposer) {
                FeedbackComposerView(preselectedType: composerPreselectedType)
                    .environmentObject(networkMonitor)
            }
            // Crash report consent sheet
            .sheet(isPresented: $isShowingCrashConsent) {
                CrashReportConsentView(
                    crashDescription: pendingCrashDescription,
                    onConsent: {
                        isShowingCrashConsent = false
                        Task {
                            try? await FeedbackService.shared.submitCrashReport(
                                pendingCrashDescription,
                                userConsented: true
                            )
                        }
                    },
                    onDecline: {
                        isShowingCrashConsent = false
                    }
                )
            }
        }
    }

    // MARK: - Helpers

    /// Builds a tappable row that opens the composer pre-selected on the given type.
    private func feedbackOptionButton(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String,
        type: FeedbackType
    ) -> some View {
        Button {
            composerPreselectedType = type
            isShowingComposer = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(iconColor)
                    .frame(width: 34, height: 34)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityHint(subtitle)
    }
}

// MARK: - Preview

#Preview {
    FeedbackView()
        .environmentObject(NetworkMonitor())
}
