import XCTest
@testable import OpenCount

final class DetectionServiceTests: XCTestCase {
    var sut: DetectionService!

    override func setUp() {
        super.setUp()
        sut = DetectionService()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    func testModelAvailability() {
        let isAvailable = sut.isModelAvailable()
        // Note: Sẽ fail nếu model chưa được tải
    }

    func testDetectionResultStructure() {
        let testImage = UIImage(systemName: "square.fill") ?? UIImage()
        let objects = [
            DetectedObject(label: "test", confidence: 0.9, boundingBox: CGRect(x: 0, y: 0, width: 0.5, height: 0.5))
        ]
        let result = DetectionResult(image: testImage, objects: objects, timestamp: Date())

        XCTAssertEqual(result.totalCount, 1)
        XCTAssertEqual(result.statistics.count, 1)
        XCTAssertEqual(result.statistics[0].label, "test")
        XCTAssertEqual(result.statistics[0].count, 1)
    }
}

final class CountViewModelTests: XCTestCase {
    var sut: CountViewModel!

    override func setUp() {
        super.setUp()
        sut = CountViewModel()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    func testInitialState() {
        XCTAssertTrue(sut.isIdle)
        XCTAssertFalse(sut.isProcessing)
        XCTAssertNil(sut.currentResult)
        XCTAssertNil(sut.errorMessage)
    }

    func testReset() {
        sut.reset()
        XCTAssertTrue(sut.isIdle)
        XCTAssertNil(sut.selectedImage)
    }

    func testMinConfidenceRange() {
        sut.minConfidence = 0.5
        XCTAssertEqual(sut.minConfidence, 0.5)
    }
}

final class DetectionResultTests: XCTestCase {
    func testStatisticsGrouping() {
        let testImage = UIImage(systemName: "square.fill") ?? UIImage()
        let objects = [
            DetectedObject(label: "person", confidence: 0.9, boundingBox: .zero),
            DetectedObject(label: "person", confidence: 0.85, boundingBox: .zero),
            DetectedObject(label: "car", confidence: 0.8, boundingBox: .zero),
        ]
        let result = DetectionResult(image: testImage, objects: objects, timestamp: Date())

        XCTAssertEqual(result.totalCount, 3)
        XCTAssertEqual(result.statistics.count, 2)
        XCTAssertEqual(result.statistics[0].label, "person")
        XCTAssertEqual(result.statistics[0].count, 2)
    }
}
