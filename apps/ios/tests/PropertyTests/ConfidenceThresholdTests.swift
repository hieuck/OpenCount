import XCTest
import SwiftCheck
import CoreGraphics
@testable import OpenCount

// Feature: open-count-ios, Property 3: Confidence threshold filtering is monotone
// Validates: Requirements 5.5, 5.6

// MARK: - Helpers

/// Generates a random confidence score in [0.0, 1.0].
private let confidenceScoreGen: Gen<Float> = Gen<Double>
    .choose((0.0, 1.0))
    .map { Float($0) }

/// Generates a random normalized coordinate in [0.0, 1.0].
private let normalizedCoordGen: Gen<Double> = Gen<Double>.choose((0.0, 1.0))

/// Generates a random `AIDetection` with a random confidence score.
private let aiDetectionGen: Gen<AIDetection> = Gen.zip(
    confidenceScoreGen,
    normalizedCoordGen,
    normalizedCoordGen,
    normalizedCoordGen,
    normalizedCoordGen
).map { score, x, y, w, h in
    AIDetection(
        normalizedBoundingBox: CGRect(x: x, y: y, width: w * (1.0 - x), height: h * (1.0 - y)),
        label: "object",
        confidenceScore: score
    )
}

/// Generates a list of 0–30 `AIDetection` values.
private let aiDetectionListGen: Gen<[AIDetection]> = Gen<Int>
    .choose((0, 30))
    .flatMap { count in
        sequence(Array(repeating: aiDetectionGen, count: count))
    }

/// Generates a pair of thresholds (T1, T2) where T1 < T2, both in [0.0, 1.0].
/// We pick two distinct values and sort them to guarantee T1 < T2.
private let thresholdPairGen: Gen<(Float, Float)> = Gen.zip(
    confidenceScoreGen,
    confidenceScoreGen
).suchThat { t1, t2 in
    t1 != t2
}.map { a, b in
    a < b ? (a, b) : (b, a)
}

// MARK: - Pure filtering helper (mirrors CountingViewModel.filteredDetections)

/// Returns detections whose confidenceScore >= threshold.
private func filter(detections: [AIDetection], threshold: Float) -> [AIDetection] {
    detections.filter { $0.confidenceScore >= threshold }
}

// MARK: - Tests

final class ConfidenceThresholdTests: XCTestCase {

    // MARK: Property 3: Confidence threshold filtering is monotone
    //
    // For any set of AI_Detections and any two threshold values T1 < T2,
    // the set of detections displayed at threshold T2 SHALL be a subset of
    // the detections displayed at threshold T1 (raising the threshold never
    // adds detections).
    //
    // Validates: Requirements 5.5, 5.6

    func testConfidenceThresholdFilteringIsMonotone() {
        // SwiftCheck property: for any list of AIDetections and any T1 < T2,
        // every detection shown at T2 is also shown at T1.
        property("Confidence threshold filtering is monotone: detections(T2) ⊆ detections(T1) for T1 < T2") <- forAll(
            aiDetectionListGen,
            thresholdPairGen
        ) { detections, thresholds in
            let (t1, t2) = thresholds
            // t1 < t2 is guaranteed by thresholdPairGen
            let atT1 = filter(detections: detections, threshold: t1)
            let atT2 = filter(detections: detections, threshold: t2)

            let idsAtT1 = Set(atT1.map { $0.id })
            let idsAtT2 = Set(atT2.map { $0.id })

            // Every detection shown at the higher threshold must also appear
            // at the lower threshold — i.e. idsAtT2 ⊆ idsAtT1.
            return idsAtT2.isSubset(of: idsAtT1)
        }
    }

    // MARK: - Additional property: count is non-increasing as threshold rises

    func testFilteredCountIsNonIncreasingWithRisingThreshold() {
        // For any detections and T1 < T2, |detections(T2)| <= |detections(T1)|.
        property("Filtered detection count is non-increasing as threshold rises") <- forAll(
            aiDetectionListGen,
            thresholdPairGen
        ) { detections, thresholds in
            let (t1, t2) = thresholds
            let countAtT1 = filter(detections: detections, threshold: t1).count
            let countAtT2 = filter(detections: detections, threshold: t2).count
            return countAtT2 <= countAtT1
        }
    }

    // MARK: - Unit tests

    /// Filtering an empty detection list always returns empty, regardless of threshold.
    func testEmptyDetectionsAlwaysReturnsEmpty() {
        let detections: [AIDetection] = []
        for threshold: Float in [0.0, 0.25, 0.5, 0.75, 1.0] {
            let result = filter(detections: detections, threshold: threshold)
            XCTAssertTrue(result.isEmpty,
                          "Empty detections filtered at \(threshold) should still be empty")
        }
    }

    /// When T1 == T2, the filtered sets are identical.
    func testEqualThresholdsProduceSameResult() {
        let detections = [
            AIDetection(normalizedBoundingBox: .zero, label: "a", confidenceScore: 0.3),
            AIDetection(normalizedBoundingBox: .zero, label: "b", confidenceScore: 0.7),
            AIDetection(normalizedBoundingBox: .zero, label: "c", confidenceScore: 0.5),
        ]
        let threshold: Float = 0.5
        let result1 = filter(detections: detections, threshold: threshold)
        let result2 = filter(detections: detections, threshold: threshold)
        XCTAssertEqual(result1.map { $0.id }, result2.map { $0.id },
                       "Same threshold must produce identical results")
    }

    /// All detections above the threshold are included; none below are.
    func testAllDetectionsAboveThresholdAreIncluded() {
        let threshold: Float = 0.6
        let above = [
            AIDetection(normalizedBoundingBox: .zero, label: "a", confidenceScore: 0.6),
            AIDetection(normalizedBoundingBox: .zero, label: "b", confidenceScore: 0.8),
            AIDetection(normalizedBoundingBox: .zero, label: "c", confidenceScore: 1.0),
        ]
        let below = [
            AIDetection(normalizedBoundingBox: .zero, label: "d", confidenceScore: 0.0),
            AIDetection(normalizedBoundingBox: .zero, label: "e", confidenceScore: 0.3),
            AIDetection(normalizedBoundingBox: .zero, label: "f", confidenceScore: 0.59),
        ]
        let all = above + below
        let result = filter(detections: all, threshold: threshold)

        let resultIDs = Set(result.map { $0.id })
        let aboveIDs = Set(above.map { $0.id })
        let belowIDs = Set(below.map { $0.id })

        XCTAssertEqual(resultIDs, aboveIDs,
                       "All detections at or above threshold should be included")
        XCTAssertTrue(resultIDs.isDisjoint(with: belowIDs),
                      "No detections below threshold should be included")
    }

    /// All detections below the threshold are excluded.
    func testAllDetectionsBelowThresholdAreExcluded() {
        let threshold: Float = 0.9
        let detections = [
            AIDetection(normalizedBoundingBox: .zero, label: "a", confidenceScore: 0.1),
            AIDetection(normalizedBoundingBox: .zero, label: "b", confidenceScore: 0.5),
            AIDetection(normalizedBoundingBox: .zero, label: "c", confidenceScore: 0.89),
        ]
        let result = filter(detections: detections, threshold: threshold)
        XCTAssertTrue(result.isEmpty,
                      "All detections below threshold 0.9 should be excluded")
    }

    /// Threshold of 0.0 includes every detection.
    func testThresholdZeroIncludesAllDetections() {
        let detections = [
            AIDetection(normalizedBoundingBox: .zero, label: "a", confidenceScore: 0.0),
            AIDetection(normalizedBoundingBox: .zero, label: "b", confidenceScore: 0.5),
            AIDetection(normalizedBoundingBox: .zero, label: "c", confidenceScore: 1.0),
        ]
        let result = filter(detections: detections, threshold: 0.0)
        XCTAssertEqual(result.count, detections.count,
                       "Threshold 0.0 should include all detections")
    }

    /// Threshold of 1.0 includes only detections with score exactly 1.0.
    func testThresholdOneIncludesOnlyPerfectScores() {
        let perfect = AIDetection(normalizedBoundingBox: .zero, label: "perfect", confidenceScore: 1.0)
        let detections = [
            AIDetection(normalizedBoundingBox: .zero, label: "a", confidenceScore: 0.5),
            AIDetection(normalizedBoundingBox: .zero, label: "b", confidenceScore: 0.99),
            perfect,
        ]
        let result = filter(detections: detections, threshold: 1.0)
        XCTAssertEqual(result.count, 1, "Only the detection with score 1.0 should pass threshold 1.0")
        XCTAssertEqual(result.first?.id, perfect.id)
    }

    /// Raising the threshold from T1 to T2 never adds new detections to the result.
    func testRaisingThresholdNeverAddsDetections() {
        let detections = [
            AIDetection(normalizedBoundingBox: .zero, label: "a", confidenceScore: 0.2),
            AIDetection(normalizedBoundingBox: .zero, label: "b", confidenceScore: 0.5),
            AIDetection(normalizedBoundingBox: .zero, label: "c", confidenceScore: 0.7),
            AIDetection(normalizedBoundingBox: .zero, label: "d", confidenceScore: 0.9),
        ]
        let thresholds: [Float] = [0.1, 0.3, 0.5, 0.7, 0.9, 1.0]
        var previousCount = Int.max

        for threshold in thresholds {
            let count = filter(detections: detections, threshold: threshold).count
            XCTAssertLessThanOrEqual(count, previousCount,
                "Raising threshold to \(threshold) should not increase detection count")
            previousCount = count
        }
    }

    // MARK: - CountingViewModel integration

    /// CountingViewModel.filteredDetections respects the monotonicity property.
    @MainActor
    func testCountingViewModelFilteredDetectionsIsMonotone() async {
        let session = CountSession(name: "Threshold Test Session")
        let viewModel = CountingViewModel(session: session)

        // Populate with detections spanning the full confidence range.
        viewModel.detections = [
            AIDetection(normalizedBoundingBox: .zero, label: "a", confidenceScore: 0.1),
            AIDetection(normalizedBoundingBox: .zero, label: "b", confidenceScore: 0.3),
            AIDetection(normalizedBoundingBox: .zero, label: "c", confidenceScore: 0.5),
            AIDetection(normalizedBoundingBox: .zero, label: "d", confidenceScore: 0.7),
            AIDetection(normalizedBoundingBox: .zero, label: "e", confidenceScore: 0.9),
        ]

        let thresholds: [Float] = [0.1, 0.3, 0.5, 0.7, 0.9]
        var previousIDs: Set<UUID>? = nil

        for threshold in thresholds {
            viewModel.confidenceThreshold = threshold
            let currentIDs = Set(viewModel.filteredDetections.map { $0.id })

            if let prev = previousIDs {
                XCTAssertTrue(currentIDs.isSubset(of: prev),
                    "filteredDetections at threshold \(threshold) must be a subset of those at the previous lower threshold")
            }
            previousIDs = currentIDs
        }
    }
}

// MARK: - SwiftCheck helper

/// Sequences a list of generators into a generator of lists.
private func sequence<T>(_ gens: [Gen<T>]) -> Gen<[T]> {
    guard !gens.isEmpty else { return Gen.pure([]) }
    return gens.reduce(Gen.pure([])) { acc, gen in
        acc.flatMap { list in
            gen.map { element in list + [element] }
        }
    }
}
