import SwiftUI
import WidgetKit
import ClockKit

// MARK: - WatchComplicationView
// WidgetKit-based complication for the OpenCount Watch app.
// Displays the total session count in a Graphic Circular family.
// Requirement 22.6

// MARK: - Timeline Entry

struct CountComplicationEntry: TimelineEntry {
    let date: Date
    let totalCount: Int
    let sessionName: String
}

// MARK: - Timeline Provider

struct CountComplicationProvider: TimelineProvider {

    typealias Entry = CountComplicationEntry

    func placeholder(in context: Context) -> CountComplicationEntry {
        CountComplicationEntry(date: Date(), totalCount: 0, sessionName: "OpenCount")
    }

    func getSnapshot(in context: Context, completion: @escaping (CountComplicationEntry) -> Void) {
        let entry = currentEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CountComplicationEntry>) -> Void) {
        let entry = currentEntry()
        // Refresh every 15 minutes to stay in sync with session changes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    // MARK: - Private

    private func currentEntry() -> CountComplicationEntry {
        // Read persisted tally from shared UserDefaults
        let totalCount = loadTotalCount()
        let sessionName = UserDefaults.standard.string(forKey: "watchSessionName") ?? "OpenCount"
        return CountComplicationEntry(date: Date(), totalCount: totalCount, sessionName: sessionName)
    }

    private func loadTotalCount() -> Int {
        guard let stringKeyed = UserDefaults.standard.dictionary(forKey: "watchTallies") as? [String: Int]
        else { return 0 }
        return stringKeyed.values.reduce(0, +)
    }
}

// MARK: - Complication Widget

struct OpenCountComplication: Widget {

    let kind: String = "OpenCountComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CountComplicationProvider()) { entry in
            CountComplicationEntryView(entry: entry)
        }
        .configurationDisplayName("OpenCount")
        .description("Shows the total count for your active session.")
        .supportedFamilies([
            .accessoryCircular,       // watchOS 9+ Graphic Circular equivalent
            .accessoryCorner,
            .accessoryInline
        ])
    }
}

// MARK: - Complication Entry View

struct CountComplicationEntryView: View {

    @Environment(\.widgetFamily) private var family
    let entry: CountComplicationEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            circularView
        case .accessoryCorner:
            cornerView
        case .accessoryInline:
            inlineView
        default:
            circularView
        }
    }

    // MARK: - Graphic Circular (accessoryCircular)
    // Requirement 22.6: Graphic Circular family showing total count prominently.

    private var circularView: some View {
        ZStack {
            // Background gauge arc
            Gauge(value: Double(min(entry.totalCount, 999)), in: 0...999) {
                EmptyView()
            }
            .gaugeStyle(.accessoryCircular)
            .tint(
                Gradient(colors: [.blue, .cyan])
            )

            // Total count number
            VStack(spacing: 0) {
                Text("\(min(entry.totalCount, 999))")
                    .font(.system(.title3, design: .rounded).bold())
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .foregroundColor(.primary)
                if entry.totalCount > 999 {
                    Text("999+")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
        }
        .accessibilityLabel("Total count: \(entry.totalCount)")
    }

    // MARK: - Corner

    private var cornerView: some View {
        ZStack {
            Image(systemName: "number.circle.fill")
                .font(.title2)
                .foregroundColor(.accentColor)
        }
        .widgetLabel {
            Text("\(entry.totalCount)")
                .font(.system(.body, design: .rounded).bold())
        }
    }

    // MARK: - Inline

    private var inlineView: some View {
        Label {
            Text("\(entry.totalCount)")
        } icon: {
            Image(systemName: "number.circle")
        }
    }
}

// MARK: - Legacy CLKComplicationDataSource (watchOS 7/8 fallback)
// Provides backward compatibility for devices running watchOS < 9.

final class ComplicationController: NSObject, CLKComplicationDataSource {

    // MARK: - Complication Configuration

    func getComplicationDescriptors(handler: @escaping ([CLKComplicationDescriptor]) -> Void) {
        let descriptors = [
            CLKComplicationDescriptor(
                identifier: "OpenCountGraphicCircular",
                displayName: "OpenCount",
                supportedFamilies: [.graphicCircular, .graphicCorner, .utilitarianSmall]
            )
        ]
        handler(descriptors)
    }

    // MARK: - Timeline Population

    func getCurrentTimelineEntry(
        for complication: CLKComplication,
        withHandler handler: @escaping (CLKComplicationTimelineEntry?) -> Void
    ) {
        handler(makeEntry(for: complication, date: Date()))
    }

    func getTimelineEntries(
        for complication: CLKComplication,
        after date: Date,
        limit: Int,
        withHandler handler: @escaping ([CLKComplicationTimelineEntry]?) -> Void
    ) {
        // Provide a single future entry 15 minutes from now
        let futureDate = Calendar.current.date(byAdding: .minute, value: 15, to: date) ?? date
        let entry = makeEntry(for: complication, date: futureDate)
        handler(entry.map { [$0] })
    }

    func getTimelineEndDate(
        for complication: CLKComplication,
        withHandler handler: @escaping (Date?) -> Void
    ) {
        handler(nil) // No end date — always current
    }

    func getPrivacyBehavior(
        for complication: CLKComplication,
        withHandler handler: @escaping (CLKComplicationPrivacyBehavior) -> Void
    ) {
        handler(.showOnLockScreen)
    }

    // MARK: - Template Construction

    private func makeEntry(
        for complication: CLKComplication,
        date: Date
    ) -> CLKComplicationTimelineEntry? {
        let totalCount = loadTotalCount()
        let countText = CLKSimpleTextProvider(text: "\(totalCount)", shortText: "\(min(totalCount, 99))")
        let label = CLKSimpleTextProvider(text: "Count")

        let template: CLKComplicationTemplate

        switch complication.family {
        case .graphicCircular:
            let t = CLKComplicationTemplateGraphicCircularStackText()
            t.line1TextProvider = CLKSimpleTextProvider(text: "COUNT")
            t.line2TextProvider = countText
            template = t

        case .graphicCorner:
            let t = CLKComplicationTemplateGraphicCornerStackText()
            t.outerTextProvider = label
            t.innerTextProvider = countText
            template = t

        case .utilitarianSmall:
            let t = CLKComplicationTemplateUtilitarianSmallFlat()
            t.textProvider = countText
            template = t

        default:
            return nil
        }

        return CLKComplicationTimelineEntry(date: date, complicationTemplate: template)
    }

    private func loadTotalCount() -> Int {
        guard let stringKeyed = UserDefaults.standard.dictionary(forKey: "watchTallies") as? [String: Int]
        else { return 0 }
        return stringKeyed.values.reduce(0, +)
    }
}

// MARK: - Preview

#if DEBUG
struct CountComplicationEntryView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            CountComplicationEntryView(
                entry: CountComplicationEntry(date: Date(), totalCount: 42, sessionName: "Bird Survey")
            )
            .previewContext(WidgetPreviewContext(family: .accessoryCircular))

            CountComplicationEntryView(
                entry: CountComplicationEntry(date: Date(), totalCount: 1234, sessionName: "Inventory")
            )
            .previewContext(WidgetPreviewContext(family: .accessoryInline))
        }
    }
}
#endif
