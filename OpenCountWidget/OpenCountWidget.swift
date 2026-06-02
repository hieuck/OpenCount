import WidgetKit
import SwiftUI
import AppIntents

// MARK: - WidgetTallyEntry
// Requirement 23.3, 23.4

/// The timeline entry carrying the data to display in the widget.
struct WidgetTallyEntry: TimelineEntry {
    /// The date this entry should be displayed.
    let date: Date
    /// The session name to display.
    let sessionName: String
    /// The object type name to display (nil = all types combined).
    let objectTypeName: String?
    /// The tally count to display.
    let tally: Int
    /// The session UUID for deep-link navigation.
    let sessionID: UUID?
    /// Whether data was successfully loaded.
    let isPlaceholder: Bool
}

// MARK: - OpenCountTimelineProvider
// Requirement 23.4: updates within 15 minutes

/// Provides timeline entries for the OpenCount widget.
/// Reads the latest tally from the shared UserDefaults app group and
/// schedules a refresh every 15 minutes.
struct OpenCountTimelineProvider: TimelineProvider {

    /// The UserDefaults suite shared between the app and widget extension.
    /// The app group identifier must be configured in both targets' entitlements.
    private let sharedDefaults = UserDefaults(suiteName: "group.com.opencount.app")

    func placeholder(in context: Context) -> WidgetTallyEntry {
        WidgetTallyEntry(
            date: Date(),
            sessionName: "My Session",
            objectTypeName: "People",
            tally: 42,
            sessionID: nil,
            isPlaceholder: true
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetTallyEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetTallyEntry>) -> Void) {
        let entry = loadEntry()
        // Schedule the next refresh 15 minutes from now — Requirement 23.4
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextRefresh))
        completion(timeline)
    }

    // MARK: - Private helpers

    /// Reads the latest tally snapshot written by the main app into the shared app group.
    private func loadEntry() -> WidgetTallyEntry {
        guard let defaults = sharedDefaults else {
            return placeholderEntry()
        }

        let sessionName = defaults.string(forKey: WidgetDataKeys.sessionName) ?? "No Session"
        let objectTypeName = defaults.string(forKey: WidgetDataKeys.objectTypeName)
        let tally = defaults.integer(forKey: WidgetDataKeys.tally)
        let sessionIDString = defaults.string(forKey: WidgetDataKeys.sessionID)
        let sessionID = sessionIDString.flatMap { UUID(uuidString: $0) }

        return WidgetTallyEntry(
            date: Date(),
            sessionName: sessionName,
            objectTypeName: objectTypeName,
            tally: tally,
            sessionID: sessionID,
            isPlaceholder: false
        )
    }

    private func placeholderEntry() -> WidgetTallyEntry {
        WidgetTallyEntry(
            date: Date(),
            sessionName: "OpenCount",
            objectTypeName: nil,
            tally: 0,
            sessionID: nil,
            isPlaceholder: true
        )
    }
}

// MARK: - WidgetDataKeys

/// Keys used to share data between the main app and the widget extension via UserDefaults app group.
enum WidgetDataKeys {
    static let sessionName = "widget_sessionName"
    static let objectTypeName = "widget_objectTypeName"
    static let tally = "widget_tally"
    static let sessionID = "widget_sessionID"
}

// MARK: - OpenCountWidgetEntryView
// Requirement 23.3, 23.5

/// The SwiftUI view rendered inside the widget for all three size families.
struct OpenCountWidgetEntryView: View {

    var entry: WidgetTallyEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        // Tapping the widget opens the corresponding session — Requirement 23.5
        let deepLink = entry.sessionID.flatMap { sessionID in
            URL(string: "opencount://session/\(sessionID.uuidString)")
        } ?? URL(string: "opencount://") ?? URL(string: "about:blank")!

        widgetContent
            .widgetURL(deepLink)
            .background(Color(.systemBackground))
    }

    @ViewBuilder
    private var widgetContent: some View {
        switch family {
        case .systemSmall:
            smallWidget
        case .systemMedium:
            mediumWidget
        case .systemLarge:
            largeWidget
        default:
            smallWidget
        }
    }

    // MARK: Small widget

    private var smallWidget: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "number.circle.fill")
                    .foregroundStyle(.blue)
                    .font(.title3)
                Spacer()
            }
            Spacer()
            Text(tallyString)
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.5)
                .foregroundStyle(.primary)
            Text(subtitleText)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding()
    }

    // MARK: Medium widget

    private var mediumWidget: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Label("OpenCount", systemImage: "number.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.blue)
                Spacer()
                Text(tallyString)
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.4)
                    .foregroundStyle(.primary)
                Text(subtitleText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(entry.sessionName)
                    .font(.headline)
                    .lineLimit(2)
                    .multilineTextAlignment(.trailing)
                if let typeName = entry.objectTypeName {
                    Text(typeName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding()
    }

    // MARK: Large widget

    private var largeWidget: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("OpenCount", systemImage: "number.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.blue)
                Spacer()
                Text(entry.date, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Divider()

            Text(entry.sessionName)
                .font(.title2.weight(.semibold))
                .lineLimit(2)

            if let typeName = entry.objectTypeName {
                Text(typeName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(alignment: .lastTextBaseline) {
                Text(tallyString)
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.4)
                    .foregroundStyle(.primary)
                Text("counted")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 8)
            }

            Text("Updated \(entry.date, style: .relative) ago")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding()
    }

    // MARK: Helpers

    private var tallyString: String {
        entry.isPlaceholder ? "—" : "\(entry.tally)"
    }

    private var subtitleText: String {
        if let typeName = entry.objectTypeName {
            return typeName
        }
        return entry.sessionName
    }
}

// MARK: - OpenCountWidget
// Requirement 23.3: small, medium, large families

/// The main WidgetKit widget definition for OpenCount.
struct OpenCountWidget: Widget {

    let kind: String = "OpenCountWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: OpenCountTimelineProvider()) { entry in
            OpenCountWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("OpenCount Tally")
        .description("Shows the current tally for your selected counting session.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
