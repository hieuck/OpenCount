import Foundation

/// Service tính toán thống kê và phân tích dữ liệu đếm
final class StatisticsService {

    // MARK: - Statistics Models

    struct ObjectStatistics {
        let label: String
        let totalCount: Int
        let averageConfidence: Double
        let detectionFrequency: Int
        let lastDetected: Date?
    }

    struct SessionStatistics {
        let totalSessions: Int
        let totalObjectsDetected: Int
        let averageObjectsPerSession: Double
        let mostCommonObject: String?
        let dateRange: (start: Date, end: Date)?
        let objectStats: [ObjectStatistics]
    }

    struct TrendData {
        let date: Date
        let count: Int
        let uniqueLabels: Int
    }

    // MARK: - Calculate Statistics

    func calculateStatistics(from results: [DetectionResult]) -> SessionStatistics {
        guard !results.isEmpty else {
            return SessionStatistics(
                totalSessions: 0,
                totalObjectsDetected: 0,
                averageObjectsPerSession: 0,
                mostCommonObject: nil,
                dateRange: nil,
                objectStats: []
            )
        }

        let totalObjects = results.reduce(0) { $0 + $1.totalCount }
        let avgPerSession = Double(totalObjects) / Double(results.count)

        var objectCounts: [String: (count: Int, confidence: [Double], dates: [Date])] = [:]

        for result in results {
            for obj in result.objects {
                if objectCounts[obj.label] == nil {
                    objectCounts[obj.label] = (count: 0, confidence: [], dates: [])
                }
                objectCounts[obj.label]?.count += 1
                objectCounts[obj.label]?.confidence.append(obj.confidence)
                objectCounts[obj.label]?.dates.append(result.timestamp)
            }
        }

        let objectStats = objectCounts.map { label, data -> ObjectStatistics in
            ObjectStatistics(
                label: label,
                totalCount: data.count,
                averageConfidence: data.confidence.isEmpty ? 0 : data.confidence.reduce(0, +) / Double(data.confidence.count),
                detectionFrequency: Set(data.dates.map { Calendar.current.startOfDay(for: $0) }).count,
                lastDetected: data.dates.max()
            )
        }.sorted { $0.totalCount > $1.totalCount }

        let mostCommon = objectStats.first?.label

        let sortedDates = results.map { $0.timestamp }.sorted()
        let dateRange = sortedDates.isEmpty ? nil : (start: sortedDates.first!, end: sortedDates.last!)

        return SessionStatistics(
            totalSessions: results.count,
            totalObjectsDetected: totalObjects,
            averageObjectsPerSession: avgPerSession,
            mostCommonObject: mostCommon,
            dateRange: dateRange,
            objectStats: objectStats
        )
    }

    func calculateDailyTrends(from results: [DetectionResult]) -> [TrendData] {
        var dailyData: [Date: (count: Int, labels: Set<String>)] = [:]

        for result in results {
            let day = Calendar.current.startOfDay(for: result.timestamp)
            if dailyData[day] == nil {
                dailyData[day] = (count: 0, labels: Set())
            }
            dailyData[day]?.count += result.totalCount
            for obj in result.objects {
                dailyData[day]?.labels.insert(obj.label)
            }
        }

        return dailyData
            .map { date, data in
                TrendData(date: date, count: data.count, uniqueLabels: data.labels.count)
            }
            .sorted { $0.date < $1.date }
    }

    func calculateHourlyTrends(from results: [DetectionResult]) -> [TrendData] {
        var hourlyData: [Date: (count: Int, labels: Set<String>)] = [:]

        for result in results {
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour], from: result.timestamp)
            let hour = Calendar.current.date(from: components) ?? result.timestamp

            if hourlyData[hour] == nil {
                hourlyData[hour] = (count: 0, labels: Set())
            }
            hourlyData[hour]?.count += result.totalCount
            for obj in result.objects {
                hourlyData[hour]?.labels.insert(obj.label)
            }
        }

        return hourlyData
            .map { date, data in
                TrendData(date: date, count: data.count, uniqueLabels: data.labels.count)
            }
            .sorted { $0.date < $1.date }
    }

    func calculateConfidenceDistribution(from results: [DetectionResult]) -> [String: Int] {
        var distribution: [String: Int] = [
            "90-100%": 0,
            "80-90%": 0,
            "70-80%": 0,
            "60-70%": 0,
            "<60%": 0
        ]

        for result in results {
            for obj in result.objects {
                let confidence = obj.confidence * 100
                if confidence >= 90 {
                    distribution["90-100%"]! += 1
                } else if confidence >= 80 {
                    distribution["80-90%"]! += 1
                } else if confidence >= 70 {
                    distribution["70-80%"]! += 1
                } else if confidence >= 60 {
                    distribution["60-70%"]! += 1
                } else {
                    distribution["<60%"]! += 1
                }
            }
        }

        return distribution
    }

    func getTopObjects(from results: [DetectionResult], limit: Int = 10) -> [ObjectStatistics] {
        let stats = calculateStatistics(from: results)
        return Array(stats.objectStats.prefix(limit))
    }

    func calculateAccuracyMetrics(from results: [DetectionResult]) -> (avgConfidence: Double, minConfidence: Double, maxConfidence: Double) {
        var allConfidences: [Double] = []

        for result in results {
            for obj in result.objects {
                allConfidences.append(obj.confidence)
            }
        }

        guard !allConfidences.isEmpty else {
            return (avgConfidence: 0, minConfidence: 0, maxConfidence: 0)
        }

        let avg = allConfidences.reduce(0, +) / Double(allConfidences.count)
        let min = allConfidences.min() ?? 0
        let max = allConfidences.max() ?? 0

        return (avgConfidence: avg, minConfidence: min, maxConfidence: max)
    }
}
