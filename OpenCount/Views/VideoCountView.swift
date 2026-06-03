import SwiftUI
import Charts
import UniformTypeIdentifiers

// MARK: - VideoCountView

/// Video frame-by-frame counting view.
///
/// Requirements: 11.1, 11.2, 11.3, 11.4, 11.5, 11.6
struct VideoCountView: View {

    let session: CountSession
    @StateObject private var viewModel = VideoPlayerViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showTimeline: Bool = false
    @State private var isFileImporterPresented: Bool = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Video import prompt when no video is loaded
                if viewModel.duration == 0 {
                    videoImportPrompt
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Frame display
                    frameView
                        .frame(maxWidth: .infinity)
                        .frame(height: 280)
                        .background(Color.black)

                    // Timeline scrubber
                    timelineScrubber
                        .padding(.horizontal)
                        .padding(.vertical, 8)

                    Divider()

                    // Navigation controls
                    navigationControls
                        .padding(.vertical, 8)

                    Divider()

                    // Auto-sampling controls
                    autoSamplingControls
                        .padding()

                    // Timeline chart (toggle)
                    if showTimeline && !viewModel.countedFrames.isEmpty {
                        timelineChart
                            .padding()
                    }

                    Spacer()
                }
            }
            .navigationTitle("Video Counting")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                if viewModel.duration > 0 {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            withAnimation { showTimeline.toggle() }
                        } label: {
                            Image(systemName: showTimeline
                                  ? "chart.line.uptrend.xyaxis.circle.fill"
                                  : "chart.line.uptrend.xyaxis.circle")
                        }
                        .accessibilityLabel(showTimeline ? "Hide timeline chart" : "Show timeline chart")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isFileImporterPresented = true
                    } label: {
                        Image(systemName: "video.badge.plus")
                    }
                    .accessibilityLabel("Import video")
                    .accessibilityHint("Choose a video file to count objects frame by frame.")
                }
            }
            .fileImporter(
                isPresented: $isFileImporterPresented,
                allowedContentTypes: [.movie, .video, .mpeg4Movie, .quickTimeMovie],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    let accessing = url.startAccessingSecurityScopedResource()
                    Task {
                        await viewModel.loadVideo(url: url)
                        if accessing { url.stopAccessingSecurityScopedResource() }
                    }
                case .failure:
                    break
                }
            }
        }
    }

    // MARK: - Video import prompt

    private var videoImportPrompt: some View {
        VStack(spacing: 20) {
            Image(systemName: "video.badge.plus")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("Import a Video")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Count objects frame by frame with AI assistance.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                isFileImporterPresented = true
            } label: {
                Label("Choose Video", systemImage: "folder")
                    .frame(minWidth: 200)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityLabel("Choose a video file to import")
        }
        .padding()
    }

    // MARK: - Frame view

    @ViewBuilder
    private var frameView: some View {
        if let frame = viewModel.currentFrame {
            Image(uiImage: frame)
                .resizable()
                .scaledToFit()
                .accessibilityLabel("Video frame at \(String(format: "%.2f", viewModel.currentTimestamp)) seconds")
                .transition(.opacity)
        } else {
            VideoCountSkeletonLoader()
                .transition(.opacity)
                .accessibilityLabel("Loading video frame")
        }
    }

    // MARK: - Timeline scrubber

    private var timelineScrubber: some View {
        VStack(spacing: 4) {
            Slider(
                value: Binding(
                    get: { viewModel.currentTimestamp },
                    set: { newValue in
                        Task { await viewModel.seekToTime(newValue) }
                    }
                ),
                in: 0...max(viewModel.duration, 1)
            )
            .accessibilityLabel("Video position")
            .accessibilityValue("\(String(format: "%.1f", viewModel.currentTimestamp)) of \(String(format: "%.1f", viewModel.duration)) seconds")

            HStack {
                Text(formatTime(viewModel.currentTimestamp))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer()
                // Counted frame markers
                if !viewModel.countedFrames.isEmpty {
                    Text("\(viewModel.countedFrames.count) frames counted")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
                Spacer()
                Text(formatTime(viewModel.duration))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Navigation controls

    private var navigationControls: some View {
        HStack(spacing: 32) {
            Button {
                Task { await viewModel.stepBackward() }
            } label: {
                Image(systemName: "backward.frame.fill")
                    .font(.title2)
            }
            .accessibilityLabel("Previous frame")

            Button {
                Task { await viewModel.seekToTime(0) }
            } label: {
                Image(systemName: "backward.end.fill")
                    .font(.title2)
            }
            .accessibilityLabel("Go to start")

            Button {
                Task { await viewModel.seekToTime(viewModel.duration) }
            } label: {
                Image(systemName: "forward.end.fill")
                    .font(.title2)
            }
            .accessibilityLabel("Go to end")

            Button {
                Task { await viewModel.stepForward() }
            } label: {
                Image(systemName: "forward.frame.fill")
                    .font(.title2)
            }
            .accessibilityLabel("Next frame")
        }
    }

    // MARK: - Auto-sampling controls

    private var autoSamplingControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Auto-Sampling")
                .font(.headline)

            HStack {
                Text("Interval:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Picker("Interval", selection: $viewModel.samplingInterval) {
                    Text("Every 1s").tag(1.0)
                    Text("Every 2s").tag(2.0)
                    Text("Every 5s").tag(5.0)
                    Text("Every 10s").tag(10.0)
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Sampling interval")
            }

            if viewModel.isProcessingAI {
                VStack(spacing: 4) {
                    ProgressView(value: viewModel.aiProgress)
                        .tint(.blue)
                    HStack {
                        Text("Processing frames…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Stop") { viewModel.stopAutoSampling() }
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .accessibilityLabel("Auto-sampling in progress: \(Int(viewModel.aiProgress * 100)) percent")
            } else {
                Button {
                    viewModel.startAutoSampling(session: session)
                } label: {
                    Label("Run AI on All Frames", systemImage: "brain.head.profile")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.duration == 0)
                .accessibilityLabel("Run AI detection on all sampled frames")
            }
        }
    }

    // MARK: - Timeline chart

    @ViewBuilder
    private var timelineChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Count Over Time")
                .font(.headline)

            if #available(iOS 16.0, *) {
                Chart {
                    ForEach(session.objectTypes.sorted { $0.sortOrder < $1.sortOrder }) { objectType in
                        let data = viewModel.tallyOverTime(for: objectType)
                        ForEach(data, id: \.timestamp) { point in
                            LineMark(
                                x: .value("Time (s)", point.timestamp),
                                y: .value("Count", point.count)
                            )
                            .foregroundStyle(by: .value("Type", objectType.name))
                        }
                    }
                }
                .frame(height: 160)
                .accessibilityLabel("Count over time chart")
            }
        }
    }

    // MARK: - Helpers

    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
