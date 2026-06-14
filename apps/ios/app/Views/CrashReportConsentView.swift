import SwiftUI

// MARK: - CrashReportConsentView

/// Shown on launch when a pending crash report is available.
/// Asks the user for consent before transmitting any crash data.
///
/// Requirements: 32.4, 32.5
struct CrashReportConsentView: View {

    // MARK: - Inputs

    let crashDescription: String
    let onConsent: () -> Void
    let onDecline: () -> Void

    // MARK: - Body

    var body: some View {
        VStack(spacing: 24) {
            // Icon
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 52))
                .foregroundStyle(.orange)
                .accessibilityHidden(true)

            // Title
            Text("OpenCount Crashed")
                .font(.title2.bold())
                .accessibilityAddTraits(.isHeader)

            // Summary
            VStack(spacing: 12) {
                Text("OpenCount detected a crash from the previous session.")
                    .font(.body)
                    .multilineTextAlignment(.center)

                // Crash description summary (truncated for readability)
                if !crashDescription.isEmpty {
                    Text(crashDescription.prefix(200) + (crashDescription.count > 200 ? "…" : ""))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.secondarySystemBackground))
                        )
                        .accessibilityLabel("Crash summary: \(crashDescription.prefix(200))")
                }
            }
            .padding(.horizontal)

            // Privacy explanation — Requirement 32.5
            Label {
                Text("No personal data, photos, or session content is included in crash reports. Only technical diagnostic information is sent.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            } icon: {
                Image(systemName: "lock.shield")
                    .foregroundStyle(.green)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal)
            .accessibilityLabel("Privacy note: No personal data is included in crash reports.")

            // Action buttons
            HStack(spacing: 16) {
                Button("Don't Send", role: .cancel) {
                    onDecline()
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Don't send crash report")
                .accessibilityHint("Dismisses the crash report without sending any data.")

                Button("Send Report") {
                    onConsent()
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("Send crash report")
                .accessibilityHint("Sends the crash report to help the OpenCount team fix the issue.")
            }
        }
        .padding(32)
        .presentationDetents([.medium])
    }
}

// MARK: - Preview

#Preview {
    CrashReportConsentView(
        crashDescription: "Signal: SIGSEGV\nException: EXC_BAD_ACCESS\n",
        onConsent: {},
        onDecline: {}
    )
}
