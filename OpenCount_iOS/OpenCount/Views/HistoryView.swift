import SwiftUI

/// View hiển thị lịch sử đếm
struct HistoryView: View {
    @StateObject private var historyService = HistoryService()
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                if historyService.items.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "clock.badge.xmark")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("Chưa có lịch sử")
                            .font(.headline)
                        Text("Kết quả đếm sẽ xuất hiện ở đây")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    List {
                        ForEach(historyService.items) { history in
                            NavigationLink(destination: HistoryDetailView(history: history)) {
                                HistoryRowView(history: history)
                            }
                        }
                        .onDelete { indices in
                            indices.forEach { index in
                                historyService.delete(historyService.items[index])
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Lịch sử")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Đóng") {
                        dismiss()
                    }
                }

                if !historyService.items.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button(role: .destructive) {
                                historyService.deleteAll()
                            } label: {
                                Label("Xóa tất cả", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Row View

struct HistoryRowView: View {
    let history: CountHistory

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(history.totalCount) vật thể")
                        .font(.headline)
                    Text(history.timestamp, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(history.timestamp, style: .time)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }

            // Top 3 statistics
            if !history.statistics.isEmpty {
                HStack(spacing: 12) {
                    ForEach(history.statistics.prefix(3), id: \.label) { stat in
                        VStack(spacing: 2) {
                            Text(stat.label)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("\(stat.count)")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    HistoryView()
}
