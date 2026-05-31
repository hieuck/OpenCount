import SwiftUI

/// Màn hình hiển thị thống kê và phân tích
struct StatisticsView: View {
    @ObservedObject var viewModel: CountViewModel
    @State private var selectedTab: StatisticsTab = .overview

    enum StatisticsTab {
        case overview
        case trends
        case topObjects
        case confidence
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Picker("Statistics", selection: $selectedTab) {
                    Text("Tổng quan").tag(StatisticsTab.overview)
                    Text("Xu hướng").tag(StatisticsTab.trends)
                    Text("Top vật thể").tag(StatisticsTab.topObjects)
                    Text("Độ tin cậy").tag(StatisticsTab.confidence)
                }
                .pickerStyle(.segmented)
                .padding()

                ScrollView {
                    VStack(spacing: 16) {
                        switch selectedTab {
                        case .overview:
                            OverviewTab(viewModel: viewModel)
                        case .trends:
                            TrendsTab(viewModel: viewModel)
                        case .topObjects:
                            TopObjectsTab(viewModel: viewModel)
                        case .confidence:
                            ConfidenceTab(viewModel: viewModel)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Thống kê")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Overview Tab

struct OverviewTab: View {
    @ObservedObject var viewModel: CountViewModel
    @State private var stats: StatisticsService.SessionStatistics?

    var body: some View {
        VStack(spacing: 16) {
            if let stats = stats {
                HStack(spacing: 12) {
                    StatCard(
                        title: "Phiên",
                        value: "\(stats.totalSessions)",
                        icon: "camera.fill",
                        color: .blue
                    )

                    StatCard(
                        title: "Vật thể",
                        value: "\(stats.totalObjectsDetected)",
                        icon: "cube.fill",
                        color: .green
                    )
                }

                HStack(spacing: 12) {
                    StatCard(
                        title: "Trung bình",
                        value: String(format: "%.1f", stats.averageObjectsPerSession),
                        icon: "chart.bar.fill",
                        color: .orange
                    )

                    StatCard(
                        title: "Phổ biến",
                        value: stats.mostCommonObject ?? "—",
                        icon: "star.fill",
                        color: .purple
                    )
                }

                if let dateRange = stats.dateRange {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Khoảng thời gian")
                            .font(.headline)

                        HStack {
                            Label(formatDate(dateRange.start), systemImage: "calendar")
                                .font(.subheadline)
                            Spacer()
                            Label(formatDate(dateRange.end), systemImage: "calendar")
                                .font(.subheadline)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                }

                if !stats.objectStats.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Top 5 vật thể")
                            .font(.headline)

                        ForEach(Array(stats.objectStats.prefix(5)), id: \.label) { obj in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(obj.label)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    Text("Độ tin cậy: \(String(format: "%.1f%%", obj.averageConfidence * 100))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("\(obj.totalCount)")
                                        .font(.headline)
                                    Text("\(obj.detectionFrequency) ngày")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                    }
                }
            } else {
                ContentUnavailableView(
                    "Chưa có dữ liệu",
                    systemImage: "chart.bar.xaxis",
                    description: Text("Chụp hoặc chọn ảnh để bắt đầu")
                )
            }
        }
        .onAppear {
            updateStats()
        }
        .onChange(of: viewModel.history) { _ in
            updateStats()
        }
    }

    private func updateStats() {
        let service = StatisticsService()
        stats = service.calculateStatistics(from: viewModel.history)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "vi_VN")
        return formatter.string(from: date)
    }
}

// MARK: - Trends Tab

struct TrendsTab: View {
    @ObservedObject var viewModel: CountViewModel
    @State private var dailyTrends: [StatisticsService.TrendData] = []

    var body: some View {
        VStack(spacing: 16) {
            if !dailyTrends.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Xu hướng hàng ngày")
                        .font(.headline)

                    HStack(alignment: .bottom, spacing: 4) {
                        ForEach(dailyTrends, id: \.date) { trend in
                            VStack(spacing: 4) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(.blue)
                                    .frame(height: CGFloat(trend.count) * 2)

                                Text(formatDateShort(trend.date))
                                    .font(.caption2)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .frame(height: 150)
                    .padding(.vertical)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Chi tiết")
                        .font(.headline)

                    ForEach(dailyTrends, id: \.date) { trend in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(formatDateFull(trend.date))
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text("\(trend.uniqueLabels) loại vật thể")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Text("\(trend.count)")
                                .font(.headline)
                                .foregroundColor(.blue)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                }
            } else {
                ContentUnavailableView(
                    "Chưa có dữ liệu",
                    systemImage: "chart.line.uptrend.xyaxis",
                    description: Text("Cần ít nhất 2 phiên để xem xu hướng")
                )
            }
        }
        .onAppear {
            updateTrends()
        }
        .onChange(of: viewModel.history) { _ in
            updateTrends()
        }
    }

    private func updateTrends() {
        let service = StatisticsService()
        dailyTrends = service.calculateDailyTrends(from: viewModel.history)
    }

    private func formatDateShort(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d/M"
        return formatter.string(from: date)
    }

    private func formatDateFull(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "vi_VN")
        return formatter.string(from: date)
    }
}

// MARK: - Stat Card Component

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }

            Text(value)
                .font(.title2)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Top Objects Tab

struct TopObjectsTab: View {
    @ObservedObject var viewModel: CountViewModel
    @State private var topObjects: [StatisticsService.ObjectStatistics] = []

    var body: some View {
        VStack(spacing: 16) {
            if !topObjects.isEmpty {
                ForEach(topObjects, id: \.label) { obj in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(obj.label)
                                .font(.headline)
                            Spacer()
                            Text("\(obj.totalCount)")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                        }

                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(.systemGray5))

                                RoundedRectangle(cornerRadius: 4)
                                    .fill(.blue)
                                    .frame(width: geometry.size.width * CGFloat(obj.averageConfidence))
                            }
                        }
                        .frame(height: 8)

                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Độ tin cậy")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(String(format: "%.1f%%", obj.averageConfidence * 100))
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Ngày phát hiện")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(obj.detectionFrequency)")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                        }

                        if let lastDetected = obj.lastDetected {
                            Text("Lần cuối: \(formatDate(lastDetected))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            } else {
                ContentUnavailableView(
                    "Chưa có dữ liệu",
                    systemImage: "list.bullet",
                    description: Text("Chụp hoặc chọn ảnh để bắt đầu")
                )
            }
        }
        .onAppear {
            updateTopObjects()
        }
        .onChange(of: viewModel.history) { _ in
            updateTopObjects()
        }
    }

    private func updateTopObjects() {
        let service = StatisticsService()
        topObjects = service.getTopObjects(from: viewModel.history, limit: 20)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "vi_VN")
        return formatter.string(from: date)
    }
}

// MARK: - Confidence Tab

struct ConfidenceTab: View {
    @ObservedObject var viewModel: CountViewModel
    @State private var distribution: [String: Int] = [:]
    @State private var metrics: (avgConfidence: Double, minConfidence: Double, maxConfidence: Double)?

    var body: some View {
        VStack(spacing: 16) {
            if let metrics = metrics {
                HStack(spacing: 12) {
                    StatCard(
                        title: "Trung bình",
                        value: String(format: "%.1f%%", metrics.avgConfidence * 100),
                        icon: "chart.bar.fill",
                        color: .blue
                    )

                    StatCard(
                        title: "Tối thiểu",
                        value: String(format: "%.1f%%", metrics.minConfidence * 100),
                        icon: "arrow.down",
                        color: .orange
                    )
                }

                StatCard(
                    title: "Tối đa",
                    value: String(format: "%.1f%%", metrics.maxConfidence * 100),
                    icon: "arrow.up",
                    color: .green
                )

                if !distribution.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Phân bố độ tin cậy")
                            .font(.headline)

                        ForEach(["90-100%", "80-90%", "70-80%", "60-70%", "<60%"], id: \.self) { range in
                            if let count = distribution[range] {
                                HStack {
                                    Text(range)
                                        .font(.subheadline)
                                        .frame(width: 60, alignment: .leading)

                                    GeometryReader { geometry in
                                        ZStack(alignment: .leading) {
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(Color(.systemGray5))

                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(colorForRange(range))
                                                .frame(width: geometry.size.width * CGFloat(count) / CGFloat(distribution.values.max() ?? 1))
                                        }
                                    }
                                    .frame(height: 24)

                                    Text("\(count)")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .frame(width: 40, alignment: .trailing)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            } else {
                ContentUnavailableView(
                    "Chưa có dữ liệu",
                    systemImage: "chart.pie.fill",
                    description: Text("Chụp hoặc chọn ảnh để bắt đầu")
                )
            }
        }
        .onAppear {
            updateConfidence()
        }
        .onChange(of: viewModel.history) { _ in
            updateConfidence()
        }
    }

    private func updateConfidence() {
        let service = StatisticsService()
        distribution = service.calculateConfidenceDistribution(from: viewModel.history)
        metrics = service.calculateAccuracyMetrics(from: viewModel.history)
    }

    private func colorForRange(_ range: String) -> Color {
        switch range {
        case "90-100%": return .green
        case "80-90%": return .blue
        case "70-80%": return .yellow
        case "60-70%": return .orange
        default: return .red
        }
    }
}

#Preview {
    StatisticsView(viewModel: CountViewModel())
}
