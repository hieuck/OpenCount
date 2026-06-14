import SwiftUI

/// Settings screen for customizing app-wide defaults.
///
/// Requirements: 17.1, 17.2, 17.3, 17.4, 17.5, 29.3, 29.4
struct SettingsView: View {

    // MARK: - Environment

    @EnvironmentObject private var syncViewModel: iCloudSyncViewModel
    @Environment(\.dismiss) private var dismiss

    // MARK: - AppStorage (persisted via UserDefaults — Req 17.3)

    /// Default marker size in points (16–48 pt). Req 17.1, 17.2
    @AppStorage("defaultMarkerSize") var defaultMarkerSize: Double = 24

    /// Default marker color stored as a hex string. Req 17.1
    @AppStorage("defaultMarkerColorHex") var defaultMarkerColorHex: String = "#FF5733"

    /// Default AI confidence threshold (0.1–0.9). Req 17.1
    @AppStorage("defaultConfidenceThreshold") var defaultConfidenceThreshold: Double = 0.5

    /// Default export format raw value. Req 17.1
    @AppStorage("defaultExportFormat") var defaultExportFormat: String = ExportFormat.csv.rawValue

    /// Whether to show a confirmation prompt before deleting a marker. Req 17.5
    @AppStorage("confirmBeforeDeleteMarker") var confirmBeforeDeleteMarker: Bool = false

    // MARK: - Local UI state

    @State private var isShowingResetConfirmation = false
    @State private var isShowingFeedback = false
    @State private var isShowingOnboarding = false
    @State private var isShowingRestoreSampleConfirmation = false
    @State private var isShowingPerformanceDashboard = false
    @State private var isShowingBackupShare = false
    @State private var backupURL: URL? = nil
    @State private var versionTapCount = 0

    // MARK: - Onboarding replay (Req 29.3)

    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = true

    // MARK: - Local API Server (Req 55)

    @AppStorage("localAPIServerEnabled") private var localAPIServerEnabled: Bool = false

    // MARK: - Computed helpers

    private var markerColor: Color {
        Color(hex: defaultMarkerColorHex) ?? .red
    }

    private var selectedExportFormat: ExportFormat {
        ExportFormat(rawValue: defaultExportFormat) ?? .csv
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                countingSection
                aiDetectionSection
                exportSection
                iCloudSection
                backupSection
                feedbackSection
                developerSection
                aboutSection
                resetSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityLabel("Done")
                        .accessibilityHint("Close the Settings screen.")
                }
            }
            .sheet(isPresented: $isShowingFeedback) {
                FeedbackComposerView()
            }
            .fullScreenCover(isPresented: $isShowingOnboarding) {
                OnboardingView()
            }
            .sheet(isPresented: $isShowingPerformanceDashboard) {
                PerformanceDashboardView()
            }
            .sheet(isPresented: $isShowingBackupShare) {
                if let url = backupURL {
                    ShareSheet(activityItems: [url])
                        .ignoresSafeArea()
                }
            }
            // Reset confirmation alert — Req 17.4
            .alert("Reset to Defaults", isPresented: $isShowingResetConfirmation) {
                Button("Reset", role: .destructive) {
                    resetToDefaults()
                }
                .accessibilityLabel("Confirm reset to defaults")
                Button("Cancel", role: .cancel) {}
                    .accessibilityLabel("Cancel reset")
            } message: {
                Text("All settings will be restored to their factory defaults. This cannot be undone.")
            }
            // Restore sample session confirmation — Req 29.4
            .alert("Restore Sample Session", isPresented: $isShowingRestoreSampleConfirmation) {
                Button("Restore") {
                    Task { await SampleSessionSeeder.seedIfNeeded(force: true) }
                }
                .accessibilityLabel("Confirm restore sample session")
                Button("Cancel", role: .cancel) {}
                    .accessibilityLabel("Cancel restore")
            } message: {
                Text("A new sample session will be added to your session list. Any existing sample session will not be removed.")
            }
        }
    }

    // MARK: - Sections

    /// Counting preferences: marker size, color, and delete confirmation.
    private var countingSection: some View {
        Section {
            // Marker size slider — Req 17.1, 17.2
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Default Marker Size")
                    Spacer()
                    Text("\(Int(defaultMarkerSize)) pt")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Slider(value: $defaultMarkerSize, in: 16...48, step: 1)
                    .accessibilityLabel("Default marker size")
                    .accessibilityValue("\(Int(defaultMarkerSize)) points")
                    .accessibilityHint("Drag to set the default size for new count markers, between 16 and 48 points.")
            }

            // Marker color picker — Req 17.1
            ColorPicker(
                "Default Marker Color",
                selection: Binding(
                    get: { markerColor },
                    set: { newColor in
                        defaultMarkerColorHex = newColor.hexString ?? "#FF5733"
                    }
                ),
                supportsOpacity: false
            )
            .accessibilityLabel("Default marker color")
            .accessibilityHint("Choose the default color for new count markers.")

            // Confirm before delete toggle — Req 17.5
            Toggle(isOn: $confirmBeforeDeleteMarker) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Confirm Before Delete Marker")
                    Text("Show a prompt before removing a count marker.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityLabel("Confirm before delete marker")
            .accessibilityHint("When enabled, a confirmation prompt appears before any count marker is removed.")
        } header: {
            Text("Counting")
        }
    }

    /// AI detection preferences: confidence threshold and model management.
    private var aiDetectionSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Confidence Threshold")
                    Spacer()
                    Text(String(format: "%.1f", defaultConfidenceThreshold))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Slider(value: $defaultConfidenceThreshold, in: 0.1...0.9, step: 0.05)
                    .accessibilityLabel("Default AI confidence threshold")
                    .accessibilityValue(String(format: "%.1f", defaultConfidenceThreshold))
                    .accessibilityHint("Drag to set the minimum confidence score for AI detections, between 0.1 and 0.9.")
                HStack {
                    Text("Low")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("High")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            NavigationLink {
                CustomModelView()
            } label: {
                Label("AI Models", systemImage: "cpu")
            }
            .accessibilityLabel("Manage AI models")
            .accessibilityHint("Import custom CoreML models or switch between built-in and imported models.")
        } header: {
            Text("AI Detection")
        } footer: {
            Text("Detections below this threshold are discarded. A lower value includes more results; a higher value requires greater certainty.")
        }
    }

    /// Export preferences: default format picker.
    private var exportSection: some View {
        Section {
            Picker("Default Export Format", selection: Binding(
                get: { selectedExportFormat },
                set: { defaultExportFormat = $0.rawValue }
            )) {
                ForEach(ExportFormat.allCases) { format in
                    Label(format.rawValue, systemImage: format.systemImage)
                        .tag(format)
                }
            }
            .accessibilityLabel("Default export format")
            .accessibilityHint("Choose the format used when exporting counting results.")
        } header: {
            Text("Export")
        }
    }

    /// iCloud backup export/import section.
    private var backupSection: some View {
        Section {
            Button {
                exportBackup()
            } label: {
                Label("Export Backup", systemImage: "arrow.down.doc.fill")
            }
            .accessibilityLabel("Export all sessions as backup file")
            .accessibilityHint("Creates a .opencount backup file you can save to Files or share.")
        } header: {
            Text("Backup")
        } footer: {
            Text("Export all sessions as a .opencount file for safekeeping or transfer to another device.")
        }
    }

    private func exportBackup() {
        Task {
            let sessions = (try? await StorageService.shared.fetchAllSessions()) ?? []
            if let url = try? syncViewModel.exportBackup(sessions: sessions) {
                await MainActor.run {
                    backupURL = url
                    isShowingBackupShare = true
                }
            }
        }
    }

    /// iCloud sync toggle and availability status.
    private var iCloudSection: some View {
        Section {
            Toggle(isOn: $syncViewModel.isSyncEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("iCloud Sync")
                    if syncViewModel.isICloudAvailable {
                        Text("iCloud is available.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Sign in to iCloud in Settings to enable sync.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .disabled(!syncViewModel.isICloudAvailable)
            .accessibilityLabel("iCloud Sync")
            .accessibilityHint(
                syncViewModel.isICloudAvailable
                    ? "Toggle to enable or disable iCloud synchronisation of your sessions."
                    : "iCloud is not available. Sign in to iCloud in the iOS Settings app to enable sync."
            )

            // Sync status row
            HStack {
                Text("Status")
                Spacer()
                syncStatusLabel
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("iCloud sync status: \(syncStatusText)")
        } header: {
            Text("iCloud Sync")
        }
    }

    /// App version and open-source information.
    private var aboutSection: some View {
        Section {
            HStack {
                Text("Version")
                Spacer()
                Text(appVersion)
                    .foregroundStyle(.secondary)
            }
            // Hidden 7-tap to unlock Performance Dashboard — Requirement 51 (Req 40)
            .onTapGesture {
                versionTapCount += 1
                if versionTapCount >= 7 {
                    versionTapCount = 0
                    isShowingPerformanceDashboard = true
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("App version \(appVersion)")

            // Replay tutorial — Requirement 29.3
            Button {
                hasSeenOnboarding = false
                isShowingOnboarding = true
            } label: {
                Label("Replay Tutorial", systemImage: "play.circle")
            }
            .accessibilityLabel("Replay onboarding tutorial")
            .accessibilityHint("Shows the introduction tutorial again.")

            // Restore sample session — Requirement 29.4
            Button {
                isShowingRestoreSampleConfirmation = true
            } label: {
                Label("Restore Sample Session", systemImage: "arrow.counterclockwise.circle")
            }
            .accessibilityLabel("Restore sample session")
            .accessibilityHint("Adds the pre-loaded demo session back to your session list.")

            // GitHub link — Requirement 32.7
            Link(destination: URL(string: "https://github.com/opencount-app/opencount")!) {
                Label("View on GitHub", systemImage: "link")
            }
            .accessibilityLabel("View OpenCount on GitHub")

            HStack {
                Text("Open Source")
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("OpenCount is open source")
            .accessibilityHint("OpenCount is free and open-source with no paywalls or subscriptions.")
        } header: {
            Text("About")
        } footer: {
            Text("OpenCount is free and open-source. No paywalls, no subscriptions, no license requirements.")
        }
    }

    /// Developer tools section — Local REST API toggle.
    /// Requirement 55 (Req 44)
    private var developerSection: some View {
        Section {
            Toggle(isOn: $localAPIServerEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Local REST API")
                    Text("Exposes session data at http://127.0.0.1:47200")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityLabel("Local REST API")
            .accessibilityHint("When enabled, a local HTTP server on port 47200 exposes session data for automation.")

            if localAPIServerEnabled {
                Label("Server running at http://127.0.0.1:47200", systemImage: "network")
                    .font(.caption)
                    .foregroundStyle(.green)
                    .accessibilityLabel("Local API server is running at port 47200")
            }
        } header: {
            Text("Developer Tools")
        } footer: {
            Text("The local API server binds only to localhost and is never accessible from external networks.")
        }
    }

    /// Feedback and diagnostics section.
    /// Requirements: 32.1–32.7
    private var feedbackSection: some View {
        Section {
            Button {
                isShowingFeedback = true
            } label: {
                Label("Send Feedback", systemImage: "envelope")
            }
            .accessibilityLabel("Send feedback")
            .accessibilityHint("Report a bug or suggest a feature.")

            Toggle(isOn: Binding(
                get: { FeedbackService.shared.isDiagnosticsOptIn },
                set: { FeedbackService.shared.isDiagnosticsOptIn = $0 }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Share Diagnostics")
                    Text("Helps improve OpenCount. No personal data is collected.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityLabel("Share diagnostics")
            .accessibilityHint("When enabled, crash reports and diagnostic data may be shared to help improve the app.")
        } header: {
            Text("Feedback & Privacy")
        }
    }

    /// Reset to defaults button.
    private var resetSection: some View {
        Section {
            Button(role: .destructive) {
                isShowingResetConfirmation = true
            } label: {
                HStack {
                    Spacer()
                    Text("Reset to Defaults")
                    Spacer()
                }
            }
            .accessibilityLabel("Reset to defaults")
            .accessibilityHint("Restores all settings to their factory defaults. A confirmation prompt will appear.")
        }
    }

    // MARK: - Sync status helpers

    private var syncStatusLabel: some View {
        Group {
            switch syncViewModel.syncStatus {
            case .idle:
                Text("Idle")
                    .foregroundStyle(.secondary)
            case .syncing:
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Syncing…")
                        .foregroundStyle(.secondary)
                }
            case .synced(let date):
                Text("Synced \(date.formatted(.relative(presentation: .named)))")
                    .foregroundStyle(.green)
            case .failed(let message):
                Text("Failed: \(message)")
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }
        }
    }

    private var syncStatusText: String {
        switch syncViewModel.syncStatus {
        case .idle: return "Idle"
        case .syncing: return "Syncing"
        case .synced(let date): return "Synced \(date.formatted(.relative(presentation: .named)))"
        case .failed(let message): return "Failed: \(message)"
        }
    }

    // MARK: - Reset action — Req 17.4

    private func resetToDefaults() {
        defaultMarkerSize = 24
        defaultMarkerColorHex = "#FF5733"
        defaultConfidenceThreshold = 0.5
        defaultExportFormat = ExportFormat.csv.rawValue
        confirmBeforeDeleteMarker = false
    }

    // MARK: - Helpers

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

// Color(hex:) and hexString are defined in Models/ColorExtensions.swift

// MARK: - Preview

#Preview {
    SettingsView()
        .environmentObject(iCloudSyncViewModel())
}
