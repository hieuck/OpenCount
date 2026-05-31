import SwiftUI
import PhotosUI

/// Màn hình chính: idle → chọn ảnh → kết quả
struct ContentView: View {
    @StateObject private var viewModel = CountViewModel()

    var body: some View {
        ZStack {
            // Background
            Color(.systemGray6)
                .ignoresSafeArea()

            switch viewModel.state {
            case .idle:
                EmptyStateView(viewModel: viewModel)

            case .processing:
                ProcessingView()

            case .result:
                if let result = viewModel.currentResult {
                    CountResultView(result: result, viewModel: viewModel)
                }

            case .error(let message):
                ErrorView(message: message, viewModel: viewModel)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.state)
        .sheet(isPresented: $viewModel.showingCamera) {
            CameraView { image in
                viewModel.capturedPhoto(image)
            }
        }
        .onChange(of: viewModel.state) { newState in
            if case .result = newState {
                // Haptic feedback khi có kết quả
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
            }
        }
    }
}

// MARK: - Trạng thái: Chưa chọn ảnh

struct EmptyStateView: View {
    @ObservedObject var viewModel: CountViewModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Icon
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 80))
                .foregroundStyle(.blue)
                .symbolEffect(.bounce, options: .repeating)

            Text("OpenCount")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Đếm vật thể bằng AI — miễn phí, mã nguồn mở")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            // Nút chụp ảnh
            Button(action: { viewModel.takePhoto() }) {
                Label("Chụp ảnh", systemImage: "camera.fill")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))
            }
            .padding(.horizontal)

            // Nút chọn từ thư viện
            PhotosPicker(
                selection: Binding(
                    get: { nil },
                    set: { viewModel.selectPhoto($0) }
                ),
                matching: .images
            ) {
                Label("Chọn từ thư viện", systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray5))
                    .foregroundColor(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))
            }
            .padding(.horizontal)

            // Footer
            Text("Chụp hoặc chọn ảnh — AI sẽ tự động phát hiện và đếm vật thể")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 8)
        }
    }
}

// MARK: - Trạng thái: Đang xử lý

struct ProcessingView: View {
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 4)
                    .frame(width: 80, height: 80)

                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(.blue, lineWidth: 4)
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
                    .animation(
                        .linear(duration: 1).repeatForever(autoreverses: false),
                        value: isAnimating
                    )
            }

            Text("AI đang xử lý...")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("Phát hiện và đếm vật thể trong ảnh")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()
        }
        .onAppear { isAnimating = true }
    }
}

// MARK: - Trạng thái: Lỗi

struct ErrorView: View {
    let message: String
    @ObservedObject var viewModel: CountViewModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)

            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button("Thử lại") {
                viewModel.reset()
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .padding()
    }
}
