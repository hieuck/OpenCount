import SwiftUI

/// View cấu hình độ nhạy AI và các tùy chọn
struct SettingsView: View {
    @ObservedObject var viewModel: CountViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Detection Settings
                Section("Cấu hình AI") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Độ tin cậy tối thiểu")
                            Spacer()
                            Text("\(Int(viewModel.minConfidence * 100))%")
                                .foregroundColor(.blue)
                                .fontWeight(.semibold)
                        }

                        Slider(
                            value: $viewModel.minConfidence,
                            in: 0.1...0.9,
                            step: 0.05
                        )

                        Text("Chỉ hiển thị vật thể có độ tin cậy cao hơn ngưỡng này")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // MARK: - About
                Section("Thông tin") {
                    HStack {
                        Text("Phiên bản")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Model AI")
                        Spacer()
                        Text("YOLOv3")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Framework")
                        Spacer()
                        Text("Core ML + Vision")
                            .foregroundColor(.secondary)
                    }
                }

                // MARK: - Links
                Section("Liên kết") {
                    Link(destination: URL(string: "https://github.com/your-org/OpenCount")!) {
                        HStack {
                            Image(systemName: "link")
                            Text("GitHub Repository")
                        }
                    }

                    Link(destination: URL(string: "https://github.com/your-org/OpenCount/issues")!) {
                        HStack {
                            Image(systemName: "exclamationmark.circle")
                            Text("Báo cáo lỗi")
                        }
                    }

                    Link(destination: URL(string: "https://github.com/your-org/OpenCount/blob/main/README.md")!) {
                        HStack {
                            Image(systemName: "book")
                            Text("Hướng dẫn")
                        }
                    }
                }

                // MARK: - License
                Section("License") {
                    Text("OpenCount được phát hành dưới MIT License — tự do sử dụng, chỉnh sửa, phân phối.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Cài đặt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Xong") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    SettingsView(viewModel: CountViewModel())
}
