import SwiftUI

/// View chi tiết một mục lịch sử
struct HistoryDetailView: View {
    let history: CountHistory
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Chi tiết đếm")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text(history.timestamp.formatted(date: .abbreviated, time: .standard))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Divider()

                // Thumbnail
                if let imageData = history.imageData,
                   let image = UIImage(data: imageData) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))
                }

                // Total count
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tổng số")
                        .font(.headline)
                    HStack {
                        Text("\(history.totalCount)")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(.blue)
                        Text("vật thể")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                }

                Divider()

                // Statistics
                VStack(alignment: .leading, spacing: 12) {
                    Text("Thống kê")
                        .font(.headline)

                    ForEach(history.statistics, id: \.label) { stat in
                        HStack {
                            Circle()
                                .fill(Constants.color(for: stat.label))
                                .frame(width: 12, height: 12)

                            Text(stat.label)
                                .font(.body)

                            Spacer()

                            Text("\(stat.count)")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                        }
                        .padding(.vertical, 4)
                    }
                }

                Spacer()
            }
            .padding()
        }
        .navigationTitle("Chi tiết")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        HistoryDetailView(
            history: CountHistory(
                id: UUID(),
                timestamp: Date(),
                totalCount: 42,
                statistics: [("person", 15), ("car", 12), ("dog", 8)],
                imageData: nil
            )
        )
    }
}
