import SwiftUI

// MARK: - CoachMarkPosition

/// Controls where the tooltip bubble is anchored relative to the highlighted view.
enum CoachMarkPosition {
    case above
    case below
    case automatic  // places below unless near the bottom of the screen
}

// MARK: - CoachMarkModifier

/// A view modifier that renders a full-screen spotlight overlay with a tooltip
/// bubble anchored to the modified view.
///
/// The spotlight effect is achieved by drawing a semi-transparent rectangle over
/// the entire screen and cutting a clear hole around the target view using
/// `.blendMode(.destinationOut)`.
///
/// Tapping anywhere on the overlay (including the tooltip) dismisses it and
/// calls `onDismiss`.
///
/// Requirements: 29.7
struct CoachMarkModifier: ViewModifier {

    // MARK: - Parameters

    /// Whether the coach mark is currently visible.
    let isPresented: Bool

    /// Short title shown in the tooltip bubble.
    let title: String

    /// Longer explanatory text shown below the title.
    let message: String

    /// Preferred tooltip position relative to the highlighted view.
    let position: CoachMarkPosition

    /// Corner radius applied to the spotlight cutout.
    let cutoutCornerRadius: CGFloat

    /// Padding added around the target view inside the spotlight cutout.
    let cutoutPadding: CGFloat

    /// Called when the user taps to dismiss the coach mark.
    let onDismiss: () -> Void

    // MARK: - State

    /// The frame of the target view in global (screen) coordinates.
    @State private var targetFrame: CGRect = .zero

    // MARK: - Body

    func body(content: Content) -> some View {
        content
            // Capture the target view's global frame.
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .onAppear {
                            targetFrame = proxy.frame(in: .global)
                        }
                        .onChange(of: proxy.frame(in: .global)) { newFrame in
                            targetFrame = newFrame
                        }
                }
            )
            .overlay {
                if isPresented && targetFrame != .zero {
                    CoachMarkOverlayView(
                        targetFrame: targetFrame,
                        title: title,
                        message: message,
                        position: position,
                        cutoutCornerRadius: cutoutCornerRadius,
                        cutoutPadding: cutoutPadding,
                        onDismiss: onDismiss
                    )
                    .ignoresSafeArea()
                    .transition(.opacity.animation(.easeInOut(duration: 0.25)))
                    .zIndex(999)
                }
            }
    }
}

// MARK: - CoachMarkOverlayView

/// The full-screen overlay that renders the spotlight cutout and tooltip bubble.
private struct CoachMarkOverlayView: View {

    let targetFrame: CGRect
    let title: String
    let message: String
    let position: CoachMarkPosition
    let cutoutCornerRadius: CGFloat
    let cutoutPadding: CGFloat
    let onDismiss: () -> Void

    // MARK: - Computed geometry

    private var paddedFrame: CGRect {
        targetFrame.insetBy(dx: -cutoutPadding, dy: -cutoutPadding)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // ── Spotlight background ──────────────────────────────────────────
            // Draw a semi-transparent overlay and punch a clear hole using
            // .compositingGroup() + .blendMode(.destinationOut).
            Color.black.opacity(0.65)
                .overlay {
                    RoundedRectangle(cornerRadius: cutoutCornerRadius, style: .continuous)
                        .frame(width: paddedFrame.width, height: paddedFrame.height)
                        .position(x: paddedFrame.midX, y: paddedFrame.midY)
                        .blendMode(.destinationOut)
                }
                .compositingGroup()
                .ignoresSafeArea()

            // ── Tooltip bubble ────────────────────────────────────────────────
            tooltipBubble
                .position(tooltipPosition)
        }
        .contentShape(Rectangle())
        .onTapGesture { onDismiss() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(message)")
        .accessibilityHint("Double-tap to dismiss this tip.")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Tooltip bubble

    private var tooltipBubble: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Spacer()
                Button("Got it") { onDismiss() }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .accessibilityLabel("Dismiss tip: \(title)")
            }
        }
        .padding(16)
        .frame(maxWidth: 280)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 4)
        )
    }

    // MARK: - Tooltip position

    private var tooltipPosition: CGPoint {
        let screenHeight = UIScreen.main.bounds.height
        let bubbleHeight: CGFloat = 120   // approximate
        let margin: CGFloat = 16

        let resolvedPosition: CoachMarkPosition
        if position == .automatic {
            // Place below unless the target is in the lower third of the screen.
            resolvedPosition = paddedFrame.maxY + bubbleHeight + margin < screenHeight
                ? .below
                : .above
        } else {
            resolvedPosition = position
        }

        let x = min(
            max(paddedFrame.midX, 140 + margin),
            UIScreen.main.bounds.width - 140 - margin
        )

        switch resolvedPosition {
        case .below, .automatic:
            return CGPoint(x: x, y: paddedFrame.maxY + bubbleHeight / 2 + margin)
        case .above:
            return CGPoint(x: x, y: paddedFrame.minY - bubbleHeight / 2 - margin)
        }
    }
}

// MARK: - View extension

extension View {

    /// Attaches a spotlight coach mark to this view.
    ///
    /// - Parameters:
    ///   - isPresented: Binding that controls visibility.
    ///   - title: Short title for the tooltip bubble.
    ///   - message: Explanatory text shown in the tooltip.
    ///   - position: Preferred tooltip placement (default `.automatic`).
    ///   - cutoutCornerRadius: Corner radius of the spotlight cutout (default `12`).
    ///   - cutoutPadding: Extra space around the target view (default `8`).
    ///   - onDismiss: Called when the user taps to dismiss.
    ///
    /// Requirements: 29.7
    func coachMark(
        isPresented: Bool,
        title: String,
        message: String,
        position: CoachMarkPosition = .automatic,
        cutoutCornerRadius: CGFloat = 12,
        cutoutPadding: CGFloat = 8,
        onDismiss: @escaping () -> Void
    ) -> some View {
        modifier(CoachMarkModifier(
            isPresented: isPresented,
            title: title,
            message: message,
            position: position,
            cutoutCornerRadius: cutoutCornerRadius,
            cutoutPadding: cutoutPadding,
            onDismiss: onDismiss
        ))
    }
}

// MARK: - Preview

#Preview {
    VStack {
        Spacer()
        Button("AI Count") {}
            .buttonStyle(.borderedProminent)
            .coachMark(
                isPresented: true,
                title: "AI Counting",
                message: "Tap here to let the on-device AI detect and count objects automatically.",
                onDismiss: {}
            )
        Spacer()
    }
}
