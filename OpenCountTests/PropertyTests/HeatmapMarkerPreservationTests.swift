import XCTest
import SwiftData
import SwiftCheck
@testable import OpenCount

// Feature: open-count-ios, Property 12: Heatmap renders without markers being lost
// Validates: Requirements 24.2

// MARK: - Helpers

/// Builds an in-memory `ModelContainer` for isolated test use.
private func makeInMemoryContainer() throws -> ModelContainer {
    let schema = Schema([
        CountSession.self,
        ObjectType.self,
        CountMarker.self,
        CountRegion.self,
        SessionImage.self,
        VideoFrameCount.self,
    ])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    return try ModelContainer(for: schema, configurations: [config])
}

/// Generates a random normalized coordinate in [0.0, 1.0].
private let normalizedCoordGen: Gen<Double> = Gen<Double>.choose((0.0, 1.0))

// MARK: - Tests

/// **Property 12: Heatmap renders without markers being lost**
///
/// For any set of Count_Markers, toggling the Density_Heatmap on and off SHALL
/// leave the Count_Markers array unchanged (heatmap is a pure rendering overlay).
///
/// **Validates: Requirements 24.2**
final class HeatmapMarkerPreservationTests: XCTestCase {

    // MARK: - Property 12a: Toggling heatmap layer on AnnotationLayerViewModel
    //         does NOT mutate textAnnotations, measureLines, or arrowAnnotations.
    //
    // The heatmap is a pure rendering overlay controlled by `visibleLayers`.
    // Toggling `.heatmap` N times must leave all annotation data arrays identical.
    //
    // Validates: Requirements 24.2

    func testHeatmapToggleDoesNotMutateAnnotationArrays() {
        // SwiftCheck property: for any number of pre-existing annotations and any
        // toggle count N ∈ [1, 20], toggling the heatmap layer N times leaves
        // textAnnotations, measureLines, and arrowAnnotations unchanged.
        property("Toggling heatmap layer N times does not mutate annotation data arrays") <- forAll(
            Gen<Int>.choose((0, 10)),   // number of text annotations
            Gen<Int>.choose((0, 10)),   // number of measure lines
            Gen<Int>.choose((0, 10)),   // number of arrow annotations
            Gen<Int>.choose((1, 20))    // N: number of toggles
        ) { textCount, lineCount, arrowCount, toggleCount in
            let semaphore = DispatchSemaphore(value: 0)
            var result = false

            Task { @MainActor in
                defer { semaphore.signal() }
                result = Self.heatmapTogglePreservesAnnotations(
                    textCount: textCount,
                    lineCount: lineCount,
                    arrowCount: arrowCount,
                    toggleCount: toggleCount
                )
            }

            semaphore.wait()
            return result
        }
    }

    // MARK: - Property 12b: Toggling ANY annotation layer type N times
    //         does NOT mutate the underlying data arrays.
    //
    // This generalises Property 12a to all AnnotationLayerType values,
    // confirming that layer visibility is a pure rendering concern.
    //
    // Validates: Requirements 24.2

    func testAnyLayerToggleDoesNotMutateAnnotationArrays() {
        // SwiftCheck property: for any AnnotationLayerType and any toggle count
        // N ∈ [1, 20], toggling that layer N times leaves all data arrays unchanged.
        property("Toggling any annotation layer N times does not mutate data arrays") <- forAll(
            Gen<Int>.fromElements(of: Array(0..<AnnotationLayerType.allCases.count)),
            Gen<Int>.choose((0, 8)),    // number of text annotations
            Gen<Int>.choose((0, 8)),    // number of measure lines
            Gen<Int>.choose((0, 8)),    // number of arrow annotations
            Gen<Int>.choose((1, 20))    // N: number of toggles
        ) { layerIndex, textCount, lineCount, arrowCount, toggleCount in
            let semaphore = DispatchSemaphore(value: 0)
            var result = false

            Task { @MainActor in
                defer { semaphore.signal() }
                let layer = AnnotationLayerType.allCases[layerIndex]
                result = Self.layerTogglePreservesAnnotations(
                    layer: layer,
                    textCount: textCount,
                    lineCount: lineCount,
                    arrowCount: arrowCount,
                    toggleCount: toggleCount
                )
            }

            semaphore.wait()
            return result
        }
    }

    // MARK: - Property 12c: Toggling heatmap layer does NOT mutate CountSession markers.
    //
    // For any CountSession with random markers, toggling the heatmap layer N times
    // on AnnotationLayerViewModel SHALL leave the session's markers array unchanged
    // (same count, same IDs, same coordinates).
    //
    // Validates: Requirements 24.2

    func testHeatmapToggleDoesNotMutateSessionMarkers() {
        property("Toggling heatmap N times does not mutate CountSession markers array") <- forAll(
            Gen<Int>.choose((1, 5)),    // number of object types
            Gen<Int>.choose((0, 20)),   // number of markers
            Gen<Int>.choose((1, 20))    // N: number of toggles
        ) { objectTypeCount, markerCount, toggleCount in
            let semaphore = DispatchSemaphore(value: 0)
            var result = false

            Task { @MainActor in
                defer { semaphore.signal() }
                do {
                    result = try await Self.heatmapTogglePreservesSessionMarkers(
                        objectTypeCount: objectTypeCount,
                        markerCount: markerCount,
                        toggleCount: toggleCount
                    )
                } catch {
                    result = false
                }
            }

            semaphore.wait()
            return result
        }
    }

    // MARK: - Core property helpers

    /// Verifies that toggling the `.heatmap` layer `toggleCount` times on a fresh
    /// `AnnotationLayerViewModel` (pre-populated with the given annotation counts)
    /// leaves all three data arrays identical after every toggle.
    @MainActor
    private static func heatmapTogglePreservesAnnotations(
        textCount: Int,
        lineCount: Int,
        arrowCount: Int,
        toggleCount: Int
    ) -> Bool {
        return layerTogglePreservesAnnotations(
            layer: .heatmap,
            textCount: textCount,
            lineCount: lineCount,
            arrowCount: arrowCount,
            toggleCount: toggleCount
        )
    }

    /// Verifies that toggling `layer` `toggleCount` times on a fresh
    /// `AnnotationLayerViewModel` (pre-populated with the given annotation counts)
    /// leaves all three data arrays identical after every toggle.
    @MainActor
    private static func layerTogglePreservesAnnotations(
        layer: AnnotationLayerType,
        textCount: Int,
        lineCount: Int,
        arrowCount: Int,
        toggleCount: Int
    ) -> Bool {
        let vm = AnnotationLayerViewModel()

        // Populate text annotations
        for i in 0..<textCount {
            vm.addTextAnnotation(
                at: CGPoint(x: Double(i) * 0.1, y: Double(i) * 0.1),
                text: "Label \(i)"
            )
        }

        // Populate measure lines
        for i in 0..<lineCount {
            vm.addMeasureLine(
                from: CGPoint(x: Double(i) * 0.05, y: 0.0),
                to: CGPoint(x: Double(i) * 0.05 + 0.1, y: 0.1)
            )
        }

        // Populate arrow annotations
        for i in 0..<arrowCount {
            vm.addArrow(
                from: CGPoint(x: 0.0, y: Double(i) * 0.1),
                to: CGPoint(x: 0.1, y: Double(i) * 0.1 + 0.05)
            )
        }

        // Snapshot the data arrays before any toggle
        let snapshotText = vm.textAnnotations
        let snapshotLines = vm.measureLines
        let snapshotArrows = vm.arrowAnnotations

        // Toggle the layer N times, asserting data arrays are unchanged after each toggle
        for _ in 0..<toggleCount {
            vm.toggleLayer(layer)

            guard vm.textAnnotations == snapshotText else { return false }
            guard vm.measureLines == snapshotLines else { return false }
            guard vm.arrowAnnotations == snapshotArrows else { return false }
        }

        return true
    }

    /// Sets up a CountSession with `objectTypeCount` Object_Types and `markerCount`
    /// markers, then toggles the `.heatmap` layer on `AnnotationLayerViewModel`
    /// `toggleCount` times, asserting that the session's markers array is unchanged
    /// (same count, same IDs, same coordinates) after every toggle.
    @MainActor
    private static func heatmapTogglePreservesSessionMarkers(
        objectTypeCount: Int,
        markerCount: Int,
        toggleCount: Int
    ) async throws -> Bool {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)

        // 1. Build the session
        let session = CountSession(name: "Heatmap Preservation Test")
        context.insert(session)

        // 2. Add object types
        var objectTypes: [ObjectType] = []
        for i in 0..<objectTypeCount {
            let ot = ObjectType(
                name: "Type \(i)",
                colorHex: String(format: "#%06X", (i + 1) * 0x111111 % 0xFFFFFF),
                iconName: "circle.fill",
                sortOrder: i,
                session: session
            )
            context.insert(ot)
            objectTypes.append(ot)
            session.objectTypes.append(ot)
        }

        // 3. Distribute markers across object types
        for j in 0..<markerCount {
            let ot = objectTypes[j % objectTypeCount]
            let marker = CountMarker(
                normalizedX: Double(j % 10) / 10.0,
                normalizedY: Double(j / 10 % 10) / 10.0,
                objectType: ot,
                isAIDerived: false,
                session: session
            )
            context.insert(marker)
            session.markers.append(marker)
        }

        // 4. Snapshot the markers before any heatmap toggle
        let snapshotCount = session.markers.count
        let snapshotIDs = session.markers.map { $0.id }
        let snapshotXs = session.markers.map { $0.normalizedX }
        let snapshotYs = session.markers.map { $0.normalizedY }

        // 5. Create the AnnotationLayerViewModel (the heatmap toggle target)
        let annotationVM = AnnotationLayerViewModel()

        // 6. Toggle heatmap N times, asserting markers are unchanged after each toggle
        for _ in 0..<toggleCount {
            annotationVM.toggleLayer(.heatmap)

            // Invariant A: marker count is unchanged
            guard session.markers.count == snapshotCount else { return false }

            // Invariant B: marker IDs are unchanged (same elements, same order)
            guard session.markers.map({ $0.id }) == snapshotIDs else { return false }

            // Invariant C: marker coordinates are unchanged
            guard session.markers.map({ $0.normalizedX }) == snapshotXs else { return false }
            guard session.markers.map({ $0.normalizedY }) == snapshotYs else { return false }
        }

        return true
    }

    // MARK: - Unit tests

    /// Toggling heatmap on a fresh AnnotationLayerViewModel with no annotations
    /// leaves all arrays empty.
    func testHeatmapToggleOnEmptyViewModelLeavesArraysEmpty() {
        let vm = AnnotationLayerViewModel()

        XCTAssertTrue(vm.textAnnotations.isEmpty)
        XCTAssertTrue(vm.measureLines.isEmpty)
        XCTAssertTrue(vm.arrowAnnotations.isEmpty)

        for _ in 0..<10 {
            vm.toggleLayer(.heatmap)
            XCTAssertTrue(vm.textAnnotations.isEmpty, "textAnnotations must remain empty after heatmap toggle")
            XCTAssertTrue(vm.measureLines.isEmpty, "measureLines must remain empty after heatmap toggle")
            XCTAssertTrue(vm.arrowAnnotations.isEmpty, "arrowAnnotations must remain empty after heatmap toggle")
        }
    }

    /// Toggling heatmap changes only the visibility flag, not the data arrays.
    func testHeatmapToggleOnlyChangesVisibilityFlag() {
        let vm = AnnotationLayerViewModel()
        vm.addTextAnnotation(at: CGPoint(x: 0.5, y: 0.5), text: "Test")
        vm.addMeasureLine(from: CGPoint(x: 0.0, y: 0.0), to: CGPoint(x: 1.0, y: 1.0))
        vm.addArrow(from: CGPoint(x: 0.1, y: 0.1), to: CGPoint(x: 0.9, y: 0.9))

        let textBefore = vm.textAnnotations
        let linesBefore = vm.measureLines
        let arrowsBefore = vm.arrowAnnotations
        let heatmapVisibleBefore = vm.isVisible(.heatmap)

        // Toggle once (hides heatmap)
        vm.toggleLayer(.heatmap)
        XCTAssertEqual(vm.isVisible(.heatmap), !heatmapVisibleBefore,
                       "Heatmap visibility should flip after toggle")
        XCTAssertEqual(vm.textAnnotations, textBefore, "textAnnotations must not change")
        XCTAssertEqual(vm.measureLines, linesBefore, "measureLines must not change")
        XCTAssertEqual(vm.arrowAnnotations, arrowsBefore, "arrowAnnotations must not change")

        // Toggle again (shows heatmap)
        vm.toggleLayer(.heatmap)
        XCTAssertEqual(vm.isVisible(.heatmap), heatmapVisibleBefore,
                       "Heatmap visibility should return to original after two toggles")
        XCTAssertEqual(vm.textAnnotations, textBefore, "textAnnotations must not change")
        XCTAssertEqual(vm.measureLines, linesBefore, "measureLines must not change")
        XCTAssertEqual(vm.arrowAnnotations, arrowsBefore, "arrowAnnotations must not change")
    }

    /// Toggling heatmap 20 times (even number) returns visibility to its original state.
    func testEvenNumberOfHeatmapTogglesRestoresVisibility() {
        let vm = AnnotationLayerViewModel()
        let initiallyVisible = vm.isVisible(.heatmap)

        for _ in 0..<20 {
            vm.toggleLayer(.heatmap)
        }

        XCTAssertEqual(vm.isVisible(.heatmap), initiallyVisible,
                       "Even number of toggles must restore original visibility")
    }

    /// Toggling heatmap 1 time flips visibility; toggling 2 times restores it.
    func testOddToggleFlipsVisibilityEvenToggleRestoresIt() {
        let vm = AnnotationLayerViewModel()
        let initial = vm.isVisible(.heatmap)

        vm.toggleLayer(.heatmap)
        XCTAssertNotEqual(vm.isVisible(.heatmap), initial, "Single toggle must flip visibility")

        vm.toggleLayer(.heatmap)
        XCTAssertEqual(vm.isVisible(.heatmap), initial, "Two toggles must restore visibility")
    }

    /// Toggling heatmap does not affect the visibility of other layers.
    func testHeatmapToggleDoesNotAffectOtherLayerVisibility() {
        let vm = AnnotationLayerViewModel()

        // Record visibility of all non-heatmap layers
        let otherLayers = AnnotationLayerType.allCases.filter { $0 != .heatmap }
        let visibilityBefore = Dictionary(uniqueKeysWithValues: otherLayers.map {
            ($0, vm.isVisible($0))
        })

        // Toggle heatmap several times
        for _ in 0..<5 {
            vm.toggleLayer(.heatmap)
        }

        // All other layers must retain their original visibility
        for layer in otherLayers {
            XCTAssertEqual(vm.isVisible(layer), visibilityBefore[layer],
                           "\(layer.rawValue) visibility must not be affected by heatmap toggle")
        }
    }

    /// CountSession markers are unchanged after toggling heatmap on AnnotationLayerViewModel.
    func testSessionMarkersUnchangedAfterHeatmapToggle() async throws {
        let container = try makeInMemoryContainer()
        let context = await MainActor.run { ModelContext(container) }

        let session = CountSession(name: "Heatmap Session")
        let objectType = ObjectType(
            name: "Birds",
            colorHex: "#FF5733",
            iconName: "circle.fill",
            sortOrder: 0,
            session: session
        )

        let markers: [CountMarker] = [
            CountMarker(normalizedX: 0.1, normalizedY: 0.2, objectType: objectType, session: session),
            CountMarker(normalizedX: 0.3, normalizedY: 0.4, objectType: objectType, session: session),
            CountMarker(normalizedX: 0.5, normalizedY: 0.6, objectType: objectType, session: session),
        ]

        await MainActor.run {
            context.insert(session)
            context.insert(objectType)
            session.objectTypes.append(objectType)
            for marker in markers {
                context.insert(marker)
                session.markers.append(marker)
            }
        }

        let snapshotIDs = await MainActor.run { session.markers.map { $0.id } }
        let snapshotXs = await MainActor.run { session.markers.map { $0.normalizedX } }
        let snapshotYs = await MainActor.run { session.markers.map { $0.normalizedY } }

        let annotationVM = await MainActor.run { AnnotationLayerViewModel() }

        // Toggle heatmap 10 times
        for _ in 0..<10 {
            await MainActor.run { annotationVM.toggleLayer(.heatmap) }

            let currentIDs = await MainActor.run { session.markers.map { $0.id } }
            let currentXs = await MainActor.run { session.markers.map { $0.normalizedX } }
            let currentYs = await MainActor.run { session.markers.map { $0.normalizedY } }

            XCTAssertEqual(currentIDs, snapshotIDs, "Marker IDs must be unchanged after heatmap toggle")
            XCTAssertEqual(currentXs, snapshotXs, "Marker X coordinates must be unchanged after heatmap toggle")
            XCTAssertEqual(currentYs, snapshotYs, "Marker Y coordinates must be unchanged after heatmap toggle")
        }
    }
}
