import SwiftUI

/// Màn hình hiển thị kết quả đếm
struct CountResultView: View {
    let result: DetectionResult
    @ObservedObject var viewModel: CountViewModel
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // Header
            resultHeader

            // Ảnh với overlay
            ZStack(alignment: .bottomTrailing) {
                Image(uiImage: result.image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .overlay(DetectionOverlay(objects: result.objects,
                                               imageSize: result.image.size))

                // Badge tổng số
                countBadge
                    .padding(8)
            }
            .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))
            .padding()

            // Tabs: Thống kê / Chi tiết
            Picker("", selection: $selectedTab) {
                Text("Thống kê").tag(0)
                Text("Chi tiết").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            if selectedTab == 0 {
                StatisticsView(statistics: result.statistics)
            } else {
                ObjectListView(objects: result.objects)
            }
        }
        .overlay(alignment: .topLeading) {
            // Nút back
            Button(action: { viewModel.reset() }) {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .padding(12)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            .padding()
        }
    }

    // MARK: - Header

    private var resultHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Kết quả")
                    .font(.title2)
                    .fontWeight(.bold)
                Text(result.timestamp, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Nút chia sẻ
            ShareLink(
                item: shareText,
                subject: Text("Kết quả đếm: \(result.totalCount) vật thể"),
                message: Text("Đếm bằng OpenCount")
            ) {
                Image(systemName: "square.and.arrow.up")
                    .font(.title3)
                    .padding(12)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal)
        .padding(.top, 60)
    }

    // MARK: - Badge

    private var countBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "number")
                .font(.caption)
            Text("\(result.totalCount)")
                .font(.title3)
                .fontWeight(.bold)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }

    // MARK: - Share

    private var shareText: String {
        """
        OpenCount - Kết quả đếm
        Tổng số: \(result.totalCount) vật thể
        Thời gian: \(result.timestamp.formatted())

        Thống kê:
        \(result.statistics.map { "  - \($0.label): \($0.count)" }.joined(separator: "\n"))

        Đếm bằng OpenCount — mã nguồn mở, miễn phí
        """
    }
}

// MARK: - Thống kê theo nhóm

struct StatisticsView: View {
    let statistics: [(label: String, count: Int)]

    var body: some View {
        List {
            ForEach(statistics, id: \.label) { stat in
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
        .listStyle(.plain)
    }
}

// MARK: - Danh sách chi tiết

struct ObjectListView: View {
    let objects: [DetectedObject]

    var body: some View {
        List(Array(objects.enumerated()), id: \.element.id) { index, obj in
            HStack {
                Text("\(index + 1)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 28)

                RoundedRectangle(cornerRadius: 4)
                    .fill(Constants.color(for: obj.label))
                    .frame(width: 12, height: 12)

                Text(obj.label)
                    .font(.body)

                Spacer()

                Text("\(Int(obj.confidence * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .listStyle(.plain)
    }
}
