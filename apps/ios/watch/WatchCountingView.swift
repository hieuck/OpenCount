import SwiftUI
import WatchKit

// MARK: - WatchCountingView
// Main Watch UI: scrollable list of object types with large tap targets,
// tally badges, and Digital Crown focus for scrolling.
// Requirements: 22.2, 22.3, 22.4

struct WatchCountingView: View {

    @EnvironmentObject private var sessionManager: WatchSessionManager

    /// Tracks the Digital Crown rotation value for scrolling.
    @State private var crownValue: Double = 0.0

    /// The index of the currently focused object type (Digital Crown driven).
    @State private var focusedIndex: Int = 0

    var body: some View {
        Group {
            if sessionManager.objectTypes.isEmpty {
                emptyStateView
            } else {
                countingListView
            }
        }
        .navigationTitle(sessionManager.sessionName)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "iphone.and.arrow.forward")
                .font(.system(size: 28))
                .foregroundColor(.secondary)
            Text("Open OpenCount on iPhone to start a session")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .padding()
    }

    // MARK: - Counting List

    private var countingListView: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(Array(sessionManager.objectTypes.enumerated()), id: \.element.id) { index, objectType in
                    ObjectTypeRow(
                        objectType: objectType,
                        tally: sessionManager.tallies[objectType.id, default: 0],
                        isFocused: index == focusedIndex
                    ) {
                        sessionManager.incrementTally(for: objectType.id)
                    }
                    .id(index)
                    // Minimum 44pt tap target enforced by the row itself
                    .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                }

                // Total count footer
                Section {
                    HStack {
                        Text("Total")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(sessionManager.totalCount)")
                            .font(.system(.body, design: .rounded).bold())
                            .foregroundColor(.primary)
                    }
                    .frame(minHeight: 44)
                }
            }
            .listStyle(.carousel)
            // Digital Crown focus — scrolls through object types
            .focusable()
            .digitalCrownRotation(
                $crownValue,
                from: 0,
                through: Double(max(0, sessionManager.objectTypes.count - 1)),
                by: 1.0,
                sensitivity: .medium,
                isContinuous: false,
                isHapticFeedbackEnabled: true
            )
            .onChange(of: crownValue) { newValue in
                let newIndex = Int(newValue.rounded())
                    .clamped(to: 0...(sessionManager.objectTypes.count - 1))
                if newIndex != focusedIndex {
                    focusedIndex = newIndex
                    withAnimation {
                        proxy.scrollTo(newIndex, anchor: .center)
                    }
                }
            }
            // Sync crown range when object types change
            .onChange(of: sessionManager.objectTypes.count) { _ in
                crownValue = Double(focusedIndex.clamped(
                    to: 0...(max(0, sessionManager.objectTypes.count - 1))
                ))
            }
        }
        // Offline indicator
        .overlay(alignment: .bottom) {
            if !sessionManager.isPhoneReachable {
                offlineBanner
            }
        }
    }

    // MARK: - Offline Banner

    private var offlineBanner: some View {
        HStack(spacing: 4) {
            Image(systemName: "iphone.slash")
                .font(.caption2)
            Text("Offline — counts queued")
                .font(.caption2)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.orange.opacity(0.85))
        .clipShape(Capsule())
        .padding(.bottom, 4)
    }
}

// MARK: - ObjectTypeRow

/// A single row in the counting list.
/// Large tap target (minimum 44pt height), colored icon, name, and tally badge.
private struct ObjectTypeRow: View {

    let objectType: WatchObjectType
    let tally: Int
    let isFocused: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                // Colored icon
                ZStack {
                    Circle()
                        .fill(Color(hex: objectType.colorHex) ?? .accentColor)
                        .frame(width: 32, height: 32)
                    Image(systemName: objectType.iconName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }

                // Object type name
                Text(objectType.name)
                    .font(.system(.body, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Spacer()

                // Tally badge
                Text("\(tally)")
                    .font(.system(.title3, design: .rounded).bold())
                    .foregroundColor(isFocused ? .accentColor : .primary)
                    .monospacedDigit()
                    .frame(minWidth: 32, alignment: .trailing)
            }
            .frame(minHeight: 44) // Requirement 22.4: minimum 44pt tap target
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            isFocused
                ? Color.accentColor.opacity(0.15)
                : Color.clear
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityLabel("\(objectType.name), count: \(tally)")
        .accessibilityHint("Double tap to increment")
    }
}

// MARK: - Color Extension

private extension Color {
    /// Initializes a Color from a hex string like "#FF5733" or "FF5733".
    init?(hex: String) {
        let cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        guard cleaned.count == 6,
              let value = UInt64(cleaned, radix: 16)
        else { return nil }
        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double(value & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Comparable Clamping Helper

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - Preview

#if DEBUG
struct WatchCountingView_Previews: PreviewProvider {
    static var previews: some View {
        let manager = WatchSessionManager()
        return WatchCountingView()
            .environmentObject(manager)
    }
}
#endif
