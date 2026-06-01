import SwiftUI
import Charts
import Darwin
import QuartzCore

// MARK: - PerformanceMonitor

/// Samples FPS and RAM usage periodically for the performance dashboard.
/// Requirement 51 (Req 40)
@MainActor
final class PerformanceMonitor: ObservableObject {

    @Published var currentFPS: Double = 0
    @Published var ramUsageMB: Double = 0
    @Published var aiLatencies: [Double] = []   // last 20 inference times in ms

    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0
    private var frameCount: Int = 0
    private var timer: Timer?

    func start() {
        // FPS via CADisplayLink
        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkTick))
        displayLink?.add(to: .main, forMode: .common)

        // RAM sampling every 500ms
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.sampleRAM()
            }
        }
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        timer?.invalidate()
        timer = nil
    }

    func recordAILatency(_ ms: Double) {
        aiLatencies.append(ms)
        if aiLatencies.count > 20 { aiLatencies.removeFirst() }
    }

    @objc private func displayLinkTick(_ link: CADisplayLink) {
        if lastTimestamp == 0 {
            lastTimestamp = link.timestamp
            return
        }
        frameCount += 1
        let elapsed = link.timestamp - lastTimestamp
        if elapsed >= 1.0 {
            currentFPS = Double(frameCount) / elapsed
            frameCount = 0
            lastTimestamp = link.timestamp
        }
    }

    private func sampleRAM() {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        if result == KERN_SUCCESS {
            ramUsageMB = Double(info.resident_size) / 1_048_576
        }
    }
}

// MARK: - PerformanceDashboardView

/// Developer-only performance dashboard.
/// Activated by tapping the version label 7 times in Settings.
/// Requirement 51 (Req 40)
struct PerformanceDashboardView: View {

    @StateObject private var monitor = PerformanceMonitor()
    @Environment(\.dismiss) private var dismiss

    private struct LatencyEntry: Identifiable {
        let id = UUID()
        let index: Int
        let ms: Double
    }

    private var latencyEntries: [LatencyEntry] {
        monitor.aiLatencies.enumerated().map { LatencyEntry(id: UUID(), index: $0.offset, ms: $0.element) }
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
                        Label("RAM Usage", systemImage: "memorychip")
                        Spacer()
                        Text(String(format: "%.1f MB", monitor.ramUsageMB))
                            .font(.body.monospacedDigit())
                            .foregroundStyle(monitor.ramUsageMB < 150 ? .green : monitor.ramUsageMB < 200 ? .orange : .red)
                    }
                    .accessibilityLabel("RAM usage: \(String(format: "%.1f", monitor.ramUsageMB)) megabytes")

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
        let diagnostics: [String: Any] = [
            "fps": monitor.currentFPS,
            "ram_mb": monitor.ramUsageMB,
            "ai_latencies_ms": monitor.aiLatencies,
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "device": UIDevice.current.model,
            "ios_version": UIDevice.current.systemVersion
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: diagnostics, options: .prettyPrinted),
              let json = String(data: data, encoding: .utf8) else { return }
        UIPasteboard.general.string = json
    }
}

// MARK: - Preview

#Preview {
    PerformanceDashboardView()
}
