import SwiftUI

// MARK: - LoadingState enum

/// Centralized loading state management for consistent UX across the app.
enum LoadingState: Equatable {
    case idle
    case loading(progress: Double? = nil)
    case success
    case error(String)

    var isLoading: Bool {
        switch self {
        case .loading:
            return true
        default:
            return false
        }
    }

    var progress: Double? {
        switch self {
        case .loading(let progress):
            return progress
        default:
            return nil
        }
    }

    var errorMessage: String? {
        switch self {
        case .error(let message):
            return message
        default:
            return nil
        }
    }
}

// MARK: - LoadingTransition modifier

/// Smooth transitions between loading and loaded states with opacity animation.
struct LoadingTransition: ViewModifier {
    let isLoading: Bool
    let duration: Double

    func body(content: Content) -> some View {
        content
            .opacity(isLoading ? 0.6 : 1.0)
            .animation(.easeInOut(duration: duration), value: isLoading)
    }
}

extension View {
    func loadingTransition(isLoading: Bool, duration: Double = 0.25) -> some View {
        modifier(LoadingTransition(isLoading: isLoading, duration: duration))
    }
}

// MARK: - LoadingStateView

/// Displays appropriate view based on loading state with smooth transitions.
struct LoadingStateView<Content: View>: View {
    let state: LoadingState
    let content: Content
    let emptyMessage: String?
    let onRetry: (() -> Void)?

    init(
        state: LoadingState,
        emptyMessage: String? = nil,
        onRetry: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.state = state
        self.emptyMessage = emptyMessage
        self.onRetry = onRetry
        self.content = content()
    }

    var body: some View {
        ZStack {
            switch state {
            case .loading(let progress):
                if let progress {
                    VStack(spacing: 12) {
                        ProgressView(value: progress)
                            .frame(maxWidth: 120)
                        Text("\(Int(progress * 100))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ProgressView()
                }

            case .error(let message):
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title2)
                        .foregroundStyle(.red)
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    if onRetry != nil {
                        Button(action: onRetry!) {
                            Text("Retry")
                                .font(.subheadline.weight(.semibold))
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding()

            case .success, .idle:
                content
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

// MARK: - SkeletonView

/// Base skeleton loader component for shimmer animation.
struct SkeletonView: View {
    let width: CGFloat?
    let height: CGFloat
    let cornerRadius: CGFloat

    @State private var isAnimating = false

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.gray.opacity(0.15))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.0),
                                Color.white.opacity(0.3),
                                Color.white.opacity(0.0)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .offset(x: isAnimating ? 300 : -300)
            )
            .frame(width: width, height: height)
            .onAppear {
                withAnimation(Animation.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    isAnimating = true
                }
            }
    }
}

// MARK: - Skeleton Loaders

/// Skeleton loader for text lines.
struct SkeletonLine: View {
    let width: CGFloat?
    let height: CGFloat

    var body: some View {
        SkeletonView(width: width, height: height, cornerRadius: 4)
    }
}

/// Skeleton loader for circular avatars.
struct SkeletonCircle: View {
    let size: CGFloat

    var body: some View {
        Circle()
            .fill(Color.gray.opacity(0.15))
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
    }
}

/// Skeleton loader for list rows.
struct SkeletonListRow: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SkeletonLine(width: 100, height: 16)
            SkeletonLine(width: nil, height: 12)
            SkeletonLine(width: 150, height: 12)
        }
        .padding(.vertical, 8)
    }
}

/// Skeleton loader for card content.
struct SkeletonCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SkeletonView(width: nil, height: 120, cornerRadius: 8)
            SkeletonLine(width: 150, height: 16)
            SkeletonLine(width: nil, height: 12)
            SkeletonLine(width: 100, height: 12)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}
