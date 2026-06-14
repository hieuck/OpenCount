import SwiftUI

// MARK: - TemplateGallerySkeletonLoader

/// Skeleton loader matching TemplateGalleryView layout.
struct TemplateGallerySkeletonLoader: View {
    var body: some View {
        List {
            ForEach(0..<6, id: \.self) { _ in
                HStack(spacing: 12) {
                    SkeletonCircle(size: 44)

                    VStack(alignment: .leading, spacing: 6) {
                        SkeletonLine(width: 120, height: 14)
                        SkeletonLine(width: 180, height: 12)
                        SkeletonLine(width: 100, height: 12)
                    }

                    Spacer()
                    SkeletonCircle(size: 24)
                }
                .padding(.vertical, 4)
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - VideoCountSkeletonLoader

/// Skeleton loader for video frame.
struct VideoCountSkeletonLoader: View {
    var body: some View {
        ZStack {
            Color.black
            VStack(spacing: 16) {
                SkeletonView(width: 200, height: 150, cornerRadius: 8)
                SkeletonLine(width: 100, height: 14)
            }
        }
    }
}

// MARK: - BatchJobSkeletonLoader

/// Skeleton loader for batch job list.
struct BatchJobSkeletonLoader: View {
    var body: some View {
        VStack(spacing: 12) {
            ForEach(0..<3, id: \.self) { _ in
                HStack(spacing: 12) {
                    SkeletonCircle(size: 40)

                    VStack(alignment: .leading, spacing: 8) {
                        SkeletonLine(width: 150, height: 14)
                        SkeletonLine(width: nil, height: 12)
                        HStack(spacing: 8) {
                            SkeletonLine(width: 60, height: 10)
                            SkeletonLine(width: 60, height: 10)
                        }
                    }

                    Spacer()
                    SkeletonLine(width: 50, height: 12)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(8)
            }
        }
        .padding()
    }
}

// MARK: - CountingViewSkeletonLoader

/// Skeleton loader for counting interface.
struct CountingViewSkeletonLoader: View {
    var body: some View {
        VStack(spacing: 0) {
            // Image placeholder
            SkeletonView(width: nil, height: 300, cornerRadius: 0)

            // Controls area
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    SkeletonCircle(size: 44)
                    SkeletonCircle(size: 44)
                    Spacer()
                    SkeletonCircle(size: 44)
                }

                VStack(spacing: 8) {
                    SkeletonLine(width: nil, height: 44)
                    SkeletonLine(width: nil, height: 44)
                }
            }
            .padding()
        }
    }
}

// MARK: - SessionListSkeletonLoader

/// Skeleton loader for session list.
struct SessionListSkeletonLoader: View {
    var body: some View {
        List {
            ForEach(0..<5, id: \.self) { _ in
                HStack(spacing: 12) {
                    SkeletonView(width: 60, height: 60, cornerRadius: 8)

                    VStack(alignment: .leading, spacing: 6) {
                        SkeletonLine(width: 150, height: 14)
                        SkeletonLine(width: 100, height: 12)
                        SkeletonLine(width: 80, height: 12)
                    }

                    Spacer()
                    SkeletonLine(width: 30, height: 14)
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - FineTuningSkeletonLoader

/// Skeleton loader for fine-tuning training.
struct FineTuningSkeletonLoader: View {
    var body: some View {
        VStack(spacing: 16) {
            SkeletonLine(width: 200, height: 16)
            SkeletonView(width: nil, height: 40, cornerRadius: 8)
            SkeletonLine(width: 100, height: 12)
            SkeletonLine(width: nil, height: 12)
            SkeletonLine(width: 150, height: 12)
        }
        .padding()
    }
}

// MARK: - ExportSkeletonLoader

/// Skeleton loader for export operation.
struct ExportSkeletonLoader: View {
    var body: some View {
        VStack(spacing: 12) {
            ForEach(0..<4, id: \.self) { _ in
                HStack(spacing: 12) {
                    SkeletonCircle(size: 20)
                    SkeletonLine(width: 150, height: 14)
                    Spacer()
                    SkeletonCircle(size: 20)
                }
                .padding(.vertical, 8)
            }
        }
        .padding()
    }
}

// MARK: - Preview

#Preview("Template Gallery") {
    TemplateGallerySkeletonLoader()
}

#Preview("Video Count") {
    VideoCountSkeletonLoader()
}

#Preview("Session List") {
    SessionListSkeletonLoader()
}
