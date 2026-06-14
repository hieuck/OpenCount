import SwiftUI

/// Enhanced onboarding flow with interactive tutorial and animated walkthrough.
///
/// Features:
/// - 7 pages covering core workflows and an interactive counting demo
/// - Smooth animated transitions between pages
/// - "Try Sample Session" button for hands-on learning
/// - "Skip" option to jump to app
/// - Interactive tutorial demonstrating manual and AI counting
///
/// Requirements: 29.1, 29.3
struct OnboardingView: View {

    // MARK: - Persistence

    /// Persisted flag that tracks whether the user has completed onboarding.
    /// Setting this to `true` dismisses the full-screen cover in the parent view.
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false

    // MARK: - Local state

    @State private var currentPage: Int = 0
    @State private var shouldShowSampleSession: Bool = false
    @State private var animatedProgress: Double = 0

    // MARK: - Pages (Req 29.1 — interactive onboarding)

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            systemImage: "sparkles",
            title: "Welcome to OpenCount",
            description: "Count objects in photos and videos with precision. Use manual markers, AI detection, or region drawing tools.",
            accentColor: .blue,
            feature: .welcome
        ),
        OnboardingPage(
            systemImage: "folder.badge.plus",
            title: "Create a Session",
            description: "Organise your counting work into sessions. Give each session a name, add photos or videos, and define the object types you want to count.",
            accentColor: .blue,
            feature: .createSession
        ),
        OnboardingPage(
            systemImage: "hand.tap.fill",
            title: "Manual Counting",
            description: "Tap anywhere on an image to place a marker. Use multiple object types, undo/redo, and a grid overlay to count systematically without missing anything.",
            accentColor: .green,
            feature: .manualCounting
        ),
        OnboardingPage(
            systemImage: "brain.head.profile",
            title: "AI Counting",
            description: "Let the on-device AI detect and count objects automatically — no internet required. Review detections, adjust the confidence threshold, and accept results with one tap.",
            accentColor: .purple,
            feature: .aiCounting
        ),
        OnboardingPage(
            systemImage: "lasso",
            title: "Region Drawing",
            description: "Draw rectangles, ellipses, or freehand polygons to focus counting on specific areas. Each region shows its own tally alongside the global count.",
            accentColor: .orange,
            feature: .regionDrawing
        ),
        OnboardingPage(
            systemImage: "square.and.arrow.up",
            title: "Export Your Data",
            description: "Share results as CSV, JSON, annotated images, or PDF reports — ready for spreadsheets, research, or archiving. Copy a plain-text summary to the clipboard in one tap.",
            accentColor: .teal,
            feature: .export
        ),
        OnboardingPage(
            systemImage: "wand.and.stars",
            title: "Try Interactive Demo",
            description: "Ready to see it in action? Start a sample session with pre-loaded images and guided interactions to learn by doing.",
            accentColor: .yellow,
            feature: .interactive
        ),
    ]

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Paged tab view with animated transitions
            TabView(selection: $currentPage) {
                ForEach(pages.indices, id: \.self) { index in
                    OnboardingPageView(
                        page: pages[index],
                        isActive: currentPage == index
                    )
                    .tag(index)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .animation(.easeInOut(duration: 0.4), value: currentPage)

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
            // Bottom action buttons on the last page
            if currentPage == pages.count - 1 {
                VStack(spacing: 12) {
                    // Try Sample Session button
                    Button {
                        shouldShowSampleSession = true
                    } label: {
                        Text("Try Sample Session")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.accentColor)
                            )
                            .foregroundStyle(.white)
                    }
                    .accessibilityLabel("Try Sample Session")
                    .accessibilityHint("Start an interactive demo session with sample images and guided interactions.")

                    // Get Started button
                    Button {
                        hasSeenOnboarding = true
                    } label: {
                        Text("Get Started")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color(.secondarySystemBackground))
                            )
                            .foregroundStyle(.primary)
                    }
                    .accessibilityLabel("Get Started")
                    .accessibilityHint("Skip the sample session and go straight to the app.")
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: currentPage)
        .background(Color(.systemBackground).ignoresSafeArea())
        .sheet(isPresented: $shouldShowSampleSession) {
            SampleSessionView {
                shouldShowSampleSession = false
                hasSeenOnboarding = true
            }
        }
    }
}

// MARK: - OnboardingPage model

/// Data model for a single onboarding page.
struct OnboardingPage {
    let systemImage: String
    let title: String
    let description: String
    var accentColor: Color = .accentColor
    let feature: OnboardingFeature

    enum OnboardingFeature {
        case welcome
        case createSession
        case manualCounting
        case aiCounting
        case regionDrawing
        case export
        case interactive
    }
}

// MARK: - OnboardingPageView

/// Renders a single onboarding page with animated icon, title, and description.
/// Uses smooth fade-in animations and parallax effects for visual appeal.
struct OnboardingPageView: View {

    let page: OnboardingPage
    let isActive: Bool

    @State private var isVisible: Bool = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Animated icon with scale and fade
            ZStack {
                Circle()
                    .fill(page.accentColor.opacity(0.12))
                    .frame(width: 140, height: 140)
                    .scaleEffect(isVisible ? 1 : 0.8)
                    .opacity(isVisible ? 1 : 0)

                Image(systemName: page.systemImage)
                    .font(.system(size: 64, weight: .thin))
                    .foregroundStyle(page.accentColor)
                    .scaleEffect(isVisible ? 1 : 0.8)
                    .opacity(isVisible ? 1 : 0)
            }
            .accessibilityHidden(true)
            .padding(.bottom, 8)

            // Animated title
            Text(page.title)
                .font(.largeTitle.weight(.bold))
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)
                .padding(.horizontal, 32)
                .accessibilityAddTraits(.isHeader)
                .opacity(isVisible ? 1 : 0)
                .offset(y: isVisible ? 0 : 10)

            // Animated description
            Text(page.description)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 40)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(isVisible ? 1 : 0)
                .offset(y: isVisible ? 0 : 10)

            // Animated feature preview for specific pages
            if isActive {
                FeaturePreviewView(feature: page.feature, accentColor: page.accentColor)
                    .opacity(isVisible ? 1 : 0)
                    .transition(.opacity)
            }

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(page.title). \(page.description)")
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                isVisible = true
            }
        }
        .onChange(of: isActive) { active in
            if active {
                isVisible = true
            } else {
                isVisible = false
            }
        }
    }
}

// MARK: - FeaturePreviewView

/// Shows a preview or mini-demo of the feature being described.
struct FeaturePreviewView: View {

    let feature: OnboardingPage.OnboardingFeature
    let accentColor: Color

    var body: some View {
        Group {
            switch feature {
            case .welcome:
                WelcomePreview(accentColor: accentColor)

            case .createSession:
                SessionCreationPreview(accentColor: accentColor)

            case .manualCounting:
                ManualCountingPreview(accentColor: accentColor)

            case .aiCounting:
                AICountingPreview(accentColor: accentColor)

            case .regionDrawing:
                RegionDrawingPreview(accentColor: accentColor)

            case .export:
                ExportPreview(accentColor: accentColor)

            case .interactive:
                InteractivePreview(accentColor: accentColor)
            }
        }
        .frame(height: 120)
        .padding(.horizontal, 32)
    }
}

// MARK: - Feature Previews

struct WelcomePreview: View {
    let accentColor: Color

    var body: some View {
        VStack {
            HStack(spacing: 16) {
                Image(systemName: "photo.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.blue)
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 28))
                    .foregroundStyle(.purple)
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 28))
                    .foregroundStyle(.teal)
            }
            .padding(.vertical, 12)
            Text("Multiple counting methods")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct SessionCreationPreview: View {
    let accentColor: Color

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(.tertiarySystemBackground))
                    .frame(width: 50, height: 50)

                VStack(alignment: .leading, spacing: 4) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.tertiarySystemBackground))
                        .frame(height: 10)
                        .frame(maxWidth: 100, alignment: .leading)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.tertiarySystemBackground))
                        .frame(height: 8)
                        .frame(maxWidth: 140, alignment: .leading)
                }

                Spacer()
            }
            .padding(12)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(10)

            Text("Organize your work into named sessions")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ManualCountingPreview: View {
    let accentColor: Color

    var body: some View {
        VStack {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.tertiarySystemBackground))

                VStack(spacing: 6) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 6, height: 6)
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 6, height: 6)
                }
            }
            .frame(height: 60)

            Text("Tap to place markers • Undo/redo • Color-coded types")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct AICountingPreview: View {
    let accentColor: Color

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                ForEach(0..<4, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.purple, lineWidth: 1.5)
                        .frame(height: 40)
                }
            }

            Text("AI automatically detects and counts objects")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct RegionDrawingPreview: View {
    let accentColor: Color

    var body: some View {
        VStack {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.tertiarySystemBackground))

                VStack {
                    HStack {
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.orange, lineWidth: 2)
                            .frame(width: 40, height: 40)
                        Spacer()
                        Circle()
                            .stroke(Color.orange, lineWidth: 2)
                            .frame(width: 40, height: 40)
                    }
                    Spacer()
                }
                .padding(12)
            }
            .frame(height: 60)

            Text("Draw regions to focus counting • Multiple shapes")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct ExportPreview: View {
    let accentColor: Color

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Label("CSV", systemImage: "doc.fill")
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.teal.opacity(0.2))
                    .cornerRadius(6)

                Label("PDF", systemImage: "doc.pdf.fill")
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.2))
                    .cornerRadius(6)

                Label("JSON", systemImage: "curlybraces")
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(6)

                Spacer()
            }

            Text("Export in multiple formats for spreadsheets & reports")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct InteractivePreview: View {
    let accentColor: Color

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "play.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(Color.yellow)
                    .cornerRadius(8)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Interactive Demo").font(.caption.weight(.semibold))
                    Text("Learn by doing").font(.caption2).foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(12)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(10)

            Text("Hands-on tutorial with sample images and guided interactions")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.yellow.opacity(0.08))
        .cornerRadius(12)
    }
}

// MARK: - SampleSessionView

/// Interactive demo session for hands-on learning.
struct SampleSessionView: View {

    @Environment(\.dismiss) private var dismiss
    let onComplete: () -> Void

    @State private var currentStep: Int = 0
    @State private var tapCount: Int = 0

    private let steps = [
        "Tap on objects in the image to place markers",
        "Tap on 3 or more objects to continue",
        "Great! You can cycle through object types by swiping",
        "Try using Undo/Redo buttons for quick corrections",
        "Sample session complete! Ready to create your first real session?"
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Interactive Demo")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    LinearProgressIndicator(
                        progress: Double(currentStep) / Double(steps.count),
                        label: "Step \(currentStep + 1) of \(steps.count)",
                        showPercentage: false
                    )

                    Text(steps[currentStep])
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)

                // Demo canvas
                ZStack {
                    Image(systemName: "photo.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(.tertiary)

                    VStack {
                        HStack {
                            Text("Tap to count: \(tapCount)")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Spacer()
                        }
                        Spacer()
                    }
                    .padding()
                }
                .frame(maxWidth: .infinity)
                .frame(height: 280)
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(12)
                .onTapGesture {
                    tapCount += 1
                    if tapCount >= 3 && currentStep == 1 {
                        advanceStep()
                    }
                }

                // Controls
                HStack(spacing: 12) {
                    Button {
                        if tapCount > 0 {
                            tapCount -= 1
                        }
                    } label: {
                        Label("Undo", systemImage: "arrow.uturn.backward")
                            .font(.caption.weight(.medium))
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button {
                        advanceStep()
                    } label: {
                        Text(currentStep == steps.count - 1 ? "Get Started" : "Next")
                            .font(.caption.weight(.medium))
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)

                Spacer()
            }
            .padding()
            .navigationTitle("Sample Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            currentStep = 0
            tapCount = 0
        }
        .onChange(of: currentStep) { step in
            if step >= steps.count {
                onComplete()
                dismiss()
            }
        }
    }

    private func advanceStep() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep += 1
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingView()
}
