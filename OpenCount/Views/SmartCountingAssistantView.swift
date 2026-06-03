import SwiftUI

// MARK: - SmartCountingAssistantView

/// Smart Counting Assistant — analyzes the current session and provides
/// AI-powered insights, suggestions, and quality checks.
///
/// Unique to OpenCount — not available in ZapCount or CountThings.
/// Requirement: Smart Assistant (Req 48)
struct SmartCountingAssistantView: View {

    let session: CountSession
    @ObservedObject var viewModel: CountingViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var insights: [CountingInsight] = []
    @State private var isAnalyzing: Bool = false

    var body: some View {
        NavigationStack {
            Group {
                if isAnalyzing {
                    analyzingView
                } else if insights.isEmpty {
                    emptyView
                } else {
                    insightsList
                }
            }
            .navigationTitle("Smart Assistant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityLabel("Close Smart Assistant")
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        analyzeSession()
                    } label: {
                        Label("Analyze", systemImage: "sparkles")
                    }
                    .disabled(isAnalyzing)
                    .accessibilityLabel("Re-analyze session")
                }
            }
        }
        .onAppear { analyzeSession() }
    }

    // MARK: - Analyzing view

    private var analyzingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .accessibilityLabel("Analyzing session")
            Text("Analyzing your session…")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty view

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("No Insights Yet")
                .font(.title2.bold())
            Text("Tap Analyze to get smart suggestions for your counting session.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Analyze Now") { analyzeSession() }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("Analyze session now")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Insights list

    private var insightsList: some View {
        List {
            Section {
                ForEach(insights) { insight in
                    InsightRow(insight: insight, onDismiss: { dismiss() })
                }
            } header: {
                Text("\(insights.count) insight\(insights.count == 1 ? "" : "s") found")
                    .font(.caption)
                    .textCase(nil)
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Analysis engine

    private func analyzeSession() {
        isAnalyzing = true
        insights = []

        Task {
            var newInsights: [CountingInsight] = []
            let markers = viewModel.markers
            let objectTypes = session.objectTypes

            // 1. Grid density suggestion
            if markers.count > 10 {
                let service = SmartCountService()
                let suggestedDensity = service.suggestGridDensity(
                    for: markers,
                    canvasSize: CGSize(width: 1000, height: 1000)
                )
                if suggestedDensity != viewModel.gridDensity {
                    let density = suggestedDensity
                    newInsights.append(CountingInsight(
                        type: .suggestion,
                        title: "Optimal Grid Density",
                        detail: "Based on \(markers.count) markers, a \(density)×\(density) grid ensures complete coverage.",
                        action: "Apply \(density)×\(density) Grid",
                        actionHandler: {
                            viewModel.gridDensity = density
                            viewModel.isGridOverlayEnabled = true
                        }
                    ))
                }
            }

            // 2. Cluster detection
            if markers.count > 5 {
                let service = SmartCountService()
                let clusters = service.detectClusters(in: markers)
                let largeClusters = clusters.filter { $0.count > 5 }
                if !largeClusters.isEmpty {
                    newInsights.append(CountingInsight(
                        type: .warning,
                        title: "Dense Clusters Detected",
                        detail: "Found \(largeClusters.count) area(s) with 5+ markers close together. Use the grid overlay to count these areas more systematically.",
                        action: nil,
                        actionHandler: nil
                    ))
                }
            }

            // 3. Uncounted object types
            let typesWithNoMarkers = objectTypes.filter { type in
                !markers.contains { $0.objectType.id == type.id }
            }
            if !typesWithNoMarkers.isEmpty && objectTypes.count > 1 {
                let names = typesWithNoMarkers.prefix(3).map(\.name).joined(separator: ", ")
                let extra = typesWithNoMarkers.count > 3 ? " and \(typesWithNoMarkers.count - 3) more" : ""
                newInsights.append(CountingInsight(
                    type: .info,
                    title: "Uncounted Object Types",
                    detail: "\(names)\(extra) have no markers yet.",
                    action: nil,
                    actionHandler: nil
                ))
            }

            // 4. Count target progress
            for type in objectTypes {
                if let target = type.targetCount, target > 0 {
                    let count = markers.filter { $0.objectType.id == type.id }.count
                    let remaining = target - count
                    if remaining > 0 {
                        newInsights.append(CountingInsight(
                            type: .progress,
                            title: "\(type.name) Target Progress",
                            detail: "\(count) of \(target) counted. \(remaining) more to reach your target.",
                            action: nil,
                            actionHandler: nil
                        ))
                    } else {
                        newInsights.append(CountingInsight(
                            type: .success,
                            title: "\(type.name) Target Reached!",
                            detail: "You've counted \(count) \(type.name) — target of \(target) achieved.",
                            action: nil,
                            actionHandler: nil
                        ))
                    }
                }
            }

            // 5. No markers yet
            if markers.isEmpty {
                newInsights.append(CountingInsight(
                    type: .info,
                    title: "No Markers Yet",
                    detail: "Start counting by tapping on the image, using voice commands, or running AI detection.",
                    action: nil,
                    actionHandler: nil
                ))
            }

            // 6. Image available but few markers — suggest AI
            if session.images.count > 0 && markers.count < 5 {
                newInsights.append(CountingInsight(
                    type: .suggestion,
                    title: "Try AI Detection",
                    detail: "You have an image but few markers. Run AI detection to automatically find and count objects.",
                    action: "Run AI Detection",
                    actionHandler: {
                        NotificationCenter.default.post(name: .runAIDetectionRequested, object: nil)
                    }
                ))
            }

            // 7. No image — suggest importing
            if session.images.isEmpty && markers.count > 0 {
                newInsights.append(CountingInsight(
                    type: .suggestion,
                    title: "Add an Image",
                    detail: "Import an image to place markers visually and get better spatial coverage.",
                    action: nil,
                    actionHandler: nil
                ))
            }

            // 8. Duplicate markers warning
            let duplicateCount = markers.filter { marker in
                markers.filter {
                    $0.id != marker.id &&
                    $0.objectType.id == marker.objectType.id &&
                    abs($0.normalizedX - marker.normalizedX) < 0.02 &&
                    abs($0.normalizedY - marker.normalizedY) < 0.02
                }.count > 0
            }.count
            if duplicateCount > 0 {
                newInsights.append(CountingInsight(
                    type: .warning,
                    title: "Possible Duplicates",
                    detail: "\(duplicateCount) marker(s) may be duplicates — placed very close to another marker of the same type. Use Review Mode to verify.",
                    action: nil,
                    actionHandler: nil
                ))
            }

            // 9. All good
            if newInsights.isEmpty {
                newInsights.append(CountingInsight(
                    type: .success,
                    title: "Looking Great!",
                    detail: "Your session looks well-organized with \(markers.count) marker\(markers.count == 1 ? "" : "s") across \(objectTypes.count) object type\(objectTypes.count == 1 ? "" : "s").",
                    action: nil,
                    actionHandler: nil
                ))
            }

            await MainActor.run {
                insights = newInsights
                isAnalyzing = false
            }
        }
    }
}

// MARK: - CountingInsight

struct CountingInsight: Identifiable {
    let id = UUID()
    let type: InsightType
    let title: String
    let detail: String
    let action: String?
    let actionHandler: (() -> Void)?

    enum InsightType {
        case suggestion, warning, info, success, progress

        var icon: String {
            switch self {
            case .suggestion: return "lightbulb.fill"
            case .warning:    return "exclamationmark.triangle.fill"
            case .info:       return "info.circle.fill"
            case .success:    return "checkmark.circle.fill"
            case .progress:   return "chart.bar.fill"
            }
        }

        var color: Color {
            switch self {
            case .suggestion: return .yellow
            case .warning:    return .orange
            case .info:       return .blue
            case .success:    return .green
            case .progress:   return .purple
            }
        }
    }
}

// MARK: - InsightRow

private struct InsightRow: View {
    let insight: CountingInsight
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: insight.type.icon)
                    .foregroundStyle(insight.type.color)
                    .font(.title3)
                    .accessibilityHidden(true)
                Text(insight.title)
                    .font(.headline)
            }

            Text(insight.detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let action = insight.action, let handler = insight.actionHandler {
                Button {
                    handler()
                    onDismiss()
                } label: {
                    Text(action)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(insight.type.color.opacity(0.15))
                        )
                        .foregroundStyle(insight.type.color)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(action)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(insight.title). \(insight.detail)")
    }
}

// MARK: - Preview

#Preview {
    let session = CountSession(name: "Bird Survey")
    let type1 = ObjectType(name: "Robin", colorHex: "#E74C3C", iconName: "bird.fill",
                           sortOrder: 0, session: session, targetCount: 10)
    let type2 = ObjectType(name: "Sparrow", colorHex: "#3498DB", iconName: "bird",
                           sortOrder: 1, session: session)
    session.objectTypes = [type1, type2]
    session.markers = (0..<7).map { i in
        CountMarker(normalizedX: Double(i) * 0.1, normalizedY: 0.5,
                    objectType: type1, session: session)
    }
    return SmartCountingAssistantView(
        session: session,
        viewModel: CountingViewModel(session: session)
    )
}
