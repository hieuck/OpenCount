import SwiftUI
import UIKit

// MARK: - HapticFeedback Helper

enum HapticFeedback {
    static func markerPlaced() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    static func selectionChanged() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }

    static func successNotification() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}

// MARK: - TallyCounterView

/// A large-button tally counter view for quick manual counting without an image.
/// Inspired by physical tally counters — one big tap increments the count.
/// Supports multiple object types with swipe to switch.
///
/// This gives OpenCount a key advantage over ZapCount and CountThings:
/// a dedicated, distraction-free counting mode for fieldwork.
struct TallyCounterView: View {

    let session: CountSession
    @ObservedObject var viewModel: CountingViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var currentTypeIndex: Int = 0
    @State private var showFlash: Bool = false
    @State private var lastCount: Int = 0

    private var objectTypes: [ObjectType] {
        session.objectTypes.sorted { $0.sortOrder < $1.sortOrder }
    }

    private var currentType: ObjectType? {
        guard !objectTypes.isEmpty else { return nil }
        return objectTypes[currentTypeIndex % objectTypes.count]
    }

    private var currentCount: Int {
        guard let type = currentType else { return 0 }
        return viewModel.markers.filter { $0.objectType.id == type.id }.count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background color from current type
                if let type = currentType {
                    (Color(hex: type.colorHex) ?? .accentColor)
                        .opacity(0.12)
                        .ignoresSafeArea()
                }

                VStack(spacing: 0) {
                    // Type selector
                    if objectTypes.count > 1 {
                        typeSelectorStrip
                            .padding(.top, 8)
                    }

                    Spacer()

                    // Count display
                    countDisplay

                    Spacer()

                    // Main tap button
                    tapButton

                    // Undo button
                    undoButton
                        .padding(.bottom, 32)
                }
            }
            .navigationTitle("Tally Counter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Type selector strip

    private var typeSelectorStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(objectTypes.indices, id: \.self) { index in
                    let type = objectTypes[index]
                    let isSelected = index == currentTypeIndex % objectTypes.count
                    let count = viewModel.markers.filter { $0.objectType.id == type.id }.count

                    Button {
                        HapticFeedback.selectionChanged()
                        withAnimation(.spring(response: 0.3)) {
                            currentTypeIndex = index
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Text(type.name)
                                .font(.caption.weight(isSelected ? .bold : .regular))
                                .foregroundStyle(isSelected ? .primary : .secondary)
                            Text("\(count)")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(isSelected
                                    ? (Color(hex: type.colorHex) ?? .accentColor)
                                    : .secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(isSelected
                                      ? (Color(hex: type.colorHex) ?? .accentColor).opacity(0.15)
                                      : Color(.secondarySystemBackground))
                        )
                        .overlay(
                            Capsule()
                                .stroke(isSelected
                                        ? (Color(hex: type.colorHex) ?? .accentColor)
                                        : Color.clear,
                                        lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Count display

    private var countDisplay: some View {
        VStack(spacing: 8) {
            if let type = currentType {
                Text(type.name)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }

            Text("\(currentCount)")
                .font(.system(size: 120, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(currentType.flatMap { Color(hex: $0.colorHex) } ?? .accentColor)
                .contentTransition(.numericText(countsDown: currentCount < lastCount))
                .animation(.spring(response: 0.3), value: currentCount)
                .accessibilityLabel("Count: \(currentCount)")

            // Target progress if set
            if let type = currentType, let target = type.targetCount, target > 0 {
                VStack(spacing: 4) {
                    ProgressView(value: Double(currentCount), total: Double(target))
                        .tint(Color(hex: type.colorHex) ?? .accentColor)
                        .frame(width: 200)
                    Text("\(currentCount) / \(target)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .overlay(
            // Flash overlay on tap
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(showFlash ? 0.3 : 0))
                .animation(.easeOut(duration: 0.15), value: showFlash)
                .allowsHitTesting(false)
        )
    }

    // MARK: - Tap button

    private var tapButton: some View {
        Button {
            guard let type = currentType else { return }
            lastCount = currentCount
            viewModel.selectedObjectType = type
            viewModel.placeMarker(at: CGPoint(x: 0.5, y: 0.5))

            // Haptic feedback for tap
            HapticFeedback.markerPlaced()
            HapticFeedback.successNotification()

            // Flash feedback
            withAnimation { showFlash = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation { showFlash = false }
            }
        } label: {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                currentType.flatMap { Color(hex: $0.colorHex) } ?? .accentColor,
                                (currentType.flatMap { Color(hex: $0.colorHex) } ?? .accentColor)
                                    .opacity(0.7)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 200, height: 200)
                    .shadow(
                        color: (currentType.flatMap { Color(hex: $0.colorHex) } ?? .accentColor)
                            .opacity(0.4),
                        radius: 20, x: 0, y: 8
                    )

                VStack(spacing: 8) {
                    Image(systemName: currentType?.iconName ?? "plus")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("TAP")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(showFlash ? 0.95 : 1.0)
        .animation(.spring(response: 0.15, dampingFraction: 0.6), value: showFlash)
        .accessibilityLabel("Count \(currentType?.name ?? "object")")
        .accessibilityHint("Tap to increment the count by 1.")
    }

    // MARK: - Undo button

    private var undoButton: some View {
        Button {
            HapticFeedback.selectionChanged()
            viewModel.undo()
        } label: {
            Label("Undo", systemImage: "arrow.uturn.backward")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .disabled(!viewModel.canUndo)
        .padding(.top, 16)
        .accessibilityLabel("Undo last count")
    }
}
