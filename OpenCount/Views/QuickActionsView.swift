import SwiftUI

// MARK: - QuickActionsView

/// A floating action button (FAB) with expandable quick actions for the counting screen.
///
/// Quick actions:
///   - Voice counting
///   - Tally counter
///   - Find missed objects
///   - Review mode
///   - Count formulas
///
/// This provides faster access to key features compared to the toolbar,
/// giving OpenCount a better UX than ZapCount and CountThings.
struct QuickActionsView: View {

    @ObservedObject var viewModel: CountingViewModel
    let session: CountSession

    @State private var isExpanded: Bool = false
    @State private var isVoicePresented: Bool = false
    @State private var isTallyPresented: Bool = false
    @State private var isReviewPresented: Bool = false
    @State private var isFormulaPresented: Bool = false
    @State private var isAssistantPresented: Bool = false

    var body: some View {
        VStack(alignment: .trailing, spacing: 12) {
            // Expanded action buttons
            if isExpanded {
                actionButton(
                    icon: "sparkles",
                    label: "Smart",
                    color: .yellow
                ) {
                    isExpanded = false
                    isAssistantPresented = true
                }

                actionButton(
                    icon: "mic.circle.fill",
                    label: "Voice",
                    color: .purple
                ) {
                    isExpanded = false
                    isVoicePresented = true
                }

                actionButton(
                    icon: "hand.tap.fill",
                    label: "Tally",
                    color: .blue
                ) {
                    isExpanded = false
                    isTallyPresented = true
                }

                actionButton(
                    icon: "eye.circle.fill",
                    label: "Review",
                    color: .orange
                ) {
                    isExpanded = false
                    isReviewPresented = true
                }

                actionButton(
                    icon: "function",
                    label: "Formula",
                    color: .green
                ) {
                    isExpanded = false
                    isFormulaPresented = true
                }
            }

            // Main FAB button
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
            } label: {
                Image(systemName: isExpanded ? "xmark" : "bolt.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(
                        Circle()
                            .fill(isExpanded ? Color.gray : Color.accentColor)
                            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                    )
                    .rotationEffect(.degrees(isExpanded ? 45 : 0))
                    .animation(.spring(response: 0.3), value: isExpanded)
            }
            .accessibilityLabel(isExpanded ? "Close quick actions" : "Open quick actions")
        }
        .padding(.trailing, 16)
        .padding(.bottom, 80) // Above the toolbar
        .sheet(isPresented: $isVoicePresented) {
            VoiceCountingView(session: session, viewModel: viewModel)
        }
        .sheet(isPresented: $isTallyPresented) {
            TallyCounterView(session: session, viewModel: viewModel)
        }
        .sheet(isPresented: $isReviewPresented) {
            ReviewModeSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $isFormulaPresented) {
            CountFormulaView(session: session, viewModel: viewModel)
        }
        .sheet(isPresented: $isAssistantPresented) {
            SmartCountingAssistantView(session: session, viewModel: viewModel)
        }
    }

    private func actionButton(
        icon: String,
        label: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    )

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(color)
                            .shadow(color: color.opacity(0.3), radius: 6, x: 0, y: 3)
                    )
            }
        }
        .buttonStyle(.plain)
        .transition(.asymmetric(
            insertion: .scale(scale: 0.5).combined(with: .opacity),
            removal: .scale(scale: 0.5).combined(with: .opacity)
        ))
        .accessibilityLabel(label)
    }
}
