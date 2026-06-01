import SwiftUI
import Charts

// MARK: - CountHistoryView

/// Displays a chronological audit log of all tally changes within a session.
/// Entries are grouped by date and show the operation type, object type, and timestamp.
///
/// Requirements: 13.6, Requirement 36
struct CountHistoryView: View {

    let session: CountSession

    @Environment(\.dismiss) private var dismiss
    @State private var isExportingAuditLog: Bool = false
    @State private var auditLogURL: URL?
    @State private var isShareSheetPresented: Bool = false
    @State private var exportError: String?
    @State private var isShowingExportError: Bool = false

    // MARK: - Grouped history

    private var groupedHistory: [(date: String, entries: [TallyHistoryEntry])] {
        let sorted = session.tallyHistory.sorted { $0.timestamp > $1.timestamp }
        var groups: [(date: String, entries: [TallyHistoryEntry])] = []
        var currentDateStr = ""
        var currentEntries: [TallyHistoryEntry] = []

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none

        for entry in sorted {
            let dateStr = formatter.string(from: entry.timestamp)
            if dateStr != currentDateStr {
                if !currentEntries.isEmpty {
                    groups.append((date: currentDateStr, entries: currentEntries))
                }
                currentDateStr = dateStr
                currentEntries = [entry]
            } else {
                currentEntries.append(entry)
            }
        }
        if !currentEntries.isEmpty {
            groups.append((date: currentDateStr, entries: currentEntries))
        }
        return groups
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if session.tallyHistory.isEmpty {
                    emptyState
                } else {
                    historyList
                }
            }
            .navigationTitle("Count History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                        .accessibilityLabel("Close count history")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        exportAuditLog()
                    } label: {
                        if isExportingAuditLog {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                    .disabled(isExportingAuditLog || session.tallyHistory.isEmpty)
                    .accessibilityLabel("Export audit log as CSV")
                }
            }
            .sheet(isPresented: $isShareSheetPresented) {
                if let url = auditLogURL {
                    ShareSheet(activityItems: [url])
                        .ignoresSafeArea()
                }
            }
            .alert("Export Failed", isPresented: $isShowingExportError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(exportError ?? "Unknown error")
            }
        }
    }

    // MARK: - History list

    private var historyList: some View {
        List {
            ForEach(groupedHistory, id: \.date) { group in
                Section(group.date) {
                    ForEach(Array(group.entries.enumerated()), id: \.offset) { _, entry in
                        HistoryEntryRow(entry: entry)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.badge.questionmark")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("No History Yet")
                .font(.title2.weight(.semibold))
            Text("Tally changes will appear here as you count.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .accessibilityElement(children: .combine)
    }

    // MARK: - Export audit log

    private func exportAuditLog() {
        isExportingAuditLog = true
        Task.detached(priority: .userInitiated) {
            do {
                let url = try buildAuditLogCSV()
                await MainActor.run {
                    isExportingAuditLog = false
                    auditLogURL = url
                    isShareSheetPresented = true
                }
            } catch {
                await MainActor.run {
                    isExportingAuditLog = false
                    exportError = error.localizedDescription
                    isShowingExportError = true
                }
            }
        }
    }

    private func buildAuditLogCSV() throws -> URL {
        var lines = ["timestamp,operation,object_type,delta"]
        let formatter = ISO8601DateFormatter()
        for entry in session.tallyHistory.sorted(by: { $0.timestamp < $1.timestamp }) {
            let ts = formatter.string(from: entry.timestamp)
            let op = entry.delta > 0 ? "add" : "remove"
            let name = entry.objectTypeName.replacingOccurrences(of: ",", with: ";")
            lines.append("\(ts),\(op),\(name),\(entry.delta)")
        }
        let csv = lines.joined(separator: "\n")
        guard let data = csv.data(using: .utf8) else {
            throw AppError.exportWriteFailure(reason: "Failed to encode audit log.")
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(session.name)_audit_log.csv")
        try data.write(to: url, options: .atomic)
        return url
    }
}

// MARK: - HistoryEntryRow

private struct HistoryEntryRow: View {

    let entry: TallyHistoryEntry

    var body: some View {
        HStack(spacing: 12) {
            // Delta badge
            ZStack {
                Circle()
                    .fill(entry.delta > 0 ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: entry.delta > 0 ? "plus" : "minus")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(entry.delta > 0 ? .green : .red)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.objectTypeName)
                    .font(.subheadline.weight(.medium))
                Text(entry.delta > 0 ? "Marker added" : "Marker removed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(entry.timestamp, format: .dateTime.hour().minute().second())
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(entry.delta > 0 ? "Added" : "Removed") marker for \(entry.objectTypeName) at \(entry.timestamp.formatted())"
        )
    }
}

// MARK: - SparklineView (used in SessionRowView)

/// A compact sparkline chart showing counting activity over the last 7 days.
/// Requirement 47 (Req 36): display sparkline in SessionRowView.
struct SparklineView: View {

    let session: CountSession

    private struct DayCount: Identifiable {
        let id = UUID()
        let day: Int   // 0 = today, 1 = yesterday, …
        let count: Int
    }

    private var dayCounts: [DayCount] {
        let calendar = Calendar.current
        let now = Date()
        return (0..<7).reversed().map { daysAgo in
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: now) ?? now
            let start = calendar.startOfDay(for: date)
            let end = calendar.date(byAdding: .day, value: 1, to: start) ?? date
            let count = session.tallyHistory.filter {
                $0.timestamp >= start && $0.timestamp < end && $0.delta > 0
            }.count
            return DayCount(day: daysAgo, count: count)
        }
    }

    var body: some View {
        Chart(dayCounts) { item in
            BarMark(
                x: .value("Day", item.day),
                y: .value("Count", item.count)
            )
            .foregroundStyle(Color.accentColor.opacity(0.7))
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .frame(width: 60, height: 24)
        .accessibilityLabel("Counting activity sparkline for the last 7 days")
        .accessibilityHidden(true)
    }
}

// MARK: - Preview

#Preview {
    let session = CountSession(name: "Bird Survey")
    let type1 = ObjectType(name: "Robin", colorHex: "#E74C3C", iconName: "bird", sortOrder: 0, session: session)
    session.objectTypes = [type1]
    session.tallyHistory = [
        TallyHistoryEntry(timestamp: Date(), objectTypeName: "Robin", delta: 1),
        TallyHistoryEntry(timestamp: Date().addingTimeInterval(-60), objectTypeName: "Robin", delta: 1),
        TallyHistoryEntry(timestamp: Date().addingTimeInterval(-120), objectTypeName: "Robin", delta: -1),
    ]
    return CountHistoryView(session: session)
        .modelContainer(for: [CountSession.self, ObjectType.self, CountMarker.self,
                               CountRegion.self, SessionImage.self, VideoFrameCount.self],
                        inMemory: true)
}
