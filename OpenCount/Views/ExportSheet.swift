import SwiftUI
import UIKit
import UserNotifications

// MARK: - ShareSheet

/// A UIViewControllerRepresentable that wraps UIActivityViewController
/// to present the system share sheet from SwiftUI.
///
/// Requirement 12.5: present UIActivityViewController with the exported file URL.
struct ShareSheet: UIViewControllerRepresentable {

    let activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - ExportSheet

/// A SwiftUI sheet that lets the user choose an export format and share the result.
///
/// Supports CSV, JSON, Annotated Image, and PDF exports via ExportService.
/// Also provides a "Copy to Clipboard" button for a plain-text summary.
/// When an `AnnotationLayerViewModel` is provided, shows per-layer export checkboxes.
///
/// Requirements: 12.5, 12.6, 12.7, 12.8, 34.6
struct ExportSheet: View {

    // MARK: - Inputs

    let session: CountSession
    var image: UIImage?
    /// Optional: when provided, enables per-layer annotation export selection.
    /// Requirement 34.6
    var annotationViewModel: AnnotationLayerViewModel?

    // MARK: - State

    @State private var selectedFormat: ExportFormat = .csv
    @State private var isExporting: Bool = false
    @State private var isShareSheetPresented: Bool = false
    @State private var exportedFileURL: URL? = nil

    /// Per-layer export selection — Requirement 34.6
    @State private var selectedExportLayers: Set<AnnotationLayerType> = Set(AnnotationLayerType.allCases)

    /// Shown after a successful PDF export.
    @State private var isPDFCompletionAlertPresented: Bool = false
    @State private var pdfExportedURL: URL? = nil

    /// Shown when an export error occurs.
    @State private var isErrorAlertPresented: Bool = false
    @State private var exportErrorMessage: String = ""

    /// Shown after "Copy to Clipboard" succeeds.
    @State private var isCopiedToastPresented: Bool = false

    /// QR Code sheet — Requirement 52 (Req 41)
    @State private var isQRCodePresented: Bool = false

    @Environment(\.dismiss) private var dismiss

    // MARK: - Services

    private let exportService = ExportService()

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Format Picker Section
                Section {
                    Picker("Format", selection: $selectedFormat) {
                        ForEach(ExportFormat.allCases) { format in
                            Label(format.rawValue, systemImage: format.systemImage)
                                .tag(format)
                        }
                    }
                    .pickerStyle(.inline)
                    .accessibilityLabel("Export format")
                    .accessibilityHint("Choose the format for the exported file.")
                } header: {
                    Text("Export Format")
                }

                // MARK: Format description
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: selectedFormat.systemImage)
                            .font(.title2)
                            .foregroundStyle(.accent)
                            .frame(width: 36)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(selectedFormat.rawValue)
                                .font(.headline)
                            Text(formatDescription(selectedFormat))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // MARK: Annotation Layer Selection (image/PDF only) — Requirement 34.6
                if (selectedFormat == .annotatedImage || selectedFormat == .pdf),
                   let avm = annotationViewModel,
                   avm.textAnnotations.count + avm.measureLines.count + avm.arrowAnnotations.count > 0 {
                    Section {
                        ForEach(AnnotationLayerType.allCases) { layer in
                            // Only show layers that have content or are core layers
                            let hasContent: Bool = {
                                switch layer {
                                case .textLabels:   return !avm.textAnnotations.isEmpty
                                case .measureLines: return !avm.measureLines.isEmpty
                                case .arrows:       return !avm.arrowAnnotations.isEmpty
                                default:            return false
                                }
                            }()
                            if hasContent {
                                Toggle(isOn: Binding(
                                    get: { selectedExportLayers.contains(layer) },
                                    set: { include in
                                        if include { selectedExportLayers.insert(layer) }
                                        else { selectedExportLayers.remove(layer) }
                                    }
                                )) {
                                    Label(layer.rawValue, systemImage: layer.systemImage)
                                }
                                .accessibilityLabel("Include \(layer.rawValue) in export")
                            }
                        }
                    } header: {
                        Text("Annotation Layers")
                    } footer: {
                        Text("Choose which annotation layers to include in the exported image or PDF.")
                    }
                }

                // MARK: Export Button Section
                Section {
                    Button {
                        performExport()
                    } label: {
                        HStack {
                            Spacer()
                            if isExporting {
                                ProgressView()
                                    .padding(.trailing, 8)
                                    .accessibilityLabel("Exporting…")
                            }
                            Label(
                                isExporting ? "Exporting…" : "Export \(selectedFormat.rawValue)",
                                systemImage: "square.and.arrow.up"
                            )
                            .font(.headline)
                            Spacer()
                        }
                    }
                    .disabled(isExporting || requiresImageButMissing)
                    .accessibilityLabel("Export \(selectedFormat.rawValue)")
                    .accessibilityHint("Tap to export the session as \(selectedFormat.rawValue) and open the share sheet.")

                    if requiresImageButMissing {
                        Label("No image available for this format.", systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .accessibilityLabel("Warning: no image available for \(selectedFormat.rawValue) export.")
                    }
                }

                // MARK: Copy to Clipboard Section
                Section {
                    Button {
                        copyToClipboard()
                    } label: {
                        HStack {
                            Spacer()
                            Label("Copy Summary to Clipboard", systemImage: "doc.on.clipboard")
                                .font(.subheadline)
                            Spacer()
                        }
                    }
                    .accessibilityLabel("Copy plain-text summary to clipboard")
                    .accessibilityHint("Copies a plain-text count summary for this session to the clipboard.")

                    if isCopiedToastPresented {
                        HStack {
                            Spacer()
                            Label("Copied!", systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                            Spacer()
                        }
                        .transition(.opacity)
                        .accessibilityLabel("Summary copied to clipboard.")
                    }
                } header: {
                    Text("Clipboard")
                }

                // MARK: QR Code Section — Requirement 52 (Req 41)
                Section {
                    Button {
                        isQRCodePresented = true
                    } label: {
                        HStack {
                            Spacer()
                            Label("Generate Verification QR Code", systemImage: "qrcode")
                                .font(.subheadline)
                            Spacer()
                        }
                    }
                    .accessibilityLabel("Generate QR code for session verification")
                    .accessibilityHint("Creates a QR code encoding the session tally for verification and sharing.")
                } header: {
                    Text("Verification")
                }
            }
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityLabel("Cancel export")
                    .accessibilityHint("Dismiss the export sheet without exporting.")
                }
            }
            // Share sheet — presented after a successful non-PDF export
            .sheet(isPresented: $isShareSheetPresented) {
                if let url = exportedFileURL {
                    ShareSheet(activityItems: [url])
                        .ignoresSafeArea()
                }
            }
            // PDF completion alert — shown after PDF export
            // Requirement 12.8: show completion notification for PDF with "Open" action
            .alert(
                "PDF Exported",
                isPresented: $isPDFCompletionAlertPresented
            ) {
                Button("Open") {
                    if let url = pdfExportedURL {
                        UIApplication.shared.open(url)
                    }
                }
                .accessibilityLabel("Open the exported PDF")
                Button("Share") {
                    exportedFileURL = pdfExportedURL
                    isShareSheetPresented = true
                }
                .accessibilityLabel("Share the exported PDF")
                Button("Done", role: .cancel) {}
                    .accessibilityLabel("Dismiss PDF export notification")
            } message: {
                Text("Your PDF report has been saved. Would you like to open or share it?")
            }
            // Error alert
            .alert(
                "Export Failed",
                isPresented: $isErrorAlertPresented
            ) {
                Button("OK", role: .cancel) {}
                    .accessibilityLabel("Dismiss error")
            } message: {
                Text(exportErrorMessage)
            }
            // QR Code sheet — Requirement 52 (Req 41)
            .sheet(isPresented: $isQRCodePresented) {
                NavigationStack {
                    QRCodeView(session: session)
                        .navigationTitle("Verification QR")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { isQRCodePresented = false }
                            }
                        }
                }
            }
        }
    }

    // MARK: - Helpers

    /// True when the selected format requires an image but none was provided.
    private var requiresImageButMissing: Bool {
        (selectedFormat == .annotatedImage || selectedFormat == .pdf) && image == nil
    }

    /// Human-readable description for each export format.
    private func formatDescription(_ format: ExportFormat) -> String {
        switch format {
        case .csv:
            return "Spreadsheet-compatible file with all marker coordinates, tallies, and metadata."
        case .json:
            return "Structured JSON file with full session data, suitable for programmatic processing."
        case .coco:
            return "COCO JSON format compatible with Roboflow, CVAT, Label Studio, and ML training pipelines."
        case .annotatedImage:
            return "PNG image with all markers and region outlines drawn on the source image."
        case .pdf:
            return "PDF report with annotated image, tally table, and session metadata."
        }
    }

    // MARK: - Export Action

    /// Performs the export for the selected format, writes to a temp file,
    /// then presents the share sheet (or PDF completion alert).
    ///
    /// Requirements: 12.5, 12.7, 12.8
    private func performExport() {
        isExporting = true

        // Run on a background thread to avoid blocking the UI.
        Task.detached(priority: .userInitiated) {
            do {
                let url = try await buildExportFile()
                await MainActor.run {
                    isExporting = false
                    if selectedFormat == .pdf {
                        pdfExportedURL = url
                        isPDFCompletionAlertPresented = true
                    } else {
                        exportedFileURL = url
                        isShareSheetPresented = true
                    }
                }
            } catch {
                await MainActor.run {
                    isExporting = false
                    exportErrorMessage = error.localizedDescription
                    isErrorAlertPresented = true
                }
            }
        }
    }

    /// Builds the export file and returns its URL in the temporary directory.
    private func buildExportFile() async throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "\(session.name)_export.\(selectedFormat.fileExtension)"
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        let fileURL = tempDir.appendingPathComponent(fileName)

        switch selectedFormat {
        case .csv:
            let data = try exportService.exportCSV(session: session)
            try data.write(to: fileURL, options: .atomic)

        case .xlsx:
            let data = try exportService.exportXLSX(session: session)
            try data.write(to: fileURL, options: .atomic)

        case .json:
            let data = try exportService.exportJSON(session: session)
            try data.write(to: fileURL, options: .atomic)

        case .coco:
            // Use image dimensions if available, otherwise default to 1024×1024
            let imageSize = image?.size ?? CGSize(width: 1024, height: 1024)
            let data = try exportService.exportCOCO(
                session: session,
                imageWidth: Int(imageSize.width),
                imageHeight: Int(imageSize.height)
            )
            try data.write(to: fileURL, options: .atomic)

        case .annotatedImage:
            guard let sourceImage = image else {
                throw AppError.exportWriteFailure(reason: "No image available for annotated image export.")
            }
            let annotationData = annotationViewModel?.exportLayers(selectedLayers: selectedExportLayers)
            let annotated = try exportService.exportAnnotatedImage(
                session: session, image: sourceImage, annotationData: annotationData)
            guard let pngData = annotated.pngData() else {
                throw AppError.exportWriteFailure(reason: "Failed to encode annotated image as PNG.")
            }
            try pngData.write(to: fileURL, options: .atomic)

        case .pdf:
            guard let sourceImage = image else {
                throw AppError.exportWriteFailure(reason: "No image available for PDF export.")
            }
            let annotationData = annotationViewModel?.exportLayers(selectedLayers: selectedExportLayers)
            let data = try exportService.exportPDF(
                session: session, image: sourceImage, annotationData: annotationData)
            try data.write(to: fileURL, options: .atomic)
        }

        return fileURL
    }

    // MARK: - Copy to Clipboard

    /// Copies the plain-text summary to the system clipboard.
    ///
    /// Requirement 12.6: copy plain-text summary to clipboard.
    private func copyToClipboard() {
        let summary = exportService.plainTextSummary(session: session)
        UIPasteboard.general.string = summary

        withAnimation {
            isCopiedToastPresented = true
        }
        // Hide the toast after 2 seconds
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run {
                withAnimation {
                    isCopiedToastPresented = false
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let session: CountSession = {
        let s = CountSession(name: "Bird Survey")
        let t1 = ObjectType(name: "Robin", colorHex: "#E74C3C", iconName: "bird", sortOrder: 0, session: s)
        let t2 = ObjectType(name: "Sparrow", colorHex: "#3498DB", iconName: "bird.fill", sortOrder: 1, session: s)
        s.objectTypes = [t1, t2]
        s.markers = [
            CountMarker(normalizedX: 0.3, normalizedY: 0.4, objectType: t1, session: s),
            CountMarker(normalizedX: 0.6, normalizedY: 0.6, objectType: t2, session: s),
        ]
        return s
    }()

    ExportSheet(session: session)
}
