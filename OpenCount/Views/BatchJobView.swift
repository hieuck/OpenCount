import SwiftUI

// MARK: - BatchJobView

/// Displays batch AI processing progress and per-image results.
///
/// Requirements: 10.1, 10.2, 10.3, 10.4, 10.5, 10.6
struct BatchJobView: View {

    let session: CountSession
    @StateObject private var viewModel = BatchJobViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var confidenceThreshold: Float = 0.5
    @State private var selectedResult: BatchImageResult?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress header
                progressHeader
                    .padding()

                Divider()

                // Image grid
                if viewModel.results.isEmpty {
                    emptyState
                } else {
                    resultsList
                }

                // Aggregated tally (shown when complete)
                if case .completed = viewModel.status {
                    aggregatedTallyView
                        .padding()
                }
            }
            .navigationTitle("Batch Processing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    if case .running = viewModel.status {
                        Button("Cancel", role: .destructive) {
                            viewModel.cancel()
                        }
                    } else if case .idle = viewModel.status, !viewModel.results.isEmpty {
                        Button("Start") {
                            viewModel.startProcessing(confidenceThreshold: confidenceThreshold)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
        .onAppear {
            viewModel.addImages(session.images)
        }
    }

    // MARK: - Progress header

    @ViewBuilder
    private var progressHeader: some View {
        switch viewModel.status {
        case .idle:
            VStack(spacing: 8) {
                HStack {
                    Text("\(viewModel.totalCount) images queued")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    HStack(spacing: 6) {
                        Text("Confidence:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(Int(confidenceThreshold * 100))%")
                            .font(.caption.bold())
                            .monospacedDigit()
                    }
                }
                Slider(value: Binding(
                    get: { Double(confidenceThreshold) },
                    set: { confidenceThreshold = Float($0) }
                ), in: 0.1...0.9, step: 0.05)
                .accessibilityLabel("Confidence threshold: \(Int(confidenceThreshold * 100)) percent")
            }

        case .running(let current, let total):
            VStack(spacing: 8) {
                LinearProgressIndicator(
                    progress: Double(current) / Double(total),
                    label: "Processing \(current) of \(total) images…",
                    showPercentage: true
                )
                .accessibilityLabel("Batch progress: \(current) of \(total) images")
            }

        case .completed:
            Label("Processing complete — \(viewModel.processedCount) images", systemImage: "checkmark.circle.fill")
                .font(.subheadline)
                .foregroundStyle(.green)
                .accessibilityLabel("Batch processing complete. \(viewModel.processedCount) images processed.")

        case .cancelled:
            Label("Cancelled — \(viewModel.processedCount) of \(viewModel.totalCount) processed", systemImage: "xmark.circle")
                .font(.subheadline)
                .foregroundStyle(.orange)

        case .paused(let current, let total):
            VStack(spacing: 8) {
                LinearProgressIndicator(
                    progress: Double(current) / Double(total),
                    label: "Paused — \(current) of \(total) processed",
                    showPercentage: true
                )
                .accessibilityLabel("Batch paused: \(current) of \(total) images")
                Button("Resume") {
                    viewModel.resume(confidenceThreshold: confidenceThreshold)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    // MARK: - Results list

    private var resultsList: some View {
        List(viewModel.results) { result in
            BatchResultRow(result: result)
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.stack")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("No Images")
                .font(.title2.bold())
            Text("Add images to this session to start batch processing.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Aggregated tally

    private var aggregatedTallyView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Total Counts")
                .font(.headline)
            ForEach(viewModel.aggregatedTally.sorted(by: { $0.value > $1.value }), id: \.key) { label, count in
                HStack {
                    Text(label)
                        .font(.subheadline)
                    Spacer()
                    Text("\(count)")
                        .font(.subheadline.bold())
                        .monospacedDigit()
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - BatchResultRow

struct BatchResultRow: View {

    let result: BatchImageResult

    var body: some View {
        HStack(spacing: 12) {
            // Status icon
            statusIcon
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(result.sessionImage.filename)
                    .font(.subheadline)
                    .lineLimit(1)

                if result.isProcessed {
                    if let error = result.error {
                        Text(error.localizedDescription)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .lineLimit(2)
                    } else {
                        Text("\(result.detections.count) objects detected")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Waiting…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var statusIcon: some View {
        if !result.isProcessed {
            Image(systemName: "clock")
                .foregroundStyle(.secondary)
        } else if result.error != nil {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        } else {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        }
    }
}
