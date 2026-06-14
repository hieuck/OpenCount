import SwiftUI

// MARK: - LinearProgressIndicator

/// Linear progress bar with label and percentage display.
struct LinearProgressIndicator: View {
    let progress: Double
    let label: String?
    let showPercentage: Bool

    init(progress: Double, label: String? = nil, showPercentage: Bool = true) {
        self.progress = min(max(progress, 0), 1.0)
        self.label = label
        self.showPercentage = showPercentage
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let label {
                HStack {
                    Text(label)
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    if showPercentage {
                        Text("\(Int(progress * 100))%")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [.blue, .blue.opacity(0.7)]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * progress)
                }
            }
            .frame(height: 6)
        }
    }
}

// MARK: - CircularProgressIndicator

/// Circular progress indicator with center text.
struct CircularProgressIndicator: View {
    let progress: Double
    let size: CGFloat
    let lineWidth: CGFloat

    init(progress: Double, size: CGFloat = 80, lineWidth: CGFloat = 6) {
        self.progress = min(max(progress, 0), 1.0)
        self.size = size
        self.lineWidth = lineWidth
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [.blue, .blue.opacity(0.6)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: progress)

            VStack(spacing: 4) {
                Text("\(Int(progress * 100))")
                    .font(.system(size: 24, weight: .bold, design: .default))
                Text("%")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - StepProgressIndicator

/// Step-based progress indicator for multi-step operations.
struct StepProgressIndicator: View {
    let currentStep: Int
    let totalSteps: Int
    let stepLabels: [String]?

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                ForEach(1...totalSteps, id: \.self) { step in
                    VStack(spacing: 4) {
                        Circle()
                            .fill(step <= currentStep ? Color.blue : Color.gray.opacity(0.2))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Text("\(step)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(step <= currentStep ? .white : .gray)
                            )

                        if let labels = stepLabels, step <= labels.count {
                            Text(labels[step - 1])
                                .font(.caption2)
                                .lineLimit(1)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if step < totalSteps {
                        VStack {
                            Spacer()
                            Divider()
                                .overlay(step < currentStep ? Color.blue : Color.gray.opacity(0.2))
                            Spacer()
                        }
                    }
                }
            }

            LinearProgressIndicator(
                progress: Double(currentStep) / Double(totalSteps),
                showPercentage: false
            )
        }
    }
}

// MARK: - DeterminateProgressOverlay

/// Full-screen overlay with progress indicator and cancel option.
struct DeterminateProgressOverlay: View {
    let progress: Double
    let title: String
    let subtitle: String?
    let allowCancel: Bool
    let onCancel: (() -> Void)?

    var body: some View {
        ZStack {
            Color.black.opacity(0.2)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Text(title)
                        .font(.headline)
                    if let subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                CircularProgressIndicator(progress: progress)

                if allowCancel {
                    Button(role: .destructive) {
                        onCancel?()
                    } label: {
                        Text("Cancel")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(24)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 20)
            .padding(32)
        }
    }
}

// MARK: - IndeterminateProgressOverlay

/// Full-screen overlay with indeterminate progress.
struct IndeterminateProgressOverlay: View {
    let title: String
    let subtitle: String?
    let allowCancel: Bool
    let onCancel: (() -> Void)?

    var body: some View {
        ZStack {
            Color.black.opacity(0.2)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Text(title)
                        .font(.headline)
                    if let subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                ProgressView()
                    .frame(width: 80, height: 80)

                if allowCancel {
                    Button(role: .destructive) {
                        onCancel?()
                    } label: {
                        Text("Cancel")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(24)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 20)
            .padding(32)
        }
    }
}

// MARK: - BufferingIndicator

/// Animated buffering indicator for streaming/loading content.
struct BufferingIndicator: View {
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.blue)
                    .frame(width: 8, height: 8)
                    .scaleEffect(isAnimating && Double(index) == (Date().timeIntervalSince1970.truncatingRemainder(dividingBy: 0.3) / 0.1).rounded() ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.6).repeatForever(), value: isAnimating)
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Preview

#Preview("Linear Progress") {
    VStack(spacing: 20) {
        LinearProgressIndicator(progress: 0.3, label: "Downloading")
        LinearProgressIndicator(progress: 0.6, label: "Processing")
        LinearProgressIndicator(progress: 1.0, label: "Complete")
    }
    .padding()
}

#Preview("Circular Progress") {
    VStack(spacing: 20) {
        CircularProgressIndicator(progress: 0.3)
        CircularProgressIndicator(progress: 0.7)
        CircularProgressIndicator(progress: 1.0)
    }
    .padding()
}

#Preview("Step Progress") {
    StepProgressIndicator(
        currentStep: 2,
        totalSteps: 4,
        stepLabels: ["Upload", "Process", "Review", "Complete"]
    )
    .padding()
}

#Preview("Buffering") {
    BufferingIndicator()
}
