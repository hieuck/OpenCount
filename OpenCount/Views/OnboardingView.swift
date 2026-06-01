import SwiftUI

/// Onboarding flow shown on first launch.
///
/// Presents 5 pages using a paged `TabView` covering the core workflows:
/// session creation, manual counting, AI counting, region drawing, and export.
/// The user can skip at any point or tap "Get Started" on the final page.
///
/// Requirements: 29.1, 29.3
struct OnboardingView: View {

    // MARK: - Persistence

    /// Persisted flag that tracks whether the user has completed onboarding.
    /// Setting this to `true` dismisses the full-screen cover in the parent view.
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false

    // MARK: - Local state

    @State private var currentPage: Int = 0

    // MARK: - Pages (Req 29.1 — 5 screens)

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            systemImage: "folder.badge.plus",
            title: "Create a Session",
            description: "Organise your counting work into sessions. Give each session a name, add photos or videos, and define the object types you want to count.",
            accentColor: .blue
        ),
        OnboardingPage(
            systemImage: "hand.tap.fill",
            title: "Manual Counting",
            description: "Tap anywhere on an image to place a marker. Use multiple object types, undo/redo, and a grid overlay to count systematically without missing anything.",
            accentColor: .green
        ),
        OnboardingPage(
            systemImage: "brain.head.profile",
            title: "AI Counting",
            description: "Let the on-device AI detect and count objects automatically — no internet required. Review detections, adjust the confidence threshold, and accept results with one tap.",
            accentColor: .purple
        ),
        OnboardingPage(
            systemImage: "lasso",
            title: "Region Drawing",
            description: "Draw rectangles, ellipses, or freehand polygons to focus counting on specific areas. Each region shows its own tally alongside the global count.",
            accentColor: .orange
        ),
        OnboardingPage(
            systemImage: "square.and.arrow.up",
            title: "Export Your Data",
            description: "Share results as CSV, JSON, annotated images, or PDF reports — ready for spreadsheets, research, or archiving. Copy a plain-text summary to the clipboard in one tap.",
            accentColor: .teal
        ),
        OnboardingPage(
            systemImage: "sparkles",
            title: "Smart Assistant",
            description: "Get AI-powered insights about your counting session — coverage analysis, cluster detection, target tracking, and actionable suggestions to improve accuracy.",
            accentColor: .yellow
        ),
    ]

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Paged tab view with built-in page indicators
            TabView(selection: $currentPage) {
                ForEach(pages.indices, id: \.self) { index in
                    OnboardingPageView(page: pages[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .animation(.easeInOut, value: currentPage)

            // Skip button — visible on all pages except the last
            if currentPage < pages.count - 1 {
                Button("Skip") {
                    hasSeenOnboarding = true
                }
                .font(.body.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.top, 56)
                .padding(.trailing, 24)
                .accessibilityLabel("Skip onboarding")
                .accessibilityHint("Skip the introduction and go straight to the app.")
            }
        }
        .overlay(alignment: .bottom) {
            // "Get Started" button on the last page
            if currentPage == pages.count - 1 {
                Button {
                    hasSeenOnboarding = true
                } label: {
                    Text("Get Started")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.accentColor)
                        )
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .accessibilityLabel("Get Started")
                .accessibilityHint("Finish the introduction and open the app.")
            }
        }
        .animation(.easeInOut(duration: 0.25), value: currentPage)
        .background(Color(.systemBackground).ignoresSafeArea())
    }
}

// MARK: - OnboardingPage model

/// Data model for a single onboarding page.
struct OnboardingPage {
    let systemImage: String
    let title: String
    let description: String
    var accentColor: Color = .accentColor
}

// MARK: - OnboardingPageView

/// Renders a single onboarding page with a large SF Symbol icon, title, and description.
/// All text uses standard SwiftUI font styles so Dynamic Type scaling is automatic.
/// Colors are semantic so Light/Dark Mode is handled automatically.
struct OnboardingPageView: View {

    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Large SF Symbol icon with per-page accent color
            ZStack {
                Circle()
                    .fill(page.accentColor.opacity(0.12))
                    .frame(width: 140, height: 140)

                Image(systemName: page.systemImage)
                    .font(.system(size: 64, weight: .thin))
                    .foregroundStyle(page.accentColor)
            }
            .accessibilityHidden(true)
            .padding(.bottom, 8)

            // Title
            Text(page.title)
                .font(.largeTitle.weight(.bold))
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)
                .padding(.horizontal, 32)
                .accessibilityAddTraits(.isHeader)

            // Description
            Text(page.description)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 40)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(page.title). \(page.description)")
    }
}

// MARK: - Preview

#Preview {
    OnboardingView()
}
