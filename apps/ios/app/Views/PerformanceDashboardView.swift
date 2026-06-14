import SwiftUI
import Charts

// MARK: - PerformanceDashboardView

/// Developer-only performance dashboard.
/// Activated by tapping the version label 7 times in Settings.
/// Displays real-time FPS, memory usage, AI inference latency, and operation tracking.
/// Requirement 51 (Req 40)
struct PerformanceDashboardView: View {

    @ObservedObject private var monitor = PerformanceMonitor.shared
    @Environment(\.dismiss) private var dismiss

    private struct LatencyEntry: Identifiable {
        let id = UUID()
        let index: Int
        let ms: Double
    }

    private var latencyEntries: [LatencyEntry] {
        monitor.aiLatencies.enumerated().map { LatencyEntry(index: $0.offset, ms: $0.element) }
    }

    var body: some View {
        NavigationStack {
            List {
                // FPS
                Section("Rendering") {
                    HStack {
                        Label("FPS", systemImage: "speedometer")
                        Spacer()
                        Text(String(format: "%.1f fps", monitor.currentFPS))
                            .font(.body.monospacedDigit())
                            .foregroundStyle(monitor.currentFPS >= 55 ? .green : monitor.currentFPS >= 30 ? .orange : .red)
                    }
                    .accessibilityLabel("Current FPS: \(String(format: "%.1f", monitor.currentFPS))")
                }

                // RAM
                Section("Memory") {
                    HStack {
                        Label("Current RAM", systemImage: "memorychip")
                        Spacer()
                        Text(String(format: "%.1f MB", monitor.ramUsageMB))
                            .font(.body.monospacedDigit())
                            .foregroundStyle(monitor.ramUsageMB < 150 ? .green : monitor.ramUsageMB < 200 ? .orange : .red)
                    }
                    .accessibilityLabel("Current RAM usage: \(String(format: "%.1f", monitor.ramUsageMB)) megabytes")

                    HStack {
                        Label("Peak RAM", systemImage: "chart.line.uptrend.xyaxis")
                        Spacer()
                        Text(String(format: "%.1f MB", monitor.peakRAMMB))
                            .font(.body.monospacedDigit())
                            .foregroundStyle(monitor.peakRAMMB < 150 ? .green : monitor.peakRAMMB < 200 ? .orange : .red)
                    }
                    .accessibilityLabel("Peak RAM usage: \(String(format: "%.1f", monitor.peakRAMMB)) megabytes")

                    // RAM budget indicator
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Budget: 200 MB")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ProgressView(value: min(monitor.ramUsageMB / 200, 1.0))
                            .tint(monitor.ramUsageMB < 150 ? .green : monitor.ramUsageMB < 200 ? .orange : .red)
                    }
                    .accessibilityLabel("RAM budget: \(Int(min(monitor.ramUsageMB / 200 * 100, 100))) percent used")
                }

                // AI Latency histogram
                Section("AI Inference Latency (last 20 runs)") {
                    if latencyEntries.isEmpty {
                        Text("No AI inference runs recorded yet.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Chart(latencyEntries) { entry in
                            BarMark(
                                x: .value("Run", entry.index),
                                y: .value("ms", entry.ms)
                            )
                            .foregroundStyle(entry.ms < 1000 ? Color.green : entry.ms < 3000 ? Color.orange : Color.red)
                        }
                        .frame(height: 120)
                        .chartXAxis(.hidden)
                        .chartYAxisLabel("ms")
                        .accessibilityLabel("AI inference latency histogram for last \(latencyEntries.count) runs")

                        let avg = latencyEntries.map(\.ms).reduce(0, +) / Double(max(latencyEntries.count, 1))
                        HStack {
                            Text("Average")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(String(format: "%.0f ms", avg))
                                .font(.caption.monospacedDigit())
                        }
                        .accessibilityLabel("Average AI latency: \(String(format: "%.0f", avg)) milliseconds")
                    }
                }

                // Operations tracking
                Section("Operations") {
                    let operationsSummary = monitor.getOperationsSummary()
                    if operationsSummary.isEmpty {
                        Text("No operations tracked yet.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(operationsSummary, id: \.name) { op in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(op.name)
                                        .font(.subheadline.weight(.semibold))
                                    Spacer()
                                    if op.slowCount > 0 {
                                        Label("\(op.slowCount) slow", systemImage: "exclamationmark.triangle.fill")
                                            .font(.caption)
                                            .foregroundStyle(.orange)
                                    }
                                }
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Avg")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text(String(format: "%.0f ms", op.avgDurationMS))
                                            .font(.caption.monospacedDigit())
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Count")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text("\(op.count)")
                                            .font(.caption.monospacedDigit())
                                    }
                                    Spacer()
                                }
                            }
                            .accessibilityLabel("\(op.name): average \(String(format: "%.0f", op.avgDurationMS))ms, \(op.count) runs, \(op.slowCount) slow")
                        }
                    }
                }

                // Export diagnostics
                Section {
                    Button {
                        exportDiagnostics()
                    } label: {
                        Label("Export Diagnostics", systemImage: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Export performance diagnostics as JSON")
                }
            }
            .navigationTitle("Performance Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .accessibilityLabel("Close performance dashboard")
                }
            }
        }
        .onAppear { monitor.start() }
        .onDisappear { monitor.stop() }
    }

    // MARK: - Export diagnostics

    private func exportDiagnostics() {
        let diagnostics = monitor.exportDiagnostics()
        guard let data = try? JSONSerialization.data(withJSONObject: diagnostics, options: .prettyPrinted),
              let json = String(data: data, encoding: .utf8) else { return }
        UIPasteboard.general.string = json
    }
}

// MARK: - Preview

#Preview {
    PerformanceDashboardView()
}
