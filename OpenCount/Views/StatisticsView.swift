import SwiftUI
import Charts

// MARK: - StatisticsView

/// Displays statistics and history for a counting session.
///
/// Includes:
/// - Total tally summary panel (Req 13.1)
/// - Pie chart for Object_Type distribution (Req 13.2)
/// - Bar chart for per-Region tally comparison (Req 13.3)
/// - Cross-session comparison picker and chart (Req 13.4)
/// - Object density calculation (Req 13.5)
/// - Tally change history log (Req 13.6)
struct StatisticsView: View {

    // MARK: - Inputs

    let session: CountSession
    /// All available sessions for cross-session comparison.
    let allSessions: [CountSession]

    // MARK: - State

    /// The session selected for cross-session comparison.
    @State private var comparisonSessionID: UUID? = nil

    @Environment(\.dismiss) private var dismiss

    // MARK: - Computed helpers

    /// Tally per ObjectType for the current session.
    private var tallyByType: [(objectType: ObjectType, count: Int)] {
        session.objectTypes
            .sorted { $0.sortOrder < $1.sortOrder }
            .map { type in
                let count = session.markers.filter { $0.objectType.id == type.id }.count
                return (objectType: type, count: count)
            }
    }

    /// Total marker count across all types.
    private var totalCount: Int {
        session.markers.count
    }

    /// Tally per Region for the current session.
    private var tallyByRegion: [(region: CountRegion, count: Int)] {
        session.regions.map { region in
            let count = session.markers.filter { marker in
                region.contains(normalizedPoint: CGPoint(x: marker.normalizedX, y: marker.normalizedY))
            }.count
            return (region: region, count: count)
        }
    }

    /// The session selected for comparison (resolved from ID).
    private var comparisonSession: CountSession? {
        guard let id = comparisonSessionID else { return nil }
        return allSessions.first { $0.id == id }
    }

    /// Other sessions available for comparison (excludes current session).
    private var otherSessions: [CountSession] {
        allSessions.filter { $0.id != session.id }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    totalTallyPanel
                    pieChartSection
                    regionBarChartSection
                    crossSessionSection
                    densitySection
                    historySection
                }
                .padding()
            }
            .navigationTitle("Statistics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .accessibilityLabel("Close statistics")
                }
            }
        }
    }

    // MARK: - Total Tally Panel (Req 13.1)

    private var totalTallyPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Total Tally", systemImage: "number.circle.fill")

            VStack(spacing: 0) {
                ForEach(tallyByType, id: \.objectType.id) { item in
                    HStack {
                        Circle()
                            .fill(Color(hex: item.objectType.colorHex) ?? .accentColor)
                            .frame(width: 12, height: 12)
                            .accessibilityHidden(true)
                        Image(systemName: item.objectType.iconName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                        Text(item.objectType.name)
                            .font(.body)
                        Spacer()
                        Text("\(item.count)")
                            .font(.body.monospacedDigit())
                            .fontWeight(.semibold)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(item.objectType.name): \(item.count) markers")

                    if item.objectType.id != tallyByType.last?.objectType.id {
                        Divider().padding(.leading, 36)
                    }
                }

                if !tallyByType.isEmpty {
                    Divider()
                    HStack {
                        Text("Total")
                            .font(.body.weight(.semibold))
                        Spacer()
                        Text("\(totalCount)")
                            .font(.body.monospacedDigit().weight(.bold))
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .accessibilityLabel("Total markers: \(totalCount)")
                }

                if tallyByType.isEmpty {
                    Text("No object types defined.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding()
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
        }
    }

    // MARK: - Pie Chart (Req 13.2)

    private var pieChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Object Type Distribution", systemImage: "chart.pie.fill")

            if tallyByType.isEmpty || totalCount == 0 {
                emptyChartPlaceholder("No data to display.")
            } else {
                Chart(tallyByType, id: \.objectType.id) { item in
                    SectorMark(
                        angle: .value("Count", item.count),
                        innerRadius: .ratio(0.4),
                        angularInset: 1.5
                    )
                    .foregroundStyle(Color(hex: item.objectType.colorHex) ?? .accentColor)
                    .accessibilityLabel("\(item.objectType.name): \(item.count) markers, \(percentage(item.count)) percent")
                }
                .frame(height: 220)
                .chartLegend(position: .bottom, alignment: .center, spacing: 8) {
                    ForEach(tallyByType, id: \.objectType.id) { item in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color(hex: item.objectType.colorHex) ?? .accentColor)
                                .frame(width: 8, height: 8)
                            Text(item.objectType.name)
                                .font(.caption2)
                        }
                    }
                }
                .accessibilityLabel("Pie chart showing distribution of \(totalCount) markers across \(tallyByType.count) object types.")
            }
        }
    }

    // MARK: - Region Bar Chart (Req 13.3)

    private var regionBarChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Per-Region Tally", systemImage: "chart.bar.fill")

            if tallyByRegion.isEmpty {
                emptyChartPlaceholder("No regions defined.")
            } else {
                Chart(tallyByRegion, id: \.region.id) { item in
                    BarMark(
                        x: .value("Region", item.region.name),
                        y: .value("Count", item.count)
                    )
                    .foregroundStyle(Color(hex: item.region.colorHex) ?? .accentColor)
                    .accessibilityLabel("\(item.region.name): \(item.count) markers")
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                            .font(.caption2)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }
                .accessibilityLabel("Bar chart comparing marker counts across \(tallyByRegion.count) regions.")
            }
        }
    }

    // MARK: - Cross-Session Comparison (Req 13.4)

    private var crossSessionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Cross-Session Comparison", systemImage: "arrow.left.arrow.right.circle.fill")

            if otherSessions.isEmpty {
                emptyChartPlaceholder("No other sessions available for comparison.")
            } else {
                Picker("Compare with", selection: $comparisonSessionID) {
                    Text("Select a session…").tag(Optional<UUID>.none)
                    ForEach(otherSessions) { s in
                        Text(s.name).tag(Optional(s.id))
                    }
                }
                .pickerStyle(.menu)
                .accessibilityLabel("Select a session to compare with \(session.name)")

                if let other = comparisonSession {
                    crossSessionChart(other: other)
                }
            }
        }
    }

    @ViewBuilder
    private func crossSessionChart(other: CountSession) -> some View {
        // Build combined data: for each ObjectType name present in either session,
        // show a grouped bar for current session and comparison session.
        let allTypeNames: [String] = {
            var names = Set(session.objectTypes.map(\.name))
            names.formUnion(other.objectTypes.map(\.name))
            return names.sorted()
        }()

        let currentTally = tallyByTypeName(session)
        let otherTally = tallyByTypeName(other)

        let entries: [CrossSessionEntry] = allTypeNames.flatMap { name in
            [
                CrossSessionEntry(typeName: name, sessionLabel: session.name, count: currentTally[name] ?? 0),
                CrossSessionEntry(typeName: name, sessionLabel: other.name, count: otherTally[name] ?? 0)
            ]
        }

        Chart(entries) { entry in
            BarMark(
                x: .value("Object Type", entry.typeName),
                y: .value("Count", entry.count)
            )
            .foregroundStyle(by: .value("Session", entry.sessionLabel))
            .accessibilityLabel("\(entry.typeName) in \(entry.sessionLabel): \(entry.count) markers")
        }
        .frame(height: 220)
        .chartForegroundStyleScale([
            session.name: Color.accentColor,
            other.name: Color.orange
        ])
        .chartLegend(position: .bottom)
        .chartXAxis {
            AxisMarks { _ in
                AxisValueLabel()
                    .font(.caption2)
            }
        }
        .accessibilityLabel("Grouped bar chart comparing \(session.name) and \(other.name) across \(allTypeNames.count) object types.")
    }

    // MARK: - Object Density (Req 13.5)

    private var densitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Object Density", systemImage: "square.grid.3x3.fill")
            Text("Density = count per unit image area (normalized 1.0 × 1.0)")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(spacing: 0) {
                ForEach(tallyByType, id: \.objectType.id) { item in
                    HStack {
                        Circle()
                            .fill(Color(hex: item.objectType.colorHex) ?? .accentColor)
                            .frame(width: 12, height: 12)
                            .accessibilityHidden(true)
                        Text(item.objectType.name)
                            .font(.body)
                        Spacer()
                        // Normalized image area = 1.0 × 1.0 = 1.0
                        Text(String(format: "%.2f per unit area", Double(item.count) / 1.0))
                            .font(.body.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(
                        "\(item.objectType.name) density: \(String(format: "%.2f", Double(item.count) / 1.0)) per unit area"
                    )

                    if item.objectType.id != tallyByType.last?.objectType.id {
                        Divider().padding(.leading, 36)
                    }
                }

                if tallyByType.isEmpty {
                    Text("No object types defined.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding()
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
        }
    }

    // MARK: - History Log (Req 13.6)

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Tally Change History", systemImage: "clock.fill")

            if session.tallyHistory.isEmpty {
                emptyChartPlaceholder("No tally changes recorded yet.")
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(session.tallyHistory.reversed().enumerated()), id: \.offset) { _, entry in
                        HStack(alignment: .top, spacing: 12) {
                            // Delta badge
                            Text(entry.delta > 0 ? "+\(entry.delta)" : "\(entry.delta)")
                                .font(.caption.monospacedDigit().weight(.bold))
                                .foregroundStyle(entry.delta > 0 ? .green : .red)
                                .frame(width: 32, alignment: .trailing)
                                .accessibilityHidden(true)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.objectTypeName)
                                    .font(.subheadline)
                                Text(entry.timestamp, style: .relative)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Text(entry.timestamp, format: .dateTime.hour().minute().second())
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(
                            "\(entry.delta > 0 ? "Added" : "Removed") \(abs(entry.delta)) \(entry.objectTypeName) marker at \(entry.timestamp.formatted())"
                        )

                        if entry.timestamp != session.tallyHistory.first?.timestamp {
                            Divider().padding(.leading, 56)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
            }
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.headline)
            .accessibilityAddTraits(.isHeader)
    }

    private func emptyChartPlaceholder(_ message: String) -> some View {
        Text(message)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
            .accessibilityLabel(message)
    }

    /// Returns the percentage string for a count relative to the total.
    private func percentage(_ count: Int) -> String {
        guard totalCount > 0 else { return "0" }
        let pct = Double(count) / Double(totalCount) * 100
        return String(format: "%.0f", pct)
    }

    /// Builds a [typeName: count] dictionary for a given session.
    private func tallyByTypeName(_ s: CountSession) -> [String: Int] {
        var result: [String: Int] = [:]
        for type_ in s.objectTypes {
            let count = s.markers.filter { $0.objectType.id == type_.id }.count
            result[type_.name] = count
        }
        return result
    }
}

// MARK: - CrossSessionEntry (moved outside @ViewBuilder to satisfy Swift restrictions)

/// Data entry for the cross-session comparison chart.
private struct CrossSessionEntry: Identifiable {
    let id = UUID()
    let typeName: String
    let sessionLabel: String
    let count: Int
}
