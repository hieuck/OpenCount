import SwiftUI
import UIKit
import UniformTypeIdentifiers

// MARK: - BulkExportView

/// Allows the user to select multiple sessions and export them as a single ZIP archive.
///
/// This feature surpasses ZapCount and CountThings which only support
/// single-session exports.
struct BulkExportView: View {

    let sessions: [CountSession]
    @Environment(\.dismiss) private var dismiss

    @State private var selectedSessionIDs: Set<UUID> = []
    @State private var selectedFormats: Set<ExportFormat> = [.csv, .json]
    @State private var isExporting: Bool = false
    @State private var exportError: String? = nil
    @State private var exportedFileURL: URL? = nil
    @State private var isShowingShareSheet: Bool = false

    private var selectedSessions: [CountSession] {
        sessions.filter { selectedSessionIDs.contains($0.id) }
    }

    private var canExport: Bool {
        !selectedSessionIDs.isEmpty && !selectedFormats.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                sessionSelectionSection
                formatSelectionSection
                exportSummarySection
            }
            .navigationTitle("Bulk Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    if isExporting {
                        ProgressView()
                            .accessibilityLabel("Exporting sessions")
                    } else {
                        Button("Export ZIP") {
                            Task { await performExport() }
                        }
                        .disabled(!canExport)
                        .fontWeight(.semibold)
                        .accessibilityLabel("Export selected sessions as ZIP")
                    }
                }
            }
            .alert("Export Error", isPresented: Binding(
                get: { exportError != nil },
                set: { if !$0 { exportError = nil } }
            )) {
                Button("OK", role: .cancel) { exportError = nil }
            } message: {
                Text(exportError ?? "")
            }
            .sheet(isPresented: $isShowingShareSheet) {
                if let url = exportedFileURL {
                    ShareSheetWrapper(activityItems: [url])
                }
            }
        }
    }

    // MARK: - Session selection

    private var sessionSelectionSection: some View {
        Section {
            // Select All / Deselect All
            HStack {
                Button("Select All") {
                    selectedSessionIDs = Set(sessions.map(\.id))
                }
                .font(.subheadline)
                .accessibilityLabel("Select all sessions")

                Spacer()

                Button("Deselect All") {
                    selectedSessionIDs = []
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Deselect all sessions")
            }

            ForEach(sessions.sorted { $0.modifiedAt > $1.modifiedAt }) { session in
                HStack(spacing: 12) {
                    Image(systemName: selectedSessionIDs.contains(session.id)
                          ? "checkmark.circle.fill"
                          : "circle")
                        .foregroundStyle(selectedSessionIDs.contains(session.id)
                                         ? .accentColor : .secondary)
                        .font(.title3)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.name)
                            .font(.subheadline.weight(.medium))
                        Text("\(session.markers.count) markers · \(session.modifiedAt.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if selectedSessionIDs.contains(session.id) {
                        selectedSessionIDs.remove(session.id)
                    } else {
                        selectedSessionIDs.insert(session.id)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(session.name), \(session.markers.count) markers")
                .accessibilityAddTraits(selectedSessionIDs.contains(session.id) ? [.isSelected] : [])
                .accessibilityHint("Tap to \(selectedSessionIDs.contains(session.id) ? "deselect" : "select") this session.")
            }
        } header: {
            Text("Sessions (\(selectedSessionIDs.count) selected)")
        }
    }

    // MARK: - Format selection

    private var formatSelectionSection: some View {
        Section("Export Formats") {
            ForEach(ExportFormat.allCases) { format in
                HStack(spacing: 12) {
                    Image(systemName: selectedFormats.contains(format)
                          ? "checkmark.square.fill"
                          : "square")
                        .foregroundStyle(selectedFormats.contains(format) ? .accentColor : .secondary)
                        .font(.title3)
                        .accessibilityHidden(true)

                    Label(format.rawValue, systemImage: format.systemImage)
                        .font(.subheadline)

                    Spacer()
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if selectedFormats.contains(format) {
                        selectedFormats.remove(format)
                    } else {
                        selectedFormats.insert(format)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(format.rawValue)
                .accessibilityAddTraits(selectedFormats.contains(format) ? [.isSelected] : [])
                .accessibilityHint("Tap to \(selectedFormats.contains(format) ? "deselect" : "select") \(format.rawValue) format.")
            }
        }
    }

    // MARK: - Export summary

    private var exportSummarySection: some View {
        Section {
            let totalMarkers = selectedSessions.reduce(0) { $0 + $1.markers.count }
            let estimatedFiles = selectedSessions.count * selectedFormats.count + 2 // +summary +README

            HStack {
                Label("Sessions", systemImage: "folder")
                Spacer()
                Text("\(selectedSessions.count)")
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Sessions: \(selectedSessions.count)")

            HStack {
                Label("Total Markers", systemImage: "number.circle")
                Spacer()
                Text("\(totalMarkers)")
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Total markers: \(totalMarkers)")

            HStack {
                Label("Files in ZIP", systemImage: "doc.zipper")
                Spacer()
                Text("~\(estimatedFiles)")
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Estimated files in ZIP: \(estimatedFiles)")
        } header: {
            Text("Export Summary")
        } footer: {
            Text("The ZIP will include a summary.csv and README.txt in addition to per-session files.")
        }
    }

    // MARK: - Export action

    private func performExport() async {
        isExporting = true
        exportError = nil

        do {
            let service = BulkExportService()
            let url = try service.exportZIP(
                sessions: selectedSessions,
                formats: selectedFormats
            )
            exportedFileURL = url
            isShowingShareSheet = true
        } catch {
            exportError = error.localizedDescription
        }

        isExporting = false
    }
}

// MARK: - ShareSheetWrapper

/// UIActivityViewController wrapper for sharing files (used in BulkExportView).
struct ShareSheetWrapper: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
