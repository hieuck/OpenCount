import SwiftUI
import Charts

// MARK: - SessionDashboardView

/// A rich dashboard showing aggregate statistics across all sessions.
///
/// Features:
/// - Total counts across all sessions
/// - Activity timeline (counts per day over last 30 days)
/// - Top object types across all sessions
/// - Session count trend
/// - Quick access to recent sessions
///
/// This dashboard gives OpenCount a significant advantage over ZapCount
/// and CountThings which show no cross-session analytics.
struct SessionDashboardView: View {

    let sessions: [CountSession]
    @Environment(\.dismiss) private var dismiss

    // MARK: - Computed analytics

    private var totalMarkers: Int {
        sessions.reduce(0) { $0 + $1.markers.count }
    }

    private var totalSessions: Int { sessions.count }

    private var totalObjectTypes: Int {
        Set(sessions.flatMap { $0.objectTypes.map(\.name) }).count
    }

    private var recentSessions: [CountSession] {
        Array(sessions.sorted { $0.modifiedAt > $1.modifiedAt }.prefix(5))
    }

    /// Markers placed per day over the last 30 days.
    private var activityData: [(date: Date, count: Int)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var result: [(date: Date, count: Int)] = []

        for dayOffset in (0..<30).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            let nextDate = calendar.date(byAdding: .day, value: 1, to: date) ?? date
            let count = sessions.flatMap(\.markers).filter { marker in
                marker.createdAt >= date && marker.createdAt < nextDate
            }.count
            result.append((date: date, count: count))
        }
        return result
    }

    /// Top 10 object type names by total count across all sessions.
    private var topObjectTypes: [(name: String, count: Int, colorHex: String)] {
        var tallies: [String: (count: Int, colorHex: String)] = [:]
        for session in sessions {
            for marker in session.markers {
                let name = marker.objectType.name
                let existing = tallies[name] ?? (count: 0, colorHex: marker.objectType.colorHex)
                tallies[name] = (count: existing.count + 1, colorHex: existing.colorHex)
            }
        }
        return tallies
            .map { (name: $0.key, count: $0.value.count, colorHex: $0.value.colorHex) }
            .sorted { $0.count > $1.count }
            .prefix(10)
            .map { $0 }
    }

    /// Average markers per session.
    private var averageMarkersPerSession: Double {
        guard totalSessions > 0 else { return 0 }
        return Double(totalMarkers) / Double(totalSessions)
    }

    /// Most productive day (highest single-day count).
    private var mostProductiveDay: (date: Date, count: Int)? {
        activityData.max { $0.count < $1.count }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    summaryCards
                    activityChartSection
                    topObjectTypesSection
                    recentSessionsSection
                }
                .padding()
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Summary cards

    private var summaryCards: some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            spacing: 12
        ) {
            StatCard(
                title: "Total Counts",
                value: "\(totalMarkers)",
                icon: "number.circle.fill",
                color: .accentColor
            )
            StatCard(
                title: "Sessions",
                value: "\(totalSessions)",
                icon: "folder.fill",
                color: .blue
            )
            StatCard(
                title: "Object Types",
                value: "\(totalObjectTypes)",
                icon: "tag.fill",
                color: .purple
            )
            StatCard(
                title: "Avg per Session",
                value: String(format: "%.0f", averageMarkersPerSession),
                icon: "chart.bar.fill",
                color: .orange
            )
        }
    }

    // MARK: - Activity chart

    private var activityChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Activity (Last 30 Days)", systemImage: "calendar.badge.clock")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            if activityData.allSatisfy({ $0.count == 0 }) {
                emptyPlaceholder("No counting activity in the last 30 days.")
            } else {
                Chart(activityData, id: \.date) { item in
                    BarMark(
                        x: .value("Date", item.date, unit: .day),
                        y: .value("Count", item.count)
                    )
                    .foregroundStyle(Color.accentColor.gradient)
                    .cornerRadius(3)
                    .accessibilityLabel("\(item.date.formatted(date: .abbreviated, time: .omitted)): \(item.count) markers")
                }
                .frame(height: 160)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 7)) { value in
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                            .font(.caption2)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine()
                        AxisValueLabel()
                            .font(.caption2)
                    }
                }
                .accessibilityLabel("Bar chart showing counting activity over the last 30 days.")

                if let best = mostProductiveDay, best.count > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                            .font(.caption)
                        Text("Most productive: \(best.date.formatted(date: .abbreviated, time: .omitted)) — \(best.count) markers")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("Most productive day: \(best.date.formatted(date: .abbreviated, time: .omitted)) with \(best.count) markers")
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemBackground))
        )
    }

    // MARK: - Top object types

    private var topObjectTypesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Top Object Types", systemImage: "chart.bar.xaxis.ascending")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            if topObjectTypes.isEmpty {
                emptyPlaceholder("No counting data yet.")
            } else {
                let maxCount = topObjectTypes.first?.count ?? 1
                VStack(spacing: 8) {
                    ForEach(topObjectTypes, id: \.name) { item in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(Color(hex: item.colorHex) ?? .accentColor)
                                .frame(width: 10, height: 10)
                                .accessibilityHidden(true)

                            Text(item.name)
                                .font(.subheadline)
                                .lineLimit(1)
                                .frame(width: 100, alignment: .leading)

                            GeometryReader { geo in
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(hex: item.colorHex) ?? .accentColor)
                                    .frame(
                                        width: geo.size.width * CGFloat(item.count) / CGFloat(maxCount),
                                        height: 18
                                    )
                            }
                            .frame(height: 18)

                            Text("\(item.count)")
                                .font(.subheadline.monospacedDigit())
                                .fontWeight(.semibold)
                                .frame(width: 50, alignment: .trailing)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(item.name): \(item.count) total markers")
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemBackground))
        )
    }

    // MARK: - Recent sessions

    private var recentSessionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Recent Sessions", systemImage: "clock.fill")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            if recentSessions.isEmpty {
                emptyPlaceholder("No sessions yet.")
            } else {
                VStack(spacing: 0) {
                    ForEach(recentSessions) { session in
                        HStack(spacing: 12) {
                            // Color swatch of first object type
                            if let firstType = session.objectTypes.first {
                                Circle()
                                    .fill(Color(hex: firstType.colorHex) ?? .accentColor)
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Image(systemName: firstType.iconName)
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.white)
                                    )
                                    .accessibilityHidden(true)
                            } else {
                                Circle()
                                    .fill(Color(.systemFill))
                                    .frame(width: 32, height: 32)
                                    .accessibilityHidden(true)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(session.name)
                                    .font(.subheadline.weight(.medium))
                                    .lineLimit(1)
                                Text(session.modifiedAt, style: .relative)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Text("\(session.markers.count)")
                                .font(.subheadline.monospacedDigit().weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(session.name), \(session.markers.count) markers, modified \(session.modifiedAt.formatted(.relative(presentation: .named)))")

                        if session.id != recentSessions.last?.id {
                            Divider().padding(.leading, 56)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.tertiarySystemBackground))
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemBackground))
        )
    }

    // MARK: - Helpers

    private func emptyPlaceholder(_ message: String) -> some View {
        Text(message)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding()
            .accessibilityLabel(message)
    }
}

// MARK: - StatCard

private struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                    .accessibilityHidden(true)
                Spacer()
            }
            Text(value)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemBackground))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}

// MARK: - Preview

#Preview {
    SessionDashboardView(sessions: [
        CountSession(name: "Bird Survey", modifiedAt: Date()),
        CountSession(name: "Inventory", modifiedAt: Date().addingTimeInterval(-3600)),
    ])
}
