import Foundation
import UIKit
import Darwin
import QuartzCore
import os.log

// MARK: - Performance Models

struct PerformanceMetrics: Codable {
    let timestamp: Date
    let operationName: String
    let duration: TimeInterval
    let memoryUsedMB: Double
    let isSlowOperation: Bool

    enum CodingKeys: String, CodingKey {
        case timestamp, operationName, duration, memoryUsedMB, isSlowOperation
    }
}

struct MemorySnapshot: Codable {
    let timestamp: Date
    let residentMB: Double
    let peakMB: Double?

    enum CodingKeys: String, CodingKey {
        case timestamp, residentMB, peakMB
    }
}

// MARK: - PerformanceMonitor Service

/// Production performance monitoring service for tracking AI inference time, memory usage, and slow operations.
/// Thread-safe and suitable for use across the app lifecycle.
/// Requirement: 51 (Req 40)
@MainActor
final class PerformanceMonitor: NSObject, ObservableObject {
    static let shared = PerformanceMonitor()

    // MARK: - Published properties for UI

    @Published var currentFPS: Double = 0
    @Published var ramUsageMB: Double = 0
    @Published var peakRAMMB: Double = 0
    @Published var aiLatencies: [Double] = []  // Last 20 AI inference times in ms

    // MARK: - Private properties

    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0
    private var frameCount: Int = 0
    private var timer: Timer?

    // Operation tracking
    private var operationMetrics: [PerformanceMetrics] = []
    private var memorySnapshots: [MemorySnapshot] = []
    private var slowOperationThresholdMS: TimeInterval = 500  // 500ms threshold

    private let logger = Logger(subsystem: "com.opencount.perf", category: "PerformanceMonitor")

    // MARK: - Lifecycle

    override private init() {
        super.init()
    }

    /// Start monitoring FPS and memory usage.
    func start() {
        // FPS sampling via CADisplayLink
        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkTick))
        displayLink?.add(to: .main, forMode: .common)

        // Memory sampling every 500ms
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.sampleMemory()
            }
        }

        logger.info("Performance monitoring started")
    }

    /// Stop monitoring FPS and memory usage.
    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        timer?.invalidate()
        timer = nil
        logger.info("Performance monitoring stopped")
    }

    // MARK: - AI Inference Tracking

    /// Record an AI inference latency measurement.
    /// - Parameter ms: Inference duration in milliseconds.
    func recordAILatency(_ ms: Double) {
        aiLatencies.append(ms)
        if aiLatencies.count > 20 {
            aiLatencies.removeFirst()
        }

        let isSlowOp = ms > slowOperationThresholdMS
        if isSlowOp {
            logger.warning("Slow AI inference: \(String(format: "%.0f", ms))ms")
        }
    }

    /// Track a named operation's performance.
    /// - Parameters:
    ///   - name: Operation identifier (e.g., "detect_objects", "export_pdf").
    ///   - duration: Duration in seconds.
    func trackOperation(name: String, duration: TimeInterval) {
        let durationMS = duration * 1000
        let memoryMB = ramUsageMB
        let isSlowOp = duration > (slowOperationThresholdMS / 1000)

        let metric = PerformanceMetrics(
            timestamp: Date(),
            operationName: name,
            duration: duration,
            memoryUsedMB: memoryMB,
            isSlowOperation: isSlowOp
        )

        operationMetrics.append(metric)
        if operationMetrics.count > 100 {
            operationMetrics.removeFirst()
        }

        if isSlowOp {
            logger.warning("Slow operation '\(name)': \(String(format: "%.0f", durationMS))ms @ \(String(format: "%.1f", memoryMB))MB")
        }
    }

    // MARK: - Memory Tracking

    /// Sample current RAM usage and update published properties.
    private func sampleMemory() {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if result == KERN_SUCCESS {
            let residentMB = Double(info.resident_size) / 1_048_576
            ramUsageMB = residentMB

            if residentMB > peakRAMMB {
                peakRAMMB = residentMB
            }

            let snapshot = MemorySnapshot(timestamp: Date(), residentMB: residentMB, peakMB: peakRAMMB)
            memorySnapshots.append(snapshot)
            if memorySnapshots.count > 50 {
                memorySnapshots.removeFirst()
            }
        }
    }

    // MARK: - FPS Sampling

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

    // MARK: - Diagnostics & Export

    /// Get a summary of recent operation metrics.
    func getOperationsSummary() -> [(name: String, count: Int, avgDurationMS: Double, slowCount: Int)] {
        var summary: [String: (count: Int, totalDuration: TimeInterval, slowCount: Int)] = [:]

        for metric in operationMetrics {
            if var existing = summary[metric.operationName] {
                existing.count += 1
                existing.totalDuration += metric.duration
                if metric.isSlowOperation {
                    existing.slowCount += 1
                }
                summary[metric.operationName] = existing
            } else {
                summary[metric.operationName] = (count: 1, totalDuration: metric.duration, slowCount: metric.isSlowOperation ? 1 : 0)
            }
        }

        return summary.map { name, stats in
            (name: name, count: stats.count, avgDurationMS: (stats.totalDuration / Double(stats.count)) * 1000, slowCount: stats.slowCount)
        }
        .sorted { $0.avgDurationMS > $1.avgDurationMS }
    }

    /// Get average AI inference latency.
    func getAverageAILatency() -> Double? {
        guard !aiLatencies.isEmpty else { return nil }
        return aiLatencies.reduce(0, +) / Double(aiLatencies.count)
    }

    /// Export diagnostics as JSON-encodable dictionary.
    func exportDiagnostics() -> [String: Any] {
        let operationsSummary = getOperationsSummary()

        return [
            "fps": currentFPS,
            "ram_current_mb": ramUsageMB,
            "ram_peak_mb": peakRAMMB,
            "ai_latencies_ms": aiLatencies,
            "ai_latency_avg_ms": getAverageAILatency() ?? 0,
            "ai_latency_max_ms": aiLatencies.max() ?? 0,
            "ai_latency_min_ms": aiLatencies.min() ?? 0,
            "operations_summary": operationsSummary.map { [
                "name": $0.name,
                "count": $0.count,
                "avg_duration_ms": $0.avgDurationMS,
                "slow_count": $0.slowCount
            ]},
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "device": UIDevice.current.model,
            "ios_version": UIDevice.current.systemVersion
        ]
    }
}

// MARK: - Convenience extension for timing

/// Helper to time a closure and automatically track performance.
extension PerformanceMonitor {
    func measure<T>(
        operation name: String,
        block: () async throws -> T
    ) async throws -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        defer {
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            trackOperation(name: name, duration: duration)
        }
        return try await block()
    }

    func measureSync<T>(
        operation name: String,
        block: () throws -> T
    ) throws -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        defer {
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            trackOperation(name: name, duration: duration)
        }
        return try block()
    }
}
