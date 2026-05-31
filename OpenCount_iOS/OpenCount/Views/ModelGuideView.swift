import SwiftUI

/// View hướng dẫn cài đặt YOLOv3 model
struct ModelGuideView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Cài đặt Model AI")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("YOLOv3 chưa được tải về")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Divider()

                    // Step 1: Clone repo
                    StepView(
                        number: 1,
                        title: "Clone repository",
                        description: "Nếu chưa có, clone project từ GitHub",
                        code: "git clone https://github.com/your-org/OpenCount.git\ncd OpenCount"
                    )

                    // Step 2: Download model
                    StepView(
                        number: 2,
                        title: "Tải YOLOv3 model",
                        description: "Chạy script để tải model (~200MB)",
                        code: "cd Scripts\n./download_model.sh"
                    )

                    // Step 3: Verify
                    StepView(
                        number: 3,
                        title: "Kiểm tra model",
                        description: "Model sẽ được lưu tại:",
                        code: "OpenCount_iOS/OpenCount/Resources/YOLOv3.mlmodel"
                    )

                    // Step 4: Build
                    StepView(
                        number: 4,
                        title: "Build app",
                        description: "Mở Xcode và build project",
                        code: "open OpenCount_iOS/OpenCount.xcodeproj\n# Cmd+R để build & run"
                    )

                    Divider()

                    // Troubleshooting
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Gặp vấn đề?")
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 8) {
                            Label("Kiểm tra kết nối internet", systemImage: "wifi")
                            Text("Script cần tải file ~200MB từ Apple")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Label("Xóa cache và thử lại", systemImage: "trash")
                            Text("rm -rf OpenCount_iOS/OpenCount/Resources/YOLOv3.mlmodel")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Label("Xem README", systemImage: "book")
                            Text("Đọc hướng dẫn chi tiết tại README.md")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Model Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Đóng") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Step Component

struct StepView: View {
    let number: Int
    let title: String
    let description: String
    let code: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Circle()
                    .fill(.blue)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text("\(number)")
                            .font(.headline)
                            .foregroundColor(.white)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            // Code block
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "terminal.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("Terminal")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Button(action: { UIPasteboard.general.string = code }) {
                        Image(systemName: "doc.on.doc")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }

                Text(code)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.primary)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Constants.cornerRadius)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
    }
}

#Preview {
    ModelGuideView()
}
