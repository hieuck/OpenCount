import SwiftUI
import StoreKit

// MARK: - ClipLiveCountView
//
// A minimal live counting view for the App Clip.
// Shows a large tally counter with a tap-to-count button.
// Prompts the user to install the full app via SKOverlay.
//
// Requirement 56 (Req 45): App Clip binary under 15 MB, opens live counting within 3 seconds.

struct ClipLiveCountView: View {

    @State private var tally: Int = 0
    @State private var isShowingInstallOverlay: Bool = false
    @State private var showResetConfirmation: Bool = false

    var body: some View {
        ZStack {
            // Dark background
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Image(systemName: "number.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                        .accessibilityHidden(true)
                    Text("OpenCount")
                        .font(.headline)
                    Spacer()
                    Button {
                        isShowingInstallOverlay = true
                    } label: {
                        Label("Get Full App", systemImage: "arrow.down.app")
                            .font(.caption.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                            .foregroundStyle(Color.accentColor)
                    }
                    .accessibilityLabel("Install the full OpenCount app")
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 8)

                Divider()

                Spacer()

                // Large tally display
                VStack(spacing: 12) {
                    Text("\(tally)")
                        .font(.system(size: 96, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: tally)
                        .accessibilityLabel("Current count: \(tally)")

                    Text("Tap the button to count")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Count button
                Button {
                    withAnimation {
                        tally += 1
                    }
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 120, height: 120)
                            .shadow(color: Color.accentColor.opacity(0.4), radius: 20, y: 8)

                        Image(systemName: "plus")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Increment count")
                .accessibilityHint("Tap to add one to the count. Current count: \(tally).")

                Spacer()

                // Action row
                HStack(spacing: 24) {
                    // Undo last count
                    Button {
                        if tally > 0 {
                            withAnimation { tally -= 1 }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                    } label: {
                        Label("Undo", systemImage: "arrow.uturn.backward")
                            .font(.subheadline)
                    }
                    .disabled(tally == 0)
                    .accessibilityLabel("Undo last count")

                    Spacer()

                    // Reset
                    Button {
                        showResetConfirmation = true
                    } label: {
                        Label("Reset", systemImage: "arrow.counterclockwise")
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }
                    .accessibilityLabel("Reset count to zero")
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
        }
        .confirmationDialog("Reset Count?", isPresented: $showResetConfirmation, titleVisibility: .visible) {
            Button("Reset to Zero", role: .destructive) {
                withAnimation { tally = 0 }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will reset the count to zero.")
        }
        .appStoreOverlay(isPresented: $isShowingInstallOverlay) {
            SKOverlay.AppClipConfiguration(position: .bottom)
        }
    }
}

#Preview {
    ClipLiveCountView()
}
