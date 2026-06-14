import XCTest
import SwiftCheck
@testable import OpenCount

// Feature: open-count-ios, Property 16: Annotation layer toggle does not mutate data
// Validates: Requirements 34.5

// MARK: - Tests

final class AnnotationLayerToggleTests: XCTestCase {

    // MARK: Property 16: Annotation layer toggle does not mutate data
    //
    // For any AnnotationLayerViewModel with any combination of annotation data
    // (text annotations, measure lines, arrow annotations), toggling any
    // AnnotationLayerType on and off N times SHALL leave the underlying annotation
    // arrays completely unchanged.
    //
    // The property asserts:
    //   After N toggle cycles on any layer:
    //     textAnnotations.count == original textAnnotations.count
    //     measureLines.count   == original measureLines.count
    //     arrowAnnotations.count == original arrowAnnotations.count
    //     textAnnotations contents are identical (by id)
    //     measureLines contents are identical (by id)
    //     arrowAnnotations contents are identical (by id)
    //
    // Validates: Requirements 34.5

    func testAnnotationLayerToggleDoesNotMutateData() {
        // SwiftCheck property: for any combination of annotation counts, any
        // AnnotationLayerType, and any number of toggle cycles (1–20), toggling
        // the layer N times leaves all underlying annotation arrays unchanged.
        property("Toggling an annotation layer N times does not mutate annotation arrays") <- forAll(
            Gen<Int>.choose((0, 8)),    // number of text annotations
            Gen<Int>.choose((0, 8)),    // number of measure lines
            Gen<Int>.choose((0, 8)),    // number of arrow annotations
            Gen<Int>.fromElements(of: AnnotationLayerType.allCases),  // layer to toggle
            Gen<Int>.choose((1, 20))    // number of toggle cycles
        ) { textCount, lineCount, arrowCount, layerType, toggleCount in
            let semaphore = DispatchSemaphore(value: 0)
            var result = false

            Task { @MainActor in
                defer { semaphore.signal() }
                result = Self.annotationLayerTogglePropertyHolds(
                    textCount: textCount,
                    lineCount: lineCount,
                    arrowCount: arrowCount,
                    layerType: layerType,
                    toggleCount: toggleCount
                )
            }

            semaphore.wait()
            return result
        }
    }

    // MARK: - Core property helper

    /// Builds an `AnnotationLayerViewModel` with the given annotation counts,
    /// toggles `layerType` exactly `toggleCount` times, then asserts that all
    /// underlying annotation arrays are structurally identical to their pre-toggle state.
    @MainActor
    private static func annotationLayerTogglePropertyHolds(
        textCount: Int,
        lineCount: Int,
        arrowCount: Int,
        layerType: AnnotationLayerType,
        toggleCount: Int
    ) -> Bool {
        let vm = AnnotationLayerViewModel()

        // 1. Populate text annotations
        for i in 0..<textCount {
            vm.addTextAnnotation(
                at: CGPoint(x: Double(i) * 0.1, y: Double(i) * 0.1),
                text: "Label \(i)",
                fontSize: 16,
                colorHex: "#FFFFFF"
            )
        }

        // 2. Populate measure lines
        for i in 0..<lineCount {
            vm.addMeasureLine(
                from: CGPoint(x: Double(i) * 0.1, y: 0.0),
                to: CGPoint(x: Double(i) * 0.1, y: 1.0),
                colorHex: "#FFFF00"
            )
        }

        // 3. Populate arrow annotations
        for i in 0..<arrowCount {
            vm.addArrow(
                from: CGPoint(x: 0.0, y: Double(i) * 0.1),
                to: CGPoint(x: 1.0, y: Double(i) * 0.1),
                colorHex: "#FF0000"
            )
        }

        // 4. Snapshot the annotation arrays before any toggles
        let originalTextAnnotations = vm.textAnnotations
        let originalMeasureLines = vm.measureLines
        let originalArrowAnnotations = vm.arrowAnnotations

        // 5. Toggle the layer N times
        for _ in 0..<toggleCount {
            vm.toggleLayer(layerType)
        }

        // 6. Assert Property 16: annotation arrays are unchanged

        // Invariant A: counts are identical
        guard vm.textAnnotations.count == originalTextAnnotations.count else { return false }
        guard vm.measureLines.count == originalMeasureLines.count else { return false }
        guard vm.arrowAnnotations.count == originalArrowAnnotations.count else { return false }

        // Invariant B: text annotation contents are identical (by id and text)
        for (original, current) in zip(originalTextAnnotations, vm.textAnnotations) {
            guard original.id == current.id,
                  original.text == current.text,
                  original.normalizedPosition == current.normalizedPosition else { return false }
        }

        // Invariant C: measure line contents are identical (by id and endpoints)
        for (original, current) in zip(originalMeasureLines, vm.measureLines) {
            guard original.id == current.id,
                  original.startPoint == current.startPoint,
                  original.endPoint == current.endPoint else { return false }
        }

        // Invariant D: arrow annotation contents are identical (by id and endpoints)
        for (original, current) in zip(originalArrowAnnotations, vm.arrowAnnotations) {
            guard original.id == current.id,
                  original.tailPoint == current.tailPoint,
                  original.headPoint == current.headPoint else { return false }
        }

        return true
    }

    // MARK: - Unit tests

    /// Toggling a visible layer hides it; toggling again restores it.
    func testToggleLayerChangesVisibility() async {
        let vm = await MainActor.run { AnnotationLayerViewModel() }

        // All layers start visible
        let allVisible = await MainActor.run {
            AnnotationLayerType.allCases.allSatisfy { vm.isVisible($0) }
        }
        XCTAssertTrue(allVisible, "All layers should be visible initially")

        // Toggle markers off
        await MainActor.run { vm.toggleLayer(.markers) }
        let markersHidden = await MainActor.run { !vm.isVisible(.markers) }
        XCTAssertTrue(markersHidden, "Markers layer should be hidden after one toggle")

        // Toggle markers back on
        await MainActor.run { vm.toggleLayer(.markers) }
        let markersVisible = await MainActor.run { vm.isVisible(.markers) }
        XCTAssertTrue(markersVisible, "Markers layer should be visible after second toggle")
    }

    /// Toggling a layer does not change the count of text annotations.
    func testToggleDoesNotChangeTextAnnotationCount() async {
        let vm = await MainActor.run { AnnotationLayerViewModel() }

        await MainActor.run {
            vm.addTextAnnotation(at: CGPoint(x: 0.1, y: 0.2), text: "A")
            vm.addTextAnnotation(at: CGPoint(x: 0.5, y: 0.5), text: "B")
            vm.addTextAnnotation(at: CGPoint(x: 0.9, y: 0.8), text: "C")
        }

        let countBefore = await MainActor.run { vm.textAnnotations.count }
        XCTAssertEqual(countBefore, 3)

        // Toggle textLabels layer 10 times
        await MainActor.run {
            for _ in 0..<10 { vm.toggleLayer(.textLabels) }
        }

        let countAfter = await MainActor.run { vm.textAnnotations.count }
        XCTAssertEqual(countAfter, 3, "Text annotation count must not change after 10 toggles")
    }

    /// Toggling a layer does not change the count of measure lines.
    func testToggleDoesNotChangeMeasureLineCount() async {
        let vm = await MainActor.run { AnnotationLayerViewModel() }

        await MainActor.run {
            vm.addMeasureLine(from: CGPoint(x: 0.0, y: 0.0), to: CGPoint(x: 1.0, y: 1.0))
            vm.addMeasureLine(from: CGPoint(x: 0.2, y: 0.3), to: CGPoint(x: 0.8, y: 0.7))
        }

        let countBefore = await MainActor.run { vm.measureLines.count }
        XCTAssertEqual(countBefore, 2)

        // Toggle measureLines layer 7 times
        await MainActor.run {
            for _ in 0..<7 { vm.toggleLayer(.measureLines) }
        }

        let countAfter = await MainActor.run { vm.measureLines.count }
        XCTAssertEqual(countAfter, 2, "Measure line count must not change after 7 toggles")
    }

    /// Toggling a layer does not change the count of arrow annotations.
    func testToggleDoesNotChangeArrowAnnotationCount() async {
        let vm = await MainActor.run { AnnotationLayerViewModel() }

        await MainActor.run {
            vm.addArrow(from: CGPoint(x: 0.1, y: 0.1), to: CGPoint(x: 0.9, y: 0.9))
        }

        let countBefore = await MainActor.run { vm.arrowAnnotations.count }
        XCTAssertEqual(countBefore, 1)

        // Toggle arrows layer 15 times
        await MainActor.run {
            for _ in 0..<15 { vm.toggleLayer(.arrows) }
        }

        let countAfter = await MainActor.run { vm.arrowAnnotations.count }
        XCTAssertEqual(countAfter, 1, "Arrow annotation count must not change after 15 toggles")
    }

    /// Toggling all layer types in sequence does not mutate any annotation array.
    func testToggleAllLayersDoesNotMutateAnyArray() async {
        let vm = await MainActor.run { AnnotationLayerViewModel() }

        await MainActor.run {
            vm.addTextAnnotation(at: CGPoint(x: 0.5, y: 0.5), text: "Test")
            vm.addMeasureLine(from: CGPoint(x: 0.0, y: 0.5), to: CGPoint(x: 1.0, y: 0.5))
            vm.addArrow(from: CGPoint(x: 0.2, y: 0.2), to: CGPoint(x: 0.8, y: 0.8))
        }

        let (textBefore, linesBefore, arrowsBefore) = await MainActor.run {
            (vm.textAnnotations.count, vm.measureLines.count, vm.arrowAnnotations.count)
        }

        // Toggle every layer type twice
        await MainActor.run {
            for layer in AnnotationLayerType.allCases {
                vm.toggleLayer(layer)
                vm.toggleLayer(layer)
            }
        }

        let (textAfter, linesAfter, arrowsAfter) = await MainActor.run {
            (vm.textAnnotations.count, vm.measureLines.count, vm.arrowAnnotations.count)
        }

        XCTAssertEqual(textAfter, textBefore, "Text annotations unchanged after toggling all layers")
        XCTAssertEqual(linesAfter, linesBefore, "Measure lines unchanged after toggling all layers")
        XCTAssertEqual(arrowsAfter, arrowsBefore, "Arrow annotations unchanged after toggling all layers")
    }

    /// Toggling a layer an even number of times restores the original visibility state.
    func testEvenNumberOfTogglesRestoresVisibility() async {
        let vm = await MainActor.run { AnnotationLayerViewModel() }

        for layer in AnnotationLayerType.allCases {
            let visibilityBefore = await MainActor.run { vm.isVisible(layer) }

            // Toggle an even number of times (6)
            await MainActor.run {
                for _ in 0..<6 { vm.toggleLayer(layer) }
            }

            let visibilityAfter = await MainActor.run { vm.isVisible(layer) }
            XCTAssertEqual(
                visibilityAfter, visibilityBefore,
                "Visibility of \(layer.rawValue) should be restored after 6 (even) toggles"
            )
        }
    }

    /// Toggling a layer an odd number of times flips the visibility state.
    func testOddNumberOfTogglesFlipsVisibility() async {
        let vm = await MainActor.run { AnnotationLayerViewModel() }

        for layer in AnnotationLayerType.allCases {
            let visibilityBefore = await MainActor.run { vm.isVisible(layer) }

            // Toggle an odd number of times (5)
            await MainActor.run {
                for _ in 0..<5 { vm.toggleLayer(layer) }
            }

            let visibilityAfter = await MainActor.run { vm.isVisible(layer) }
            XCTAssertNotEqual(
                visibilityAfter, visibilityBefore,
                "Visibility of \(layer.rawValue) should be flipped after 5 (odd) toggles"
            )
        }
    }
}
